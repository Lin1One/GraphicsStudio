// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "GraphicsStudio/LightModel/PhysicallyBasedLighting" {
    Properties {
        _Color ("漫反射颜色", Color) = (1,1,1,1)             //主颜色
        _MainTex ("反射率", 2D) = "white" {}                //反射率贴图
        _SpecularColor ("镜面反射颜色", Color) = (1,1,1,1)   //高光颜色
        _SpecularPower("镜面反射系数", Range(0,1)) = 1    //高光系数
        _SpecularRange("镜面反射范围（光泽度）", Range(1,40)) = 0   //高光范围
        _Glossiness("光滑度",Range(0,1)) = 1            //光滑度（粗糙度 = 1-(_Glossiness * _Glossiness);）
        _Metallic("金属度",Range(0,1)) = 0            //金属度
        _Anisotropic("各向异性强度", Range(-20,1)) = 0       //各向异性强度
        _Ior("Ior 折射因子", Range(1,4)) = 1.5                       //折射因子，用于描述光穿过一个表面的速度，使用于 SchlickIOR 近似 fresnel 函数
        _UnityLightingContribution("Unity 间接光系数", Range(0,1)) = 1 //Unity 间接光系数

        [Space]
        [Label]s("--------------------调试工具--------------------",float) = 1
        [Space]
        [KeywordEnum(BlinnPhong,Phong,Beckmann,Gaussian,GGX,TrowbridgeReitz,TrowbridgeReitzAnisotropic, Ward)] 
        _NormalDistModel("法线分布函数;", Float) = 0
        [KeywordEnum(AshikhminShirley,AshikhminPremoze,Duer,Neumann,Kelemen,ModifiedKelemen,Cook,Ward,Kurt)]
        _GeoShadowModel("几何阴影函数;", Float) = 0
        [KeywordEnum(None,Walter,Beckman,GGX,Schlick,SchlickBeckman,SchlickGGX, Implicit)]
        _SmithGeoShadowModel("Smith 几何阴影函数(该项为 None，则使用前一选项的函数);", Float) = 0
        [KeywordEnum(Schlick,SchlickIOR, SphericalGaussian)]
        _FresnelModel("菲涅尔函数;", Float) = 0

        [Toggle] _ENABLE_NDF ("仅显示 D ", Float) = 0
        [Toggle] _ENABLE_G ("仅显示 G", Float) = 0
        [Toggle] _ENABLE_F ("仅显示 F", Float) = 0
        [Toggle] _ENABLE_D ("仅显示 Diffuse", Float) = 0
    }

