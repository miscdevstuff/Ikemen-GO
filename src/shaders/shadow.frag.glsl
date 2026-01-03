/* Shadow Fragment Shader - Final Logic Fix + Syntax Correction */
#ifdef GL_ES
    precision highp float;
    precision mediump int;
#endif

struct Light {
    vec3 direction; float range;
    vec3 color; float intensity;
    vec3 position; float innerConeCos;
    float outerConeCos; int type;
    float shadowBias; float shadowMapFar;
};

#if __VERSION__ >= 450
    // --- MODERN PATH ---
    #define COMPAT_TEXTURE texture
    layout (constant_id = 3) const bool useTexture = false;
    layout(binding = 0) uniform EnvironmentUniform {
        layout(offset = 1536) Light lights[4];
    };
    layout(binding = 1) uniform MaterialUniform {
        mat3 texTransform;
        vec4 baseColorFactor;
        float ambientOcclusionStrength;
        float alphaThreshold;
        bool enableAlpha;
    };
    layout(binding = 5) uniform sampler2D tex;
    layout(location = 0) in vec4 FragPos;
    layout(location = 1) in float vColorAlpha;
    layout(location = 2) in vec2 texcoord0;
    layout(location = 3) in flat int lightIndex;
    
    void main() {
        vec4 color = baseColorFactor;
        if (useTexture) color *= COMPAT_TEXTURE(tex, vec2(texTransform * vec3(texcoord0, 1.0)));
        if ((enableAlpha && color.a * vColorAlpha <= 0.0) || (color.a * vColorAlpha < alphaThreshold)) discard;
        
        int index = lightIndex;
        float dist = length(FragPos.xyz - lights[index].position);
        gl_FragDepth = dist / lights[index].shadowMapFar;
    }
#else
    // --- ANDROID / LEGACY PATH ---
    #define COMPAT_VARYING varying
    #define COMPAT_TEXTURE texture2D
    
    uniform sampler2D tex;
    uniform mat3 texTransform;
    uniform bool enableAlpha;
    uniform bool useTexture;
    uniform float alphaThreshold;
    uniform vec4 baseColorFactor;
    uniform Light lights[4];
    
    COMPAT_VARYING vec4 FragPos;
    COMPAT_VARYING float vColorAlpha;
    COMPAT_VARYING vec2 texcoord0;
    COMPAT_VARYING float vLightIndex; 
    
    const int LightType_Directional = 1;

    void main() {
        vec4 color = baseColorFactor;
        if (useTexture) {
            color = color * COMPAT_TEXTURE(tex, vec2(texTransform * vec3(texcoord0, 1.0)));
        }
        color.a *= vColorAlpha;

        if ((enableAlpha && color.a <= 0.0) || (color.a < alphaThreshold)) {
            discard;
        }

        int index = int(vLightIndex + 0.5);
        
        float lightMapFar = 100.0;
        vec3 lightPos = vec3(0.0);
        int type = LightType_Directional;

        if (index == 0) {
            lightMapFar = lights[0].shadowMapFar;
            lightPos = lights[0].position;
            type = lights[0].type;
        } else if (index == 1) {
            lightMapFar = lights[1].shadowMapFar;
            lightPos = lights[1].position;
            type = lights[1].type;
        } else if (index == 2) {
            lightMapFar = lights[2].shadowMapFar;
            lightPos = lights[2].position;
            type = lights[2].type;
        } else {
            lightMapFar = lights[3].shadowMapFar;
            lightPos = lights[3].position;
            type = lights[3].type;
        }

        // KEEP THIS: Write depth to color (fixes GLES 2.0 crash)
        if (type != LightType_Directional) {
            float lightDistance = length(FragPos.xyz - lightPos);
            float normalizedDist = lightDistance / lightMapFar;
            gl_FragColor = vec4(normalizedDist, 0.0, 0.0, 1.0);
        } else {
            gl_FragColor = vec4(gl_FragCoord.z, 0.0, 0.0, 1.0); 
        }
    }
#endif
