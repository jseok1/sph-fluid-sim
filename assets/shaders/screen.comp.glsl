#version 460 core

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;
layout(rgba32f, binding = 0) uniform image2D screen;

struct Particle {
  float mass;
  vec3 position;
  vec3 velocity;
  float density;
  float pressure;
};

layout(std430, binding = 0) buffer ParticleBuffer {
  Particle particles[];
};

struct Ray {
  vec3 origin;
  vec3 direction;
};

struct Camera {
  vec3 origin;
  vec3 u, v, w;  // orthonormal basis where -w is viewing direction
  float fovy;
};

uniform Camera camera;

Ray generateRay(ivec2 screenCoords, ivec2 screenDims) {
  float height = 2 * tan(radians(camera.fovy / 2));
  float width = height * screenDims.x / screenDims.y;

  float x = width * (screenCoords.x + 0.5) / screenDims.x - width / 2.0;
  float y = height * (screenCoords.y + 0.5) / screenDims.y - height / 2.0;
  float z = -1.0;

  Ray ray;
  ray.direction = camera.u * x + camera.v * y + camera.w * z;
  ray.origin = camera.origin;

  return ray;
}

void main() {
  float radius = 0.5;

  ivec2 screenCoords = ivec2(gl_GlobalInvocationID.xy); // NOT [0, 1]
  ivec2 screenDims = imageSize(screen);
  vec4 screenColor = vec4(0.6, 0.88, 1.0, 1.0);

  Ray ray = generateRay(screenCoords, screenDims);
  float min = 10000.0;

  for (int i = 0; i < 5; i++) {
    vec3 o_c = ray.origin - particles[i].position;
    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, o_c);
    float c = dot(o_c, o_c) - radius * radius;
    float discriminant = b * b - 4.0 * a * c;

    if(discriminant >= 0.0) {
      float t = (-b - sqrt(discriminant)) / (2.0 * a);
      vec3 intersection = ray.origin + ray.direction * t;
      if(t >= 1 && t < min) {
        screenColor = vec4((normalize(intersection - particles[i].position) + 1.0) / 2.0, 1.0);
        min = t;
      }
    } 
  }

  imageStore(screen, screenCoords, screenColor);
}