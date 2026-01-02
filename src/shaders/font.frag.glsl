/* Font Fragment Shader - Android/GLES 2.0 Compatible */

#ifdef GL_ES
    precision mediump float;
    precision mediump int;
#endif

// Inputs from vertex shader
varying vec2 fragTexCoord;

// Uniforms
uniform sampler2D tex;
uniform vec4 textColor;

void main() {
    // Font textures are usually single-channel (alpha/red), so we put it in Alpha
    // Original logic: vec4(1.0, 1.0, 1.0, texture(...).r)
    vec4 sampled = vec4(1.0, 1.0, 1.0, texture2D(tex, fragTexCoord).r);
    
    // Multiply by text color
    // min(textColor, 1.0) is a safety check from the original shader
    gl_FragColor = min(textColor, vec4(1.0, 1.0, 1.0, 1.0)) * sampled;
}
