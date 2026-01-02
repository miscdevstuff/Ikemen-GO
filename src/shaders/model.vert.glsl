#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

#if __VERSION__ >= 450
#define COMPAT_TEXTURE texture
layout(binding = 0) uniform UniformBufferObject0 {
    mat4 view, projection;
    mat4 lightMatrices[4];
    layout(offset = 688) vec3 cameraPosition;
};

layout(binding = 2) uniform UniformBufferObject2 {
    mat4 model,normalMatrix;
    int numJoints,numTargets,morphTargetTextureDimension,numVertices;
    vec4 morphTargetWeight[2];
    vec4 morphTargetOffset;
    float meshOutline;
};

layout(binding = 3) uniform sampler2D jointMatrices;
layout(binding = 4) uniform sampler2D morphTargetValues;

layout (constant_id = 0) const bool useJoint0 = false;
layout (constant_id = 1) const bool useJoint1 = false;
layout (constant_id = 2) const bool useNormal = false;
layout (constant_id = 3) const bool useTangent = false;
layout (constant_id = 4) const bool useVertColor = false;
layout (constant_id = 5) const bool useOutlineAttribute = false;

layout(location = 0) in int vertexId;
layout(location = 1) in vec3 position;
layout(location = 2) in vec2 uv;
layout(location = 3) in vec3 normalIn;
layout(location = 4) in vec4 tangentIn;
layout(location = 5) in vec4 vertColor;
layout(location = 6) in vec4 joints_0;
layout(location = 7) in vec4 joints_1;
layout(location = 8) in vec4 weights_0;
layout(location = 9) in vec4 weights_1;
layout(location = 10) in vec4 outlineAttribute;

layout(location = 0) out vec3 normal;
layout(location = 1) out vec3 tangent;
layout(location = 2) out vec3 bitangent;
layout(location = 3) out vec2 texcoord;
layout(location = 4) out vec4 vColor;
layout(location = 5) out vec3 worldSpacePos;
layout(location = 6) out vec4 lightSpacePos[4];

#else
// --- GLES 2.0 / ANDROID PATH ---
#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#extension GL_EXT_gpu_shader4 : enable
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

uniform mat4 model,view,projection,normalMatrix;
uniform sampler2D jointMatrices;
uniform sampler2D morphTargetValues;
uniform int morphTargetTextureDimension;
uniform int numJoints;
uniform int numTargets;
uniform vec4 morphTargetWeight[2];
uniform vec4 morphTargetOffset;
uniform int numVertices;
uniform vec3 cameraPosition;
uniform float meshOutline;
uniform mat4 lightMatrices[4];

// NOTE: Changed vertexId to float to ensure compatibility
COMPAT_ATTRIBUTE float vertexId;
COMPAT_ATTRIBUTE vec3 position;
COMPAT_ATTRIBUTE vec3 normalIn;
COMPAT_ATTRIBUTE vec4 tangentIn;
COMPAT_ATTRIBUTE vec4 vertColor;
COMPAT_ATTRIBUTE vec2 uv;
COMPAT_ATTRIBUTE vec4 joints_0;
COMPAT_ATTRIBUTE vec4 joints_1;
COMPAT_ATTRIBUTE vec4 weights_0;
COMPAT_ATTRIBUTE vec4 weights_1;
COMPAT_ATTRIBUTE vec4 outlineAttribute;

COMPAT_VARYING vec3 normal;
COMPAT_VARYING vec3 tangent;
COMPAT_VARYING vec3 bitangent;
COMPAT_VARYING vec2 texcoord;
COMPAT_VARYING vec4 vColor;
COMPAT_VARYING vec3 worldSpacePos;
COMPAT_VARYING vec4 lightSpacePos[4];

#define useJoint0 (weights_0.x + weights_0.y + weights_0.z + weights_0.w + \
                   weights_1.x + weights_1.y + weights_1.z + weights_1.w > 0.0)

const bool useJoint1 = true;
const bool useNormal = true;
const bool useTangent = true;
const bool useVertColor = true;
const bool useOutlineAttribute = true;

// --- MANUAL TRANSPOSE FIX ---
mat4 transpose(mat4 m) {
    return mat4(
        m[0][0], m[1][0], m[2][0], m[3][0],
        m[0][1], m[1][1], m[2][1], m[3][1],
        m[0][2], m[1][2], m[2][2], m[3][2],
        m[0][3], m[1][3], m[2][3], m[3][3]
    );
}
// ----------------------------
#endif

mat4 getMatrixFromTexture(float index){
    mat4 mat;
    float j = index; 
    // Manual texture lookups to avoid dependent texture read issues on older Mali
    mat[0] = COMPAT_TEXTURE(jointMatrices,vec2(0.5/6.0,(j+0.5)/float(numJoints)));
    mat[1] = COMPAT_TEXTURE(jointMatrices,vec2(1.5/6.0,(j+0.5)/float(numJoints)));
    mat[2] = COMPAT_TEXTURE(jointMatrices,vec2(2.5/6.0,(j+0.5)/float(numJoints)));
    mat[3] = vec4(0.0,0.0,0.0,1.0);
    return transpose(mat);
}

