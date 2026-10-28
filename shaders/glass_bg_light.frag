#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// Light counterpart of glass_bg.frag: the same glass slabs and drifting light,
// but drawn on the design's #F7F7F7 page. Light shows up as colour absorbed
// from the page (Beer–Lambert), and the slab edges are white specular lines
// with a thin blue refraction shadow instead of glowing lines.

uniform vec2 uSize;  // logical px
uniform float uTime; // seconds

out vec4 fragColor;

const vec3 BASE = vec3(0.9686);               // #F7F7F7
const vec3 AZURE = vec3(0.012, 0.529, 0.953); // #0387F3
const vec3 SKY = vec3(0.45, 0.72, 1.00);
const vec3 GLASS = vec3(0.62, 0.80, 1.00);

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

vec2 orbPos(float a, float t) {
  return vec2(a * (0.50 + 0.32 * sin(t * 0.42)),
              0.21 + 0.10 * sin(t * 0.31 + 1.7));
}

// Per-channel colour density of the light behind the glass.
vec3 field(vec2 q, float a, float t) {
  vec3 d = vec3(0.0);

  // Soft sky tint anchored to the top-right corner.
  vec2 w = (q - vec2(a * 1.02, -0.06)) * vec2(0.85, 1.2);
  d += (1.0 - SKY) * 0.45 * exp(-dot(w, w) / 0.08);

  // Broad, slow wash.
  vec2 h = vec2(a * (0.74 + 0.14 * sin(t * 0.21)),
                0.10 + 0.05 * sin(t * 0.17 + 1.0));
  d += (1.0 - SKY) * 0.30 * blob(q, h, 0.18);

  // Wandering light: azure core, sky halo.
  float pulse = 0.70 + 0.30 * sin(t * 0.55 + 0.6);
  vec2 b = orbPos(a, t);
  d += (1.0 - AZURE) * 0.50 * pulse * blob(q, b, 0.105);
  d += (1.0 - SKY) * 0.30 * pulse * blob(q, b, 0.21);

  return d;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float H = uSize.y;
  float a = uSize.x / H;
  vec2 q = frag / H;
  float t = uTime;

  // Same slab geometry and motion as the dark version.
  float ang = 0.67 + 0.04 * sin(t * 0.27);
  vec2 dir = vec2(cos(ang), sin(ang));
  vec2 nrm = vec2(-dir.y, dir.x);
  vec2 o = vec2(a * 0.24 + 0.022 * sin(t * 0.23), 0.0);
  float s = dot(q - o, nrm);
  float u = dot(q - o, dir);

  float e1 = -0.036 + 0.006 * sin(t * 0.37 + 0.5);
  float e2 = -0.170 + 0.012 * sin(t * 0.29 + 2.0);

  vec3 d;
  if (s > 0.0) {
    d = field(q, a, t);
  } else {
    float k = s > e1 ? 1.0 : (s > e2 ? 2.0 : 3.0);
    float lead = s > e1 ? -s : (s > e2 ? e1 - s : e2 - s);
    vec2 off = nrm * (0.045 * k + 0.060 * exp(-lead / 0.025));
    vec3 dr = field(q + off * 1.07, a, t);
    vec3 dg = field(q + off, a, t);
    vec3 db = field(q + off * 0.93, a, t);
    d = vec3(dr.r, dg.g, db.b) * 1.15;
    // Glass body: faint blue, strongest just inside each slab's edge.
    d += (1.0 - GLASS) * (0.08 * k + 0.30 * exp(-lead / 0.030));
  }

  vec2 orb = orbPos(a, t);
  float lit = 0.22 + 1.40 * blob(o + dir * max(u, 0.0), orb, 0.20);
  float along = smoothstep(-0.01, 0.03, u) * mix(1.0, 0.30, smoothstep(0.06, 0.42, u));

  // Thin blue refraction shadow just inside each edge.
  d += (1.0 - AZURE) * 0.50 * line(s, -0.004, 0.0030) * lit * along;
  d += (1.0 - AZURE) * 0.18 * line(s, e1 - 0.003, 0.0025) * lit * along;
  d += (1.0 - AZURE) * 0.22 * line(s, e2 - 0.003, 0.0040) * lit;

  // Spectral fringe where the front edge runs off the right side.
  float fr = smoothstep(0.20, 0.34, u) * (1.0 - smoothstep(0.44, 0.58, u));
  float lr = line(s, -0.009, 0.0035);
  float lg = line(s, -0.013, 0.0035);
  float lb = line(s, -0.017, 0.0035);
  d += vec3(lg + lb, lr + lb, lr + lg) * 0.30 * fr * (0.35 + 0.65 * lit);

  // Lower half stays the plain page colour.
  float mask = 1.0 - smoothstep(0.12, 0.60, q.y);
  vec3 col = BASE * exp(-d * mask);

  // White specular edges.
  float spec = (line(s, 0.0, 0.0022) * 0.95 + line(s, 0.0, 0.010) * 0.35) * lit * along
             + line(s, e1, 0.0012) * 0.50 * lit * along
             + line(s, e2, 0.0014) * 0.60 * lit;
  col = mix(col, vec3(1.0), clamp(spec * mask, 0.0, 1.0));

  col += (hash(frag + fract(t) * 91.7) - 0.5) / 255.0 * mask;

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
