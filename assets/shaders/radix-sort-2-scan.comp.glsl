#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) buffer OffsetsBuffer {
  uint g_histogram[];
};

shared uint l_histogram[WORKGROUP_SIZE];

uniform uint g_offsets_size;  // maybe avoid full clear and clear inside this shader
uniform uint offset;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint WORKGROUPS = gl_NumWorkGroups.x;

  l_histogram[l_tid] = g_histogram[offset + g_tid];
  barrier();

  uint stride = 2;

  // TODO: WORKGROUP_SIZE should be RADIX
  // upsweep (reduction)
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);

      l_histogram[i] += l_histogram[j];
    }
    barrier();

    stride *= 2;
  }

  // if (WORKGROUPS > 1) {
  //   if (g_tid < ceil(WORKGROUPS / WORKGROUP_SIZE) * WORKGROUP_SIZE) {
  //     g_histogram[offset + WORKGROUP_SIZE * WORKGROUPS + g_tid] = 0;
  //   }
  // }
  // barrier();
  // ^ should optimize this below like above to only clear next layer
  // if (offset + WORKGROUP_SIZE * WORKGROUPS + g_tid < g_offsets_size) {
  //   g_histogram[offset + WORKGROUP_SIZE * WORKGROUPS + g_tid] = 0;
  // }

  if (l_tid == WORKGROUP_SIZE - 1) {
    if (WORKGROUPS > 1) {
      g_histogram[offset + WORKGROUP_SIZE * WORKGROUPS + wid] = l_histogram[l_tid];
    }
    l_histogram[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < WORKGROUP_SIZE; d *= 2) {
    stride /= 2;

    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);
      uint l_offset = l_histogram[i];

      l_histogram[i] += l_histogram[j];
      l_histogram[j] = l_offset;
    }
    barrier();
  }

  g_histogram[offset + g_tid] = l_histogram[l_tid];
}
