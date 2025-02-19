#version 460 core

#define WORKGROUP_SIZE 1024 / 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 5) buffer LastHistogramBuffer {
  uint g_last_histogram[];
};

shared uint l_last_histogram[WORKGROUP_SIZE];

// TODO: need to recurse as many level as needed since 256 x 256 isn't that big
// allocate 3 g_last_histogram SSBOs? 256^3 = 16 million

void main() {
  uint g_tid = gl_GlobalInvocationID.x;  // + gl_GlobalInvocationID.y +
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;

  // use first 0 - n / BLOCK_SIZE invocations to scan over last elements
  l_last_histogram[l_tid] = g_last_histogram[g_tid];

  uint stride = 2;

  // upsweep (reduction)
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
    }
    stride *= 2;
    barrier();
  }

  if (l_tid == WORKGROUP_SIZE - 1) {
    l_last_histogram[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < 256; d *= 2) {
    stride /= 2;
    if (l_tid < d) {
      uint copy = l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)];

      l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
      l_last_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)] = copy;
    }
    barrier();
  }

  g_last_histogram[g_tid] = l_last_histogram[l_tid];
}
