#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 2) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_handles_front[];
};

layout(std430, binding = 3) readonly buffer ParticleHandlesBackBuffer {
  ParticleHandle g_handles_back[];
};

layout(std430, binding = 5) buffer LogBuffer {
  uint log[];
};

void main() {
  uint g_tid = gl_GlobalInvocationID.x;

  // maybe this could also be a conditional by uniform in the first shader
  // if (pass == 0) then swap...

  log[g_tid] = g_handles_back[g_tid].index;  // this is also fine

  // create an MWE!!!!!!!!!!!!!!!!!

  ParticleHandle dummy;
  dummy.hash = g_tid;
  dummy.index = g_tid;

  g_handles_front[g_tid] = dummy;  // this is fine
  // g_handles_front[g_tid] = g_handles_back[g_tid];  // this is the problem?????????????

  // scattering from front to back is ok
  // but copying from back to front is bad

  // from the other version, it was also writing to front
  // so writing to the front ssbo is bad ~ next theory - is it just writing to front that is bad?
  // let's try dummy
  // dummy is ok
}
