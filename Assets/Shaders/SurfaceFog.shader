// Fog effect for geometry. It fades regular geometry that falls through the meshs that use this shader.
// Useful to create a fog at the bottom of an environment (e.g. a room or a landscape): simply create a material
// that uses this shader and apply it to a plane that lies where the fog starts.
// To use this shader you have to use Deferred render mode or activate the Depth Texture flag for your camera.

// This is not a volumetric fog effect, so it works only when the camera is above the mesh that uses the fog, not inside it.
// It also doesn't work with orthographic cameras and oblique frustrums.
Shader "Custom/Surface Fog"
{
    Properties
    {
        _FogColor("Fog Color", Color) = (1, 1, 1, 1)
        _FogStrength ("Fog Strength", Float) = 1
    }

    SubShader
    {
        // For the fog to work it's important that the Queue is set to "Queue" = "Transparent+1", so that
        // the fog mesh renders after all geometry is rendered and its values can blend with geometry ones.
        Tags { "RenderType" = "Fade" "RenderPipeline" = "UniversalRenderPipeline" "Queue" = "Transparent+1"}

        Pass
        {
            // The goal is to calculate the amount of alpha to apply to the fog color before returning it
            // so this logic assumes that we blend the resulting color with the source based on the alpha.
            Blend SrcAlpha OneMinusSrcAlpha
            // Even if this shader is supposed to be rendered after all geometry and trasparent objects
            // is seem resonable to avoid writing on the depth buffer, since the fog mesh depth shouldn't be used
            // by other draw calls (for exemple, post process effect could still need the geometry depth buffer to
            // perform some effects and wouldn't want the depth buffer values to be filled by the fog mesh ones)
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Provide utilites to access the depth texture through the SampleSceneDepth method.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object space.
                float4 positionOS   : POSITION;                 
            };

            struct Varyings
            {
                // The positionHCS variable contains the vertex positions in homogeneous coordinate space.
                float4 positionHCS  : SV_POSITION;
                // The positionWS variable contains the vertex positions in world space.
                float3 positionWS   : TEXCOORD0;
            };

            // To make the Unity shader SRP Batcher compatible, declare all
            // properties related to a Material in a a single CBUFFER block with 
            // the name UnityPerMaterial.
            CBUFFER_START(UnityPerMaterial)
                half4 _FogColor;
                float _FogStrength;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // The TransformObjectToHClip function transforms vertex positions
                // from object space to homogenous space
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                // The TransformObjectToWorld function transforms vertex positions
                // from object space to world space. Needed to calculate the current depth value
                // in the fragment shader.
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // General idea:
                // - Retrieve the linear depth from the camera depth texture for the current screen position.
                // This representes the depth value of the previously rendered geometry that we want to apply the for to.
                // (Remember that the shader has been instructed to be rendered after all geometry and transparent objects with "Queue"="Transparent+1")
                // - Retrieve the linear depth for the current pixel that representes where the fog starts.
                // - Calculate the fog alpha by subtracting the geometry depth and the current pixel depth, multiplyed by a fog strength factor
                // This representes how much the fog has affected the geometry in the current pixel.

                // Note: This procedure resambles the SoftParticle function in
                // Packages/com.unity.render-pipelines.universal/ShaderLibrary/Particles.hlsl.
                // As a matter of fact, the particle shader used in Fade Mode can be used to do fairly the same thing that this shader does.

                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                float rawDepth = SampleSceneDepth(UV);
                float sceneZ = LinearEyeDepth(rawDepth, _ZBufferParams);
                float thisZ = LinearEyeDepth(IN.positionWS.xyz, GetWorldToViewMatrix());
                float fogAlpha = saturate(_FogStrength * (sceneZ - thisZ));

                half4 resultColor = _FogColor;
                resultColor.a = fogAlpha;
                return resultColor;
            }
            ENDHLSL
        }
    }
}