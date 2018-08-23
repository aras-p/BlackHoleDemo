﻿Shader "Hidden/Kino/PostProcessing/Streak"
{
    HLSLINCLUDE

    #include "PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_HighTex, sampler_HighTex);

    float4 _MainTex_TexelSize;
    float _Threshold;
    float _Stretch;
    float _Intensity;
    half3 _Color;
    int _Mode;

    // Prefilter: Shrink horizontally and apply threshold.
    half4 FragPrefilter(VaryingsDefault i) : SV_Target
    {
        // Actually this should be 1, but we assume you need more blur...
        const float vscale = 1.5;
        const float dy = _MainTex_TexelSize.y * vscale / 2;

        float2 uv = i.texcoord;
        half3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(uv.x, uv.y - dy)).rgb;
        half3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(uv.x, uv.y + dy)).rgb;
        half3 c = (c0 + c1) / 2;

        if (_Mode == 0)
        {
            float br = max(c.r, max(c.g, c.b));
            c *= max(0, br - _Threshold) / max(br, 1e-5);
        }
        if (_Mode == 1)
        {
            if (c.r > _Threshold) c.r = 1;
            if (c.g > _Threshold) c.g = 1;
            if (c.b > _Threshold) c.b = 1;
        }


        return half4(c, 1);
    }

    // Downsampler
    half4 FragDownsample(VaryingsDefault i) : SV_Target
    {
        // Actually this should be 1, but we assume you need more blur...
        const float hscale = 1.25;
        const float dx = _MainTex_TexelSize.x * hscale;

        float2 uv = i.texcoord;
        float u0 = uv.x - dx * 5;
        float u1 = uv.x - dx * 3;
        float u2 = uv.x - dx * 1;
        float u3 = uv.x + dx * 1;
        float u4 = uv.x + dx * 3;
        float u5 = uv.x + dx * 5;

        half3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u0, uv.y)).rgb;
        half3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u1, uv.y)).rgb;
        half3 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u2, uv.y)).rgb;
        half3 c3 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u3, uv.y)).rgb;
        half3 c4 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u4, uv.y)).rgb;
        half3 c5 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, float2(u5, uv.y)).rgb;

        // Simple box filter
        half3 c = (c0 + c1 + c2 + c3 + c4 + c5) / 6;

        return half4(c, 1);
    }

    // Upsampler
    half4 FragUpsample(VaryingsDefault i) : SV_Target
    {
        half3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb / 4;
        half3 c1 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb / 2;
        half3 c2 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb / 4;
        half3 c3 = SAMPLE_TEXTURE2D(_HighTex, sampler_HighTex, i.texcoord).rgb;
        return half4(lerp(c3, c0 + c1 + c2, _Stretch), 1);
    }

    // Final composition
    half4 FragComposition(VaryingsDefault i) : SV_Target
    {
        half3 c0 = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord).rgb;
        half3 c3 = SAMPLE_TEXTURE2D(_HighTex, sampler_HighTex, i.texcoord).rgb;
        half3 cf = c0 * _Color * _Intensity * 5 + c3;
        if (_Mode == 1)
        {
            c0 = saturate(c0 * c0);
            c0 = lerp(1, c0, _Intensity);
            cf = c0 * c3;
        }
        if (_Mode == 2)
            cf = c0 * 3;
        return half4(cf, 1);
    }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragPrefilter
            ENDHLSL
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragDownsample
            ENDHLSL
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragUpsample
            ENDHLSL
        }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment FragComposition
            ENDHLSL
        }
    }
}
