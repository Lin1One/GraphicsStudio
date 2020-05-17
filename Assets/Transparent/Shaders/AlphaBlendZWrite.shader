﻿Shader "GraphicsStudio/Transparent/AlphaBlendZWrite"
{

    Properties 
    {
        _Color ("Color Tint", Color) = (1,1,1,1)     
        _MainTex ("Main Tex", 2D) = "white" {}
        _AlphaScale ("Alpha Scale",Range(0,1)) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "AlphaTest"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
        }
        Pass
        {
            // 新添加的Pass的目的仅仅是为了把模型的深度信息写入深度缓冲中
            // 从而剔除模型中被自身遮挡的片元。
            Zwrite On
            //在ShaderLab中，ColorMask用于设置颜色通道的写掩码（write mask）。
            //ColorMask RGB | A | 0 | 其他任何R、G、B、A的组合
            ColorMask 0
        }
        Pass
        {
            Tags 
            {
                "LightMode"="ForwardBase"
            }
            Zwrite off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed _AlphaScale;


            struct a2v 
            {    
                float4 vertex : POSITION;    
                float3 normal : NORMAL;
                float4 texcoord : TEXCOORD0;
            };

            struct v2f 
            {    
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert(a2v v) 
            {   
                v2f o;    
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target 
            {  
                fixed4 texColor = tex2D(_MainTex,i.uv);
                fixed3 albedo = texColor.rgb * _Color.rgb;
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 disffuse = _LightColor0.rgb * albedo * max(0,dot(worldNormal,worldLightDir));
                return fixed4(ambient + disffuse,texColor.a * _AlphaScale);
            }
            ENDCG
        }
    }
    Fallback "Transparent/VertexLit"
}