mat4 getJointMatrix(){
    mat4 ret = mat4(0.0);
    ret += weights_0.x*getMatrixFromTexture(joints_0.x);
    ret += weights_0.y*getMatrixFromTexture(joints_0.y);
    ret += weights_0.z*getMatrixFromTexture(joints_0.z);
    ret += weights_0.w*getMatrixFromTexture(joints_0.w);
    if(useJoint1){
        ret += weights_1.x*getMatrixFromTexture(joints_1.x);
        ret += weights_1.y*getMatrixFromTexture(joints_1.y);
        ret += weights_1.z*getMatrixFromTexture(joints_1.z);
        ret += weights_1.w*getMatrixFromTexture(joints_1.w);
    }
    // Optimization: Check equality with 0.0 using small epsilon or just assume 
    // identity if weight sum is low, but for safety on GLES2 we keep it simple.
    // However, equality check '==' on float matrices can be risky.
    // We assume if it's zeroed out, we return identity.
    // For GLES2 safety, let's just return identity if weights are near zero.
    float weightSum = dot(weights_0, vec4(1.0)) + dot(weights_1, vec4(1.0));
    if(weightSum < 0.01) {
         return mat4(1.0);
    }
    return ret;
}

float getMorphTargetWeight(int idx) {
    // Unrolling helper: avoid complex indexing if possible, but limited options here.
    int vecIndex  = idx / 4;
    int compIndex = idx - vecIndex * 4;

    if (vecIndex == 0) {
        if (compIndex == 0) return morphTargetWeight[0].x;
        if (compIndex == 1) return morphTargetWeight[0].y;
        if (compIndex == 2) return morphTargetWeight[0].z;
        return morphTargetWeight[0].w;
    } else {
        if (compIndex == 0) return morphTargetWeight[1].x;
        if (compIndex == 1) return morphTargetWeight[1].y;
        if (compIndex == 2) return morphTargetWeight[1].z;
        return morphTargetWeight[1].w;
    }
}

void main() {
    texcoord = uv;
    vColor = useVertColor ? vertColor : vec4(1.0);
    vec4 pos = vec4(position, 1.0);

    // MORPH TARGET LOOP
    // Android GLES2 compilers struggle with loops that have non-constant bounds.
    // We keep the loop but ensure indexing is robust.
    if (morphTargetOffset[0] > 0.0){
        for (int idx = 0; idx < 8; ++idx) // CAP at 8 targets max to help unroller
        {
            if (idx >= numTargets) break; // Break early

            float i   = float(idx) * float(numVertices) + vertexId;
            float dim = float(morphTargetTextureDimension);

            // Safe UV calculation
            float row = floor(i / dim);
            vec2 xy = vec2(
                (i - row * dim + 0.5) / dim,
                (row + 0.5) / dim
            );

            float idxf = float(idx);
            float w    = getMorphTargetWeight(idx);
            
            // Texture read
            vec4 val = COMPAT_TEXTURE(morphTargetValues, xy);

            if (idxf < morphTargetOffset[0]){
                pos.xyz += w * val.xyz;
            } else if (idxf >= morphTargetOffset[2] && idxf < morphTargetOffset[3]){
                texcoord += w * val.xy;
            }
        }
    }

    if (useJoint0){
        mat4 jointMatrix = getJointMatrix();
        pos = jointMatrix * pos;
        
        vec4 tmp2 = model * pos;
        
        // Simplified Outline Logic
        if (meshOutline > 0.0) {
             vec3 outlineNormal = normalIn;
             if(useNormal){
                 outlineNormal = mat3(jointMatrix) * outlineNormal;
                 outlineNormal = normalize(mat3(normalMatrix) * outlineNormal);
             }
             float thick = (outlineAttribute.w > 0.0) ? outlineAttribute.w : 1.0;
             tmp2.xyz += outlineNormal * thick * meshOutline * length(cameraPosition - tmp2.xyz);
        }

        gl_Position = projection * view * tmp2;
        worldSpacePos = vec3(tmp2);
        
        // Loop unrolling for lights
        lightSpacePos[0] = lightMatrices[0] * tmp2;
        lightSpacePos[1] = lightMatrices[1] * tmp2;
        lightSpacePos[2] = lightMatrices[2] * tmp2;
        lightSpacePos[3] = lightMatrices[3] * tmp2;

        if(useNormal){
            normal = mat3(jointMatrix) * normalIn;
            normal = normalize(mat3(normalMatrix) * normal);
        }
        if(useTangent){
            tangent   = mat3(jointMatrix) * tangentIn.xyz;
            tangent   = normalize(vec3(model * vec4(tangent, 0.0)));
            bitangent = cross(normal, tangent) * tangentIn.w;
        }

    } else {
        if (useNormal) normal = normalize(mat3(normalMatrix) * normalIn);
        if (useTangent) {
            tangent   = normalize(vec3(model * vec4(tangentIn.xyz, 0.0)));
            bitangent = cross(normal, tangent) * tangentIn.w;
        }

        vec4 tmp2 = model * pos;
        
        // Simplified Outline
        if (meshOutline > 0.0) {
             float thick = (outlineAttribute.w > 0.0) ? outlineAttribute.w : 1.0;
             vec3 nDir = (useNormal) ? normal : normalize(position); 
             tmp2.xyz += nDir * thick * meshOutline * length(cameraPosition - tmp2.xyz);
        }

        gl_Position = projection * view * tmp2;
        worldSpacePos = vec3(tmp2);
        
        lightSpacePos[0] = lightMatrices[0] * tmp2;
        lightSpacePos[1] = lightMatrices[1] * tmp2;
        lightSpacePos[2] = lightMatrices[2] * tmp2;
        lightSpacePos[3] = lightMatrices[3] * tmp2;
    }
    
    #if __VERSION__ >= 450
    gl_Position.y = -gl_Position.y;
    #endif
}