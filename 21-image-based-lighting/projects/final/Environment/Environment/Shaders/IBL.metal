///// Copyright (c) 2023 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#include <metal_stdlib>
using namespace metal;
#import "Lighting.h"
#import "ShaderDefs.h"

float calculateShadow(
  float4 shadowPosition,
  depth2d<float> shadowTexture);

fragment float4 fragment_IBL(
  constant Params &params [[buffer(ParamsBuffer)]],
  VertexOut in [[stage_in]],
  constant Light *lights [[buffer(LightBuffer)]],
  constant Material &_material [[buffer(MaterialBuffer)]],
  texture2d<float> baseColorTexture [[texture(BaseColor)]],
  texture2d<float> normalTexture [[texture(NormalTexture)]],
  texture2d<float> roughnessTexture [[texture(RoughnessTexture)]],
  texture2d<float> metallicTexture [[texture(MetallicTexture)]],
  texture2d<float> aoTexture [[texture(AOTexture)]],
  texture2d<float> opacityTexture [[texture(OpacityTexture)]],
  depth2d<float> shadowTexture [[texture(ShadowTexture)]],
  texturecube<float> skybox [[texture(SkyboxTexture)]],
  texturecube<float> skyboxDiffuse [[texture(SkyboxDiffuseTexture)]],
  texture2d<float> brdfLut [[texture(BRDFLutTexture)]])
{
  // Load the materials from textures
  constexpr sampler textureSampler(
                                   filter::linear,
                                   mip_filter::linear,
                                   address::repeat);
  Material material = _material;
  float2 uv = in.uv * params.tiling;
  if (!is_null_texture(baseColorTexture)) {
    float4 color = baseColorTexture.sample(textureSampler, uv);
    material.baseColor = color.rgb;
  }
  if (params.alphaBlending) {
    if (!is_null_texture(opacityTexture)) {
      material.opacity = opacityTexture.sample(textureSampler, uv).r;
    }
  }
  if (!is_null_texture(roughnessTexture)) {
    material.roughness = roughnessTexture.sample( textureSampler, uv).r;
  }
  if (!is_null_texture(metallicTexture)) {
    material.metallic = metallicTexture.sample(textureSampler, uv).r;
  }
  if (!is_null_texture(aoTexture)) {
    material.ambientOcclusion = aoTexture.sample(textureSampler, uv).r;
  }
  float3 normal;
  if (is_null_texture(normalTexture)) {
    normal = in.worldNormal;
  } else {
    normal = normalTexture.sample(textureSampler, uv).rgb;
    normal = normal * 2 - 1;
    normal = float3x3(
                      in.worldTangent,
                      in.worldBitangent,
                      in.worldNormal) * normal;
  }
  normal = normalize(normal);

  // the final result
  float4 color = float4(material.baseColor, 1);

  float3 viewDirection =
  in.worldPosition.xyz - params.cameraPosition;
  viewDirection = normalize(viewDirection);
  float3 textureCoordinates =
  reflect(viewDirection, normal);

  float4 diffuse = skyboxDiffuse.sample(textureSampler, normal);

  diffuse = mix(pow(diffuse, 0.2), diffuse, material.metallic);
  diffuse *= calculateShadow(in.shadowPosition, shadowTexture);

  color = diffuse * float4(material.baseColor, 1);

  constexpr sampler s(filter::linear, mip_filter::linear);
  float3 prefilteredColor
  = skybox.sample(s,
                  textureCoordinates,
                  level(material.roughness * 10)).rgb;
  float nDotV = saturate(dot(normal, -viewDirection));
  float2 envBRDF
  = brdfLut.sample(s, float2(material.roughness, nDotV)).rg;
  float3 f0 = mix(0.04, material.baseColor.rgb, material.metallic);
  float3 specularIBL = f0 * envBRDF.r + envBRDF.g;

  float3 specular = prefilteredColor * specularIBL;
  color += float4(specular, 1);
  color *= material.ambientOcclusion;
  return color;
}