SubShader {
        Tags {
            "RenderType"="Opaque" "Queue"="Geometry"
        }

        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardBase"
            }

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #define UNITY_PASS_FORWARDBASE
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "Lighting.cginc"
            #pragma multi_compile_fwdbase_fullshadows
            #pragma multi_compile _NORMALDISTMODEL_BLINNPHONG _NORMALDISTMODEL_PHONG _NORMALDISTMODEL_BECKMANN _NORMALDISTMODEL_GAUSSIAN _NORMALDISTMODEL_GGX _NORMALDISTMODEL_TROWBRIDGEREITZ _NORMALDISTMODEL_TROWBRIDGEREITZANISOTROPIC _NORMALDISTMODEL_WARD
            #pragma multi_compile _GEOSHADOWMODEL_ASHIKHMINSHIRLEY _GEOSHADOWMODEL_ASHIKHMINPREMOZE _GEOSHADOWMODEL_DUER_GEOSHADOWMODEL_NEUMANN _GEOSHADOWMODEL_KELEMAN _GEOSHADOWMODEL_MODIFIEDKELEMEN _GEOSHADOWMODEL_COOK _GEOSHADOWMODEL_WARD _GEOSHADOWMODEL_KURT
            #pragma multi_compile _SMITHGEOSHADOWMODEL_NONE _SMITHGEOSHADOWMODEL_WALTER _SMITHGEOSHADOWMODEL_BECKMAN _SMITHGEOSHADOWMODEL_GGX _SMITHGEOSHADOWMODEL_SCHLICK _SMITHGEOSHADOWMODEL_SCHLICKBECKMAN _SMITHGEOSHADOWMODEL_SCHLICKGGX _SMITHGEOSHADOWMODEL_IMPLICIT
            #pragma multi_compile _FRESNELMODEL_SCHLICK _FRESNELMODEL_SCHLICKIOR _FRESNELMODEL_SPHERICALGAUSSIAN
            #pragma multi_compile _ENABLE_NDF_OFF _ENABLE_NDF_ON
            #pragma multi_compile _ENABLE_G_OFF _ENABLE_G_ON
            #pragma multi_compile _ENABLE_F_OFF _ENABLE_F_ON
            #pragma multi_compile _ENABLE_D_OFF _ENABLE_D_ON
            #pragma target 3.0

            float4 _Color;              //主颜色
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularRange;
            float _Glossiness;          //光滑度（1- 粗糙度）
            float _Metallic;            //金属度
            float _Anisotropic;
            float _Ior;
            float _NormalDistModel;
            float _GeoShadowModel;
            float _FresnelModel;
            float _UnityLightingContribution;

            struct VertexInput {
                float4 vertex : POSITION;       //模型顶点坐标
                float3 normal : NORMAL;         //模型顶点法线
                float4 tangent : TANGENT;       //模型顶点切线
                float2 texcoord0 : TEXCOORD0;   //UV 坐标
                float2 texcoord1 : TEXCOORD1;   //LightMap UV 坐标
            };

            struct VertexOutput {
                float4 pos : SV_POSITION;       //裁剪空间坐标
                float2 uv0 : TEXCOORD0;         //UV 坐标
                float2 uv1 : TEXCOORD1;         //lightmap uv 坐标

                //below we create our own variables with the texcoord semantic.
                //在寄存器存放自定义的变量
                float3 normalDir : TEXCOORD3;   //法线
                float3 posWorld : TEXCOORD4;    //世界坐标
                float3 tangentDir : TEXCOORD5;  //切线
                float3 bitangentDir : TEXCOORD6;//副切线
                LIGHTING_COORDS(7,8)            //Unity 函数宏，在寄存器保存 unity 光照、shadow 变量
                UNITY_FOG_COORDS(9)             //Unity 函数宏，在寄存器保存 fog 相关变量
            };

            VertexOutput vert (VertexInput v) {
                VertexOutput o = (VertexOutput)0;
                o.uv0 = v.texcoord0;
                o.uv1 = v.texcoord1;
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.tangentDir = normalize( mul( unity_ObjectToWorld, float4( v.tangent.xyz, 0.0 ) ).xyz );
                o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                UNITY_TRANSFER_FOG(o,o.pos);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }

            //取样环境光, 需添加添加 reflection probe 到你的场景中并且进行烘焙。
            //能在片段程序中调用这个函数，然后它使用环境采样数据来近似环境光。
            UnityGI GetUnityGI(float3 lightColor, 
                float3 lightDirection, 
                float3 normalDirection,
                float3 viewDirection, 
                float3 viewReflectDirection, 
                float attenuation, 
                float roughness, 
                float3 worldPos){
                //Unity light Setup ::
                UnityLight light;
                light.color = lightColor;
                light.dir = lightDirection;
                light.ndotl = max(0.0h,dot( normalDirection, lightDirection));

                UnityGIInput d;
                d.light = light;
                d.worldPos = worldPos;
                d.worldViewDir = viewDirection;
                d.atten = attenuation;
                d.ambient = 0.0h;
                d.boxMax[0] = unity_SpecCube0_BoxMax;
                d.boxMin[0] = unity_SpecCube0_BoxMin;
                d.probePosition[0] = unity_SpecCube0_ProbePosition;
                d.probeHDR[0] = unity_SpecCube0_HDR;
                d.boxMax[1] = unity_SpecCube1_BoxMax;
                d.boxMin[1] = unity_SpecCube1_BoxMin;
                d.probePosition[1] = unity_SpecCube1_ProbePosition;
                d.probeHDR[1] = unity_SpecCube1_HDR;
                
                Unity_GlossyEnvironmentData ugls_en_data;
                ugls_en_data.roughness = roughness;
                ugls_en_data.reflUVW = viewReflectDirection;
                UnityGI gi = UnityGlobalIllumination(d, 1.0h, normalDirection, ugls_en_data );
                return gi;
            }

// ---------------------------------- helper functions --------------------------------------------------- //
 
            float MixFunction(float i, float j, float x) {
                return j * x + i * (1.0 - x);
            }
            float2 MixFunction(float2 i, float2 j, float x){
                return j * x + i * (1.0h - x);
            }
            float3 MixFunction(float3 i, float3 j, float x){
                return j * x + i * (1.0h - x);
            }
            float MixFunction(float4 i, float4 j, float x){
                return j * x + i * (1.0h - x);
            }
            float sqr(float x){
                return x*x;
            }

