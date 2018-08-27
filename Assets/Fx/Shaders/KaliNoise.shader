Shader "Demo/Raymarch/KaliNoise"
{
	Properties
	{
		_Color ("Diffuse", Color) = (0.3,0.3,0.3,1.0)
		_SpecColor ("Specular", Color) = (0.2,0.2,0.2,1.0)
		_Smoothness ("Smoothness", Range(0,1)) = 0.5

        [IntRange] _SoundBand ("Sound Band", Range(0,9)) = 4
        _SoundMin ("Sound Min", Range(0,0.4)) = 0.1
        _SoundMax("Sound Max", Range(0,0.4)) = 0.3
        [Toggle] _ByPassSound("No Sound", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Cull Off
			Name "DEFERRED"
	        Stencil
	        {
	            Comp Always
	            Pass Replace
	            //Ref [_StencilNonBackground] // problematic
	            Ref 128
	        }

CGPROGRAM
#pragma vertex vert
#pragma fragment frag

#include "Raymarching.cginc"

#define kMaxRaymarchIterations 20
#define kMarchPrecision 0.2

float4 _Param1, _Param2;
float4x4 _RaymarchTransform;
float4x4 _RaymarchInverseTransform;
float _GlobalAudioSpectrumLevel[10];
float _GlobalAudioSpectrumPeak[10];
float _GlobalAudioSpectrumMean[10];
float _SoundMin, _SoundMax, _ByPassSound, _SoundBand;
float4 _TimelineTime;


float kali(float3 p)
{
    float3 kaliParam = _Param1.xyz;
    float cylRadius = _Param1.w * 0.07;
    float2 d = 100.0;
	for (int i=0; i<7; ++i)
	{
		p = abs(p) / dot(p, p) - kaliParam;
 		d.x = min(d.x, length(p.xz));	
 	}
	return d.x - cylRadius;
}

float kaliXform(float3 pos)
{
    float3 opos = float3(_RaymarchTransform[0].w, _RaymarchTransform[1].w, _RaymarchTransform[2].w);
    pos -= opos;
    pos = mul((float3x3)_RaymarchInverseTransform, pos);
    return kali(pos);
}

float kaliHollow(float3 pos)
{
	float d = kaliXform(pos);
	//float ds = length(pos-getCameraPosition()) - _Param2.x;
	//return max(d, -ds);
	return d;
}

float map(float3 p)
{
    return kaliHollow(p);
}

float3 calcNormal(float3 p)
{
    const float d = 0.01;
    return normalize( float3(
        map(p+float3(  d,0.0,0.0))-map(p+float3( -d,0.0,0.0)),
        map(p+float3(0.0,  d,0.0))-map(p+float3(0.0, -d,0.0)),
        map(p+float3(0.0,0.0,  d))-map(p+float3(0.0,0.0, -d)) ));
}

void raymarch(float2 pos, inout float inoutDistance, out float outSteps, out float outLastDistance, out float3 outPos)
{
    float3 camPos      = getCameraPosition();
    float3 camForward  = getCameraForward();
    float3 camUp       = getCameraUp();
    float3 camRight    = getCameraRight();
    float  camFocalLen = getCameraFocalLength();

    float3 rayDir = normalize(camRight*pos.x + camUp*pos.y + camForward*camFocalLen);
    float maxDistance = _ProjectionParams.z - _ProjectionParams.y;
    outPos = camPos + rayDir * inoutDistance;

    //float width = _Param1.w + smoothstep(_SoundMin, _SoundMax, _GlobalAudioSpectrumMean[4]) * 3;

    outSteps = 0.0;
    outLastDistance = 10.0;
    for (int i = 0; i < kMaxRaymarchIterations; ++i)
    {
        outLastDistance = map(outPos);        
        inoutDistance += outLastDistance;
        outPos += rayDir * outLastDistance * kMarchPrecision;
        outSteps += 1.0;
    }
    clip(_Param2.y-outLastDistance);
    inoutDistance = min(inoutDistance, maxDistance);
}

half4 _Color;
half3 _SpecColor;
half _Smoothness;

gbuffer_out frag(float4 ipos : SV_Position)
{
    float2 pos = ipos.xy * (_ScreenParams.zw-1) * 2 - 1;
    pos.x *= _ScreenParams.x / _ScreenParams.y;

    float num_steps = 1.0;
    float last_distance = 0.0;
    float distance = _ProjectionParams.y;
    float3 ray_pos;
    float3 normal;
    raymarch(pos, distance, num_steps, last_distance, ray_pos);

    normal = calcNormal(ray_pos);

    float4 color = _Color;
    
    float3 camPos      = getCameraPosition();
    float3 camDir = ray_pos - camPos;
    camDir *= 25;    

    gbuffer_out o;
    o.diffuse = color;
    o.spec_smoothness = float4(_SpecColor, _Smoothness);
    o.normal = float4(normal*0.5+0.5, 1.0);
    half3 ambient = ShadeSH9(half4(normal,1)) * color;
    o.emission = half4(ambient,1);
    o.depth = computeDepth(mul(UNITY_MATRIX_VP, float4(camPos + camDir, 1.0)));
    return o;
}
ENDCG
		}
	}
}
