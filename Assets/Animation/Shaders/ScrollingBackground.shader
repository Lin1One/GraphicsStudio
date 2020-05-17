﻿Shader "GraphicsStudio/Animation/ScrollingBackground"
{

    Properties 
    {      
        _MainTex ("Main Tex", 2D) = "white" {}
        _DetailTex("2nd Layer(RGB)",2D) = "White"{}
        _ScrollX("BaseLayerScrollSpeed",Float) = 1.0
        _Scroll2X("2ndLayerScrollSpeed",Float) = 1.0
        _Multiplier("Layer Multiplier",Float) = 1
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
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

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _DetailTex;
            float4 _DetailTex_ST;
            float _ScrollX;
            float _Scroll2X;
            float _Multiplier;

            struct a2v 
            {    
                float4 vertex : POSITION;    
                float4 texcoord : TEXCOORD0;
            };

            struct v2f 
            {    
                float4 pos : SV_POSITION;
                float4 uv : TEXCOORD0;
            };

            v2f vert(a2v v) 
            {   
                v2f o;    
                o.pos = UnityObjectToClipPos(v.vertex);
                //frac 返回分量数值的小数部分
                //计算uv 的水平偏移
                o.uv.xy = TRANSFORM_TEX(v.texcoord,_MainTex) + 
                    frac(float2(_ScrollX,0.0) * _Time.y);
                o.uv.zw = TRANSFORM_TEX(v.texcoord,_DetailTex) + 
                    frac(float2(_Scroll2X,0.0) * _Time.y);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target 
            {  
                fixed4 firstLayer = tex2D(_MainTex,i.uv.xy);
                fixed4 secondLayer = tex2D(_DetailTex,i.uv.zw);
                //前后两张图混合
                fixed4 c = lerp(firstLayer, secondLayer, secondLayer.a);    
                c.rgb *= _Multiplier;
                return c;
            }
            ENDCG
            
        }
    }
    Fallback "Transparent/VertexLit"
}
