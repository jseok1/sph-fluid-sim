#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 1) buffer Hashes {
  uint offsets[];
};

shared uint histogram[256];  // Local histogram for 8-bit values

const uint SUBGROUP_SIZE = 64;

void main() {
  uint index = gl_GlobalInvocationID.x;
  uint value = data[index];

  // Extract current digit (8 bits)
  uint shift = 8 * (passNumber);  // Change per pass
  uint digit = (value >> shift) & 0xFF;

  // Initialize histogram in shared memory
  if (gl_LocalInvocationID.x < 256) {
    histogram[gl_LocalInvocationID.x] = 0;  // each invocation clears the histogram
  }
  memoryBarrierShared();
  barrier();

  // Atomic increment of histogram bucket
  atomicAdd(histogram[digit], 1);
  barrier();
}

shared uint prefixSum[256];

void scanHistogram() {
  uint tid = gl_LocalInvocationID.x;

  // Load histogram into shared memory
  if (tid < 256) {
    prefixSum[tid] = histogram[tid];
  }
  barrier();

  // Parallel Blelloch scan
  for (uint offset = 1; offset < 256; offset *= 2) {
    uint temp = 0;
    if (tid >= offset) {
      temp = prefixSum[tid - offset];
    }
    barrier();
    prefixSum[tid] += temp;
    barrier();
  }
}

layout(std430, binding = 1) buffer OutputBuffer {
  uint output[];
};

void scatter() {
  uint index = gl_GlobalInvocationID.x;
  uint value = data[index];

  uint shift = 8 * (passNumber);
  uint digit = (value >> shift) & 0xFF;

  // Compute destination index using prefix sum
  uint destIndex = atomicAdd(prefixSum[digit], 1);

  // Write to output buffer
  output[destIndex] = value;
}

void main() {
  for (int pass = 0; pass < 4; pass++) {  // 8-bit per pass → 4 passes for 32-bit keys
    histogramCompute(pass);
    scanHistogram();
    scatter();
    barrier();

    // Swap buffers (Ping-Pong)
    if (gl_LocalInvocationID.x < data.length()) {
      data[gl_LocalInvocationID.x] = output[gl_LocalInvocationID.x];
    }
  }
}
