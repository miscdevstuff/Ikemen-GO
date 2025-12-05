#define MATH_PI 3.1415926535897932384626433832795

#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
#if __VERSION__ >= 450
#extension GL_EXT_multiview : enable
#define currentFace gl_ViewIndex
layout(binding = 0)uniform samplerCube cubeMap;
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
#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE_CUBE_LOD textureCubeLod
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


vec3 uvToXYZ(int face, vec2 uv)
{
    if(face == 0)
        return vec3(     1.0,   uv.y,    -uv.x);

    else if(face == 1)
        return vec3(    -1.0,   uv.y,     uv.x);

    else if(face == 2)
        return vec3(   +uv.x,   -1.0,    +uv.y);

    else if(face == 3)
        return vec3(   +uv.x,    1.0,    -uv.y);

    else if(face == 4)
        return vec3(   +uv.x,   uv.y,      1.0);

    else { // if(face == 5)
        return vec3(    -uv.x,  +uv.y,     -1.0);
    }
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

// GGX microfacet distribution
// https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.html
// This implementation is based on https://bruop.github.io/ibl/,
//  https://www.tobias-franke.eu/log/2014/03/30/notes_on_importance_sampling.html
// and https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
MicrofacetDistributionSample GGX(vec2 xi, float roughness)
{
    MicrofacetDistributionSample ggx;

    // evaluate sampling equations
    float alpha = roughness * roughness;
    ggx.cosTheta = saturate(sqrt((1.0 - xi.y) / (1.0 + (alpha * alpha - 1.0) * xi.y)));
    ggx.sinTheta = sqrt(1.0 - ggx.cosTheta * ggx.cosTheta);
    ggx.phi = 2.0 * MATH_PI * xi.x;

    // evaluate GGX pdf (for half vector)
    ggx.pdf = D_GGX(ggx.cosTheta, alpha);

    // Apply the Jacobian to obtain a pdf that is parameterized by l
    // see https://bruop.github.io/ibl/
    // Typically you'd have the following:
    // float pdf = D_GGX(NoH, roughness) * NoH / (4.0 * VoH);
    // but since V = N => VoH == NoH
    ggx.pdf /= 4.0;

    return ggx;
}

MicrofacetDistributionSample Lambertian(vec2 xi, float roughness)
{
    MicrofacetDistributionSample lambertian;

    // Cosine weighted hemisphere sampling
    lambertian.cosTheta = sqrt(1.0 - xi.y);
    lambertian.sinTheta = sqrt(xi.y);
    lambertian.phi = 2.0 * MATH_PI * xi.x;

    lambertian.pdf = lambertian.cosTheta / MATH_PI; // solid angle pdf

    return lambertian;
}

#if __VERSION__ >= 130
// Hammersley Points on the Hemisphere (uint-based version)
float radicalInverse_VdC(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}
vec2 hammersley2d(int i, int N) {
    return vec2(float(i)/float(N), radicalInverse_VdC(uint(i)));
}
#else
// GLES2-safe approximation: no integer modulo, no loops with `%`
vec2 hammersley2d(int i, int N) {
    float fi   = float(i);
    float invN = 1.0 / float(N);
    float x    = fi * invN;
    // simple hash for y, good enough for importance sampling
    float y    = fract(sin(fi * 12.9898) * 43758.5453);
    return vec2(x, y);
}
#endif

// TBN generates a tangent bitangent normal coordinate frame from the normal
mat3 generateTBN(vec3 normal)
{
    vec3 bitangent = vec3(0.0, 1.0, 0.0);

    float NdotUp = dot(normal, vec3(0.0, 1.0, 0.0));
    float epsilon = 0.0000001;
    if (1.0 - abs(NdotUp) <= epsilon)
    {
        // Sampling +Y or -Y, so we need a more robust bitangent.
        if (NdotUp > 0.0)
        {
            bitangent = vec3(0.0, 0.0, 1.0);
        }
        else
        {
            bitangent = vec3(0.0, 0.0, -1.0);
        }
    }

    vec3 tangent = normalize(cross(bitangent, normal));
    bitangent = cross(normal, tangent);

    return mat3(tangent, bitangent, normal);
}

// getImportanceSample returns an importance sample direction with pdf in the .w component
vec4 getImportanceSample(int sampleIndex, vec3 N, float roughness)
{
    // generate a quasi monte carlo point in the unit square [0,1)^2
    vec2 xi = hammersley2d(sampleIndex, sampleCount);

    MicrofacetDistributionSample importanceSample;

    if(distribution == cLambertian)
    {
        importanceSample = Lambertian(xi, roughness);
    }
    else if(distribution == cGGX)
    {
        importanceSample = GGX(xi, roughness);
    }

    vec3 localSpaceDirection = normalize(vec3(
        importanceSample.sinTheta * cos(importanceSample.phi), 
        importanceSample.sinTheta * sin(importanceSample.phi), 
        importanceSample.cosTheta
    ));
    mat3 TBN = generateTBN(N);
    vec3 direction = TBN * localSpaceDirection;

    return vec4(direction, importanceSample.pdf);
}

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
float computeLod(float pdf)
{
    float lod = 0.5 * log2( 6.0 * float(width) * float(width) / (float(sampleCount) * pdf));
    return lod;
}

vec3 filterColor(vec3 N)
{
    vec3 color = vec3(0.0);
    float weight = 0.0;

    for(int i = 0; i < sampleCount; ++i)
    {
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
                if(roughness == 0.0)
                {
                    lod = 0.0;
                }
                vec3 sampleColor = COMPAT_TEXTURE_CUBE_LOD(cubeMap, L, lod).rgb * intensityScale;
                color += sampleColor * NdotL;
                weight += NdotL;
            }
        }
    }

    if(weight != 0.0)
    {
        color /= weight;
    }
    else
    {
        color /= float(sampleCount);
    }

    return color.rgb ;
}

// From the filament docs. Geometric Shadowing function
float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = pow(roughness, 4.0);
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

// Compute LUT for GGX distribution.
vec3 LUT(float NdotV, float roughness)
{
    vec3 V = vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);
    vec3 N = vec3(0.0, 0.0, 1.0);

    float A = 0.0;
    float B = 0.0;
    float C = 0.0;

    for(int i = 0; i < sampleCount; ++i)
    {
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
        vec2 newUV = texcoord;
        newUV = newUV*2.0-1.0;

        vec3 scan = uvToXYZ(currentFace, newUV);

        vec3 direction = normalize(scan);
        direction.y = -direction.y;

        color = filterColor(direction);

        FragColor.a = 1.0;
        FragColor.rgb = color;
    }else{
        color = LUT(texcoord.x, texcoord.y);
        FragColor.rgb = color;
        FragColor.a = 1.0;
        return;
    }
}