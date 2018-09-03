Shader "Demo/Raymarch/Pyramid"
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

#define kMaxRaymarchIterations 128

float4 _Param1, _Param2;
float4x4 _RaymarchTransform;
float4x4 _RaymarchInverseTransform;
float _GlobalAudioSpectrumLevel[10];
float _GlobalAudioSpectrumPeak[10];
float _GlobalAudioSpectrumMean[10];
float _SoundMin, _SoundMax, _ByPassSound, _SoundBand;
float4 _TimelineTime;

float pyramid(float3 p)
{
    float3 w = p;
    float3 q = p;

    q.xz = mod(q.xz+1.0, 2.0) - 1.0;
    
    float d = sdBox(q, 1.0);
    float s = 1.0;
    for (int m = 0; m < 6; ++m)
    {
        float h = m/6.0;

        p =  q - 0.5*sin(abs(p.y) + float(m)*3.0+float3(0.0,3.0,1.0));

        float3 a = mod(p*s, 2.0) - 1.0;
        s *= 3.0;
        float3 r = abs(1.0 - 3.0*abs(a));

        float da = max(r.x,r.y);
        float db = max(r.y,r.z);
        float dc = max(r.z,r.x);
        float c = (min(da,min(db,dc))-1.0)/s;

        d = max(c, d);
   }
    
   float d1 = length(w-float3(0.22,0.35,0.4)) - 0.09;
   d = min(d, d1);

   float d2 = w.y + 0.22;
   d = min(d,d2);
    
   return d;
}


float map(float3 pos)
{
    //float3 opos = float3(_RaymarchTransform[0].w, _RaymarchTransform[1].w, _RaymarchTransform[2].w);
    //pos -= opos;
    //pos = mul((float3x3)_RaymarchInverseTransform, pos);
    return pyramid(pos);
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
    //float maxDistance = _ProjectionParams.z - _ProjectionParams.y;
    float maxDistance = 16;
    outPos = camPos + rayDir * inoutDistance;

    outSteps = 0.0;
    outLastDistance = 0.0;
    for (int i = 0; i < kMaxRaymarchIterations; ++i)
    {
        outLastDistance = map(outPos);
        inoutDistance += outLastDistance;
        outPos += rayDir * outLastDistance;
        outSteps += 1.0;
        if (outLastDistance < 0.0001 || inoutDistance > maxDistance)
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
