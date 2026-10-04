//!PARAM STRENGTH
//!DESC Overall sharpen amount
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 3.0
0.8

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
//!DESC Below this gradient: no sharpening (grain/banding guard)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.06

//!PARAM EDGE_HI
//!DESC Above this gradient: full sharpening
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.20

//!PARAM OVERSHOOT
//!DESC Allowed overshoot beyond local range (fraction of range)
//!TYPE float
//!MINIMUM 0.0
//!MAXIMUM 1.0
0.08

//!HOOK LUMA
//!BIND HOOKED
//!DESC adaptive anime sharpen (luma)

float L(float x, float y) { return HOOKED_texOff(vec2(x, y)).x; }

vec4 hook() {
    float c  = L(0,0);
    float n  = L(0,-1), s = L(0,1), w = L(-1,0), e = L(1,0);
    float nw = L(-1,-1), ne = L(1,-1), sw = L(-1,1), se = L(1,1);

    float blur = (4.0*c + 2.0*(n+s+w+e) + (nw+ne+sw+se)) / 16.0;

    float gx = (ne + 2.0*e + se) - (nw + 2.0*w + sw);
    float gy = (sw + 2.0*s + se) - (nw + 2.0*n + ne);
    float m  = smoothstep(EDGE_LO, EDGE_HI, length(vec2(gx, gy)));

    float d  = c - blur;
    float g  = (d < 0.0) ? DARK_GAIN : BRIGHT_GAIN;
    float o  = c + STRENGTH * m * g * d;

    float mn = min(min(min(n,s),min(w,e)), min(min(nw,ne),min(sw,se)));
    float mx = max(max(max(n,s),max(w,e)), max(max(nw,ne),max(sw,se)));
    mn = min(mn, c); mx = max(mx, c);
    float r = mx - mn;
    o = clamp(o, mn - OVERSHOOT*r, mx + OVERSHOOT*r);

    vec4 col = HOOKED_tex(HOOKED_pos);
    col.x = o;
    return col;
}
