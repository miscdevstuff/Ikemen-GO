/* Scanline Vertex Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    precision mediump float;
    precision mediump int;
#endif

attribute vec2 VertCoord;
uniform vec2 TextureSize;

// Output to frag
varying vec3 v_texCoord;

void main(void) {
    gl_Position = vec4(VertCoord, 0.0, 1.0);
    
    // Z is explicitly 0.0, XY is standard texture mapping
    v_texCoord = vec3((VertCoord + 1.0) / 2.0, 0.0);
}
