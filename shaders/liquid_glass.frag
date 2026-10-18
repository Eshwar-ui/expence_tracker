#include <flutter/runtime_effect.glsl>

// The engine supplies the input texture size and sampler for ImageFilter.shader.
uniform vec2 u_size;
uniform float u_radius;
uniform float u_refraction;
uniform sampler2D u_backdrop;
out vec4 frag_color;

float roundedRect(vec2 p, vec2 halfSize, float radius) {
  vec2 q = abs(p) - halfSize + radius;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void main() {
  vec2 size = max(u_size, vec2(1.0));
  vec2 xy = FlutterFragCoord().xy;
  vec2 p = xy - size * 0.5;
  float radius = min(u_radius, min(size.x, size.y) * 0.5);
  float d = roundedRect(p, size * 0.5, radius);
  vec2 normal = vec2(
    roundedRect(p + vec2(0.5, 0.0), size * 0.5, radius) -
      roundedRect(p - vec2(0.5, 0.0), size * 0.5, radius),
    roundedRect(p + vec2(0.0, 0.5), size * 0.5, radius) -
      roundedRect(p - vec2(0.0, 0.5), size * 0.5, radius)
  );
  normal /= max(length(normal), 0.001);
  float rim = 1.0 - smoothstep(0.0, max(radius, 1.0), max(-d, 0.0));
  vec2 bend = normal * sin(rim * 3.14159265) * u_refraction;
  vec2 uv = (xy - bend) / size;
  vec2 fringe = normal * rim * 0.45 / size;
  #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
    fringe.y = -fringe.y;
  #endif
  vec2 inset = 0.5 / size;
  vec4 base = texture(u_backdrop, clamp(uv, inset, 1.0 - inset));
  float red = texture(u_backdrop, clamp(uv + fringe, inset, 1.0 - inset)).r;
  float blue = texture(u_backdrop, clamp(uv - fringe, inset, 1.0 - inset)).b;
  frag_color = vec4(red, base.g, blue, base.a);
}