// ---------------------------------- NDF 法线分布函数（微表面分布函数）------------------------------------- //
 
            // Blinn-Phong NDF
            // Blin 近似算出了Phong高光，并将其作为 Phong 高光模型的优化版。
            // Blin 通过半角向量与法向量点乘显然比计算光的反射方向要快。
            // 这个算法算出来的结果要比Phong更加柔和。
            float BlinnPhongNormalDistribution(float NdotH, float specularpower, float speculargloss){
                float Distribution = pow(NdotH,speculargloss) * specularpower;
                Distribution *= (2 + specularpower) / (2*3.1415926535);
                return Distribution;
            }

            // Phong NDF
            // 产生比Blin近似出更好的效果
            float PhongNormalDistribution(float RdotV, float specularpower, float speculargloss){
                float Distribution = pow(RdotV,speculargloss) * specularpower;
                Distribution *= (2+specularpower) / (2*3.1415926535);
                return Distribution;
            }

            // Beckman NDF
            // roughness ：粗糙度
            // NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            // 粗糙度和法线与半角向量的点乘共同对物体表面的法线分布进行近似。
            // 在 Beckman 光照模型处理物体表面的时候需要注意一点:Beckman光照模型随着光滑度的变化在慢慢变化，直到一个高光点聚拢在了一个确定的点上。
            // 当表面的光滑度 1 - roughness 增加的时候反射高光聚拢在了一起，
            // 产生了非常不错的从粗糙到光滑的艺术效果。
            // 这种表现效果在早期的粗糙材质中非常受欢迎，对于塑料中光滑度的渲染也非常不错。
            float BeckmannNormalDistribution(float roughness, float NdotH)
            {
                float roughnessSqr = roughness*roughness;
                float NdotHSqr = NdotH*NdotH;
                return max(0.000001,(1.0 / (3.1415926535*roughnessSqr*NdotHSqr*NdotHSqr))* exp((NdotHSqr-1)/(roughnessSqr*NdotHSqr)));
            }

            // Gaussian NDF
            // roughness ：粗糙度 (1- (_Glossiness * _Glossiness))^2
            // NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            // 依赖于粗糙度以及表面法线与半角向量的点乘
            float GaussianNormalDistribution(float roughness, float NdotH)
            {
                float roughnessSqr = roughness*roughness;
                float thetaH = acos(NdotH);
                return exp(-thetaH*thetaH/roughnessSqr);
            }

            // GGX NDF
            // roughness ：粗糙度 (1- (_Glossiness * _Glossiness))^2
            // NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            // GGX是最受欢迎的光照模型之一，当前大多数的BRDF函数都依赖于它的实现。
            // GGX是由Bruce Walter和Kenneth Torrance发表出来的。
            // 在[论文](https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.pdf)中的许多算法都是目前大量被使用到的。
            float GGXNormalDistribution(float roughness, float NdotH)
            {
                float roughnessSqr = roughness*roughness;
                float NdotHSqr = NdotH*NdotH;
                float TanNdotHSqr = (1-NdotHSqr)/NdotHSqr;
                return (1.0/3.1415926535) * sqr(roughness/(NdotHSqr * (roughnessSqr + TanNdotHSqr)));
                // float denom = NdotHSqr * (roughnessSqr-1)
            }

            //Trowbridge-Reitz NDF
            //roughness ：粗糙度 (1- (_Glossiness * _Glossiness))^2
            //NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            //与 GGX 主要可见的区别就是物体边缘的高光比GGX产生的锐利边缘要更加柔和。
            float TrowbridgeReitzNormalDistribution(float NdotH, float roughness){
                float roughnessSqr = roughness*roughness;
                float Distribution = NdotH*NdotH * (roughnessSqr-1.0) + 1.0;
                return roughnessSqr / (3.1415926535 * Distribution*Distribution);
            }

            //Trowbridge-Reitz Anisotropic NDF
            //anisotropic 各向异性强度
            //NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            //HdotX ：半角向量点乘切线
            //HdotY ：半角向量点乘次切线
            //各向异性的 NDF 方程产生了各向异性的表面描述。它允许我们做出有各项异性效果的表面。
            //各向异性的材质与各向同性的材质的其中一个区别是: 是否需要使用切线或者副法线来描述表面。
            float TrowbridgeReitzAnisotropicNormalDistribution(float anisotropic, float NdotH, float HdotX, float HdotY){
                float aspect = sqrt(1.0h-anisotropic * 0.9h);
                float X = max(.001, sqr(1.0-_Glossiness)/aspect) * 5;
                float Y = max(.001, sqr(1.0-_Glossiness)*aspect) * 5;
                return 1.0 / (3.1415926535 * X*Y * sqr(sqr(HdotX/X) + sqr(HdotY/Y) + NdotH*NdotH));
            }

            //Ward AnisoTropic NDF
            //anisotropic 各向异性强度
            //NdotL ：法线点乘入射光方向
            //NdotV ：法线点乘相机方向
            //NdotH ：法线点乘半角向量 ( l + v ) / | l + v |
            //HdotX ：半角向量点乘切线
            //HdotY ：半角向量点乘次切线
            //Ward 方式的各向异性BRDF函数产生了与上一个方式不同的效果。
            //其高光变得更加柔和，随着光滑度的降低高光消失得更快了。
            float WardAnisotropicNormalDistribution(float anisotropic, float NdotL, float NdotV, float NdotH, float HdotX, float HdotY){
                float aspect = sqrt(1.0h-anisotropic * 0.9h);
                float X = max(.001, sqr(1.0-_Glossiness)/aspect) * 5;
                float Y = max(.001, sqr(1.0-_Glossiness)*aspect) * 5;
                float exponent = -(sqr(HdotX/X) + sqr(HdotY/Y)) / sqr(NdotH);
                float Distribution = 1.0 / ( 3.14159265 * X * Y * sqrt(NdotL * NdotV));
                Distribution *= exp(exponent);
                return Distribution;
            }

