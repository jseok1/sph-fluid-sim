#version 460 core

struct Particle {
  float mass;
  float density;
  float volume;
  float position[3];
  float velocity[3];
};

layout(std430, binding = 0) buffer ParticleBuffer {
  Particle particles[];
};

layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aNormal;

out vec3 fColor;
out vec3 fPosition;
out vec3 fNormal;

uniform mat4 view;
uniform mat4 projection;

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

  // aColor = normalize(
  //   vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2])
  // ) / 2.0 + 0.5;
  // float alpha =
  //   length(vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2])) /
  //   10;

  // fColor = alpha * vec3(235, 91, 75) / 255.0 + (1.0 - alpha) * vec3(75, 123, 235) / 255.0;
  fColor =
    (normalize(vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2])) +
     0.01) /
      2.0 +
    0.5;
  fPosition = vec3(model * vec4(aPos, 1.0));
  fNormal = transpose(mat3(inverse(model))) * aNormal;
}
