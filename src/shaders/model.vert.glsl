#ifdef GL_ES
precision highp float;
precision mediump int;
#endif

#if __VERSION__ >= 450
    // VULKAN / MODERN GL PATH (Keep as is)
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
    layout(location = 6) in vec4 boneWeights;
    layout(location = 7) in vec4 boneIndices;
    layout(location = 8) in vec4 outlineAttribute;

    layout(location = 0) out vec3 worldSpacePos;
    layout(location = 1) out vec3 normal;
    layout(location = 2) out vec2 texcoord;
    layout(location = 3) out vec4 lightSpacePos[4]; // Array OK in 450
    layout(location = 7) out float vColor;
    layout(location = 8) out vec3 tangent;
    layout(location = 9) out vec3 bitangent;

    // Helper for 450
    float getMorphTargetWeight(int idx) {
        if (idx < 4) return morphTargetWeight[0][idx];
        return morphTargetWeight[1][idx-4];
    }
    mat4 getJointMatrix() {
        mat4 jointMatrix = mat4(0.0);
        for(int i=0; i<4; i++){
            int idx = int(boneIndices[i]);
            float weight = boneWeights[i];
            if(weight > 0.0){
                float j = float(idx) * 4.0;
                float w = 2048.0; // Texture width assumed
                vec4 r0 = COMPAT_TEXTURE(jointMatrices, vec2((j+0.5)/w,0.0));
                vec4 r1 = COMPAT_TEXTURE(jointMatrices, vec2((j+1.5)/w,0.0));
                vec4 r2 = COMPAT_TEXTURE(jointMatrices, vec2((j+2.5)/w,0.0));
                vec4 r3 = COMPAT_TEXTURE(jointMatrices, vec2((j+3.5)/w,0.0));
                jointMatrix += weight * mat4(r0, r1, r2, r3);
            }
        }
        return jointMatrix;
    }

#else
    // --- ANDROID / LEGACY PATH ---
    #define COMPAT_VARYING varying 
    #define COMPAT_ATTRIBUTE attribute 
    #define COMPAT_TEXTURE texture2D

    // Uniforms
    uniform mat4 view, projection;
    uniform mat4 lightMatrices[4];
    uniform vec3 cameraPosition;
    uniform mat4 model, normalMatrix;
    uniform int numJoints, numTargets, morphTargetTextureDimension, numVertices;
    uniform vec4 morphTargetWeight[2];
    uniform vec4 morphTargetOffset;
    uniform float meshOutline;
    uniform sampler2D jointMatrices;
    uniform sampler2D morphTargetValues;

    // Constants (Simulated as bool uniforms or defines)
    uniform bool useJoint0;
    uniform bool useJoint1;
    uniform bool useNormal;
    uniform bool useTangent;
    uniform bool useVertColor;
    uniform bool useOutlineAttribute;

    // Attributes
    COMPAT_ATTRIBUTE float vertexId; // Must be float in GLES2
    COMPAT_ATTRIBUTE vec3 position;
    COMPAT_ATTRIBUTE vec2 uv;
    COMPAT_ATTRIBUTE vec3 normalIn;
    COMPAT_ATTRIBUTE vec4 tangentIn;
    COMPAT_ATTRIBUTE vec4 vertColor;
    COMPAT_ATTRIBUTE vec4 boneWeights;
    COMPAT_ATTRIBUTE vec4 boneIndices;
    COMPAT_ATTRIBUTE vec4 outlineAttribute;

    // Varyings (UNROLLED ARRAYS)
    COMPAT_VARYING vec3 worldSpacePos;
    COMPAT_VARYING vec3 normal;
    COMPAT_VARYING vec2 texcoord;
    
    // Unrolled light positions for GLES 2.0
    COMPAT_VARYING vec4 v_lightSpacePos0;
    COMPAT_VARYING vec4 v_lightSpacePos1;
    COMPAT_VARYING vec4 v_lightSpacePos2;
    COMPAT_VARYING vec4 v_lightSpacePos3;
    
    COMPAT_VARYING float vColor;
    COMPAT_VARYING vec3 tangent;
    COMPAT_VARYING vec3 bitangent;

    // Helpers
    float getMorphTargetWeight(int idx) {
        if (idx == 0) return morphTargetWeight[0].x;
        if (idx == 1) return morphTargetWeight[0].y;
        if (idx == 2) return morphTargetWeight[0].z;
        if (idx == 3) return morphTargetWeight[0].w;
        if (idx == 4) return morphTargetWeight[1].x;
        return 0.0;
    }

    mat4 getJointMatrix() {
        mat4 jointMatrix = mat4(0.0);
        for(int i=0; i<4; i++){
            int idx = int(boneIndices[i]);
            float weight = boneWeights[i];
            if(weight > 0.0){
                float j = float(idx) * 4.0;
                float w = 2048.0; 
                vec4 r0 = COMPAT_TEXTURE(jointMatrices, vec2((j+0.5)/w,0.0));
                vec4 r1 = COMPAT_TEXTURE(jointMatrices, vec2((j+1.5)/w,0.0));
                vec4 r2 = COMPAT_TEXTURE(jointMatrices, vec2((j+2.5)/w,0.0));
                vec4 r3 = COMPAT_TEXTURE(jointMatrices, vec2((j+3.5)/w,0.0));
                jointMatrix += weight * mat4(r0, r1, r2, r3);
            }
        }
        return jointMatrix;
    }
