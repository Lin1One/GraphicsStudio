#if !defined(LIGHTING_INCLUDED)
#define LIGHTING_INCLUDED


#pragma target 3.0
#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

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

UnityLight CreateLight (Interpolators i) {
	UnityLight light;
	//light.dir = _WorldSpaceLightPos0.xyz;
	//点光源，计算光的方向

	// Unity根据当前光源和着色器变量的关键字决定使用哪个变量。
	// 当渲染方向光的时候，它使用的是DIRECTIONAl变量。
	// 当渲染点光源的时候，它使用的是POINT变量。
	// 当没有一个合适匹配的时候，它只是从列表中选择第一个着色器变体。
	//#if defined(POINT)
	#if defined(POINT) || defined(SPOT)
		light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
	#else
		light.dir = _WorldSpaceLightPos0.xyz;
	#endif

	//光强衰减
	float3 lightVec = _WorldSpaceLightPos0.xyz - i.worldPos;
	//当距离接近零的时候，衰减因子变为无穷大。
	//float attenuation = 1 / (dot(lightVec, lightVec));
	//float attenuation = 1 / (1 + dot(lightVec, lightVec));
	//float attenuation = 0;

	//可以访问UNITY_LIGHT_ATTENUATION 宏。这个宏插入代码以计算正确的衰减因子。
	// 第一个是包含衰减的变量的名称。我们将使用衰减混合多个光源的效果。
	// 第二个参数与阴影有关。因为我们目前不实现阴影相关的内容，所以将这个值设置为0。 
	// 第三个参数是当前物体表面在世界空间中的位置。
	// 宏定义了当前范围中的变量 attenuation 。所以我们不应该再自己声明它了。

	// #ifdef POINT
	// uniform sampler2D _LightTexture0;
	// uniform unityShadowCoord4x4 unity_WorldToLight;
	// #define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
	// 	unityShadowCoord3 lightCoord = \
	// 		mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
	// 	fixed destName = \
	// 		(tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr). \
	// 		UNITY_ATTEN_CHANNEL * SHADOW_ATTENUATION(input));
	// #endif
	//每个光源类型都有一个。在默认情况下，它是为方向光源准备的版本，根本没有衰减。
	//正确的宏只有在知道我们正在处理点光源的时候才会被定义
	
	UNITY_LIGHT_ATTENUATION(attenuation, 0, i.worldPos);
	light.color = _LightColor0.rgb * attenuation;
	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}


Interpolators MyVertexProgram(VertexData v){
	Interpolators i;
	i.uv = TRANSFORM_TEX(v.uv,_MainTex);
	i.position = UnityObjectToClipPos(v.position);
	i.worldPos = mul(unity_ObjectToWorld, v.position);
	i.normal = UnityObjectToWorldNormal(v.normal);
	return i;
}

float4 MyFragmentProgram(Interpolators i):SV_TARGET{
	i.normal = normalize(i.normal);
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
	float3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
	//float3 specularTint;
	float oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(
		albedo, _Metallic, _SpecularTint.rgb, oneMinusReflectivity);
	//创建光源的代码移动到一个单独的函数里面
	UnityLight light = CreateLight(i);
	// float3 lightDir = _WorldSpaceLightPos0.xyz;
	// float3 lightColor = _LightColor0.rgb;
	// light.color = lightColor;
	// light.dir = lightDir;
	// light.ndotl = DotClamped(i.normal, lightDir);
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;
		
	return UNITY_BRDF_PBS(albedo, _SpecularTint.rgb,
		oneMinusReflectivity,_Smoothness,
		i.normal, viewDir,
		light,indirectLight);
}
#endif
