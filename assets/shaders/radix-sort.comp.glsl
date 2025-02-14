#version 460 core

layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer InputBuffer {
  uint g_input[];
};

layout(std430, binding = 3) buffer OutputBuffer {
  uint g_output[];
};

layout(std430, binding = 4) buffer HistogramBuffer {
  uint g_histograms[];
};

shared uint histogram[256];  // stores 8-bit values, 2⁸ = 256
shared uint prefixSum[256];

void scanHistogram() {
  uint tid = gl_LocalInvocationID.x;

  // can we do prefix sum directly on the histogram? (would be more performant probably)
  uint offset = 1;
  prefixSum[2 * tid] = histogram[2 * tid];
  prefixSum[2 * tid + 1] = histogram[2 * tid + 1];
  for (uint d = 256 / 2; d > 0; d /= 2) {
    barrier();
    if (tid < d) {
      prefixSum[offset * (2 * tid + 2) - 1] += prefixSum[offset * (2 * tid + 1) - 1];
    }
    offset *= 2;
  }

  if (tid == 0) {
    prefixSum[255] = 0;
  }

  for (uint d = 1; d < 256; d *= 2) {
    offset /= 2;
    barrier();
    if (tid < d) {
      uint t = prefixSum[offset * (2 * tid + 1) - 1];
      prefixSum[offset * (2 * tid + 1) - 1] = prefixSum[offset * (2 * tid + 2) - 1];
      prefixSum[offset * (2 * tid + 2) - 1] += t;
    }
  }
}

void scatter(uint pass) {}

void main() {
  uint tid = gl_GlobalInvocationID.x;

  // count, scan, scatter
  // NVIDIA's radix sort
  // 1-block per workgroup
  // local histogram and scan
  // sort locally to coalesce writes to global memory

  // 1. Sort each block in on-chip memory according to the
  //    i-th digit using the split primitive (see Figure 2).
  // 2. Compute offsets for each of the r buckets, storing them
  //    to global memory in column-major order (see Figure 3).
  // 3. Perform a prefix sum over this table.
  // 4. Compute the output location for each element using
  //    the prefix sum results and scatter the elements to their
  //    computed locations (Figure 4).



  // for best performance, should copy input buffer into shared memory, do operations there, then
  // write to output buffer

  // 8-bit per pass → 4 passes for 32-bit keys
  // for (uint pass = 0; pass < 4; pass++) {
  //   uint digit = (g_input[tid] >> 8 * pass) & 0xFF;

  //   if (tid < 256) {
  //     histogram[tid] = 0;
  //   }
  //   barrier();

  //   atomicAdd(histogram[digit], 1);
  //   barrier();

  //   if (tid < 256) {
  //     prefixSum[tid] = histogram[tid];
  //   }
  //   barrier();

  //   scanHistogram();

    // need to move counts into a global histogram (in "column-major" format) then do a prefix
    // sum on the entire array
    // then, the offsets in each part of the global histogram corresponding to each workgroup will
    // be correct. now, you still need to ensure stability when copying into the output buffer.
    //
    // j = (i - l_prefix_sum[digit]) + g_prefix_sum[digit]  AFTER being locally sorted
    // g_output[j] = g_input[i];

    // do a local radix sort on the corresponding input for this workgroup.. then for i in the
    // SORTED buffer, di =


    // bin flags
    // [2 5 6 1 6]
    // [0 0 1 0 1] <-- flag for 6 (so there has to be 2^8 sets of flags for each possible digit, which span the num_local_threads size)
    // each thread finds flags[digit][tid] = 1
    // then a prefix sum of this gives the local offset
    // gotta do a local scan on each of the 258 digits
    // but at that point, why not just loop over shared memory?

    // so then sorting locally might be good

    // prefix sum has 2 uses: global offsets of bins, local offsets of keys within bins (using binary flag array
    //Reduce-then-scan digit binning)

    // Onesweep
    // 1. Compute digit histograms for ALL digit places in a single pass.
    // 2. Compute the global bin offset for every digit in each digit place.
    // 3. p = ceil(k/d) iterations of chained scan digit binning.
    //    For each iteration, each thread block reads its tile of elements, decodes key digits,
    //    participates in a chained scan of block-wide digit counts, and scatters its elements into their
    //    global output bins.

    // 1. atomic operations on shared histogram -> then global histogram
    // 2. 1 thread block per global histogram to compute prefix sum
    // 3. 1 thread block per tile (block = threads x items). Use atomic counter to assign
    //    tiles to blocks. Then distribute elemtns to 

    // test histogram
    // if (gl_LocalInvocationID.x < 256) {
    //   g_output[i] = prefixSum[gl_LocalInvocationID.x];
    // }

    // uint j = atomicAdd(prefixSum[digit], 1); // NOT stable
    // g_output[j] = g_input[i];
    // barrier();

    // // Swap buffers (Ping-Pong)
    // if (gl_LocalInvocationID.x < g_input.length()) {
    //   g_input[gl_LocalInvocationID.x] = g_output[gl_LocalInvocationID.x];
    // }
  // }
}
