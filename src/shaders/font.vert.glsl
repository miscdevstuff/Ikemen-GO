/* Font Vertex Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    precision highp float;
    precision mediump int;
#endif

// Attributes
attribute vec2 vert;
attribute vec2 vertTexCoord;

// Uniforms
uniform vec2 resolution;

// Output to fragment shader
varying vec2 fragTexCoord;

void main() {
   // Convert the rectangle from pixels to 0.0 to 1.0
   vec2 zeroToOne = vert / resolution;

   // Convert from 0->1 to 0->2
   vec2 zeroToTwo = zeroToOne * 2.0;

   // Convert from 0->2 to -1->+1 (clipspace)
   vec2 clipSpace = zeroToTwo - 1.0;

   // Pass texture coordinate to fragment shader
   fragTexCoord = vertTexCoord;

   // Flip Y axis for standard OpenGL coordinate system if needed, 
   // but usually fonts are rendered with specific ortho matrices.
   // The original shader did: vec4(clipSpace * vec2(1, -1), 0, 1)
   gl_Position = vec4(clipSpace * vec2(1.0, -1.0), 0.0, 1.0);
}
