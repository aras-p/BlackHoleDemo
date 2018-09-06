// Upgrade NOTE: replaced 'defined FOG_COMBINED_WITH_WORLD_POS' with 'defined (FOG_COMBINED_WITH_WORLD_POS)'

// Swarm - Special renderer that draws a swarm of swirling/crawling lines.
// https://github.com/keijiro/Swarm
Shader "Swarm/Tube"
{
    Properties
    {
        _Smoothness("Smoothness", Range(0, 1)) = 0
        _Metallic("Metallic", Range(0, 1)) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        
    	Pass {
	    	Name "DEFERRED"
		    Tags { "LightMode" = "Deferred" }
	        Stencil
	        {
	            Comp Always
	            Pass Replace
	            //Ref [_StencilNonBackground] // problematic
	            Ref 128
	        }		    

CGPROGRAM
#pragma vertex vert_surf
#pragma fragment frag_surf
#pragma instancing_options procedural:setup
#pragma multi_compile_instancing
#include "HLSLSupport.cginc"
#define UNITY_INSTANCING_PROCEDURAL_FUNC setup
#include "UnityShaderVariables.cginc"
#include "UnityShaderUtilities.cginc"

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

        struct Input
        {
            half param : COLOR;
        };

        half _Smoothness;
        half _Metallic;

        half3 _GradientA;
        half3 _GradientB;
        half3 _GradientC;
        half3 _GradientD;

        float _Radius;

        float4x4 _LocalToWorld;
        float4x4 _WorldToLocal;

        StructuredBuffer<float4> _PositionBuffer;
        StructuredBuffer<float4> _TangentBuffer;
        StructuredBuffer<float4> _NormalBuffer;

        uint _InstanceCount;
        uint _HistoryLength;
        uint _IndexOffset;
        uint _IndexLimit;

        half3 CosineGradient(half param)
        {
            half3 c = _GradientB * cos(_GradientC * param + _GradientD);
            return GammaToLinearSpace(saturate(c + _GradientA));
        }

        void vert(inout appdata_full v, out Input data, uint iid)
        {
            UNITY_INITIALIZE_OUTPUT(Input, data);

            float phi = v.vertex.x; // Angle in slice
            float cap = v.vertex.y; // -1:head, +1:tail
            float seg = v.vertex.z; // Segment index
            uint iseg = min((uint)seg, _IndexLimit);

            // Parameter along the curve (used for coloring).
            float param = seg / _HistoryLength;
            param += (float)iid / _InstanceCount; 

            // Index of the current slice in the buffers.
            uint idx = iid;
            idx += _InstanceCount * ((iseg + _IndexOffset) % _HistoryLength);

            float3 p = _PositionBuffer[idx].xyz; // Position
            float3 t = _TangentBuffer[idx].xyz;  // Curve-TNB: Tangent 
            float3 n = _NormalBuffer[idx].xyz;   // Curve-TNB: Normal
            float3 b = cross(t, n);              // Curve-TNB: Binormal

            float3 normal = n * cos(phi) + b * sin(phi); // Surface normal

            // Feedback the results.
            v.vertex = float4(p + normal * _Radius * (1 - abs(cap)), 1);
            v.normal = normal * (1 - abs(cap)) + n * cap;
            //v.color = param;
            v.color = _PositionBuffer[idx].w;
        }

        void setup()
        {
            unity_ObjectToWorld = _LocalToWorld;
            unity_WorldToObject = _WorldToLocal;
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

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            //o.Albedo = CosineGradient(IN.param);
            o.Albedo = _Colors[IN.param];        
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
        }

        

// vertex-to-fragment interpolation data
struct v2f_surf {
  UNITY_POSITION(pos);
  float3 worldNormal : TEXCOORD0;
  float3 worldPos : TEXCOORD1;
  fixed4 color : COLOR0;
  #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
    half3 sh : TEXCOORD4; // SH
  #endif
};

// vertex shader
v2f_surf vert_surf (appdata_full v, uint iid : SV_InstanceID)
{
  v2f_surf o;
  UNITY_INITIALIZE_OUTPUT(v2f_surf,o);
  Input customInputData;
  vert (v, customInputData, iid);
  o.pos = UnityObjectToClipPos(v.vertex);
  float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
  float3 worldNormal = UnityObjectToWorldNormal(v.normal);
  o.worldPos.xyz = worldPos;
  o.worldNormal = worldNormal;
  o.color = v.color;
    #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
      o.sh = 0;
      o.sh = ShadeSHPerVertex (worldNormal, o.sh);
    #endif
  return o;
}

// fragment shader
void frag_surf (v2f_surf IN,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    , out half4 outShadowMask : SV_Target4
#endif
) {
  // prepare and unpack data
  Input surfIN;
  #ifdef FOG_COMBINED_WITH_TSPACE
    UNITY_EXTRACT_FOG_FROM_TSPACE(IN);
  #elif defined (FOG_COMBINED_WITH_WORLD_POS)
    UNITY_EXTRACT_FOG_FROM_WORLD_POS(IN);
  #else
    UNITY_EXTRACT_FOG(IN);
  #endif
  UNITY_INITIALIZE_OUTPUT(Input,surfIN);
  surfIN.param.x = 1.0;
  float3 worldPos = IN.worldPos.xyz;
  #ifndef USING_DIRECTIONAL_LIGHT
    fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
  #else
    fixed3 lightDir = _WorldSpaceLightPos0.xyz;
  #endif
  float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
  surfIN.param = IN.color;
  #ifdef UNITY_COMPILER_HLSL
  SurfaceOutputStandard o = (SurfaceOutputStandard)0;
  #else
  SurfaceOutputStandard o;
  #endif
  o.Albedo = 0.0;
  o.Emission = 0.0;
  o.Alpha = 0.0;
  o.Occlusion = 1.0;
  fixed3 normalWorldVertex = fixed3(0,0,1);
  o.Normal = IN.worldNormal;
  normalWorldVertex = IN.worldNormal;

  // call surface function
  surf (surfIN, o);
fixed3 originalNormal = o.Normal;
  half atten = 1;

  // Setup lighting environment
  UnityGI gi;
  UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
  gi.indirect.diffuse = 0;
  gi.indirect.specular = 0;
  gi.light.color = 0;
  gi.light.dir = half3(0,1,0);
  // Call GI (SH/reflections) lighting function
  UnityGIInput giInput;
  UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
  giInput.light = gi.light;
  giInput.worldPos = worldPos;
  giInput.worldViewDir = worldViewDir;
  giInput.atten = atten;
  giInput.lightmapUV = 0.0;
  giInput.ambient = ShadeSH9(half4(o.Normal,1)) * o.Albedo;
  giInput.probeHDR[0] = unity_SpecCube0_HDR;
  giInput.probeHDR[1] = unity_SpecCube1_HDR;
  LightingStandard_GI(o, giInput, gi);

  // call lighting function to output g-buffer
  outEmission = LightingStandard_Deferred (o, worldViewDir, gi, outGBuffer0, outGBuffer1, outGBuffer2);
  #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    outShadowMask = 1;
  #endif
}


ENDCG

}


    }
    FallBack Off
}
