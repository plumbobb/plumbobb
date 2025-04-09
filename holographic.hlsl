// Adapted from this example that uses the Unity URP extension:
// https://medium.com/@gonzabarranco/how-to-make-a-hologram-shader-in-unity-with-hlsl-3d6ba415befb
// The following HLSL code works with Unity's Basic Pipeline

Shader "Custom/Hologram"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Holo Color", Color) =  (1, 1, 1, 1)
        _FColor ("Fresnel Color", Color) =  (1, 1, 1, 1)
        _AlphaTexture("Alpha Mask", 2D) = "white" {}
        _Scale ("Alpha Tiling", Range(0,5.0)) = 1
        _ScrollSpeed ("Alpha Speed", Range(0,5.0)) = 1.0
        _FresnelInt ("Fresnel Intensity", Range(0,1)) = 0.5
        _FresnelPow("Fresnel Power", Range(1, 5)) = 1
    }

    SubShader 
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent"}

        Blend SrcAlpha One
        ZWrite Off
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex, _AlphaTexture;
            float4 _MainTex_ST, _Color, _FColor;
            half _Scale, _ScrollSpeed, _FresnelInt, _FresnelPow;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 alphaPos : TEXCOORD1;
                float3 normal : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };

            v2f vert(appdata v)
            {
                v2f o;
                
                // Transform vertex to clip space using the built-in MVP matrix
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // Convert to world space
                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.worldPos = worldPos.xyz;

                // Convert to view space manually (Built-in RP replacement for TransformWorldToView)
                float4 viewPos = mul(UNITY_MATRIX_V, worldPos);
                o.alphaPos = viewPos.xyz;

                // Scroll Alpha
                o.alphaPos.y += _Time.y * _ScrollSpeed;

                // Normal transformation
                o.normal = normalize(mul((float3x3)unity_ObjectToWorld, v.normal));

                return o;
            }

            float FresnelCalculator(float3 normal, float3 viewDir, float fresnelPow)
            {
                return 1.0 - max(0, dot(normal, viewDir));
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float4 color = tex2D(_MainTex, i.uv);
                float4 alphaColor = tex2D(_AlphaTexture, i.alphaPos.xy * _Scale);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Fresnel - Ensure positive value for pow()
                float fresnel = FresnelCalculator(i.normal, viewDir, _FresnelPow);
                fresnel = pow(abs(fresnel), _FresnelPow) * _FresnelInt;
                float3 fresnelColor = fresnel * _FColor.rgb;

                color.rgb += fresnelColor;
                color.a = alphaColor.a;

                return _Color * color;
            }

            ENDCG
        }
    }
}
