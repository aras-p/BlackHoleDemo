Shader "Demo/Particles/Alpha Blended Sound" {
Properties {
    _TintColor ("Tint Color", Color) = (1,1,1,1)
    _MainTex ("Particle Texture", 2D) = "white" {}
    [IntRange] _SoundBand ("Sound Band", Range(0,9)) = 4
    _SoundMin ("Sound Min", Range(0,0.4)) = 0.1
    _SoundMax("Sound Max", Range(0,0.4)) = 0.3
    _MinAlpha("Min Alpha", Range(0,1)) = 0.1
    [Toggle] _ByPassSound("No Sound", Float) = 0
}

Category {
    Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "PreviewType"="Plane" }
    Blend SrcAlpha OneMinusSrcAlpha
    ColorMask RGB
    Cull Off Lighting Off ZWrite Off

    SubShader {
        Pass {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            sampler2D _MainTex;
            half4 _TintColor;

            float _GlobalAudioSpectrumLevel[10];
            float _GlobalAudioSpectrumPeak[10];
            float _GlobalAudioSpectrumMean[10];
            float _SoundMin, _SoundMax, _ByPassSound, _MinAlpha, _SoundBand;

            struct appdata_t {
                float4 vertex : POSITION;
                half4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                half4 color : COLOR;
                float2 texcoord : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            float4 _MainTex_ST;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                half soundAlpha = smoothstep(_SoundMin, _SoundMax, _GlobalAudioSpectrumLevel[_SoundBand]);
                soundAlpha = lerp(_MinAlpha, 1.0, soundAlpha);
                if (_ByPassSound != 0)
                    soundAlpha = 1;
                o.color = v.color * _TintColor;
                o.color.a *= soundAlpha;
                o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            float _InvFade;

            half4 frag (v2f i) : SV_Target
            {
                half4 col = i.color * tex2D(_MainTex, i.texcoord);

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
}
