#ifdef GL_ES
    // Enable derivatives for dFdx/dFdy used in PBR
    #extension GL_OES_standard_derivatives : enable
    precision highp float;
    precision mediump int;
#endif

// -- Structs --
struct Light {
    vec3 direction;
    float range;
    vec3 color;
    float intensity;
    vec3 position;
    float innerConeCos;
    float outerConeCos;
    int type;
    float shadowBias;
    float shadowMapFar;
};

#if __VERSION__ >= 450
    // MODERN PATH (Keep as is)
    #define ENABLE_SHADOW 
    #define COMPAT_TEXTURE texture
    #define COMPAT_TEXTURE_CUBE texture
    #define COMPAT_TEXTURE_CUBE_LOD textureLod
    #define COMPAT_SHADOW_MAP_TEXTURE() texture(shadowCubeMap,vec4(1.0, -(xy.y*2-1),-(xy.x*2-1),index)).r
    #define COMPAT_SHADOW_CUBE_MAP_TEXTURE() texture(shadowCubeMap,vec4(xyz,index)).r
    
    layout(binding = 0) uniform EnvironmentUniform {
        layout(offset = 384) Light lights[4];
        layout(offset = 640) mat3 environmentRotation;
        layout(offset = 688) vec3 cameraPosition;
        layout(offset = 700) float environmentIntensity;
        layout(offset = 704) int mipCount;
    };
    layout(binding = 1) uniform MaterialUniform {
        mat3 texTransform,normalMapTransform,metallicRoughnessMapTransform,ambientOcclusionMapTransform,emissionMapTransform;
        vec4 baseColorFactor;
        vec3 emission;
        vec2 metallicRoughness;
        float ambientOcclusionStrength;
        float alphaThreshold;
        bool enableAlpha;
    };
    layout(binding = 2) uniform sampler2D tex;
    layout(binding = 3) uniform sampler2D normalMap;
    layout(binding = 4) uniform sampler2D metallicRoughnessMap;
    layout(binding = 5) uniform sampler2D ambientOcclusionMap;
    layout(binding = 6) uniform sampler2D emissionMap;
    layout(binding = 7) uniform samplerCube environmentMap;
    layout(binding = 8) uniform sampler2D brdfLUT;
    layout(binding = 9) uniform samplerCubeArray shadowCubeMap;

    layout (constant_id = 0) const bool useJoint0 = false;
    layout (constant_id = 1) const bool useJoint1 = false;
    layout (constant_id = 2) const bool useNormal = false;
    layout (constant_id = 3) const bool useTangent = false;
    layout (constant_id = 4) const bool useVertColor = false;
    layout (constant_id = 6) const bool useTexture = false;
    layout (constant_id = 7) const bool useNormalMap = false;
    layout (constant_id = 8) const bool useMetallicRoughnessMap = false;
    layout (constant_id = 9) const bool useAmbientOcclusionMap = false;
    layout (constant_id = 10) const bool useEmissionMap = false;
    layout (constant_id = 11) const bool useEnvironmentMap = false;
    layout (constant_id = 12) const bool useShadowMap = false;

    layout(location = 0) in vec3 worldSpacePos;
    layout(location = 1) in vec3 normal;
    layout(location = 2) in vec2 texcoord;
    layout(location = 3) in vec4 lightSpacePos[4];
    layout(location = 7) in float vColor;
    layout(location = 8) in vec3 tangent;
    layout(location = 9) in vec3 bitangent;

    // Helper to access array
    vec4 getLightSpacePos(int i) { return lightSpacePos[i]; }

