#ifndef raymarching_h_included
#define raymarching_h_included

#include "UnityCG.cginc"

#define PI      3.1415926535897932384626433832795

float deg2rad(float  deg) { return deg*PI/180.0; }
float2 deg2rad(float2 deg) { return deg*PI/180.0; }
float3 deg2rad(float3 deg) { return deg*PI/180.0; }
float4 deg2rad(float4 deg) { return deg*PI/180.0; }

float  modc(float  a, float  b) { return a - b * floor(a/b); }
float2 modc(float2 a, float2 b) { return a - b * floor(a/b); }
float3 modc(float3 a, float3 b) { return a - b * floor(a/b); }
float4 modc(float4 a, float4 b) { return a - b * floor(a/b); }

float3 getCameraPosition()    { return _WorldSpaceCameraPos; }
float3 getCameraForward()     { return -UNITY_MATRIX_V[2].xyz; }
float3 getCameraUp()          { return UNITY_MATRIX_V[1].xyz; }
float3 getCameraRight()       { return UNITY_MATRIX_V[0].xyz; }
float getCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }

float computeDepth(float4 clippos)
{
#if defined(SHADER_TARGET_GLSL) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)
    return ((clippos.z / clippos.w) + 1.0) * 0.5;
#else
    return clippos.z / clippos.w;
#endif
}


float3 rotateX(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(p.x, c*p.y+s*p.z, -s*p.y+c*p.z);
}

float3 rotateY(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(c*p.x-s*p.z, p.y, s*p.x+c*p.z);
}

float3 rotateZ(float3 p, float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float3(c*p.x+s*p.y, -s*p.x+c*p.y, p.z);
}

float2 rotate(float2 v, float a) {
	return float2(cos(a)*v.x + sin(a)*v.y, -sin(a)*v.x + cos(a)*v.y);
}


float4 vert (float4 pos : POSITION) : SV_POSITION
{
	return pos;
}

struct gbuffer_out
{
    half4 diffuse           : SV_Target0; // RT0: diffuse color (rgb), occlusion (a)
    half4 spec_smoothness   : SV_Target1; // RT1: spec color (rgb), smoothness (a)
    half4 normal            : SV_Target2; // RT2: normal (rgb), --unused, very low precision-- (a) 
    half4 emission          : SV_Target3; // RT3: emission (rgb), --unused-- (a)
    float depth             : SV_Depth;
};

#endif
