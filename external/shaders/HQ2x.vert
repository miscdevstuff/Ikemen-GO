/* HQ2x Vertex Shader - Clean Android/GLES 2.0 Version */
/* Fixed: Removed varying arrays, added precision, standard attributes */

#ifdef GL_ES
    precision highp float;
    precision mediump int;
#endif

// Inputs provided by Ikemen GO engine
attribute vec2 VertCoord;
uniform vec2 TextureSize;

// Outputs to Fragment Shader (Unrolled for compatibility)
varying vec2 v_texCoord; // Center (c11)
varying vec4 v_t1;       // Top-Left (xy), Top (zw)
varying vec4 v_t2;       // Top-Right (xy), Right (zw)
varying vec4 v_t3;       // Bottom-Right (xy), Bottom (zw)
varying vec4 v_t4;       // Bottom-Left (xy), Left (zw)

void main() {
    // Map Vertex Coordinates (-1 to 1) to Texture Coordinates (0 to 1)
    // This matches the logic: vec2 texCoord = (VertCoord + 1.0) / 2.0;
    vec2 texCoord = (VertCoord + 1.0) * 0.5;
    v_texCoord = texCoord;

    // Calculate Texel Size
    float x = 0.5 * (1.0 / TextureSize.x);
    float y = 0.5 * (1.0 / TextureSize.y);

    // Pre-calculate offsets for the 8 neighbors
    vec2 dg1 = vec2( x, y);
    vec2 dg2 = vec2(-x, y);
    vec2 dx  = vec2( x, 0.0);
    vec2 dy  = vec2( 0.0, y);

    // Pack neighbors into vec4 varyings to save registers
    // Matches logic: TexCoord[1]
    v_t1.xy = texCoord - dg1; // Top-Left
    v_t1.zw = texCoord - dy;  // Top

    // Matches logic: TexCoord[2]
    v_t2.xy = texCoord - dg2; // Top-Right
    v_t2.zw = texCoord + dx;  // Right

    // Matches logic: TexCoord[3]
    v_t3.xy = texCoord + dg1; // Bottom-Right
    v_t3.zw = texCoord + dy;  // Bottom

    // Matches logic: TexCoord[4]
    v_t4.xy = texCoord + dg2; // Bottom-Left
    v_t4.zw = texCoord - dx;  // Left

    // Standard Position Output
    gl_Position = vec4(VertCoord, 0.0, 1.0);
}
