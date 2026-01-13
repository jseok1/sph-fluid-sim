#version 460 core

layout(std430, binding = 0) readonly buffer PositionsFrontBuffer {
  float g_positions_front[];
};

layout(std430, binding = 2) readonly buffer VelocitiesFrontBuffer {
  float g_velocities_front[];
};

layout(location = 0) in vec3 v_xyz;
layout(location = 1) in vec2 v_uv;

out vec2 f_uv;
out vec4 f_sample;

struct Camera {
  mat4 view;
  mat4 projection;
  vec3 u;
  vec3 v;
  vec3 w;
};

uniform Camera camera;
uniform uint particle_count;
// uniform float smoothingRadius;

// const float pi = 3.1415926535;

// vec3 neighborhood[27] = {
//   // clang-format off
//   vec3(-1.0, -1.0, -1.0),
//   vec3(-1.0, -1.0,  0.0),
//   vec3(-1.0, -1.0,  1.0),
//   vec3(-1.0,  0.0, -1.0),
//   vec3(-1.0,  0.0,  0.0),
//   vec3(-1.0,  0.0,  1.0),
//   vec3(-1.0,  1.0, -1.0),
//   vec3(-1.0,  1.0,  0.0),
//   vec3(-1.0,  1.0,  1.0),
//   vec3( 0.0, -1.0, -1.0),
//   vec3( 0.0, -1.0,  0.0),
//   vec3( 0.0, -1.0,  1.0),
//   vec3( 0.0,  0.0, -1.0),
//   vec3( 0.0,  0.0,  0.0),
//   vec3( 0.0,  0.0,  1.0),
//   vec3( 0.0,  1.0, -1.0),
//   vec3( 0.0,  1.0,  0.0),
//   vec3( 0.0,  1.0,  1.0),
//   vec3( 1.0, -1.0, -1.0),
//   vec3( 1.0, -1.0,  0.0),
//   vec3( 1.0, -1.0,  1.0),
//   vec3( 1.0,  0.0, -1.0),
//   vec3( 1.0,  0.0,  0.0),
//   vec3( 1.0,  0.0,  1.0),
//   vec3( 1.0,  1.0, -1.0),
//   vec3( 1.0,  1.0,  0.0),
//   vec3( 1.0,  1.0,  1.0),
//   // clang-format on
// };
//

// uniform float lookAhead;
// uniform uint HASH_TABLE_SIZE;
// uint hash(vec3 position) {
//   uint hash = uint(mod(
//     (uint(floor((position.x + 15.0) / smoothingRadius)) * 73856093) ^
//       (uint(floor((position.y + 15.0) / smoothingRadius)) * 19349663) ^
//       (uint(floor((position.z + 15.0) / smoothingRadius)) * 83492791),
//     HASH_TABLE_SIZE
//   ));
//   return hash;
// }

// uint interleaveBits(uint bits) {
//   bits &= 0x000003FF;  // keep only 10 bits (3 x 10 bits = 30 bits <= 32 bits)
//   bits = (bits | (bits << 16)) & 0x030000FF;  // 00000011 00000000 00000000 11111111
//   bits = (bits | (bits << 8))  & 0x0300F00F;  // 00000011 00000000 11110000 00001111
//   bits = (bits | (bits << 4))  & 0x030C30C3;  // 00000011 00001100 00110000 11000011
//   bits = (bits | (bits << 2))  & 0x09249249;  // 00001001 00100100 10010010 01001001
//   return bits;
// }
//
// uint hash(vec3 position) {
//   // Morton code for locality-preserving hashing
//   uint x = uint((position.x + 5) / smoothingRadius);
//   uint y = uint((position.y + 5) / smoothingRadius);
//   uint z = uint((position.z + 5) / smoothingRadius);
//   uint hash = (interleaveBits(z) << 2) | (interleaveBits(y) << 1) | interleaveBits(x);
//   hash = uint(mod(hash, HASH_TABLE_SIZE));  // better if bitwise &
//   return hash;
// }

layout(binding = 0) uniform sampler2D gradient;

const float pi = 3.1415926535;

void main() {
  uint g_tid = gl_BaseInstance + gl_InstanceID;

  uint i = g_tid;
  vec3 position_i = vec3(g_positions_front[3 * i + 0],
                         g_positions_front[3 * i + 1],
                         g_positions_front[3 * i + 2]);
  vec3 velocity_i = vec3(g_velocities_front[3 * i + 0],
                         g_velocities_front[3 * i + 1],
                         g_velocities_front[3 * i + 2]);

  gl_Position = camera.projection * camera.view * vec4(position_i + camera.u * v_xyz.x + camera.v * v_xyz.y, 1.0);

  f_uv = v_uv;
  f_sample = texture(gradient, vec2(2.0 / pi * atan(length(velocity_i) / 1.5), 0.5)); // 1D eventually?

  // uint TRACK = 436;
  // uint h = hash(position_i);
  // vec3 position_track = vec3(g_positions_front[3 * TRACK], g_positions_front[3 * TRACK + 1], g_positions_front[3 * TRACK + 2]);
  // for (int i = 0; i < 27; i++) {
  //   if (h == hash(position_track + neighborhood[i] * smoothingRadius)) {
  //     f_sample = vec4(0.75, 0.25, 0.25, 0.5);
  //   }
  // }
  //
  // if (i == TRACK) {
  //   f_sample = vec4(0.33, 1.0, 0.20, 1.0);
  // }
}
