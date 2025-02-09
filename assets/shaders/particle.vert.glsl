#version 460 core

struct Particle {
  float mass;
  float density;
  float volume;
  float pressure;
  float position[3];
  float velocity[3];
  uint hash;
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

uniform mat4 view;
uniform mat4 projection;
uniform int nParticles;
uniform float smoothingRadius;

const float pi = 3.1415926535;

void main() {
  uint i = gl_BaseInstance + gl_InstanceID;

  vec3 position =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);

  // TODO: scaling transformation should be done with transform class in C++
  // clang-format off
  mat4 model = mat4(
           0.1,        0.0,        0.0, 0.0,
           0.0,        0.1,        0.0, 0.0,
           0.0,        0.0,        0.1, 0.0,
    position.x, position.y, position.z, 1.0
  );
  // clang-format on

  gl_Position = projection * view * model * vec4(aPos, 1.0);

  // max density from 0 to numParticles all in one using a logarithmic scale
  // sample from texture

  float normalizedDensity =
    particles[i].density * 25.681528662420382165605095541401;  // nParticles * 0.001 * 315.0 / (64.0
                                                               // * pi * pow(smoothingRadius, 3));
  fTexCoords = vec2(normalizedDensity, 0.5);

  // vec3 velocity =
  //   vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]) / 5.0;
  // fTexCoords = vec2(clamp(length(velocity), 0.0, 1.0), 0.5);

  fPosition = vec3(model * vec4(aPos, 1.0));
  fNormal = transpose(mat3(inverse(model))) * aNormal;
}
