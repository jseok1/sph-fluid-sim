#version 460 core

in vec2 f_uv;
in vec4 f_sample;

out vec4 f_color;

void main() {
  if (length(f_uv - vec2(0.5)) > 0.5) discard;

  // linearize gl_FragCoord.z?
  // f_color = vec4(vec3(gl_FragCoord.z / gl_FragCoord.w), 1.0);
  f_color = f_sample;
}
