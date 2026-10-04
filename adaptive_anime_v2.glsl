// adaptive_anime_v2.glsl  -  luma-only adaptive sharpen for anime (libplacebo / mpv user-shader format)
//
// Original code. Design ideas drawn from:
//   - Anime4K Deblur-DoG (bloc97, MIT): noise floor on the detail signal, and boosting soft edges
//     more than edges that are already sharp (here judged by detail/contrast ratio).
//   - bacondither adaptive-sharpen (BSD): soft (tanh-like) limiting against the distance to the
//     nearest local extreme instead of a hard clamp.
//   - AMD CAS (MIT): sharpening limited by local headroom (here: local min/max room).
// Dark side and bright side are limited separately: lines may overshoot a little, halos may not.

//!PARAM STRENGTH
//!DESC Overall sharpen amount
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
0.7

//!PARAM DARK_GAIN
//!DESC Multiplier on darkening side (lines)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
1.3

//!PARAM BRIGHT_GAIN
//!DESC Multiplier on brightening side (halo risk)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
0.6

//!PARAM EDGE_LO
//!DESC Local 3x3 contrast below this: no sharpening (grain/banding guard)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.05

//!PARAM EDGE_HI
//!DESC Local 3x3 contrast above this: full sharpening
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.16

//!PARAM NOISE_FLOOR
//!DESC Detail below this is treated as noise and faded out
//!TYPE float
//!MINIMUM 0.001
//!MAXIMUM 0.2
0.012

//!PARAM SOFT_BOOST
//!DESC Extra gain on soft/blurry edges (0 = none). Sharp edges never get this
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
0.8

//!PARAM SHARP_CUT
//!DESC Gain reduction on edges that are already sharp (0 = none, 1 = leave them untouched)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.4

//!PARAM SHARP_RATIO
//!DESC Detail/contrast ratio at which an edge counts as fully sharp (an ideal step is ~0.25)
//!TYPE float
//!MINIMUM 0.05
//!MAXIMUM 0.5
0.20

//!PARAM DARK_OVERSHOOT
//!DESC Extra room to darken below the local minimum (fraction of local range)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.10

//!PARAM BRIGHT_OVERSHOOT
//!DESC Extra room to brighten above the local maximum (keep small: halos)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.04

//!HOOK LUMA
//!BIND HOOKED
//!DESC adaptive anime sharpen v2 (luma)

#define Y(ox, oy) (HOOKED_texOff(vec2(ox, oy)).x)

// Smooth limiter: ~identity for v << s, saturates at s (tanh-like, same family as bacondither's soft_lim)
float softlim(float v, float s) {
    if (s <= 1e-5) return 0.0;
    float x = clamp(v / s, 0.0, 3.0);
    return s * clamp(x * (27.0 + x * x) / (27.0 + 9.0 * x * x), 0.0, 1.0);
}

vec4 hook() {
    float c  = Y(0, 0);
    float n  = Y(0, -1), s = Y(0, 1), w = Y(-1, 0), e = Y(1, 0);
    float nw = Y(-1, -1), ne = Y(1, -1), sw = Y(-1, 1), se = Y(1, 1);

    // detail = pixel minus 3x3 gaussian
    float blur = (4.0 * c + 2.0 * (n + s + w + e) + (nw + ne + sw + se)) / 16.0;
    float d = c - blur;

    // edge gate: 3x3 local contrast (non-zero at the centre of a thin line, unlike a gradient)
    float mn3 = min(min(min(n, s), min(w, e)), min(min(nw, ne), min(sw, se)));
    float mx3 = max(max(max(n, s), max(w, e)), max(max(nw, ne), max(sw, se)));
    float gate = smoothstep(EDGE_LO, EDGE_HI, max(mx3, c) - min(mn3, c));

    // detail shaping: noise floor, then soft edges are boosted and already-sharp edges are held back.
    // a / contrast is ~0.25 for an ideal step and smaller for blurry edges, independent of line brightness.
    float contrast = max(max(mx3, c) - min(mn3, c), 1e-3);
    float a  = abs(d);
    float nz = smoothstep(0.0, NOISE_FLOOR, a);
    float q  = smoothstep(0.0, SHARP_RATIO, a / contrast);          // 0 = soft, 1 = sharp
    float boost = mix(1.0 + SOFT_BOOST, 1.0 - SHARP_CUT, q);

    float gain  = (d < 0.0) ? DARK_GAIN : BRIGHT_GAIN;
    float delta = sign(d) * a * STRENGTH * gate * nz * gain * boost;

    // local range from 3x3 plus the four taps at distance 2
    float n2 = Y(0, -2), s2 = Y(0, 2), w2 = Y(-2, 0), e2 = Y(2, 0);
    float mn = min(min(min(min(n, s), min(w, e)), min(min(nw, ne), min(sw, se))), min(min(n2, s2), min(w2, e2)));
    float mx = max(max(max(max(n, s), max(w, e)), max(max(nw, ne), max(sw, se))), max(max(n2, s2), max(w2, e2)));
    mn = min(mn, c);
    mx = max(mx, c);
    float r = mx - mn;

    float room_up = (mx - c) + BRIGHT_OVERSHOOT * r;
    float room_dn = (c - mn) + DARK_OVERSHOOT * r;
    float lim = (delta >= 0.0) ? softlim(delta, room_up) : -softlim(-delta, room_dn);

    vec4 col = HOOKED_tex(HOOKED_pos);
    col.x = c + lim;
    return col;
}
