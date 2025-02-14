#version 460 core

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

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

uniform float deltaTime;
uniform int nParticles;
uniform float smoothingRadius;
uniform float lookAhead;
uniform float tankLength;
uniform float tankWidth;
uniform float tankHeight;
uniform float time;

const float pi = 3.1415926535;
const float gravity = 9.81 * 0.1;
const float viscosity = 0.0005;  // 0.001 mass, 0.0 rest density, 0.01 - 0.05 play around
const float restDensity = 0.0;
const float gas = 8.31 * 0.2;

// uint hash(vec3 position) {
//   uint hash = mod(
//     (floor(position[0] / smoothingRadius) * 73856093) ^
//       (floor(position[1] / smoothingRadius) * 19349663) ^
//       (floor(position[2] / smoothingRadius) * 83492791),
//     mHash
//   );
//   return hash;
// }

// // look into inout?
// void neighbors(vec3 position) {
//   // spatial hashing - open addressing via linear probing (requries nParticles slots or ideally like
//   // 10x the memory) index sorting - nParticles slots, nGridCells slots <cell index, particle>
//   // actually cell index is % len(startIndices), so startIndices can be any length
//   // use handle idea (need to sort handles every step, and should also reorder particles on every
//   // 100th step for cache locality) use insertion sort > radix sort for reordering handles. use
//   // Z-sort idea? (kinda difficult with an infinte domain?), instead of sorting, reorder accoring to
//   // Z-curve Imhsen et al. cites the memory consumption on infinite domains as a major drawback of
//   // index sorting, but you don't need a cell index necessarily, use a cell hash which is allowed to
//   // collide. ^ this is the idea behind spatial hashing.

//   vec3 neighborhood[27] = {
//     position + vec3(-1.0, -1.0, -1.0), position + vec3(-1.0, -1.0, 0.0),
//     position + vec3(-1.0, -1.0, 1.0),  position + vec3(-1.0, 0.0, -1.0),
//     position + vec3(-1.0, 0.0, 0.0),   position + vec3(-1.0, 0.0, 1.0),
//     position + vec3(-1.0, 1.0, -1.0),  position + vec3(-1.0, 1.0, 0.0),
//     position + vec3(-1.0, 1.0, 1.0),   position + vec3(0.0, -1.0, -1.0),
//     position + vec3(0.0, -1.0, 0.0),   position + vec3(0.0, -1.0, 1.0),
//     position + vec3(0.0, 0.0, -1.0),   position + vec3(0.0, 0.0, 0.0),
//     position + vec3(0.0, 0.0, 1.0),    position + vec3(0.0, 1.0, -1.0),
//     position + vec3(0.0, 1.0, 0.0),    position + vec3(0.0, 1.0, 1.0),
//     position + vec3(1.0, -1.0, -1.0),  position + vec3(1.0, -1.0, 0.0),
//     position + vec3(1.0, -1.0, 1.0),   position + vec3(1.0, 0.0, -1.0),
//     position + vec3(1.0, 0.0, 0.0),    position + vec3(1.0, 0.0, 1.0),
//     position + vec3(1.0, 1.0, -1.0),   position + vec3(1.0, 1.0, 0.0),
//     position + vec3(1.0, 1.0, 1.0),
//   };

//   for (uint j = 0; j < 27; j++) {
//     uint hash = hash(neighborhood[j]);
//     uint offset = offsets[hash];

//     uint k = offset;
//     while (particles[k].hash == hash) {
//       // ...some calculation...
//     }
//   }
// }

vec3 random_dir() {
  return vec3(
    fract(sin(dot(gl_GlobalInvocationID.xy + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.yz + time, vec2(12.9898, 78.233))) * 43758.5453),
    fract(sin(dot(gl_GlobalInvocationID.zx + time, vec2(12.9898, 78.233))) * 43758.5453)
  );
}

