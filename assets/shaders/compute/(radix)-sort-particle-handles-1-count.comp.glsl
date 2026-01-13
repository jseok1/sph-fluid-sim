#version 460 core

#define RADIX 256
#define RADIX_SIZE 8        // 8-bit radix (2⁸ = 256)
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

layout(std430, binding = 10) buffer HistogramBuffer {
  uint g_histogram[];
};

shared uint false_total;
shared ParticleHandle l_handles[WORKGROUP_SIZE];
shared uint l_histogram[RADIX];
shared uint l_offsets_bitwise[RADIX];

uniform float lookAhead;
uniform uint HASH_TABLE_SIZE;
uniform float smoothingRadius;
uniform uint pass;

uint hash(vec3 position) {
  uint hash = uint(mod(
    (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
      (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
      (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
    HASH_TABLE_SIZE
  ));
  return hash;
}

void scan(uint l_tid) {
  uint stride = 2;

  // upsweep (reduction)
  for (uint d = WORKGROUP_SIZE / 2; d > 0; d /= 2) {
    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);

      l_offsets_bitwise[i] += l_offsets_bitwise[j];
    }
    barrier();

    stride *= 2;
  }

  if (l_tid == WORKGROUP_SIZE - 1) {
    l_offsets_bitwise[l_tid] = 0;
  }
  barrier();

  // downsweep
  for (uint d = 1; d < WORKGROUP_SIZE; d *= 2) {
    stride /= 2;

    if (l_tid < d) {
      uint i = WORKGROUP_SIZE - 1 - (stride * l_tid);
      uint j = WORKGROUP_SIZE - 1 - (stride * l_tid + stride / 2);
      uint l_offset_bitwise = l_offsets_bitwise[i];

      l_offsets_bitwise[i] += l_offsets_bitwise[j];
      l_offsets_bitwise[j] = l_offset_bitwise;
    }
    barrier();
  }
}

void split(uint l_tid, ParticleHandle handle, uint bit) {
  if (l_tid == WORKGROUP_SIZE - 1) {
    false_total = WORKGROUP_SIZE - (l_offsets_bitwise[l_tid] + bit);
  }
  barrier();

  uint l_offset =
    bit == 1 ? l_offsets_bitwise[l_tid] + false_total : l_tid - l_offsets_bitwise[l_tid];
  barrier();

  l_handles[l_offset] = handle;
  barrier();
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;
  uint WORKGROUPS = gl_NumWorkGroups.x;

  // TODO: it's actually more efficient to handle 4 elements per invocation instead of just 1

  // 0. copy into local memory (and ping-pong buffers)
  l_handles[l_tid] = (pass & 0x1) == 0 ? g_particle_handles_front[g_tid] : g_particle_handles_back[g_tid];

  // 1. local radix sort on digit
  for (uint i = 0; i < RADIX_SIZE; i++) {
    ParticleHandle handle = l_handles[l_tid];

    uint key = handle.hash;
    uint bit = (key >> RADIX_SIZE * pass + i) & 0x1;

    l_offsets_bitwise[l_tid] = bit;
    barrier();

    scan(l_tid);
    split(l_tid, handle, bit);
  }

  // 2. local histogram and offsets
  if (l_tid < RADIX) {
    l_histogram[l_tid] = 0;
  }
  barrier();

  uint key = l_handles[l_tid].hash;
  uint digit = (key >> RADIX_SIZE * pass) & 0xFF;

  atomicAdd(l_histogram[digit], 1);
  barrier();

  // 3. copy local histogram to global histogram (in "column-major" order)
  if (l_tid < RADIX) {
    g_histogram[l_tid * WORKGROUPS + wid] = l_histogram[l_tid];
  }

  // 4. copy locally sorted values to global memory
  if ((pass & 0x1) == 0) {
    g_particle_handles_front[g_tid] = l_handles[l_tid];
  } else {
    g_particle_handles_back[g_tid] = l_handles[l_tid];
  }
}
