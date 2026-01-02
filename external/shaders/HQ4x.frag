/* HQ4x Fragment Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
    #else
        precision mediump float;
    #endif
    precision mediump int;
#endif

uniform sampler2D Texture;

// Inputs from Vertex Shader
varying vec2 v_t0;
varying vec4 v_t1;
varying vec4 v_t2;
varying vec4 v_t3;
varying vec4 v_t4;
varying vec4 v_t5;
varying vec4 v_t6;

// Constants
const float mx = 1.00;
const float k = -1.10;
const float max_w = 0.75;
const float min_w = 0.03;
const float lum_add = 0.33;

void main() {
    // Map unrolled varyings back to the algorithm's expected logic
    vec3 c  = texture2D(Texture, v_t0).xyz;
    vec3 i1 = texture2D(Texture, v_t1.xy).xyz;
    vec3 i2 = texture2D(Texture, v_t2.xy).xyz;
    vec3 i3 = texture2D(Texture, v_t3.xy).xyz;
    vec3 i4 = texture2D(Texture, v_t4.xy).xyz;
    
    vec3 o1 = texture2D(Texture, v_t5.xy).xyz;
    vec3 o3 = texture2D(Texture, v_t6.xy).xyz;
    vec3 o2 = texture2D(Texture, v_t5.zw).xyz;
    vec3 o4 = texture2D(Texture, v_t6.zw).xyz;
    
    vec3 s1 = texture2D(Texture, v_t1.zw).xyz;
    vec3 s2 = texture2D(Texture, v_t2.zw).xyz;
    vec3 s3 = texture2D(Texture, v_t3.zw).xyz;
    vec3 s4 = texture2D(Texture, v_t4.zw).xyz;

    vec3 dt = vec3(1.0, 1.0, 1.0);

    float ko1 = dot(abs(o1 - c), dt);
    float ko2 = dot(abs(o2 - c), dt);
    float ko3 = dot(abs(o3 - c), dt);
    float ko4 = dot(abs(o4 - c), dt);

    float k1 = min(dot(abs(i1 - i3), dt), max(ko1, ko3));
    float k2 = min(dot(abs(i2 - i4), dt), max(ko2, ko4));

    float w1 = k2; if(ko3 < ko1) w1 *= ko3 / ko1;
    float w2 = k1; if(ko4 < ko2) w2 *= ko4 / ko2;
    float w3 = k2; if(ko1 < ko3) w3 *= ko1 / ko3;
    float w4 = k1; if(ko2 < ko4) w4 *= ko2 / ko4;

    c = (w1 * o1 + w2 * o2 + w3 * o3 + w4 * o4 + 0.001 * c) / (w1 + w2 + w3 + w4 + 0.001);

    w1 = k * dot(abs(i1 - c) + abs(i3 - c), dt) / (0.125 * dot(i1 + i3, dt) + lum_add);
    w2 = k * dot(abs(i2 - c) + abs(i4 - c), dt) / (0.125 * dot(i2 + i4, dt) + lum_add);
    w3 = k * dot(abs(s1 - c) + abs(s3 - c), dt) / (0.125 * dot(s1 + s3, dt) + lum_add);
    w4 = k * dot(abs(s2 - c) + abs(s4 - c), dt) / (0.125 * dot(s2 + s4, dt) + lum_add);

    w1 = clamp(w1 + mx, min_w, max_w);
    w2 = clamp(w2 + mx, min_w, max_w);
    w3 = clamp(w3 + mx, min_w, max_w);
    w4 = clamp(w4 + mx, min_w, max_w);

    vec3 res = (w1 * (i1 + i3) + w2 * (i2 + i4) + w3 * (s1 + s3) + w4 * (s2 + s4) + c) / (2.0 * (w1 + w2 + w3 + w4) + 1.0);
    
    gl_FragColor = vec4(res, 1.0);
}