float poly6(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius * smoothingRadius - distance * distance);
  return 315.0 * b * b * b / (64.0 * pi * pow(smoothingRadius, 9));
}

vec3 grad_spiky(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  vec3 dir = origin != position ? normalize(origin - position) : normalize(random_dir());
  float b = max(0.0, smoothingRadius - distance);
  return -45.0 / pi / pow(smoothingRadius, 6) * b * b * dir;
}

float lap_vis(vec3 origin, vec3 position) {
  float distance = distance(origin, position);
  float b = max(0.0, smoothingRadius - distance);
  return 45.0 / pi / pow(smoothingRadius, 6) * b;
}

float density(uint i) {
  vec3 predicted_position_i =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]) +
    vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]) * lookAhead;

  float density = 0.0;
  for (uint j = 0; j < nParticles; j++) {
    vec3 predicted_position_j =
      vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2]) +
      vec3(particles[j].velocity[0], particles[j].velocity[1], particles[j].velocity[2]) *
        lookAhead;

    density +=
      particles[j].mass *
      poly6(
        predicted_position_i, predicted_position_j
        //  vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]),
        //  vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2])
      );
  }
  return density;
}

float volume(uint i) {
  return particles[i].mass / particles[i].density;
}

float pressure(uint i) {
  float pressure = gas * (particles[i].density - restDensity);
  return pressure;
}

vec3 acceleration(uint i) {
  vec3 position_i =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);
  vec3 velocity_i =
    vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]);

  vec3 predicted_position_i = position_i + velocity_i * lookAhead;

  vec3 acceleration = vec3(0.0);

  for (uint j = 0; j < nParticles; j++) {
    if (j == i) continue;

    vec3 position_j =
      vec3(particles[j].position[0], particles[j].position[1], particles[j].position[2]);
    vec3 velocity_j =
      vec3(particles[j].velocity[0], particles[j].velocity[1], particles[j].velocity[2]);

    vec3 predicted_position_j = position_j + velocity_j * lookAhead;

    /** acceleration due to pressure */
    acceleration -= particles[j].volume * (particles[i].pressure + particles[j].pressure) /
                    (2.0 * particles[i].density) *
                    grad_spiky(predicted_position_i, predicted_position_j);

    /** acceleration due to viscosity */
    acceleration += viscosity * particles[j].volume * (velocity_j - velocity_i) /
                    particles[i].density * lap_vis(predicted_position_i, predicted_position_j);
  }

  /** acceleration due to gravity */
  acceleration.y -= gravity;

  return acceleration;
}

void main() {
  uint i = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y + gl_GlobalInvocationID.z;

  particles[i].density = density(i);
  particles[i].volume = volume(i);
  particles[i].pressure = pressure(i);

  // memory barrier needed?
  barrier(); // THIS ONLY SYNCHRONIZES PER WORK GROUPPPPPPPP (must call separate kernels)

  vec3 position =
    vec3(particles[i].position[0], particles[i].position[1], particles[i].position[2]);
  vec3 velocity =
    vec3(particles[i].velocity[0], particles[i].velocity[1], particles[i].velocity[2]);

  velocity += acceleration(i) * deltaTime;
  position += velocity * deltaTime;

  velocity.x *= position.x < -tankLength || position.x > tankLength ? -0.5 : 1.0;
  position.x = clamp(position.x, -tankLength, tankLength);
  velocity.y *= position.y < -tankHeight || position.y > tankHeight ? -0.5 : 1.0;
  position.y = clamp(position.y, -tankHeight, tankHeight);
  velocity.z *= position.z < -tankWidth || position.z > tankWidth ? -0.5 : 1.0;
  position.z = clamp(position.z, -tankWidth, tankWidth);

  particles[i].position[0] = position.x;
  particles[i].position[1] = position.y;
  particles[i].position[2] = position.z;
  particles[i].velocity[0] = velocity.x;
  particles[i].velocity[1] = velocity.y;
  particles[i].velocity[2] = velocity.z;
}
