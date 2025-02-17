#version 460 core

#define WORKGROUP_SIZE 256
#define RADIX 256
#define KEY_SIZE 8

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer InputBuffer {
  uint g_input[];
};

layout(std430, binding = 3) buffer OutputBuffer {
  uint g_output[];
};

layout(std430, binding = 4) buffer HistogramBuffer {
  uint g_histograms[];
};

shared uint false_total = 0;
shared uint l_input[WORKGROUP_SIZE];  // 256
shared uint l_bit_flags[256];
shared uint l_offsets[256];  // stores 8-bit values, 2⁸ = 256

uint scan() {
  uint l_tid = gl_LocalInvocationID.x;  // +

  uint true_before = 0;

  // not the worst since bounded by 256 but ideally also parallelize
  for (uint i = 0; i < l_tid; i++) {
    true_before += l_bit_flags[i];
  }

  return true_before;
}

uint split(uint bit) {
  uint l_tid = gl_LocalInvocationID.x;  // +

  // (1) Count ’True’ predicates held by lower-numbered threads
  uint true_before = scan();

  // (2) Last thread calculates total number of ’False’ predicates
  if (l_tid == WORKGROUP_SIZE - 1) {
    false_total = WORKGROUP_SIZE - (true_before + bit);
  }
  barrier();

  // (3) Compute and return the ’rank’ for this thread
  // why was there -1 here?
  return bit == 1 ? true_before + false_total : l_tid - true_before;  // weird there's no truthy
}

void main() {
  uint g_tid = gl_GlobalInvocationID.x;  // + gl_GlobalInvocationID.y +
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;

  // TODO: it's actually more efficient to handle 4 elements per invocation instead of just 1

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

  g_histograms[g_tid] = 0;
  l_input[l_tid] = g_input[g_tid];  // copy into shared memory

  // 255 becomes 1???

  // 8-bit per pass → 4 passes for 32-bit keys
  for (uint pass = 0; pass < 1; pass++) {
    // 1. local radix sort on digit
    for (uint i = 0; i < 8; i++) {
      // DO FIRST - local for radix sort prefix sum

      uint key = l_input[l_tid];
      uint bit = (key >> 8 * pass + i) & 0x1;

      l_bit_flags[l_tid] = bit;
      barrier();

      uint l_dst_idx = split(bit);
      barrier();

      l_input[l_dst_idx] = key;
      barrier();
    }

    // 2. local histogram and offsets
    if (l_tid == WORKGROUP_SIZE - 1) {
      // l_offsets[0] = 0;
      // for (uint i = 1; i < 256; i++) {
      //   if (l_input[i] != l_input[i - 1]) {
      //     l_offsets[l_input[i]] = i;
      //   }
      // }

      for (uint i = 0; i < 256; i++) {
        // col-major!
        g_histograms[l_input[i] * 2 + wid]++;
      }
    }
    barrier();

    g_output[g_tid] = l_input[l_tid];

    // uint digit = (l_input[tid] >> 8 * pass) & 0xFF;

    // if (tid < RADIX) {
    //   histogram[tid] = 0;
    // }
    // barrier();

    // atomicAdd(histogram[digit], 1);
    // barrier();

    // if (tid < 256) {
    //   prefixSum[tid] = histogram[tid];
    // }
    // barrier();

    // scanHistogram();
  }

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
  // [0 0 1 0 1] <-- flag for 6 (so there has to be 2^8 sets of flags for each possible digit, which
  // span the num_local_threads size) each thread finds flags[digit][tid] = 1 then a prefix sum of
  // this gives the local offset gotta do a local scan on each of the 258 digits but at that point,
  // why not just loop over shared memory?

  // so then sorting locally might be good

  // prefix sum has 2 uses: global offsets of bins, local offsets of keys within bins (using binary
  // flag array
  // Reduce-then-scan digit binning)

  // Onesweep
  // 1. Compute digit histograms for ALL digit places in a single pass.
  // 2. Compute the global bin offset for every digit in each digit place.
  // 3. p = ceil(k/d) iterations of chained scan digit binning.
  //    For each iteration, each thread block reads its tile of elements, decodes key digits,
  //    participates in a chained scan of block-wide digit counts, and scatters its elements into
  //    their global output bins.

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
