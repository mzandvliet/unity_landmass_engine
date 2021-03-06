﻿Shader "Custom/Terrain/TerrainTile" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_HeightTex ("Height Map", 2D) = "white" {}
		_NormalTex ("Normal Map", 2D) = "bump" {}
	}

	SubShader {
		Tags { "RenderType"="Opaque" }

		Pass {
			Tags { "LightMode"="ForwardBase" }

			CGPROGRAM

			#pragma target 3.0
			#pragma fragmentoption ARB_precision_hint_fastest

			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase

			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "LogDepth.cginc"

			sampler2D _MainTex;
			sampler2D _HeightTex;
			sampler2D _NormalTex;
			float _Scale;
			float _HeightScale;
			float2 _LerpRanges;
			float4 _LightColor0;

			struct v2f {
				float4 pos : POSITION;
				float3 lightDir : TEXCOORD0;
				float2 uv : TEXCOORD1;
				float3 normal : TEXCOORD2;
				float3 viewDir : TEXCOORD3;
				float flogz : TEXCOORD4;
				LIGHTING_COORDS(5, 6)
			};

			inline float invLerp(float start, float end, float val) {
				return saturate((val - start) / (end - start));
			}

			/*
			 * Get a bilinearly interpolated sample from a texture (used in vert shader texture fetch, which doesn't support filtering)
			 *
			 * Could optimize by sampling from pre-calculated texture specificalliy for filtering step (http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter18.html)
			 * or by evaluating procedural height function after morphing vertex
			 */
			float4 tex2Dlod_bilinear(sampler2D tex, float4 uv) {
				const float g_resolution = 16.0;
				const float g_resolutionInv = 1/16.0;

				float2 pixelFrac = frac(uv.xy * g_resolution);

				float4 baseUV = uv - float4(pixelFrac * g_resolutionInv,0,0);
				float4 heightBL = tex2Dlod(tex, baseUV);
				float4 heightBR = tex2Dlod(tex, baseUV + float4(g_resolutionInv,0,0,0));
				float4 heightTL = tex2Dlod(tex, baseUV + float4(0,g_resolutionInv,0,0));
				float4 heightTR = tex2Dlod(tex, baseUV + float4(g_resolutionInv,g_resolutionInv,0,0));

				float4 tA = lerp(heightBL, heightBR, pixelFrac.x);
				float4 tB = lerp(heightTL, heightTR, pixelFrac.x);

				return lerp(tA, tB, pixelFrac.y);
			}

			float UnpackHeight(float4 c) {
				return (c.r * 256 + c.g) / 257.0;
			}

			float3 UnpackHeightNormal(float4 c) {
				return (c.xyz * 2.0) - float3(1,1,1);
			}

			// Todo: right now this is in unit quad space, so gridpos == vertex. Simplify.
			float2 morphVertex(float2 gridPos, float2 vertex, float lerp) {
				const float g_resolution = 16.0; // Todo: supply from script

				float2 fracPart = frac(gridPos.xy * g_resolution * 0.5) * 2; // Create sawtooth pattern that peaks every other vertex
				return vertex - (fracPart  / g_resolution * lerp);
			}

			v2f vert (appdata_base v) {
				v2f o;

				/* shift odd-numbered vertices to even numbered vertices based on distance to camera */

				float height = UnpackHeight(tex2Dlod_bilinear(_HeightTex, float4(v.vertex.x, v.vertex.z, 0, 0)));

				float4 wsVertex = mul(_Object2World, v.vertex); // world space vert for distance
				wsVertex.y = height * _HeightScale;

				// Construct morph parameter based on distance to camera
				float distance = length(wsVertex.xyz - _WorldSpaceCameraPos);
				float morph = invLerp(_LerpRanges.x, _LerpRanges.y, distance);

				// Morph in local unit space
				float2 morphedVertex = morphVertex(float2(v.vertex.x, v.vertex.z), float2(v.vertex.x, v.vertex.z), morph);
				wsVertex.x = morphedVertex.x;
				wsVertex.z = morphedVertex.y;

				// Make splat texture tile
				o.uv = morphedVertex * _Scale / 16.0; // Todo: set resolution and uv-scale from script


				wsVertex = mul(_Object2World, wsVertex); // Morphed vertex to world space

				// Sample height using morphed local unit space
				height = UnpackHeight(tex2Dlod_bilinear(_HeightTex, float4(morphedVertex.x, morphedVertex.y, 0, 0)));
				wsVertex.y = height * _HeightScale;

				// To clip space
				o.pos = mul(UNITY_MATRIX_VP, wsVertex);
				// Transform logarithmically
				//o.flogz = TransformVertexLog(o.pos);

				o.lightDir = normalize(ObjSpaceLightDir(v.vertex));

				float4 normal = tex2Dlod_bilinear(_NormalTex, float4(morphedVertex,0,0));
				o.normal = UnpackHeightNormal(normal);

				TRANSFER_VERTEX_TO_FRAGMENT(o);

				return o;
			}

			half4 frag(v2f i) : COLOR { //out float depth:DEPTH
				// Transform logarithmically
				//depth = GetFragmentDepthLog(i.flogz);

				float3 L = normalize(i.lightDir);
				float3 N = normalize(i.normal);

				float attenuation = LIGHT_ATTENUATION(i) * 2;
				float4 ambient = UNITY_LIGHTMODEL_AMBIENT * 2;

				float NDotL = saturate(dot(N, L));
				float4 diffuseTerm = NDotL * _LightColor0 * attenuation;

				float4 diffuse = tex2D(_MainTex, i.uv);
				float4 finalColor = (ambient + diffuseTerm) * diffuse;

			//	return tex2D(_HeightTex, i.uv);
				//return half4(N, 1.0);
				return finalColor;
			}

			ENDCG
		}
	}
	FallBack "Diffuse"
}