#else
    // --- ANDROID / LEGACY PATH ---
    #define COMPAT_VARYING varying
    #define COMPAT_TEXTURE texture2D
    #define COMPAT_TEXTURE_CUBE textureCube
    // Android GLES2 needs explicit LOD extension or fallback
    #ifdef GL_EXT_shader_texture_lod
        #define COMPAT_TEXTURE_CUBE_LOD textureCubeLodEXT
    #else
        #define COMPAT_TEXTURE_CUBE_LOD textureCube // Fallback, might be blurry
    #endif

    #define COMPAT_SHADOW_MAP_TEXTURE() texture2D(shadowCubeMap, vec2(0.0)).r 
    #define COMPAT_SHADOW_CUBE_MAP_TEXTURE() textureCube(shadowCubeMap, vec3(0.0)).r
    // Note: True shadow mapping in GLES2 requires substantial work (depth packing). 
    // For now we placeholder it to compile.

    uniform Light lights[4];
    uniform mat3 environmentRotation;
    uniform vec3 cameraPosition;
    uniform float environmentIntensity;
    uniform int mipCount;

    uniform mat3 texTransform, normalMapTransform, metallicRoughnessMapTransform, ambientOcclusionMapTransform, emissionMapTransform;
    uniform vec4 baseColorFactor;
    uniform vec3 emission;
    uniform vec2 metallicRoughness;
    uniform float ambientOcclusionStrength;
    uniform float alphaThreshold;
    uniform bool enableAlpha;

    uniform sampler2D tex;
    uniform sampler2D normalMap;
    uniform sampler2D metallicRoughnessMap;
    uniform sampler2D ambientOcclusionMap;
    uniform sampler2D emissionMap;
    uniform samplerCube environmentMap;
    uniform sampler2D brdfLUT;
    uniform samplerCube shadowCubeMap; // Using standard cube sampler for compat

    uniform bool useJoint0;
    uniform bool useJoint1;
    uniform bool useNormal;
    uniform bool useTangent;
    uniform bool useVertColor;
    uniform bool useTexture;
    uniform bool useNormalMap;
    uniform bool useMetallicRoughnessMap;
    uniform bool useAmbientOcclusionMap;
    uniform bool useEmissionMap;
    uniform bool useEnvironmentMap;
    uniform bool useShadowMap;

    COMPAT_VARYING vec3 worldSpacePos;
    COMPAT_VARYING vec3 normal;
    COMPAT_VARYING vec2 texcoord;
    
    // Receive Unrolled Arrays
    COMPAT_VARYING vec4 v_lightSpacePos0;
    COMPAT_VARYING vec4 v_lightSpacePos1;
    COMPAT_VARYING vec4 v_lightSpacePos2;
    COMPAT_VARYING vec4 v_lightSpacePos3;

    COMPAT_VARYING float vColor;
    COMPAT_VARYING vec3 tangent;
    COMPAT_VARYING vec3 bitangent;
    
    #define FragColor gl_FragColor

    vec4 getLightSpacePos(int i) { 
        if(i==0) return v_lightSpacePos0;
        if(i==1) return v_lightSpacePos1;
        if(i==2) return v_lightSpacePos2;
        if(i==3) return v_lightSpacePos3;
        return vec4(0.0);
    }
#endif

// ... [Rest of the PBR logic remains mostly the same, simplified for brevity] ...
// I will include the critical Main loop structure

const float PI = 3.14159265359;

// ... [Insert PBR Math Functions: fresnelSchlick, DistributionGGX, etc from your file] ...
// To ensure code fits, I assume you keep the math functions as is.
// They generally work in GLES2 provided derivatives are enabled.

void main() {
    // 1. Base Color
    vec4 color = baseColorFactor;
    if(useTexture){
        color *= COMPAT_TEXTURE(tex, vec2(texTransform * vec3(texcoord, 1.0)));
    }
    
    // 2. Normal Mapping (Critical part)
    vec3 N;
    if (useNormal) {
         if (useNormalMap && useTangent) {
             vec3 t = normalize(tangent);
             vec3 b = normalize(bitangent);
             vec3 n = normalize(normal);
             mat3 TBN = mat3(t, b, n);
             vec3 nMap = COMPAT_TEXTURE(normalMap, vec2(normalMapTransform * vec3(texcoord, 1.0))).rgb;
             N = normalize(TBN * (nMap * 2.0 - 1.0));
         } else {
             N = normalize(normal);
         }
    } else {
         // Using Derivatives (requires extension)
         vec3 dx = dFdx(worldSpacePos);
         vec3 dy = dFdy(worldSpacePos);
         N = normalize(cross(dx, dy));
    }
    
    // ... [Standard PBR Lighting Loop using N, cameraPosition, lights] ...
    
    FragColor = color; // Placeholder for logic
    // Ensure you copy the PBR logic from your original file here
    // But use 'getLightSpacePos(i)' instead of 'lightSpacePos[i]'
}
