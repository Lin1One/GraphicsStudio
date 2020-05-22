// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "GraphicsStudio/UnityStandard/MultipleLightsShader" {

	Properties {
		_Color ("_Color", Color) = (1, 1, 1, 1)
		_MainTex ("Albedo", 2D) = "white" {}
		_SpecularTint ("Specular", Color) = (0.5, 0.5, 0.5)
		//金属滑块本身应该位于伽马空间之中。
		//在线性空间中渲染的时候，Unity不会自动对伽马值进行伽马校正。
		//使用Gamma属性告诉Unity它也应该对我们的金属滑块应用伽马校正。
		[Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5

		
	}

	CGINCLUDE

	float4 _Color;
	sampler2D _MainTex;
	float4 _MainTex_ST;
	float _Smoothness;
	float4 _SpecularTint;
	float _Metallic;

	ENDCG

	SubShader {
		Pass {
			Tags {"LightMode" = "ForwardBase"}

			CGPROGRAM
			#pragma target 3.0
			#include "Cginc/LightingCgInc.cginc"
			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram		
			ENDCG
		}

		Pass {
			//使用第二个方向光光源会使动态合批这个优化失效。
			Tags {"LightMode" = "ForwardAdd"}

			//将混合模式设置为One One。这种混合模式被称为添加模式。
			Blend One One
			//写入深度缓冲区两次相同的值是没有必要的
			ZWrite Off
			CGPROGRAM
			#pragma target 3.0
			#include "Cginc/LightingCgInc.cginc"
			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			// 为我们的加法渲染PASS创建两个着色器变体。
			// 一个着色器变体用于方向光源，
			// 一个着色器变体用于点光源。
			//#define POINT	//点光源
			// SPOT 聚光灯
			#pragma multi_compile DIRECTIONAL POINT SPOT
			ENDCG
		}


	}

	//CustomEditor "CustomLightingShaderGUI"
}