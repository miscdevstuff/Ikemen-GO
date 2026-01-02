/* Cubemap Filtering Shader - Android GLES 2.0 Compatible */
#define MATH_PI 3.1415926535897932384626433832795

#ifdef GL_ES
    #extension GL_EXT_shader_texture_lod : enable
    #extension GL_OES_standard_derivatives : enable
    precision highp float;
    precision mediump int;
#endif

#if __VERSION__ >= 450
    #extension GL_EXT_multiview : enable
    #define currentFace gl_ViewIndex
    layout(binding = 0) uniform samplerCube cubeMap;
    #define COMPAT_TEXTURE_CUBE_LOD textureLod
    layout(push_constant, std430) uniform u {
        int sampleCount;
        int distribution;
        int width;
        float roughness;
        float intensityScale;
        bool isLUT;
    };
    layout(location = 0) in vec2 texcoord;
    layout(location = 0) out vec4 FragColor;
#else
    #if __VERSION__ >= 130
        #define COMPAT_VARYING in
        #define COMPAT_TEXTURE_CUBE_LOD textureLod
        out vec4 FragColor;
    #else
        // --- ANDROID FIX ---
        #define COMPAT_VARYING varying
        #define FragColor gl_FragColor
        // Use extension for LOD if available, otherwise fallback to standard (blurry but works)
        #ifdef GL_EXT_shader_texture_lod
            #define COMPAT_TEXTURE_CUBE_LOD textureCubeLodEXT
        #else
            #define COMPAT_TEXTURE_CUBE_LOD textureCube // Fallback ignores LOD
        #endif
        // --- END FIX ---
    #endif
    uniform samplerCube cubeMap;
    uniform int sampleCount;
    uniform int distribution;
    uniform int width;
    uniform int currentFace;
    uniform float roughness;
    uniform float intensityScale;
    uniform bool isLUT;
    COMPAT_VARYING vec2 texcoord;
#endif

const int cLambertian = 0;
const int cGGX = 1;
const int cCharlie = 2;
const int MAX_SAMPLES = 512; // Hard limit for GLES 2.0 loops

vec3 uvToXYZ(int face, vec2 uv)
{
    if(face == 0) return vec3(1.0, uv.y, -uv.x);
    else if(face == 1) return vec3(-1.0, uv.y, uv.x);
    else if(face == 2) return vec3(uv.x, -1.0, uv.y);
    else if(face == 3) return vec3(uv.x, 1.0, -uv.y);
    else if(face == 4) return vec3(uv.x, uv.y, 1.0);
    else return vec3(-uv.x, uv.y, -1.0);
}

vec2 dirToUV(vec3 dir)
{
    return vec2(
            0.5 + 0.5 * atan(dir.z, dir.x) / MATH_PI,
            1.0 - acos(dir.y) / MATH_PI);
}

float saturate(float v)
{
    return clamp(v, 0.0, 1.0);
}

struct MicrofacetDistributionSample
{
    float pdf;
    float cosTheta;
    float sinTheta;
    float phi;
};

float D_GGX(float NdotH, float roughness) {
    float a = NdotH * roughness;
    float k = roughness / (1.0 - NdotH * NdotH + a * a);
    return k * k * (1.0 / MATH_PI);
}

MicrofacetDistributionSample GGX(vec2 xi, float roughness)
{
    MicrofacetDistributionSample ggx;
    float alpha = roughness * roughness;
    ggx.cosTheta = saturate(sqrt((1.0 - xi.y) / (1.0 + (alpha * alpha - 1.0) * xi.y)));
    ggx.sinTheta = sqrt(1.0 - ggx.cosTheta * ggx.cosTheta);
    ggx.phi = 2.0 * MATH_PI * xi.x;
    ggx.pdf = D_GGX(ggx.cosTheta, alpha);
    ggx.pdf /= 4.0;
    return ggx;
}

MicrofacetDistributionSample Lambertian(vec2 xi, float roughness)
{
    MicrofacetDistributionSample lambertian;
    lambertian.cosTheta = sqrt(1.0 - xi.y);
    lambertian.sinTheta = sqrt(xi.y);
    lambertian.phi = 2.0 * MATH_PI * xi.x;
    lambertian.pdf = lambertian.cosTheta / MATH_PI;
    return lambertian;
}

#if __VERSION__ >= 130
float radicalInverse_VdC(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10;
}
vec2 hammersley2d(int i, int N) {
    return vec2(float(i)/float(N), radicalInverse_VdC(uint(i)));
}
#else
// GLES2-safe approximation: No bitwise operators supported in ES 2.0
vec2 hammersley2d(int i, int N) {
    float fi   = float(i);
    float invN = 1.0 / float(N);
    float x    = fi * invN;
    float y    = fract(sin(fi * 12.9898) * 43758.5453);
    return vec2(x, y);
}
#endif

