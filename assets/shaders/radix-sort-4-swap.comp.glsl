#version 460 core

#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

layout(std430, binding = 3) buffer ParticleHandlesBackBuffer {
  ParticleHandle g_handles_back[];
};

struct LogThing {
  uint g_tid;
  uint l_tid;
  uint g_offset;
  // uint g_offset_1;
  // uint g_offset_2;
  uint l_offset;
  uint scatter;
};

layout(std430, binding = 5) buffer LogBuffer {
  LogThing log[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  // g_handles_front[g_tid] = g_handles_back[g_tid];

  g_handles_front[g_tid].index += 1;
  g_handles_front[g_tid].index -= 1;
  g_handles_back[g_tid].index += 1;
  g_handles_back[g_tid].index -= 1;
  log[g_tid].g_tid += 1;
  log[g_tid].g_tid -= 1;

  // log[g_tid] = g_handles_front[g_tid].index + g_handles_back[g_tid].index;
  // Ok when I do this, RenderDoc captures a later snapshot after the radix-3 shader is run,
  // so this gives me the latest look into the SSBOs
  // Basically, what's happening is that back is getting messed up. Then doing
  // g_handles_front[g_tid] = g_handles_back[g_tid]; copies that bug to the front, which is why both
  // seem to be messed up.
  // so what's going on is that back is being unintentionally modified in the previous shader

  // by the time the shader3 finishes, the things that will be messed up ARE messed up.
  // but each g_tid runs once as expected
}
