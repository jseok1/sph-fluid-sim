#version 460 core

#define WORKGROUP_SIZE 256

layout(local_size_x = WORKGROUP_SIZE, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 2) buffer InputBuffer {
  uint g_input[];
};

layout(std430, binding = 3) buffer OutputBuffer {
  uint g_output[];
};

layout(std430, binding = 4) buffer HistogramBuffer {
  uint g_offsets[];
};

layout(std430, binding = 5) buffer LastHistogramBuffer {
  uint g_last_histogram[];
};

layout(std430, binding = 6) buffer LogSSBO {
  uint log[];
};

uniform uint pass;

void main() {
  uint g_tid = gl_GlobalInvocationID.x;  // + gl_GlobalInvocationID.y +
  uint l_tid = gl_LocalInvocationID.x;
  uint wid = gl_WorkGroupID.x;

  uint key = g_input[g_tid];
  uint digit = (key >> 8 * pass) & 0xFF;

  uint l_offset;
  // bad (could store within separate SSBO?)  -- better way to calculate in O(1)?
  for (uint i = 0; i < 256; i++) {
    if (((g_input[wid * 256 + i] >> 8 * pass) & 0xFF) == digit) {
      l_offset = i;
      break;
    }
  }
  uint g_offset =
    g_offsets[digit * 2 + wid] + g_last_histogram[uint(floor((digit * 2 + wid) / 256))];

  // is this coalesced???
  g_output[l_tid - l_offset + g_offset] = key;
}
