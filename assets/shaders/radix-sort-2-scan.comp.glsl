#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) buffer OffsetsBuffer {
  uint g_offsets[];
};

shared uint l_offsets[WORKGROUP_SIZE];

uniform uint g_offsets_size;
uniform uint offset;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint n_workgroups = gl_NumWorkGroups.x;

  l_offsets[l_tid] = g_offsets[offset + g_tid];
  barrier();

  uint stride = 2;

  // TODO: WORKGROUP_SIZE should be RADIX
  // upsweep (reduction)
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);

      l_offsets[i] += l_offsets[j];
    }
    barrier();

    stride *= 2;
  }

  // if (n_workgroups > 1) {
  //   if (g_tid < ceil(n_workgroups / WORKGROUP_SIZE) * WORKGROUP_SIZE) {
  //     g_offsets[offset + WORKGROUP_SIZE * n_workgroups + g_tid] = 0;
  //   }
  // }
  // barrier();
  // ^ should optimize this below like above to only clear next layer
  if (offset + WORKGROUP_SIZE * n_workgroups + g_tid < g_offsets_size) {
    g_offsets[offset + WORKGROUP_SIZE * n_workgroups + g_tid] = 0;
  }

  if (l_tid == WORKGROUP_SIZE - 1) {
    if (n_workgroups > 1) {
      g_offsets[offset + WORKGROUP_SIZE * n_workgroups + wid] = l_offsets[l_tid];
    }
    l_offsets[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < WORKGROUP_SIZE; d *= 2) {
    stride /= 2;

    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);
      uint l_offset = l_offsets[i];

      l_offsets[i] += l_offsets[j];
      l_offsets[j] = l_offset;
    }
    barrier();
  }

  g_offsets[offset + g_tid] = l_offsets[l_tid];
}