mat3 generateTBN(vec3 normal)
{
    vec3 bitangent = vec3(0.0, 1.0, 0.0);
    float NdotUp = dot(normal, vec3(0.0, 1.0, 0.0));
    float epsilon = 0.0000001;
    if (1.0 - abs(NdotUp) <= epsilon)
    {
        if (NdotUp > 0.0) bitangent = vec3(0.0, 0.0, 1.0);
        else bitangent = vec3(0.0, 0.0, -1.0);
    }
    vec3 tangent = normalize(cross(bitangent, normal));
    bitangent = cross(normal, tangent);
    return mat3(tangent, bitangent, normal);
}

vec4 getImportanceSample(int sampleIndex, vec3 N, float roughness)
{
    vec2 xi = hammersley2d(sampleIndex, sampleCount);
    MicrofacetDistributionSample importanceSample;

    if(distribution == cLambertian) importanceSample = Lambertian(xi, roughness);
    else if(distribution == cGGX) importanceSample = GGX(xi, roughness);

    vec3 localSpaceDirection = normalize(vec3(
        importanceSample.sinTheta * cos(importanceSample.phi), 
        importanceSample.sinTheta * sin(importanceSample.phi), 
        importanceSample.cosTheta
    ));
    mat3 TBN = generateTBN(N);
    vec3 direction = TBN * localSpaceDirection;
    return vec4(direction, importanceSample.pdf);
}

float computeLod(float pdf)
{
    float lod = 0.5 * log2( 6.0 * float(width) * float(width) / (float(sampleCount) * pdf));
    return lod;
}

vec3 filterColor(vec3 N)
{
    vec3 color = vec3(0.0);
    float weight = 0.0;

    // ANDROID FIX: Loop must have constant bounds
    for(int i = 0; i < MAX_SAMPLES; ++i)
    {
        if(i >= sampleCount) break; // Break dynamically

        vec4 importanceSample = getImportanceSample(i, N, roughness);
        vec3 H = importanceSample.xyz;
        float pdf = importanceSample.w;
        float lod = computeLod(pdf);

        if(distribution == cLambertian)
        {
            vec3 lambertian = COMPAT_TEXTURE_CUBE_LOD(cubeMap, H, lod).rgb * intensityScale;
            color += lambertian;
        }
        else if(distribution == cGGX || distribution == cCharlie)
        {
            vec3 V = N;
            vec3 L = normalize(reflect(-V, H));
            float NdotL = dot(N, L);
            if (NdotL > 0.0)
            {
                if(roughness == 0.0) lod = 0.0;
                vec3 sampleColor = COMPAT_TEXTURE_CUBE_LOD(cubeMap, L, lod).rgb * intensityScale;
                color += sampleColor * NdotL;
                weight += NdotL;
            }
        }
    }

    if(weight != 0.0) color /= weight;
    else color /= float(sampleCount);

    return color.rgb;
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = pow(roughness, 4.0);
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

vec3 LUT(float NdotV, float roughness)
{
    vec3 V = vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);
    vec3 N = vec3(0.0, 0.0, 1.0);
    float A = 0.0;
    float B = 0.0;
    float C = 0.0;

    // ANDROID FIX: Loop must have constant bounds
    for(int i = 0; i < MAX_SAMPLES; ++i)
    {
        if(i >= sampleCount) break;

        vec4 importanceSample = getImportanceSample(i, N, roughness);
        vec3 H = importanceSample.xyz;
        vec3 L = normalize(reflect(-V, H));

        float NdotL = saturate(L.z);
        float NdotH = saturate(H.z);
        float VdotH = saturate(dot(V, H));
        if (NdotL > 0.0)
        {
            if (distribution == cGGX)
            {
                float V_pdf = V_SmithGGXCorrelated(NdotV, NdotL, roughness) * VdotH * NdotL / NdotH;
                float Fc = pow(1.0 - VdotH, 5.0);
                A += (1.0 - Fc) * V_pdf;
                B += Fc * V_pdf;
                C += 0.0;
            }
        }
    }

    return vec3(4.0 * A, 4.0 * B, 4.0 * 2.0 * MATH_PI * C) / float(sampleCount);
}

void main()
{
    vec3 color = vec3(0.0);

    if(!isLUT){
        vec2 newUV = texcoord * 2.0 - 1.0;
        vec3 scan = uvToXYZ(currentFace, newUV);
        vec3 direction = normalize(scan);
        direction.y = -direction.y;
        color = filterColor(direction);
        FragColor = vec4(color, 1.0);
    } else {
        color = LUT(texcoord.x, texcoord.y);
        FragColor = vec4(color, 1.0);
    }
}
