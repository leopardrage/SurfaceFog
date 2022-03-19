#ifndef SURFACE_FOG_INCLUDED
#define SURFACE_FOG_INCLUDED

struct Attributes
{
    float4 positionOS   : POSITION;                 
};

struct Varyings
{
    float4 positionHCS  : SV_POSITION;
    float4 positionVS   : TEXCOORD0;
};

float SurfaceFog(float rawDepth, float4 viewPos, float4 zBufferParam, float fogStrength) {
    // Decode linear depth from the depth texture (same implementation of LinearEyeDepth, URP)
    // Transform depth texture values (in clip space, thus non linear) in view space values.
    float sceneZ = 1.0 / (zBufferParam.z * rawDepth + zBufferParam.w);
    float thisZ = abs(viewPos.z);
    return saturate(fogStrength * (sceneZ - thisZ)); 
}

#endif