// ---------------------------------- GSF Geometric Shadow Function 几何阴影函数 -------------------------- //

            // Impalicit GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // 经验模型是几何阴影渲染背后的基本逻辑
            // 通过将法线与光线的点乘和视觉方向与法线的点乘相乘，得到了一个比较精确的表面效果
            // 并且这个表面效果能够通过我们视线变换而变换。
            float ImplicitGeometricShadowingFunction (float NdotL, float NdotV){
                float Gs = (NdotL*NdotV);
                return Gs;
            }

            // Ward GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // VdotH : 相机方向点乘半角向量
            // NdotH ：法线点乘半角向量
            // Ward GSF 是加强版的 Implicit GSF。Ward用这种方式来加强法线描述函数。
            // 它非常适合用于突出当视角与平面角度发生改变后各向异性带的表现。
            float WardGeometricShadowingFunction (float NdotL, float NdotV, float VdotH, float NdotH){
                float Gs = pow( NdotL * NdotV, 0.5);
                return (Gs);
            }

            // Ashikhmin-Shirley GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // LdotH : 入射光方向点乘半角向量
            // 设计用于各项异性的 NDF 法线描述方程，Ashikhmin-Shirley GSF提供了一个不错的各项异性表现基础。
            float AshikhminShirleyGeometricShadowingFunction (float NdotL, float NdotV, float LdotH){
                float Gs = NdotL*NdotV/(LdotH*max(NdotL,NdotV));
                return (Gs);
            }

            // Ashikhmin-Premoze GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // 这个阴影模型原本就是设计用于和各项同性的 NDF 进行配合的，
            // 不像 Ashikhmin-Shirley 的方式。Ashikhmin-Shirley 方式是非常subtle的一种GSF。
            float AshikhminPremozeGeometricShadowingFunction (float NdotL, float NdotV){
                float Gs = NdotL*NdotV/(NdotL+NdotV - NdotL*NdotV);
                return (Gs);
            }

            // Duer GSF
            // lightDirection ：入射光方向
            // viewDirection ：相机方向
            // normalDirection ：法线
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // Duer提出了这个GSF函数，解决了Ward GSF 函数中发现的高光反射问题,Ward GSF 在后面也会提到。
            // Duer GSF产生了与 Ashikhmin-Shirley 非常相似的结果
            // 但是它更倾向于用在各向同性的 BRDF 中，或者非常细微的各向异性 BRDF 上。
            float DuerGeometricShadowingFunction (float3 lightDirection,float3 viewDirection, float3 normalDirection,float NdotL, float NdotV){
                float3 LpV = lightDirection + viewDirection;
                float Gs = dot(LpV,LpV) * pow(dot(LpV,normalDirection),-4);
                return (Gs);
            }

            // Neumann GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // Neumann GSF 是另一种针对于各向异性 NDF 的GSF
            // 它产生了更明显的基于视线与光照方向的几何着色。
            float NeumannGeometricShadowingFunction (float NdotL, float NdotV){
                float Gs = (NdotL*NdotV)/max(NdotL, NdotV);
                return (Gs);
            }

            // Kelemen GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // LdotV ：入射光方向点乘相机方向
            // VdotH : 相机方向点乘半角向量
            // Kelemen GSF这种方式较为符合能量守恒。
            // 不像多数前面的模型，集合阴影的比例始终是常数，而是基于视角改变，
            // 这是一个非常近似于Cook-Torrance几何阴影着色方式的函数。
            float KelemenGeometricShadowingFunction (float NdotL, float NdotV, float LdotH, float VdotH){
                // float Gs = (NdotL*NdotV)/ (LdotH * LdotH); //this
                float Gs = (NdotL*NdotV)/(VdotH * VdotH); //or this?
                return (Gs);
            }

            // Modified-Kelemen GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness ：粗糙度
            //这是一个修改版的 Kelemen函数。它通过将原来的做法修改为粗糙度来进行阴影描述。
            float ModifiedKelemenGeometricShadowingFunction (float NdotV, float NdotL, float roughness)
            {
                float c = 0.797884560802865; // c = sqrt(2 / Pi)
                float k = roughness * roughness * c;
                float gH = NdotV * k +(1-k);
                return (gH * gH * NdotL);
            }

            // Cook-Torrance GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // VdotH : 相机方向点乘半角向量
            // NdotH ：法线点乘半角向量
            // Cook-Torrance几何阴影函数是为了解决三种几何衰减的情况而创造出来的。
            // 第一种情况是光在没有被干涉的情况下进行反射
            // 第二种是反射的光在反射完之后被阻挡了
            // 第三种情况是有些光在到达下一个微表面之前被阻挡了。
            // 为了完全算出一下这些情况，使用下面列出的 Cook-Torrance 几何阴影函数来进行计算。
            float CookTorrenceGeometricShadowingFunction (float NdotL, float NdotV, float VdotH, float NdotH){
                float Gs = min(1.0, min(2*NdotH*NdotV / VdotH, 2*NdotH*NdotL / VdotH));
                return (Gs);
            }


            // Kurt GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // VdotH : 相机方向点乘半角向量
            // Kurt GSF是另一种各向异性的GSF，这个模型用于帮助控制基于粗糙度的各向异性表面描述。
            // 这个模型追求能量守恒，特别是切线角部分。
            float KurtGeometricShadowingFunction (float NdotL, float NdotV, float VdotH, float alpha){
                float Gs = (VdotH * pow(NdotL * NdotV, alpha))/ NdotL * NdotV;
                return (Gs);
            }

            // SmithModelsBelow
            // Gs = F(NdotL) * F(NdotV);
            // Smith Based GSF 被认为比其他的GSF更加精确，
            // 因为其基于粗糙度以及NDF这些函数需要处理两块数据以计算完整的GSF结果。

            // Walter et all. GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // 一般情况下GGX的GSF，Walter et all创建了这个函数可以用于任意的微表面分布函数。
            // Walter et al认为“GSF对于BRDF形状的影响非常微小，除了在接近视线切线边缘或者非常粗糙的时候影响则会很大，但是不管怎么样，都需要保证能量守恒。”
            // 在这个思想指导下，他们创建了一个符合这条原则的GSF公式，并且使用粗糙度来调整GSF的强度。
            float WalterEtAlGeometricShadowingFunction (float NdotL, float NdotV, float alpha){
                float alphaSqr = alpha*alpha;
                float NdotLSqr = NdotL*NdotL;
                float NdotVSqr = NdotV*NdotV;
                float SmithL = 2/(1 + sqrt(1 + alphaSqr * (1-NdotLSqr)/(NdotLSqr)));//F(NdotL)
                float SmithV = 2/(1 + sqrt(1 + alphaSqr * (1-NdotVSqr)/(NdotVSqr)));//F(NdotV);
                float Gs = (SmithL * SmithV);
                return Gs;
            }

            // Smith-Beckman GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness 粗糙度
            // 最初是用于和Beckman微表面分布函数进行匹配的，Walter et al提出这也是适用于Phong NDF的GSF。
            float BeckmanGeometricShadowingFunction (float NdotL, float NdotV, float roughness){
                float roughnessSqr = roughness*roughness;
                float NdotLSqr = NdotL*NdotL;
                float NdotVSqr = NdotV*NdotV;
                float calulationL = (NdotL)/(roughnessSqr * sqrt(1- NdotLSqr));
                float calulationV = (NdotV)/(roughnessSqr * sqrt(1- NdotVSqr));
                float SmithL = calulationL < 1.6 ? 
                    (((3.535 * calulationL) + (2.181 * calulationL * calulationL))/(1 + (2.276 * calulationL) + (2.577 * calulationL * calulationL))) : 1.0;
                float SmithV = calulationV < 1.6 ? 
                    (((3.535 * calulationV) + (2.181 * calulationV * calulationV))/(1 + (2.276 * calulationV) + (2.577 * calulationV * calulationV))) : 1.0;
                float Gs = (SmithL * SmithV);
                return Gs;
            }

            // GGX GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness 粗糙度
            // 是对Walter et al模型的重构，是对Ndot/NdotV产生的GSF相乘得到的GSF。
            float GGXGeometricShadowingFunction (float NdotL, float NdotV, float roughness){
                float roughnessSqr = roughness*roughness;
                float NdotLSqr = NdotL*NdotL;
                float NdotVSqr = NdotV*NdotV;
                float SmithL = (2 * NdotL)/ (NdotL + sqrt(roughnessSqr + ( 1-roughnessSqr) * NdotLSqr));
                float SmithV = (2 * NdotV)/ (NdotV + sqrt(roughnessSqr + ( 1-roughnessSqr) * NdotVSqr));
                float Gs = (SmithL * SmithV) ;
                return Gs;
            }

            // Schlick GSF
            // Schlick 已经写了一系列对于 SmithGSF 的近似模型，并且可以使用在其他的 Smith GSF。
            // 最简单的对Smith GSF的近似模型。Gs = F(NdotL) * F(NdotV);
            // Schlick GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness 粗糙度
            float SchlickGeometricShadowingFunction (float NdotL, float NdotV, float roughness)
            {
                float roughnessSqr = roughness*roughness;
                float SmithL = (NdotL)/(NdotL * (1-roughnessSqr) + roughnessSqr);
                float SmithV = (NdotV)/(NdotV * (1-roughnessSqr) + roughnessSqr);
                return (SmithL * SmithV);
            }

            // Schlick-Beckman GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness 粗糙度
            // 这是 Schlick 对Beckman函数的近似。
            // 通过对2/PI的平方根乘以粗糙度，而不是我们直接预计算出来的0.797884..来进行实现的。
            float SchlickBeckmanGeometricShadowingFunction (float NdotL, float NdotV, float roughness){
                float roughnessSqr = roughness*roughness;
                float k = roughnessSqr * 0.797884560802865;
                float SmithL = (NdotL)/ (NdotL * (1- k) + k);
                float SmithV = (NdotV)/ (NdotV * (1- k) + k);
                float Gs = (SmithL * SmithV);
                return Gs;
            }

            // Schlick-GGX GSF
            // NdotL ：法线点乘入射光方向
            // NdotV : 法线点乘相机方向
            // roughness 粗糙度
            // Schlick对于 GGX GSF 的近似实现，通过简单将我们的粗糙度除以2来进行模拟。
            float SchlickGGXGeometricShadowingFunction (float NdotL, float NdotV, float roughness){
                float k = roughness / 2;
                float SmithL = (NdotL)/ (NdotL * (1- k) + k);
                float SmithV = (NdotV)/ (NdotV * (1- k) + k);
                float Gs = (SmithL * SmithV);
                return Gs;
            }

