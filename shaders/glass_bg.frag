#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Animated "light behind tilted glass" background, modelled on the reference
// recording: black canvas, deep-blue haze in the top-right, a stack of glass
// slabs whose edges catch a wandering soft light, and a spectral fringe where
// the front edge leaves the screen.

uniform vec2 uSize;  // logical px
uniform float uTime; // seconds

out vec4 fragColor;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float blob(vec2 q, vec2 c, float r) {
  vec2 d = q - c;
  return exp(-dot(d, d) / (r * r));
}

float line(float s, float e, float w) {
  return exp(-abs(s - e) / w);
}

// The bright orb that drifts behind the glass.
vec2 orbPos(float a, float t) {
  return vec2(a * (0.50 + 0.32 * sin(t * 0.42)),
              0.21 + 0.10 * sin(t * 0.31 + 1.7));
}

// Light that sits behind the glass (q: y in 0..1, x in 0..aspect).
vec3 scene(vec2 q, float a, float t) {
  vec3 c = vec3(0.0);

  // Deep-blue haze anchored to the top-right corner.
  vec2 w = (q - vec2(a * 1.02, -0.06)) * vec2(0.85, 1.2);
  c += vec3(0.004, 0.018, 0.120) * exp(-dot(w, w) / 0.08);

  // Broad, slow wash.
  vec2 h = vec2(a * (0.74 + 0.14 * sin(t * 0.21)),
                0.10 + 0.05 * sin(t * 0.17 + 1.0));
  c += vec3(0.006, 0.024, 0.150) * blob(q, h, 0.18);

  // Wandering soft light.
  float pulse = 0.72 + 0.28 * sin(t * 0.55 + 0.6);
  vec2 b = orbPos(a, t);
  c += vec3(0.50, 0.58, 0.80) * pulse * blob(q, b, 0.105);
  c += vec3(0.015, 0.060, 0.280) * pulse * blob(q, b, 0.21);

  return c;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float H = uSize.y;
  float a = uSize.x / H;
  vec2 q = frag / H;
  float t = uTime;

  // Glass slabs: edges run down-right at ~38deg from the top of the screen.
  float ang = 0.67 + 0.04 * sin(t * 0.27);
  vec2 dir = vec2(cos(ang), sin(ang));  // along the edge
  vec2 nrm = vec2(-dir.y, dir.x);       // points to the open (lower-left) side
  vec2 o = vec2(a * 0.24 + 0.022 * sin(t * 0.23), 0.0);
  float s = dot(q - o, nrm);  // > 0 open area, < 0 under glass
  float u = dot(q - o, dir);  // distance along the edge

  float e1 = -0.036 + 0.006 * sin(t * 0.37 + 0.5);
  float e2 = -0.170 + 0.012 * sin(t * 0.29 + 2.0);

  vec3 col;
  if (s > 0.0) {
    col = scene(q, a, t);
  } else {
    float k = s > e1 ? 1.0 : (s > e2 ? 2.0 : 3.0);
    float lead = s > e1 ? -s : (s > e2 ? e1 - s : e2 - s);
    // Refraction: shift the light, harder near each slab's leading edge.
    vec2 off = nrm * (0.045 * k + 0.060 * exp(-lead / 0.025));
    vec3 cr = scene(q + off * 1.07, a, t);
    vec3 cg = scene(q + off, a, t);
    vec3 cb = scene(q + off * 0.93, a, t);
    col = vec3(cr.r, cg.g, cb.b) * vec3(0.40, 0.58, 1.00);
    // Glass body: deep blue, brightest just inside each slab's edge.
    col += vec3(0.001, 0.005, 0.030) * k;
    col += vec3(0.004, 0.016, 0.090) * exp(-lead / 0.030);
  }

  // Edges light up when the orb passes near them.
  vec2 orb = orbPos(a, t);
  float lit = 0.22 + 1.40 * blob(o + dir * max(u, 0.0), orb, 0.20);
  float along = smoothstep(-0.01, 0.03, u) * mix(1.0, 0.30, smoothstep(0.06, 0.42, u));

  vec3 edgeBlue = vec3(0.18, 0.40, 1.00);
  vec3 edgeCore = vec3(0.62, 0.78, 1.00);
  col += (edgeBlue * 0.55 * line(s, 0.0, 0.008) + edgeCore * line(s, 0.0, 0.0024)) * lit * along;
  col += edgeBlue * 0.12 * line(s, -0.02, 0.040) * lit;
  col += edgeCore * 0.14 * line(s, e1, 0.0012) * lit * along;
  col += (edgeBlue * 0.10 * line(s, e2, 0.012) + edgeCore * 0.22 * line(s, e2, 0.0014)) * lit;

  // Spectral fringe where the front edge runs off the right side.
  float fr = smoothstep(0.20, 0.34, u) * (1.0 - smoothstep(0.44, 0.58, u));
  vec3 fringe = vec3(line(s, -0.007, 0.0035), line(s, -0.011, 0.0035), line(s, -0.015, 0.0035));
  col += fringe * vec3(0.95, 0.70, 1.00) * fr * (0.35 + 0.65 * lit) * 0.55;

  // Keep the lower half pitch black, like the reference.
  col *= 1.0 - smoothstep(0.12, 0.60, q.y);

  // Base, soft tone curve, dither.
  col += vec3(0.000, 0.003, 0.012);
  col = 1.0 - exp(-col * 1.1);
  col += (hash(frag + fract(t) * 91.7) - 0.5) / 255.0;

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
