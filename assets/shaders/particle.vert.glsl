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

out vec3 aColor;

uniform mat4 view;
uniform mat4 projection;

void main() {
  uint i = gl_BaseInstance + gl_InstanceID;

  vec3 position =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);

  gl_Position = projection * view * vec4(aPos + position, 1.0);

  aColor = normalize(vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]) / 2.0 + 0.5);
}
