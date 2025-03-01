#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer InputBuffer {
  uint g_input[];
};

layout(std430, binding = 3) buffer OutputBuffer {
  uint g_output[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  // ping-pong buffers
  g_input[g_tid] = g_output[g_tid];
}
