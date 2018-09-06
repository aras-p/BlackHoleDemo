Shader "Demo/Raymarch/PyramidsMarched"
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

#define kMaxRaymarchIterations 200
#define kRaymarchPrecision 0.5

float4 _Param1, _Param2;
float4x4 _RaymarchTransform;
float4x4 _RaymarchInverseTransform;
float4 _TimelineTime;


// h: cos a, sin a, baseWidth. done as intersection(octahedron, box)
float2 sdPyramid(float3 p, float3 h, float slice)
{
    // Tetrahedron = Octahedron * Cube
    float dist = h.z * h.x;
    float height = dist / h.y;
    float sliceH = height / 6;
    float box = sdBox(p - float3(0,sliceH*(slice+0.5),0), float3(h.z,sliceH/2,h.z));
 
    float d = 0.0;
    d = max( d, abs( dot(p, float3( -h.x, h.y, 0 )) ));
    d = max( d, abs( dot(p, float3(  h.x, h.y, 0 )) ));
    d = max( d, abs( dot(p, float3(  0, h.y, h.x )) ));
    d = max( d, abs( dot(p, float3(  0, h.y,-h.x )) ));
    float octa = d - dist;
    return float2(max(box,octa), slice);
}

float2 opU(float2 a, float2 b)
{
    return a.x < b.x ? a : b;
}

static const half4 _Colors[6] = 
{
    half4(0.314, 0.040, 0.730, 1.000),
    half4(0.082, 0.474, 0.939, 1.000),
    half4(0.181, 0.397, 0.054, 1.000),
    half4(0.896, 0.591, 0.082, 1.000),
    half4(0.831, 0.202, 0.045, 1.000),
    half4(0.658, 0.051, 0.095, 1.000),
};

float2 pyramidScene(float3 p)
{
    p.xz -= 0.6;
    float3 origPos = p;
    float repeatSize = 1.2;
    p.xz = mod(p.xz, repeatSize) - 0.5*repeatSize;
    float2 pIndex = trunc(abs(origPos.xz - p.xz) / repeatSize);
    float pDistanceFromCenter = pIndex.x + pIndex.y;
    
    // _Param1.x: amount of pyramid disassemble translation
    // _Param1.y: amount of pyramid disassemble rotation
    // _Param1.z: how much distance to center should affect translation
    // _Param1.w: how much distance to center should affect rotation
    float disasmY = _Param1.x * (1 + _Param1.z * (pDistanceFromCenter));
    float disasmRot = _Param1.y * 0.1 * (1 + _Param1.w * (pDistanceFromCenter));
    
    float3 pyr = float3(cos(deg2rad(34)), sin(deg2rad(34)), 0.6);
    float2 pDist = float2(10000, 0);
    for (int i = 0; i < 6; ++i)
    {
        float2 pSlice = sdPyramid(rotateY(p - float3(0,disasmY*i,0), disasmRot*i), pyr, i);
        //float2 pSlice = sdPyramid(p - float3(0,disasmY*i,0), pyr, i);
        pDist = opU(pDist, pSlice);
    }
    return pDist;
}


float2 map(float3 pos)
{
    float3 opos = float3(_RaymarchTransform[0].w, _RaymarchTransform[1].w, _RaymarchTransform[2].w);
    pos -= opos;
    pos = mul((float3x3)_RaymarchInverseTransform, pos);

    float dall = sdSphere(pos, 30);
    float2 dpyr = pyramidScene(pos);
    return float2(max(dpyr.x, dall), dpyr.y);
}

float3 calcNormal(float3 p)
{
    const float d = 0.001;
    return normalize( float3(
        map(p+float3(  d,0.0,0.0)).x-map(p+float3( -d,0.0,0.0)).x,
        map(p+float3(0.0,  d,0.0)).x-map(p+float3(0.0, -d,0.0)).x,
        map(p+float3(0.0,0.0,  d)).x-map(p+float3(0.0,0.0, -d)).x));
}

void raymarch(float2 pos, inout float inoutDistance, out float outSteps, out float outLastDistance, out float3 outPos, out float outIndex)
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
        float2 m = map(outPos);
        outLastDistance = m.x * kRaymarchPrecision;
        outIndex = m.y;
        inoutDistance += outLastDistance;
        outPos += rayDir * outLastDistance;
        outSteps += 1.0;
        if (outLastDistance <= 0.001 || inoutDistance > maxDistance)
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
    float index;
    raymarch(pos, distance, num_steps, last_distance, ray_pos, index);
    normal = calcNormal(ray_pos);

    float4 color = _Color;
    color.r = index / 6.0;
    color.g = 1 - index / 6.0;
    color.rgb = _Colors[index];

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
