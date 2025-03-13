#version 460 core

struct Particle {
  float mass;
  float density;
  float volume;
  float pressure;
  float position[3];
  float velocity[3];
};

layout(std430, binding = 0) buffer Particles {
  Particle particles[];
};

layout(std430, binding = 1) buffer Hashes {
  uint offsets[];
};

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;

out vec2 fTexCoords;
out vec3 fPosition;
out vec3 fNormal;
out vec4 fHash;

uniform mat4 view;
uniform mat4 projection;
uniform uint nParticles;
uniform float smoothingRadius;

const float pi = 3.1415926535;

// clang-format off
vec3 neighborhood[27] = {
  vec3(-1.0, -1.0, -1.0),
  vec3(-1.0, -1.0,  0.0),
  vec3(-1.0, -1.0,  1.0),
  vec3(-1.0,  0.0, -1.0),
  vec3(-1.0,  0.0,  0.0),
  vec3(-1.0,  0.0,  1.0),
  vec3(-1.0,  1.0, -1.0),
  vec3(-1.0,  1.0,  0.0),
  vec3(-1.0,  1.0,  1.0),
  vec3( 0.0, -1.0, -1.0),
  vec3( 0.0, -1.0,  0.0),
  vec3( 0.0, -1.0,  1.0),
  vec3( 0.0,  0.0, -1.0),
  vec3( 0.0,  0.0,  0.0),
  vec3( 0.0,  0.0,  1.0),
  vec3( 0.0,  1.0, -1.0),
  vec3( 0.0,  1.0,  0.0),
  vec3( 0.0,  1.0,  1.0),
  vec3( 1.0, -1.0, -1.0),
  vec3( 1.0, -1.0,  0.0),
  vec3( 1.0, -1.0,  1.0),
  vec3( 1.0,  0.0, -1.0),
  vec3( 1.0,  0.0,  0.0),
  vec3( 1.0,  0.0,  1.0),
  vec3( 1.0,  1.0, -1.0),
  vec3( 1.0,  1.0,  0.0),
  vec3( 1.0,  1.0,  1.0),
};
// clang-format on

layout(std430, binding = 5) buffer LogBuffer {
  float log[];
};

uniform float lookAhead;
uniform uint mHash;
uint hash(vec3 position) {
  uint hash = uint(mod(
    (uint(floor(position.x / smoothingRadius)) * 73856093) ^
      (uint(floor(position.y / smoothingRadius)) * 19349663) ^
      (uint(floor(position.z / smoothingRadius)) * 83492791),
    mHash
  ));

  return hash;
}

void main() {
  uint g_tid = gl_BaseInstance + gl_InstanceID;

  Particle particle = particles[g_tid];

  vec3 position = vec3(particle.position[0], particle.position[1], particle.position[2]);

  // TODO: scaling transformation should be done with transform class in C++
  // clang-format off
  mat4 model = mat4(
          0.05,        0.0,        0.0, 0.0,
           0.0,       0.05,        0.0, 0.0,
           0.0,        0.0,       0.05, 0.0,
    position.x, position.y, position.z, 1.0
  );
  // clang-format on

  gl_Position = projection * view * model * vec4(aPos, 1.0);

  // max density from 0 to numParticles all in one using a logarithmic scale
  // sample from texture

  float normalizedDensity =
    particle.density * 25.681528662420382165605095541401;  // nParticles * 0.001 * 315.0 / (64.0
                                                           // * pi * pow(smoothingRadius, 3));
  fTexCoords = vec2(normalizedDensity, 0.5);

  // vec3 velocity =
  //   vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]) / 5.0;
  // fTexCoords = vec2(clamp(length(velocity), 0.0, 1.0), 0.5);

  fPosition = vec3(model * vec4(aPos, 1.0));
  fNormal = transpose(mat3(inverse(model))) * aNormal;

  vec3 velocity = vec3(particle.velocity[0], particle.velocity[1], particle.velocity[2]);

  fHash = vec4(0.25, 0.25, 0.75, 0.5);
  for (int i = 0; i < 27; i++) {
    uint h = hash(position);
    log[gl_BaseInstance + gl_InstanceID] = h;
    if (h == hash(vec3(1.0) + neighborhood[i] * smoothingRadius)) {
      fHash = vec4(0.75, 0.25, 0.25, 1.0);
    }
  }
}
