/* Scanline Fragment Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    #ifdef GL_FRAGMENT_PRECISION_HIGH
        precision highp float;
    #else
        precision mediump float;
    #endif
    precision mediump int;
#endif

uniform sampler2D Texture;
uniform vec2 TextureSize;

varying vec3 v_texCoord;

void main(void) {
    vec4 rgb = texture2D(Texture, v_texCoord.xy);
    vec4 intens;

    // Scanline logic (based on window Y coordinate)
    if (fract(gl_FragCoord.y * (0.5 * 4.0 / 3.0)) > 0.5)
        intens = vec4(0.0);
    else
        intens = smoothstep(0.2, 0.8, rgb) + normalize(vec4(rgb.xyz, 1.0));

    float level = (4.0 - v_texCoord.z) * 0.19;
    
    gl_FragColor = intens * (0.5 - level) + rgb * 1.1;
}
