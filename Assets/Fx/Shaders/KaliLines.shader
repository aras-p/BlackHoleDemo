Shader "Demo/Raymarch/KaliLines"
{
	Properties
	{
		_Color ("Diffuse", Color) = (0.3,0.3,0.3,1.0)
		_SpecColor ("Specular", Color) = (0.2,0.2,0.2,1.0)
		_Smoothness ("Smoothness", Range(0,1)) = 0.5
        _KaliParam ("Param (xyz), Thick (w)", Vector) = (0.52, 0.5, 1.5, 1.5) // xyz: fractal params, w: thickness
        _KaliParam2 ("Hollow (x)", Vector) = (1.1, 0,0,0)

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

#define kMaxRaymarchIterations 100


float4 _KaliParam;
float4 _KaliParam2;
float4x4 _RaymarchTransform;
float _GlobalAudioSpectrumLevel[10];
float _GlobalAudioSpectrumPeak[10];
float _GlobalAudioSpectrumMean[10];
float _SoundMin, _SoundMax, _ByPassSound, _SoundBand;
float4 _TimelineTime;


float kali(float3 pos)
{
    float3 opos = float3(_RaymarchTransform[0].w, _RaymarchTransform[1].w, _RaymarchTransform[2].w);
    pos -= opos;
    pos = mul(pos, (float3x3)_RaymarchTransform);

	float len = length(pos);
	if (len > 7)
		return len * 10;

	float4 p = float4(pos,1);
	float4 param = _KaliParam;
    half sa1 = smoothstep(_SoundMin, _SoundMax, _GlobalAudioSpectrumLevel[1]);
    half sa2 = smoothstep(_SoundMin, _SoundMax, _GlobalAudioSpectrumLevel[2]);
    half sa3 = smoothstep(_SoundMin, _SoundMax, _GlobalAudioSpectrumLevel[3]);
    param.x -= sa1 * 0.01;
    param.y -= sa2 * 0.01;
    //param.z -= sa3 * 0.01;
    param.z -= (_TimelineTime.x-30) * 0.01;
    //param.z -= soundAlpha * 0.1;

	float d = 10000.0;
	for (int i = 0; i < 6; ++i)
	{
        p = abs(p) / dot(p.xyz, p.xyz);
        d = min(d, length(p.xy) / (p.w*param.w));
        p.xyz -= param.xyz;
	}
	return max(1.0e-5f, d) * 10.0;
}

float kaliHollow(float3 pos)
{
	float d = kali(pos);
	float ds = length(pos-getCameraPosition()) - _KaliParam2.x;
	return max(d, -ds);
}

float map(float3 p)
{
    return kaliHollow(p);
}

float3 calcNormal(float3 p)
{
    const float d = 0.001;
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

    outSteps = 0.0;
    outLastDistance = 0.0;
    for (int i = 0; i < kMaxRaymarchIterations; ++i)
    {
        outLastDistance = map(outPos);
        inoutDistance += outLastDistance;
        outPos += rayDir * outLastDistance;
        outSteps += 1.0;
        if (outLastDistance < 0.003 || inoutDistance > maxDistance)
            break;
    }
    inoutDistance = min(inoutDistance, maxDistance);
    if (inoutDistance >= maxDistance)
        discard;
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

    gbuffer_out o;
    o.diffuse = color;
    o.spec_smoothness = float4(_SpecColor, _Smoothness);
    o.normal = float4(normal*0.5+0.5, 1.0);
    half3 ambient = ShadeSH9(half4(normal,1)) * color;
    o.emission = half4(ambient,1);
    o.depth = computeDepth(mul(UNITY_MATRIX_VP, float4(ray_pos, 1.0)));
    return o;	
}
ENDCG
		}
	}
}
