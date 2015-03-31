Shader "Nature/Terrain/Standard" {
	Properties {
		// set by terrain engine
		_Control ("Control (RGBA)", 2D) = "red" {}
		_Splat3 ("Layer 3 (A)", 2D) = "white" {}
		_Splat2 ("Layer 2 (B)", 2D) = "white" {}
		_Splat1 ("Layer 1 (G)", 2D) = "white" {}
		_Splat0 ("Layer 0 (R)", 2D) = "white" {}
		_Normal3 ("Normal 3 (A)", 2D) = "bump" {}
		_Normal2 ("Normal 2 (B)", 2D) = "bump" {}
		_Normal1 ("Normal 1 (G)", 2D) = "bump" {}
		_Normal0 ("Normal 0 (R)", 2D) = "bump" {}
		_Height3 ("Height 3 (A)", 2D) = "white" {}
		_Height2 ("Height 2 (B)", 2D) = "white" {}
		_Height1 ("Height 1 (G)", 2D) = "white" {}
		_Height0 ("Height 0 (R)", 2D) = "white" {}

		[Gamma] _Metallic0 ("Metallic 0", Range(0.0, 1.0)) = 0.0
		[Gamma] _Metallic1 ("Metallic 1", Range(0.0, 1.0)) = 0.0
		[Gamma] _Metallic2 ("Metallic 2", Range(0.0, 1.0)) = 0.0
		[Gamma] _Metallic3 ("Metallic 3", Range(0.0, 1.0)) = 0.0
		_Smoothness ("Smoothness", Range(0.0, 1.0)) = 0.0

		_GlobalColorTex ("Global Color", 2D) = "white" {}
		_GlobalNormalTex ("Global Normal", 2D) = "bump" {}

		// used in fallback on old cards & base map
		_MainTex ("BaseMap (RGB)", 2D) = "white" {}
		_Color ("Main Color", Color) = (1,1,1,1)

		_FresnelBias ("Fresnel Bias", Range(-1.0, 1.0)) = 0.0
		_FresnelScale ("Fresnel Scale", Range(0.0, 2.0)) = 1.0
		_FresnelPower ("Fresnel Power", Range(0.01, 16.0)) = 1.0
	}

	SubShader {
		Tags {
			"SplatCount" = "4"
			"Queue" = "Geometry-100"
			"RenderType" = "Opaque"
		}

		CGPROGRAM
		// As we can't blend normals in g-buffer, this shader will not work in standard deferred path.
		// So we use exclude_path:deferred to force it to only use the forward path.
		#pragma surface surf Standard vertex:SplatmapVert finalcolor:myfinal exclude_path:prepass exclude_path:deferred
		#pragma multi_compile_fog
		#pragma target 3.0
		// needs more than 8 texcoords
		#pragma exclude_renderers gles
		#include "UnityPBSLighting.cginc"

		#pragma multi_compile __ _TERRAIN_NORMAL_MAP
		#pragma multi_compile __ _TERRAIN_OVERRIDE_SMOOTHNESS

		#include "../CGIncludes/TerrainSplatmapCommon.cginc"

		#ifdef _TERRAIN_OVERRIDE_SMOOTHNESS
			half _Smoothness;
		#endif

		half _Metallic0;
		half _Metallic1;
		half _Metallic2;
		half _Metallic3;

		void surf (Input IN, inout SurfaceOutputStandard o) {
			half4 splat_control;
			half weight;
			fixed4 mixedDiffuse;
			SplatmapMix(IN, splat_control, weight, mixedDiffuse, o.Normal);
			o.Albedo = mixedDiffuse.rgb;
			o.Alpha = weight;
			#ifdef _TERRAIN_OVERRIDE_SMOOTHNESS
				o.Smoothness = _Smoothness;
			#else
				o.Smoothness = mixedDiffuse.a;
			#endif
			o.Metallic = dot(splat_control, half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3));
		}

		void myfinal(Input IN, SurfaceOutputStandard o, inout fixed4 color)
		{
			SplatmapApplyWeight(color, o.Alpha);
			SplatmapApplyFog(color, IN);
		}

		ENDCG
	}

	Dependency "AddPassShader" = "Hidden/TerrainEngine/Splatmap/Standard-AddPass"
	Dependency "BaseMapShader" = "Hidden/TerrainEngine/Splatmap/Standard-Base"

	Fallback "Nature/Terrain/Diffuse"
}