// ---------------------------------- FF 菲涅尔方程 ------------------------------------------------------- //
// 菲涅尔效应是由第一个描述它的法国物理学家Augustin-Jean Fresnel命名的。
// 这个现象表现在视角改变的情况下表面反射强度的改变。反射强度随着视角与表面切角增大而增强。

            //schlick functions
            float SchlickFresnel(float i){
                float x = clamp(1.0-i, 0.0, 1.0);
                float x2 = x*x;
                return x2*x2*x;
            }

            //normal incidence reflection calculation
            float F0 (float NdotL, float NdotV, float LdotH, float roughness){
                // Diffuse fresnel
                float FresnelLight = SchlickFresnel(NdotL);
                float FresnelView = SchlickFresnel(NdotV);
                float FresnelDiffuse90 = 0.5 + 2.0 * LdotH*LdotH * roughness;
                return MixFunction(1, FresnelDiffuse90, FresnelLight) * MixFunction(1, FresnelDiffuse90, FresnelView);
            }

            float3 FresnelLerp (float3 x, float3 y, float d)
            {
                float t = SchlickFresnel(d);
                return lerp (x, y, t);
            }

            // Schlick Fresnel
            // Schilck 的 近似菲涅尔方程。这个菲涅尔效果的近似算式允许我们计算切角的反光。
            float3 SchlickFresnelFunction(float3 SpecularColor,float LdotH){
                return SpecularColor + (1 - SpecularColor)* SchlickFresnel(LdotH);
            }

            // SchlickIOR 近似式
            // ior : 折射因子 （Index of Refraction ,IOR）
            // IOR 是一个标量，用于描述光穿过一个表面的速度。
            float SchlickIORFresnelFunction(float ior,float LdotH){
                float f0 = pow((ior-1,2)/(ior+1),2);
                return f0 + (1 - f0) * SchlickFresnel(LdotH);
            }

            // Spherical-Gaussian Fresnel
            // Spherical-Gaussian 菲涅尔方程产生了与 Schlicks 近似式非常相近的结果。
            // 其中唯一的区别是它的power值是由Spherical Gaussian算式来算出来的。
            float SphericalGaussianFresnelFunction(float LdotH,float SpecularColor)
            {
                float power = ((-5.55473 * LdotH) - 6.98316) * LdotH;
                return SpecularColor + (1 - SpecularColor) * pow(2,power);
            }

