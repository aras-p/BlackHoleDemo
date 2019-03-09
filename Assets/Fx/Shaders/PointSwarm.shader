Shader "Demo/Point Swarm"
{
    Properties
    {
        _Smoothness("Smoothness", Range(0, 1)) = 0
        _Metallic("Metallic", Range(0, 1)) = 0
        _Texture("Texture", 2D) = "white"
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
	            Ref 128 //Ref [_StencilNonBackground] // problematic
	        }		    

CGPROGRAM
#pragma vertex vert
#pragma fragment frag
#include "HLSLSupport.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityShaderUtilities.cginc"

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "UnityPBSLighting.cginc"

half _Smoothness;
half _Metallic;

float4x4 _LocalToWorld;
float4x4 _WorldToLocal;

struct Point
{
    float3 pos;
    float3 col;
};
StructuredBuffer<Point> PointBuffer;

struct v2f
{
    UNITY_POSITION(pos);
    float3 worldNormal : TEXCOORD0;
    float3 worldPos : TEXCOORD1;
    fixed4 color : COLOR0;
    #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
        half3 sh : TEXCOORD4; // SH
    #endif    
};

sampler2D _Texture;
float4 _Texture_ST;

v2f vert (appdata_full v, uint iid : SV_InstanceID)
{
    unity_ObjectToWorld = _LocalToWorld;
    unity_WorldToObject = _WorldToLocal;

    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f,o);
    
    Point pt = PointBuffer[iid];
    
    v.vertex.xyz *= 0.05;
    v.vertex.xyz += pt.pos.xyz;
    
    o.pos = UnityObjectToClipPos(v.vertex);
    
    //float2 uv = o.pos.xy/o.pos.w * 0.5 + 0.5;
    //uv = TRANSFORM_TEX(uv, _Texture);
    //o.color = tex2Dlod(_Texture, float4(uv, 0, 0));
    o.color = half4(pt.col, 1);
    
    float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    o.worldPos.xyz = worldPos;
    o.worldNormal = worldNormal;
    #if UNITY_SHOULD_SAMPLE_SH && !UNITY_SAMPLE_FULL_SH_PER_PIXEL
        o.sh = ShadeSHPerVertex (worldNormal, o.sh);
    #endif
    return o;
}

void frag (v2f IN,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    , out half4 outShadowMask : SV_Target4
#endif
)
{
    float3 worldPos = IN.worldPos.xyz;
    float3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
    SurfaceOutputStandard o = (SurfaceOutputStandard)0;
    o.Emission = 0.0;
    o.Alpha = 0.0;
    o.Occlusion = 1.0;
    o.Normal = IN.worldNormal;
    
    o.Albedo = IN.color.rgb;      
    o.Metallic = _Metallic;
    o.Smoothness = _Smoothness;
    
    // Setup lighting environment
    UnityGI gi;
    UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
    gi.indirect.diffuse = 0;
    gi.indirect.specular = 0;
    gi.light.color = 0;
    gi.light.dir = half3(0,1,0);
    UnityGIInput giInput;
    UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
    giInput.light = gi.light;
    giInput.worldPos = worldPos;
    giInput.worldViewDir = worldViewDir;
    giInput.atten = 1.0;
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
