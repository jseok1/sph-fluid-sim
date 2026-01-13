#version 460 core

#define RADIX 256
#define WORKGROUP_SIZE 256  // workgroup size ≥ radix

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

struct ParticleHandle {
  uint hash;
  uint index;
};

layout(std430, binding = 7) buffer ParticleHandlesFrontBuffer {
  ParticleHandle g_particle_handles_front[];
};

layout(std430, binding = 8) buffer ParticleHandlesBackBuffer {
  ParticleHandle g_particle_handles_back[];
};

layout(std430, binding = 10) readonly buffer HistogramBuffer {
  uint g_histogram[];
};

uniform uint pass;
uniform uint particle_count;

shared uint l_histogram[RADIX];

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint WORKGROUPS = gl_NumWorkGroups.x;

  ParticleHandle handle = (pass & 0x1) == 0 ? g_particle_handles_front[g_tid] : g_particle_handles_back[g_tid];
  uint key = handle.hash;
  uint digit = (key >> 8 * pass) & 0xFF;

  if (l_tid == 0 || digit != ((((pass & 0x1) == 0 ? g_particle_handles_front[g_tid - 1].hash
                                                : g_particle_handles_back[g_tid - 1].hash) >>
                               8 * pass) &
                              0xFF)) {
    l_histogram[digit] = l_tid;
  }
  barrier();

  uint l_offset = l_histogram[digit];
  uint g_offset = 0;

  uint curr_i = digit * WORKGROUPS + wid;
  uint curr_n = uint(ceil(float(particle_count) / WORKGROUP_SIZE) * RADIX);
  uint offset = 0;
  while (curr_n > 1) {
    g_offset += g_histogram[offset + curr_i];
    offset += uint(ceil(float(curr_n) / WORKGROUP_SIZE)) * WORKGROUP_SIZE;
    curr_i = uint(floor(float(curr_i) / WORKGROUP_SIZE));

    curr_n /= WORKGROUP_SIZE;
  }

  if ((pass & 0x1) == 0) {
    g_particle_handles_back[l_tid - l_offset + g_offset] = handle;
  } else {
    g_particle_handles_front[l_tid - l_offset + g_offset] = handle;
  }
}