// ---------------------------------------- Frag --------------------------------------------------------- //

            float4 frag(VertexOutput i) : COLOR {
                float3 normalDirection = normalize(i.normalDir);        //法线，顶点法线在插值后需重新 normalize
                float3 viewDirection = normalize(_WorldSpaceCameraPos.xyz - i.posWorld.xyz);    //视点方向
                //法线修正
                float shiftAmount = dot(i.normalDir, viewDirection);    //视点方向与顶点法线夹角Cos
                normalDirection = shiftAmount < 0.0f ? normalDirection + viewDirection * (-shiftAmount + 1e-5f) : normalDirection;

                //光照参数
                float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - i.posWorld.xyz,_WorldSpaceLightPos0.w));
                float3 lightReflectDirection = reflect(-lightDirection, normalDirection );
                float3 viewReflectDirection = normalize(reflect( -viewDirection, normalDirection ));
                float NdotL = max(0.0, dot(normalDirection, lightDirection ));      //法线，入射光夹角
                float3 halfDirection = normalize(viewDirection + lightDirection);   //半角量
                float NdotH = max(0.0,dot( normalDirection, halfDirection));
                float NdotV = max(0.0,dot( normalDirection, viewDirection));
                float VdotH = max(0.0,dot( viewDirection, halfDirection));
                float LdotH = max(0.0,dot(lightDirection, halfDirection));
                float LdotV = max(0.0,dot(lightDirection, viewDirection));
                float RdotV = max(0.0, dot( lightReflectDirection, viewDirection ));
                float attenuation = LIGHT_ATTENUATION(i);           //Unity函数宏：计算光照衰减量
                float3 attenColor = attenuation * _LightColor0.rgb;

                //get Unity Scene lighting data
                //场景光照数据
                UnityGI gi = GetUnityGI(
                    _LightColor0.rgb, 
                    lightDirection, 
                    normalDirection, 
                    viewDirection, 
                    viewReflectDirection, 
                    attenuation, 
                    1- _Glossiness, 
                    i.posWorld.xyz);
                float3 indirectDiffuse = gi.indirect.diffuse.rgb ;  //间接光漫反射
                float3 indirectSpecular = gi.indirect.specular.rgb; //间接光镜面发射

                //漫反射计算
                float3 diffuseColor = tex2D(_MainTex, i.uv0).rgb *_Color.rgb * (1.0 - _Metallic);   //漫反射颜色（金属度为1，不发生漫反射）
                float roughness = 1-(_Glossiness * _Glossiness);
                roughness = roughness * roughness;
                float f0 = F0(NdotL, NdotV, LdotH, roughness);      //计算菲涅尔漫反射系数
                diffuseColor *= f0;
                diffuseColor += indirectDiffuse;                    //加上间接光漫反射

                //镜面发射计算
                float3 specColor = lerp(_SpecularColor.rgb, _Color.rgb, _Metallic * 0.5);  //高光反射颜色
                float3 SpecularDistribution = specColor;            //镜面反射法线分布项 D
                float GeometricShadow = 1;                          //几何阴影项 G
                float3 FresnelFunction = specColor;                 //菲涅尔项  F

                //选择法线分布函数 NDF -----------------------------------------------------
                #ifdef _NORMALDISTMODEL_BLINNPHONG
                SpecularDistribution *= BlinnPhongNormalDistribution(NdotH, _Glossiness, max(1,_Glossiness * 40));
                #elif _NORMALDISTMODEL_PHONG
                SpecularDistribution *= PhongNormalDistribution(RdotV, _Glossiness, max(1,_Glossiness * 40));
                #elif _NORMALDISTMODEL_BECKMANN
                SpecularDistribution *= BeckmannNormalDistribution(roughness, NdotH);
                #elif _NORMALDISTMODEL_GAUSSIAN
                SpecularDistribution *= GaussianNormalDistribution(roughness, NdotH);
                #elif _NORMALDISTMODEL_GGX
                SpecularDistribution *= GGXNormalDistribution(roughness, NdotH);
                #elif _NORMALDISTMODEL_TROWBRIDGEREITZ
                SpecularDistribution *= TrowbridgeReitzNormalDistribution(NdotH, roughness);
                #elif _NORMALDISTMODEL_TROWBRIDGEREITZANISOTROPIC
                SpecularDistribution *= TrowbridgeReitzAnisotropicNormalDistribution(_Anisotropic,NdotH, dot(halfDirection, i.tangentDir), dot(halfDirection, i.bitangentDir));
                #elif _NORMALDISTMODEL_WARD
                SpecularDistribution *= WardAnisotropicNormalDistribution(_Anisotropic,NdotL, NdotV, NdotH, dot(halfDirection, i.tangentDir), dot(halfDirection, i.bitangentDir));
                #else
                SpecularDistribution *= GGXNormalDistribution(roughness, NdotH);
                #endif

                //选择几何阴影函数 ----------------------------------------------------------------------------------
                #ifdef _SMITHGEOSHADOWMODEL_NONE
                #ifdef _GEOSHADOWMODEL_ASHIKHMINSHIRLEY
                GeometricShadow *= AshikhminShirleyGeometricShadowingFunction (NdotL, NdotV, LdotH);
                #elif _GEOSHADOWMODEL_ASHIKHMINPREMOZE
                GeometricShadow *= AshikhminPremozeGeometricShadowingFunction (NdotL, NdotV);
                #elif _GEOSHADOWMODEL_DUER
                GeometricShadow *= DuerGeometricShadowingFunction (lightDirection, viewDirection, normalDirection, NdotL, NdotV);
                #elif _GEOSHADOWMODEL_NEUMANN
                GeometricShadow *= NeumannGeometricShadowingFunction (NdotL, NdotV);
                #elif _GEOSHADOWMODEL_KELEMAN
                GeometricShadow *= KelemenGeometricShadowingFunction (NdotL, NdotV, LdotH, VdotH);
                #elif _GEOSHADOWMODEL_MODIFIEDKELEMEN
                GeometricShadow *= ModifiedKelemenGeometricShadowingFunction (NdotV, NdotL, roughness);
                #elif _GEOSHADOWMODEL_COOK
                GeometricShadow *= CookTorrenceGeometricShadowingFunction (NdotL, NdotV, VdotH, NdotH);
                #elif _GEOSHADOWMODEL_WARD
                GeometricShadow *= WardGeometricShadowingFunction (NdotL, NdotV, VdotH, NdotH);
                #elif _GEOSHADOWMODEL_KURT
                GeometricShadow *= KurtGeometricShadowingFunction (NdotL, NdotV, VdotH, roughness);
                #else
                GeometricShadow *= ImplicitGeometricShadowingFunction (NdotL, NdotV);
                #endif

                ////SmithModelsBelow
                ////Gs = F(NdotL) * F(NdotV);
                #elif _SMITHGEOSHADOWMODEL_WALTER
                GeometricShadow *= WalterEtAlGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_BECKMAN
                GeometricShadow *= BeckmanGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_GGX
                GeometricShadow *= GGXGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_SCHLICK
                GeometricShadow *= SchlickGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_SCHLICKBECKMAN
                GeometricShadow *= SchlickBeckmanGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_SCHLICKGGX
                GeometricShadow *= SchlickGGXGeometricShadowingFunction (NdotL, NdotV, roughness);
                #elif _SMITHGEOSHADOWMODEL_IMPLICIT
                GeometricShadow *= ImplicitGeometricShadowingFunction (NdotL, NdotV);
                #else
                GeometricShadow *= ImplicitGeometricShadowingFunction (NdotL, NdotV);
                #endif

                //Fresnel Function-------------------------------------------------------------------------------------------------
                #ifdef _FRESNELMODEL_SCHLICK
                FresnelFunction *= SchlickFresnelFunction(specColor, LdotH);
                #elif _FRESNELMODEL_SCHLICKIOR
                FresnelFunction *= SchlickIORFresnelFunction(_Ior, LdotH);
                #elif _FRESNELMODEL_SPHERICALGAUSSIAN
                FresnelFunction *= SphericalGaussianFresnelFunction(LdotH, specColor);
                #else
                FresnelFunction *= SchlickIORFresnelFunction(_Ior, LdotH);
                #endif

                #ifdef _ENABLE_NDF_ON
                return float4(float3(1,1,1)* SpecularDistribution,1);
                #endif
                #ifdef _ENABLE_G_ON
                return float4(float3(1,1,1) * GeometricShadow,1) ;
                #endif
                #ifdef _ENABLE_F_ON
                return float4(float3(1,1,1)* FresnelFunction,1);
                #endif
                #ifdef _ENABLE_D_ON
                return float4(float3(1,1,1)* diffuseColor,1);
                #endif

                // specularity = (D * G * F) / 
                //    (4 * ( NdotL * NdotV));
                // float3 lightingModel = (diffuseColor + specularity);
                // lightingModel *= NdotL;
                // float4 finalDiffuse = float4(lightingModel * attenColor,1);
                // return finalDiffuse;

                //PBR
                float3 specularity = (SpecularDistribution * FresnelFunction * GeometricShadow) / 
                    (4 * ( NdotL * NdotV));
                float grazingTerm = saturate(roughness + _Metallic);
                float3 unityIndirectSpecularity = indirectSpecular * 
                    FresnelLerp(specColor,grazingTerm,NdotV) * 
                    max(0.15,_Metallic) * 
                    (1-roughness*roughness* roughness);

                float3 lightingModel = ((diffuseColor) + 
                    specularity + 
                    (unityIndirectSpecularity *_UnityLightingContribution));
                lightingModel *= NdotL;
                float4 finalColor = float4(lightingModel * attenColor,1);
                UNITY_APPLY_FOG(i.fogCoord, finalColor);
                return finalColor;
            }
// --------------------------------------------------------------------------------------------------------- //
            ENDCG
        }
    }

    FallBack "Legacy Shaders/Diffuse"
}