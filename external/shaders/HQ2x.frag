/* HQ2x Fragment Shader - Clean Android/GLES 2.0 Version */
/* Fixed: Removed arrays, implemented exact math from your reference */

#ifdef GL_ES
    // High precision is required for color math to prevent banding
    #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
    #else
        precision mediump float;
    #endif
    precision mediump int;
#endif

// Uniforms
uniform sampler2D Texture;

// Inputs from Vertex Shader (Matching the unrolled structure)
varying vec2 v_texCoord;
varying vec4 v_t1;
varying vec4 v_t2;
varying vec4 v_t3;
varying vec4 v_t4;

// HQ2x Algorithm Constants
const float mx = 0.325;
const float k = -0.250;
const float max_w = 0.25;
const float min_w =-0.05;
const float lum_add = 0.25;

void main() {
    // 1. Fetch Samples using the pre-calculated offsets
    // Mapping:
    // v_t1.xy = Top-Left (c00)   v_t1.zw = Top (c10)
    // v_t2.xy = Top-Right (c20)  v_t2.zw = Right (c21) -> Wait, check vert mapping
    
    // Let's strictly follow the Vertex Logic mapping:
    // v_t1.xy = TL, v_t1.zw = Top
    // v_t2.xy = TR, v_t2.zw = Right
    // v_t3.xy = BR, v_t3.zw = Bottom
    // v_t4.xy = BL, v_t4.zw = Left
    
    // YOUR REFERENCE CODE MAPPING:
    // c00 = GET_TEX(1).xy -> v_t1.xy (TL)
    // c10 = GET_TEX(1).zw -> v_t1.zw (Top)
    // c20 = GET_TEX(2).xy -> v_t2.xy (TR)
    // c01 = GET_TEX(4).zw -> v_t4.zw (Left)
    // c11 = GET_TEX(0).xy -> v_texCoord (Center)
    // c21 = GET_TEX(2).zw -> v_t2.zw (Right)
    // c02 = GET_TEX(4).xy -> v_t4.xy (BL)
    // c12 = GET_TEX(3).zw -> v_t3.zw (Bottom)
    // c22 = GET_TEX(3).xy -> v_t3.xy (BR)

    vec3 c00 = texture2D(Texture, v_t1.xy).xyz;
    vec3 c10 = texture2D(Texture, v_t1.zw).xyz;
    vec3 c20 = texture2D(Texture, v_t2.xy).xyz;
    vec3 c01 = texture2D(Texture, v_t4.zw).xyz;
    vec3 c11 = texture2D(Texture, v_texCoord).xyz;
    vec3 c21 = texture2D(Texture, v_t2.zw).xyz;
    vec3 c02 = texture2D(Texture, v_t4.xy).xyz;
    vec3 c12 = texture2D(Texture, v_t3.zw).xyz;
    vec3 c22 = texture2D(Texture, v_t3.xy).xyz;

    vec3 dt = vec3(1.0, 1.0, 1.0);

    // 2. The Core HQ2x Math (Exact copy of your reference logic)
    float md1 = dot(abs(c00 - c22), dt);
    float md2 = dot(abs(c02 - c20), dt);

    float w1 = dot(abs(c22 - c11), dt) * md2;
    float w2 = dot(abs(c02 - c11), dt) * md1;
    float w3 = dot(abs(c00 - c11), dt) * md2;
    float w4 = dot(abs(c20 - c11), dt) * md1;

    float t1 = w1 + w3;
    float t2 = w2 + w4;
    float ww = max(t1, t2) + 0.0001;

    // Center pixel adjustment
    c11 = (w1 * c00 + w2 * c20 + w3 * c22 + w4 * c02 + ww * c11) / (t1 + t2 + ww);

    float lc1 = k / (0.12 * dot(c10 + c12 + c11, dt) + lum_add);
    float lc2 = k / (0.12 * dot(c01 + c21 + c11, dt) + lum_add);

    w1 = clamp(lc1 * dot(abs(c11 - c10), dt) + mx, min_w, max_w);
    w2 = clamp(lc2 * dot(abs(c11 - c21), dt) + mx, min_w, max_w);
    w3 = clamp(lc1 * dot(abs(c11 - c12), dt) + mx, min_w, max_w);
    w4 = clamp(lc2 * dot(abs(c11 - c01), dt) + mx, min_w, max_w);

    // Final Output Calculation
    vec3 color = w1 * c10 + w2 * c21 + w3 * c12 + w4 * c01 + (1.0 - w1 - w2 - w3 - w4) * c11;

    gl_FragColor = vec4(color, 1.0);
}
