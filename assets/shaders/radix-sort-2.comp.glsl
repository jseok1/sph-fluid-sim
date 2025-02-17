#version 460 core

#define WORKGROUP_SIZE 256
#define RADIX 256
#define KEY_SIZE 8

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) buffer HistogramBuffer {
  uint g_histogram[];
};

shared uint l_histogram[WORKGROUP_SIZE];  // 256

void main() {
  uint g_tid = gl_GlobalInvocationID.x;  // + gl_GlobalInvocationID.y +
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;

  l_histogram[l_tid] = g_histogram[g_tid];

  uint stride = 2;

  // reduction
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
    }
    stride *= 2;
    barrier();
  }

  if (l_tid == WORKGROUP_SIZE - 1) {
    l_histogram[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < 256; d *= 2) {
    stride /= 2;
    if (l_tid < d) {
      uint copy = l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)];

      l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid)] +=
        l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)];
      l_histogram[WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2)] = copy;
    }
    barrier();
  }

  g_histogram[g_tid] = l_histogram[l_tid];
}
