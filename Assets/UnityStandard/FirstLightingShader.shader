// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "GraphicsStudio/UnityStandard/FirstLightingShader" {

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
			//使用ForwardBase通道。这是当使用前向渲染路径渲染某个物体的时候使用的第一遍渲染。
			//它让我们可以访问场景的主要方向光
			Tags {"LightMode" = "ForwardBase"}
			//Blend [_SrcBlend] [_DstBlend]

			CGPROGRAM
			
			#pragma target 3.0

			#include "UnityCG.cginc"
			#include "UnityStandardBRDF.cginc"
			#include "UnityStandardUtils.cginc"

			#pragma vertex MyVertexProgram
			#pragma fragment MyFragmentProgram

			struct VertexData{
				float4 position : POSITION;
				float3 normal : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct Interpolators{
				float4 position : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : TEXCOORD1;
				float4 worldPos : TEXCOORD2;
			};

			Interpolators MyVertexProgram(VertexData v){
				Interpolators i;
				i.uv = TRANSFORM_TEX(v.uv,_MainTex);
				i.position = UnityObjectToClipPos(v.position);
				i.worldPos = mul(unity_ObjectToWorld, v.position);
				//法线从物体空间转到世界坐标空间
				//i.normal = v.normal;
				//i.normal = mul(unity_ObjectToWorld, float4(v.normal, 0));
				//i.normal = mul((float3x3)unity_ObjectToWorld, v.normal);//只对矩阵的3×3的部分做乘法运算

				//法线现在处于世界坐标空间，但有些进行了缩放。因此，必须在转换后对法线进行归一化。
				//i.normal = normalize(i.normal);

				//当大小不均匀的时候时，应该对法线进行取逆操作。
				//当它们被再次被归一化后，法线将匹配变形的曲面的形状。而这对于均匀尺度来说没有影响。
				//必须对大小进行取逆操作，但旋转应该保持不变
				//对缩放取逆，但同时保持旋转不变
				//Unity还提供一个世界空间到物体空间的变换矩阵。
				//这些矩阵实际上是彼此的逆矩阵。
				//这给出了需要的缩放矩阵的逆矩阵，但也给了我们旋转矩阵和位移矩阵的逆矩阵
				//可以通过转置矩阵来移除那些我们不需要的效果。
				//i.normal = mul(transpose((float3x3)unity_WorldToObject),v.normal);
				//i.normal = normalize(i.normal);
				
				//UnityObjectToWorldNormal 函数
				//  float3 UnityObjectToWorldNormal( in float3 norm ) {
				// 		return normalize(
				// 		unity_WorldToObject[0].xyz * norm.x +
				// 		unity_WorldToObject[1].xyz * norm.y +
				// 		unity_WorldToObject[2].xyz * norm.z
				// );
				i.normal = UnityObjectToWorldNormal(v.normal);
				return i;
			}

			float4 MyFragmentProgram(Interpolators i):SV_TARGET{
				//在顶点程序中产生正确的法线之后，正确的法线值会通过内插值器。
				//在不同单位长度的向量之间进行线性内插不会生成另外一个单位长度的向量。它会比单位长度的向量要小一些。
				//片段着色器中再次对法线进行归一化。
				i.normal = normalize(i.normal);
				
				//return float4(i.normal * 0.5 + 0.5,1);
				//计算表面法线向量和光的入射方向的点积来确定这个兰伯特反射系数
				//return dot(float3(0, 1, 0), i.normal);

				//由于光的入射方向和表面法线之间的角度在这一点上必须大于90°，所以其余弦和点积变为负。
				//return max(0, dot(float3(0, 1, 0), i.normal));
				//return saturate(dot(float3(0, 1, 0), i.normal));

				//UnityStandardBRDF 导入文件定义了方便的DotClamped 函数。这个函数会执行一个点积，并确保点积的结果永远不为负。
				//inline half DotClamped (half3 a, half3 b) {
				// 	#if (SHADER_TARGET < 30 || defined(SHADER_API_PS3))
				// 		return saturate(dot(a, b));
				// 	#else
				// 		return max(0.0h, dot(a, b));
				// 	#endif
				// }
				//return DotClamped(float3(0, 1, 0), i.normal);

				//UnityShaderVariables 里面定义了float4_WorldSpaceLightPos0
				//其中包含了当前光源的位置。或者在定向光的情况下光线来自的方向。
				//在这产生正确的结果之前，我们必须告诉Unity我们要使用哪个光源的数据。 
				//我们可以通过添加一个LightMode 标签到我们的着色器进行这个Pass。
				float3 lightDir = _WorldSpaceLightPos0.xyz;
				//return DotClamped(lightDir, i.normal);

				//每个光源都有自己的颜色，可以通过 fixed L_LightColor0 变量获得光源的颜色
				//光源的颜色是在UnityLightingCommon之中进行定义的。
				float3 lightColor = _LightColor0.rgb;
				//float3 diffuse = lightColor * DotClamped(lightDir, i.normal);

				//使用材质的纹理和色调来定义材质的反射率
				//float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				//float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
				//return float4(diffuse, 1);

				//----镜面反射-----
				//Blinn 反射模型来计算光的反射。
				//通过float3 _WorldSpaceCameraPos来访问摄像机的位置，这在UnityShaderVariables中进行定义。
				float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

				//要知道反射的光在哪里，我们可以使用标准 reflect 函数。要获取入射光线的方向并基于表面法线对它进行反射。所以我们必须对我们的光的入射方向取反。
				//float3 reflectionDir = reflect(-lightDir, i.normal);
				//return float4(reflectionDir * 0.5 + 0.5, 1);

				//使用 clamped 点积来计算出有多少光线会到达我们的眼睛
				//return DotClamped(viewDir, reflectionDir);

				//点积乘以一个更高的指数来缩小高光
				//return pow(	DotClamped(viewDir, reflectionDir),_Smoothness * 100);

				//Blinn-Phong
				//最常用的反射模型是Blinn-Phong。
				//使用的是光的入射方向和视线方向之间的半矢量。
				//法线和半矢量之间的点积可以确定镜面高光的贡献。
				//一个很大的限制是，它可以为从后面照亮的物体产生无效的高光。
				//光滑度值为0.01的情况下，得到的不正确的高光结果。
				//可以通过使用阴影或是通过基于光的入射方向来淡出镜面高光来进行隐藏。
				float3 halfVector = normalize(lightDir + viewDir);
				// return pow(DotClamped(halfVector, i.normal),_Smoothness * 100);

				//float3 halfVector = normalize(lightDir + viewDir);
				// float3 specular = lightColor * pow(
				// 	DotClamped(halfVector, i.normal),_Smoothness * 100);
				//return float4(specular, 1);

				//用颜色属性控制镜面高光反射的颜色和强度。
				// float3 halfVector = normalize(lightDir + viewDir);
				// float3 specular = _SpecularTint.rgb * lightColor * 
				// 	pow(DotClamped(halfVector, i.normal),_Smoothness * 100);
				// return float4(specular, 1);
				
				//漫反射和镜面高光反射是光照拼图的两个部分。
				//return float4(diffuse + specular, 1);

				//能量守恒
				//只是添加漫反射和镜面高光反射的结果在一起的话，得到的反射结果可以比光源的入射光更亮。
				//必须确保材质的漫反射和镜面高光反射部分的总和不超过1
				float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
				// albedo *= 1 - _SpecularTint.rgb;

				//单色的能量守恒。
				//albedo *= 1 - max(_SpecularTint.r, max(_SpecularTint.g, _SpecularTint.b));
				
				//在UnityStandardUtils之中进行定义 EnergyConservationBetweenDiffuseAndSpecular 函数
				//这个函数使用反射率和镜面高光颜色作为输入，并输出调整后的反射率。
				//第三个输出参数，称为“1-反射率”。

				// 镜面高光的工作流：
				// 	可以通过使用强烈的镜面高光色调来创建金属。
				// 	通过使用比较弱的单色镜面高光来创建介电材料。
				// float3 albedo = tex2D(_MainTex, i.uv).rgb * _Tint.rgb;
				// float oneMinusReflectivity;
				// albedo = EnergyConservationBetweenDiffuseAndSpecular(albedo,
				// 	_SpecularTint.rgb,oneMinusReflectivity);


				// 金属的工作流程：
				// 	金属没有反射率，我们可以使用它的基础颜色作为镜面高光色调的颜色数据。
				// 	非金属没有一个彩色的镜面高光，所以我们不需要一个单独的镜面高光色调。
				// float3 specularTint = albedo * _Metallic;
				// float oneMinusReflectivity = 1 - _Metallic;
				// albedo *= oneMinusReflectivity;

				//即使是纯电介质仍然具有一些镜面高光反射。
				//因此，镜面高光反射强度和反射值与金属滑块的值不是完全匹配的。
				//同时这也会受到颜色空间的影响。
				// UnityStandardUtils 有 DiffuseAndSpecularFromMetallic 函数，它为我们处理这个问题。
				float3 specularTint; 
				float oneMinusReflectivity;
				albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, 
					specularTint, oneMinusReflectivity);

				float3 diffuse = albedo * lightColor * DotClamped(lightDir, i.normal);
				//float3 halfVector = normalize(lightDir + viewDir);
				float3 specular = specularTint * lightColor * pow(DotClamped(halfVector, i.normal),
					_Smoothness * 100);
				return float4(diffuse + specular,1);
			}

			ENDCG
		}

	}

	//CustomEditor "CustomLightingShaderGUI"
}