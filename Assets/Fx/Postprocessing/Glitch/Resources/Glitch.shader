// inspired by "mpeg artifacts" shadertoy https://www.shadertoy.com/view/Md2GDw
Shader "Hidden/Aras/PostProcessing/Glitch"
{

HLSLINCLUDE
#include "PostProcessing/Shaders/StdLib.hlsl"
#include "PostProcessing/Shaders/Colors.hlsl"

TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);

float4 _Params;

float random (float2 uv)
{
    return frac(sin(dot(uv, float2(12.9898,78.233))) * 43758.5453);
}

half4 Frag(VaryingsDefault i, float4 fragCoord : SV_Position) : SV_Target
{
    float2 uv = i.texcoord;
    float2 block = floor(fragCoord.xy / 16.0);
    float2 uv_noise = block;
    uv_noise += _Time.y*float2(5.47,3.46);
    float block_thresh = pow(frac(_Time.y * 1236.0453), 2.0) * 0.2 * _Params.x;
    float line_thresh = pow(frac(_Time.y * 2236.0453), 3.0) * 0.7 * _Params.x;

    float2 uv_r = i.texcoord, uv_g = i.texcoord, uv_b = i.texcoord;
    float3 res;

    // glitch some blocks and lines
    if (random(uv_noise) < block_thresh * _Params.y ||
        random(float2(1-uv_noise.y,0)) < line_thresh * _Params.y)
    {

        float2 dist = (frac(uv_noise) - 0.5) * 0.3;
        uv_r += dist * 0.1;
        uv_g += dist * 0.2;
        uv_b += dist * 0.125;
    }

    res.r = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv_r).r;
    res.g = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv_g).g;
    res.b = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv_b).b;

    // loose luma for some blocks
    if (random(uv_noise+29) < block_thresh * 0.1 * _Params.z)
        res.rgb = res.ggg;

    // discolor block lines
    if (random(float2(uv_noise.y+31,0)) < line_thresh * 0.1 * _Params.z)
        res.rgb = float3(0.0, dot(res.rgb, float3(1,1,1)), 0.0);

    // interleave lines in some blocks
    if (random(uv_noise+51) < block_thresh * 0.01 * _Params.w ||
        random(float2(1-uv_noise.y,7)) < line_thresh * 0.01 * _Params.w)
    {
        float lin = frac(fragCoord.y / 3.0);
        float3 mask = float3(3.0, 0.0, 0.0);
        if (lin > 0.333)
            mask = float3(0.0, 3.0, 0.0);
        if (lin > 0.666)
            mask = float3(0.0, 0.0, 3.0);        
        res *= mask;
    }

    // debug
    //res.r = random(uv_noise);
    //res.g = random(uv_noise+29);
    //res.b = random(uv_noise+61);
    return float4(res, 1);
}
ENDHLSL

    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
