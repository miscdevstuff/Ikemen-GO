/* Shadow Geometry Shader - Disabled for Android (GLES 2.0) */
/* GLES 2.0 does not support Geometry Shaders. This file is skipped on Android. */

#ifndef GL_ES
// --- START DESKTOP ONLY CODE ---

#if __VERSION__ >= 130
    #define COMPAT_POS_IN(i) gl_in[i].gl_Position
    layout(triangle_strip, max_vertices = 18) out;
    uniform int layerOffset;
    #define LAYER_OFFSET layerOffset
    layout(triangles) in;
    in float vColor[];
    in vec2 texcoord[];
    out vec4 FragPos;
    out float vColorAlpha;
    out vec2 texcoord0;
#else
    #extension GL_EXT_geometry_shader4: enable
    #define COMPAT_POS_IN(i) gl_PositionIn[i]
    #define LAYER_OFFSET 0

    varying in float vColor[3];
    varying in vec2 texcoord[3];
    varying out vec4 FragPos;
    varying out float vColorAlpha;
    varying out vec2 texcoord0;
#endif

uniform int lightIndex;
struct Light
{
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
uniform Light lights[4];

uniform mat4 lightMatrices[24];

const int LightType_None = 0;
const int LightType_Directional = 1;
const int LightType_Point = 2;
const int LightType_Spot = 3;

void main() {
    // This logic emits geometry to different CubeMap faces (gl_Layer)
    // This is impossible to emulate in GLES 2.0 shaders.
    if(lights[lightIndex].type == LightType_Point){
        for(int face = 0; face < 6; ++face)
        {
            gl_Layer = LAYER_OFFSET+face; 
            for(int i = 0; i < 3; ++i) 
            {
                FragPos = COMPAT_POS_IN(i);
                texcoord0 = texcoord[i];
                vColorAlpha = vColor[i];
                gl_Position = lightMatrices[lightIndex*6+face] * COMPAT_POS_IN(i);
                EmitVertex();
            }    
            EndPrimitive();
        }
    }else if(lights[lightIndex].type != LightType_None){
        gl_Layer = LAYER_OFFSET;
        for(int i = 0; i < 3; ++i) 
        {
            FragPos = COMPAT_POS_IN(i);
            texcoord0 = texcoord[i];
            vColorAlpha = vColor[i];
            gl_Position = lightMatrices[lightIndex] * COMPAT_POS_IN(i);
            EmitVertex();
        }
        EndPrimitive();
    }
}

// --- END DESKTOP ONLY CODE ---
#endif
