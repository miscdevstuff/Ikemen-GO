/* Shadow Vertex Shader - Android/GLES 2.0 Strict Fix */
#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

#if __VERSION__ >= 450
    // --- MODERN PATH (Vulkan/Desktop) ---
    #extension GL_ARB_shader_viewport_layer_array  : enable
    #define COMPAT_TEXTURE texture
    layout (constant_id = 0) const bool useJoint0 = false;
    layout (constant_id = 1) const bool useJoint1 = false;
    layout (constant_id = 2) const bool useVertColor = false;

    struct Light {
        vec3 direction; float range;
        vec3 color; float intensity;
        vec3 position; float innerConeCos;
        float outerConeCos; int type;
        float shadowBias; float shadowMapFar;
    };

    layout(binding = 0) uniform UniformBufferObject0 {
        mat4 lightMatrices[24];
        Light lights[4];
        vec4 layers[6];
    };
    layout(binding = 2) uniform UniformBufferObject2 {
        vec4 morphTargetWeight[2];
        vec4 morphTargetOffset;
        int numJoints,numTargets,morphTargetTextureDimension;
    };
    layout(binding = 3) uniform sampler2D jointMatrices;
    layout(binding = 4) uniform sampler2D morphTargetValues;

    layout(push_constant, std430) uniform u {
        mat4 model;
        int numVertices;
    };

    layout(location = 0) in int vertexId;
    layout(location = 1) in vec3 position;
    layout(location = 2) in vec2 uv;
    layout(location = 3) in vec4 vertColor;
    layout(location = 4) in vec4 joints_0;
    layout(location = 5) in vec4 joints_1;
    layout(location = 6) in vec4 weights_0;
    layout(location = 7) in vec4 weights_1;

    layout(location = 0) out vec4 FragPos;
    layout(location = 1) out float vColorAlpha;
    layout(location = 2) out vec2 texcoord0;
    layout(location = 3) out flat int lightIndex;

    mat4 transpose(mat4 m) { return m; } 

#else
    // --- ANDROID / LEGACY PATH ---
    #define COMPAT_VARYING varying 
    #define COMPAT_ATTRIBUTE attribute 
    #define COMPAT_TEXTURE texture2D

    uniform mat4 model;
    uniform sampler2D jointMatrices;
    uniform sampler2D morphTargetValues;
    uniform int morphTargetTextureDimension;
    uniform int numJoints;
    uniform int numTargets;
    uniform vec4 morphTargetWeight[2];
    uniform vec4 morphTargetOffset;
    uniform int numVertices;
    
    // Engine provides 24 matrices
    uniform mat4 lightMatrices[24]; 
    uniform int lightIndex; 

    COMPAT_ATTRIBUTE float vertexId;
    COMPAT_ATTRIBUTE vec3 position;
    COMPAT_ATTRIBUTE vec4 vertColor;
    COMPAT_ATTRIBUTE vec2 uv;
    COMPAT_ATTRIBUTE vec4 joints_0;
    COMPAT_ATTRIBUTE vec4 joints_1;
    COMPAT_ATTRIBUTE vec4 weights_0;
    COMPAT_ATTRIBUTE vec4 weights_1;
    
    COMPAT_VARYING vec4 FragPos;
    COMPAT_VARYING float vColorAlpha;
    COMPAT_VARYING vec2 texcoord0;
    COMPAT_VARYING float vLightIndex;

    #define useJoint0 (weights_0.x + weights_0.y + weights_0.z + weights_0.w + \
                       weights_1.x + weights_1.y + weights_1.z + weights_1.w > 0.0)

    #define useJoint1 true
    #define useVertColor true
    
    mat4 transpose(mat4 m) {
        return mat4(
            m[0][0], m[1][0], m[2][0], m[3][0],
            m[0][1], m[1][1], m[2][1], m[3][1],
            m[0][2], m[1][2], m[2][2], m[3][2],
            m[0][3], m[1][3], m[2][3], m[3][3]
        );
    }

    mat4 getMatrixFromTexture(float index){
        mat4 mat;
        float nj = float(numJoints > 0 ? numJoints : 1); 
        mat[0] = COMPAT_TEXTURE(jointMatrices,vec2(0.5/6.0,(index+0.5)/nj));
        mat[1] = COMPAT_TEXTURE(jointMatrices,vec2(1.5/6.0,(index+0.5)/nj));
        mat[2] = COMPAT_TEXTURE(jointMatrices,vec2(2.5/6.0,(index+0.5)/nj));
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
        if(abs(ret[0][0]) < 0.0001 && abs(ret[3][3]) < 0.0001) return mat4(1.0);
        return ret;
    }

    float getMorphTargetWeight(int idx) {
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
#endif

void main() {
    #if __VERSION__ >= 450
        texcoord0 = uv;
        vColorAlpha = useVertColor ? vertColor.a : 1.0;
        vec4 pos = vec4(position, 1.0);
        FragPos = model * pos;
        gl_Position = lightMatrices[0] * FragPos; 
    #else
        // --- LEGACY LOGIC ---
        texcoord0 = uv;
        vColorAlpha = useVertColor ? vertColor.a : 1.0;
        vec4 pos = vec4(position, 1.0);

        // Morph Targets - STRICT GLES 2.0 LOOP
        // Removed 'break' and dynamic conditions from loop header
        if (morphTargetOffset[0] > 0.0){
            for (int idx = 0; idx < 8; ++idx) {
                // Guard the logic instead of breaking
                if (idx < numTargets) {
                    float i   = float(idx) * float(numVertices) + vertexId;
                    float dim = float(morphTargetTextureDimension);
                    vec2 xy = vec2((i + 0.5) / dim - floor(i / dim), (floor(i / dim) + 0.5) / dim);
                    float w = getMorphTargetWeight(idx);
                    float idxf = float(idx);

                    if (idxf < morphTargetOffset[0]){
                        pos += w * COMPAT_TEXTURE(morphTargetValues, xy);
                    } else if (idxf >= morphTargetOffset[2] && idxf < morphTargetOffset[3]){
                        texcoord0 += w * vec2(COMPAT_TEXTURE(morphTargetValues, xy));
                    }
                }
            }
        }

        if (useJoint0){
            mat4 jointMatrix = getJointMatrix();
            FragPos = model * jointMatrix * pos;
        } else {
            FragPos = model * pos;
        }

        // Pass light index to Fragment Shader
        vLightIndex = float(lightIndex);
        
        // Project Shadow
        // If this indexing fails on specific device, we may need a fallback, 
        // but this is standard compliant for Vertex Shaders.
        gl_Position = lightMatrices[lightIndex] * FragPos; 
    #endif
}
