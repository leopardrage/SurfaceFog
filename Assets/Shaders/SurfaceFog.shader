// Fog effect for geometry. It fades regular geometry that falls through the meshs that use this shader.
// Useful to create a fog at the bottom of an environment (e.g. a room or a landscape): simply create a material
// that uses this shader and apply it to a plane that lies where the fog starts.
// To use this shader you need a filled depth texture. You can achieve this by activating the Depth Texture flag for your camera,
// using the Deferred render mode, working with Screen Space Shadow Maps or any other feature that inheritently generate
// a depth texture to work.

// This is not a volumetric fog effect, so it works only when the camera is above the mesh that uses the fog, not inside it.
// It also doesn't work with orthographic cameras and oblique frustrums.
Shader "Custom/Surface Fog"
{
    Properties
    {
        _FogColor("Fog Color", Color) = (1, 1, 1, 1)
        _FogStrength ("Fog Strength", Float) = 1
    }

    HLSLINCLUDE

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

    ENDHLSL

    SubShader
    {
        PackageRequirements
        {
            "com.unity.render-pipelines.universal": "7.0"
        }

        // For the fog to work it's important that the Queue is set to "Queue" = "Transparent-1", so that
        // the fog mesh renders after all opaque objects are rendered (including skyboxes, that are rendered between
        // geometry and transparent objects) and its values can blend with already rendered ones.
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent-1"
        }

        Pass
        {
            // The goal is to calculate the amount of alpha to apply to the fog color before returning it
            // so this logic assumes that we blend the resulting color with the source based on the alpha.
            Blend SrcAlpha OneMinusSrcAlpha
            // Even if this shader is supposed to be rendered after all geometry and trasparent objects,
            // it seems resonable to avoid writing on the depth buffer, since the fog mesh depth shouldn't be used
            // by other draw calls (for exemple, post process effect could still need the geometry depth values to
            // perform some effects and wouldn't want the depth buffer values to be filled by the fog mesh ones)
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // Provide utilites to access the depth texture through the SampleSceneDepth method.
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            // SRP Batcher compatibility
            CBUFFER_START(UnityPerMaterial)
                half4 _FogColor;
                float _FogStrength;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionVS = mul(UNITY_MATRIX_MV, IN.positionOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // General idea:
                // - Retrieve the linear depth from the camera depth texture for the current screen position.
                // This representes the depth value of the previously rendered geometry that we want to apply the fog to.
                // (Remember that the shader has been instructed to be rendered after all geometry and transparent objects with "Queue"="Transparent+1")
                // - Retrieve the linear depth for the current pixel that representes where the fog starts.
                // - Calculate the fog alpha by subtracting the geometry depth and the current pixel depth, multiplyed by a fog strength factor
                // This representes how much the fog has affected the geometry in the current pixel.

                // Note: This procedure resambles the SoftParticle function in
                // Packages/com.unity.render-pipelines.universal/ShaderLibrary/Particles.hlsl.
                // As a matter of fact, the particle shader used in Fade Mode can be used to do fairly the same thing that this shader does.

                // _ScaledScreenParams is only available in SRP. It's like _ScreenParams
                // in Built-in RP, but takes the Render Scale value (SRP only) into account.
                float2 UV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                float rawDepth = SampleSceneDepth(UV);

                float fogAlpha = SurfaceFog(rawDepth, IN.positionVS, _ZBufferParams, _FogStrength);

                half4 resultColor = _FogColor;
                resultColor.a = fogAlpha;
                return resultColor;
            }
            ENDHLSL
        }
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent-1"
        }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            half4 _FogColor;
            float _FogStrength;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = UnityObjectToClipPos(IN.positionOS);
                OUT.positionVS = mul(UNITY_MATRIX_MV, IN.positionOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 UV = IN.positionHCS.xy / _ScreenParams.xy;
                float rawDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, UV);
                float fogAlpha = SurfaceFog(rawDepth, IN.positionVS, _ZBufferParams, _FogStrength);

                half4 resultColor = _FogColor;
                resultColor.a = fogAlpha;
                return resultColor;
            }

            ENDHLSL
        }
    }
}