#endif

void main() {
    texcoord = uv;
    
    // Handle Vertex Color
    #if __VERSION__ >= 450
        if (useVertColor) vColor = vertColor.a; else vColor = 1.0;
    #else
        if (useVertColor) vColor = vertColor.a; else vColor = 1.0;
    #endif

    vec4 pos = vec4(position, 1.0);

    // Morph Targets
    if (morphTargetOffset[0] > 0.0){
        for (int idx = 0; idx < 8; ++idx) { // Cap loop for GLES2 safety
            if(idx >= numTargets) break;
            
            float i   = float(idx) * float(numVertices) + float(vertexId);
            float dim = float(morphTargetTextureDimension);

            vec2 xy = vec2(
                (i + 0.5) / dim - floor(i / dim),
                (floor(i / dim) + 0.5) / dim
            );

            float idxf = float(idx);
            float w    = getMorphTargetWeight(idx);

            if (idxf < morphTargetOffset[0]){
                pos += w * COMPAT_TEXTURE(morphTargetValues, xy);
            } else if (idxf >= morphTargetOffset[2] && idxf < morphTargetOffset[3]){
                texcoord += w * vec2(COMPAT_TEXTURE(morphTargetValues, xy));
            }
        }
    }

    // Skeletal Animation
    if (useJoint0){
        mat4 jointMatrix = getJointMatrix();
        // Recalculate pos with joints
        vec4 tmp2 = jointMatrix * pos;
        
        gl_Position = projection * view * tmp2;
        worldSpacePos = vec3(tmp2);
        
        // Output Unrolled Light Positions
        #if __VERSION__ >= 450
            lightSpacePos[0] = lightMatrices[0] * tmp2;
            lightSpacePos[1] = lightMatrices[1] * tmp2;
            lightSpacePos[2] = lightMatrices[2] * tmp2;
            lightSpacePos[3] = lightMatrices[3] * tmp2;
        #else
            v_lightSpacePos0 = lightMatrices[0] * tmp2;
            v_lightSpacePos1 = lightMatrices[1] * tmp2;
            v_lightSpacePos2 = lightMatrices[2] * tmp2;
            v_lightSpacePos3 = lightMatrices[3] * tmp2;
        #endif

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
        // Static Mesh
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
        
        #if __VERSION__ >= 450
            lightSpacePos[0] = lightMatrices[0] * tmp2;
            lightSpacePos[1] = lightMatrices[1] * tmp2;
            lightSpacePos[2] = lightMatrices[2] * tmp2;
            lightSpacePos[3] = lightMatrices[3] * tmp2;
        #else
            v_lightSpacePos0 = lightMatrices[0] * tmp2;
            v_lightSpacePos1 = lightMatrices[1] * tmp2;
            v_lightSpacePos2 = lightMatrices[2] * tmp2;
            v_lightSpacePos3 = lightMatrices[3] * tmp2;
        #endif
    }
}
