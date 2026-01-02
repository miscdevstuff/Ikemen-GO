/* HQ4x Vertex Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    precision highp float;
    precision mediump int;
#endif

// Attributes & Uniforms
attribute vec2 VertCoord;
uniform vec2 TextureSize;

// Unrolled Varyings (Arrays not supported in GLES 2 varying)
varying vec2 v_t0; // Center
varying vec4 v_t1;
varying vec4 v_t2;
varying vec4 v_t3;
varying vec4 v_t4;
varying vec4 v_t5;
varying vec4 v_t6;

void main() {
    // Map -1..1 to 0..1
    vec2 texCoord = (VertCoord + 1.0) / 2.0;

    // Fixed: Use actual TextureSize instead of hardcoded 0.001
    // This ensures it scales correctly on Android screens
    float x = 1.0 / TextureSize.x;
    float y = 1.0 / TextureSize.y;

    vec2 dg1 = vec2( x, y);
    vec2 dg2 = vec2(-x, y);
    vec2 sd1 = dg1 * 0.5;
    vec2 sd2 = dg2 * 0.5;
    vec2 ddx = vec2( x, 0.0);
    vec2 ddy = vec2( 0.0, y);

    gl_Position = vec4(VertCoord, 0.0, 1.0);

    // Mapping based on original TexCoord array indices
    // TexCoord[0]
    v_t0 = texCoord;
    
    // TexCoord[1]
    v_t1.xy = texCoord - sd1;
    v_t1.zw = texCoord - ddy;

    // TexCoord[2]
    v_t2.xy = texCoord - sd2;
    v_t2.zw = texCoord + ddx;

    // TexCoord[3]
    v_t3.xy = texCoord + sd1;
    v_t3.zw = texCoord + ddy;

    // TexCoord[4]
    v_t4.xy = texCoord + sd2;
    v_t4.zw = texCoord - ddx;

    // TexCoord[5]
    v_t5.xy = texCoord - dg1;
    v_t5.zw = texCoord - dg2;

    // TexCoord[6]
    v_t6.xy = texCoord + dg1;
    v_t6.zw = texCoord + dg2;
}
