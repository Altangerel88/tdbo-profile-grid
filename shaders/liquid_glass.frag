#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// iOS 27-style Liquid Glass for a small control, run as a BackdropFilter
// (Impeller only). Lens + dispersion as in tdb_loyalty's apple_glass.frag,
// plus what iOS 27 changed: content behind is diffused more, the specular
// highlights are brighter, and the pane gets a darkened edge for separation.
// The highlight faces a light the widget passes in (the background's drifting
// light), and a touch makes light pool under the finger.
//
// A BackdropFilter hands the shader the whole screen, so FlutterFragCoord() is
// in screen device pixels and uSize is the screen texture. uRect carries the
// pane's own bounds in those pixels; every length below is device pixels too.
uniform vec2 uSize;        // engine: backdrop texture size
uniform vec4 uRect;        // pane bounds: left, top, right, bottom
uniform float uRadius;     // corner radius
uniform float uThickness;  // how far the lensing reaches inward
uniform float uBend;       // refraction strength at the rim
uniform float uFrost;      // base frost
uniform float uSpec;       // specular gain
uniform float uDark;       // 0 = light appearance, 1 = dark
uniform vec3 uFrostColor;  // what the frost pulls toward
uniform vec2 uLight;       // unit vector from the pane toward the light
uniform vec3 uPress;       // touch x, y and press strength 0..1
uniform sampler2D uTex;

out vec4 fragColor;

float sdRound(vec2 p, vec2 b, float r) {
  vec2 q = abs(p) - b + vec2(r);
  return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void main() {
  vec2 px = FlutterFragCoord().xy;
  vec2 centre = (uRect.xy + uRect.zw) * 0.5;
  vec2 hs = (uRect.zw - uRect.xy) * 0.5;
  vec2 p = px - centre;
  float press = uPress.z;

  float d = sdRound(p, hs, uRadius);
  float e = 1.0;
  float dx = sdRound(p + vec2(e, 0.0), hs, uRadius) - sdRound(p - vec2(e, 0.0), hs, uRadius);
  float dy = sdRound(p + vec2(0.0, e), hs, uRadius) - sdRound(p - vec2(0.0, e), hs, uRadius);
  vec2 n = normalize(vec2(dx, dy) + vec2(1e-6));

  // Lensing near the rim, like a bevel; a pressed pane swells and bends more.
  float edge = clamp(1.0 - smoothstep(-uThickness, 0.0, d), 0.0, 1.0);
  float bend = uBend * edge * edge * (1.0 + 0.45 * press);

  vec2 uv = px / uSize;
  vec2 off = (n * bend) / uSize;
  // Slight convex magnification across the body.
  vec2 mag = -p * (0.06 + 0.05 * press) / uSize;

  vec3 col = vec3(
    texture(uTex, clamp(uv + mag + off * 1.12, vec2(0.0), vec2(1.0))).r,
    texture(uTex, clamp(uv + mag + off * 1.00, vec2(0.0), vec2(1.0))).g,
    texture(uTex, clamp(uv + mag + off * 0.88, vec2(0.0), vec2(1.0))).b
  );

  // Adaptive frost: busier or contrasting content behind gets more of it.
  float sat = max(col.r, max(col.g, col.b)) - min(col.r, min(col.g, col.b));
  float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
  float adapt = mix(1.0 - lum, lum, uDark);
  float frost = clamp(uFrost + sat * 0.45 + adapt * 0.25, 0.0, 0.94);
  col = mix(col, uFrostColor, frost);

  // Specular: the rim facing the light, and a softer one where light exits.
  // Kept to a band thinner than the corner radius, where the edge normal turns
  // smoothly; deeper in, a rounded box's normal snaps along its diagonals.
  float band = smoothstep(-uThickness * 0.55, 0.0, d);
  band *= band;
  float facing = dot(n, uLight);
  float lit = max(facing, 0.0);
  float spec = pow(lit, 4.0) * band;
  float exitSpec = pow(max(-facing, 0.0), 6.0) * band * 0.45;
  col += (spec + exitSpec) * uSpec * (1.0 + 0.6 * press);
  // Soft sheen across the half that faces the light.
  col += max(dot(p / hs, uLight), 0.0) * mix(0.03, 0.05, uDark);

  // Darkened edge for separation, with a bright hairline where it is lit.
  float rimW = max(uThickness * 0.07, 1.0);
  float inner = smoothstep(rimW * 4.0, 0.0, -d);
  col *= 1.0 - inner * mix(0.10, 0.22, uDark) * (1.0 - lit);
  col += smoothstep(rimW, 0.0, abs(d)) * (mix(0.12, 0.13, uDark) + 0.75 * lit * lit);

  // Light pools under the finger.
  float rr = min(hs.x, hs.y) * 1.1;
  vec2 tp = px - uPress.xy;
  col += exp(-dot(tp, tp) / (rr * rr)) * press * mix(0.20, 0.16, uDark);

  fragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
