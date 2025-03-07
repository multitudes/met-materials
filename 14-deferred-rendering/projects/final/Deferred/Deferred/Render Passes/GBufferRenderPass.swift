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

import MetalKit

struct GBufferRenderPass: RenderPass {
  let label = "G-buffer Render Pass"
  var descriptor: MTLRenderPassDescriptor?

  var pipelineState: MTLRenderPipelineState
  let depthStencilState: MTLDepthStencilState?
  weak var shadowTexture: MTLTexture?

  var albedoTexture: MTLTexture?
  var normalTexture: MTLTexture?
  var positionTexture: MTLTexture?
  var depthTexture: MTLTexture?

  init(view: MTKView) {
    pipelineState = PipelineStates.createGBufferPSO(
      colorPixelFormat: view.colorPixelFormat)
    depthStencilState = Self.buildDepthStencilState()
    descriptor = MTLRenderPassDescriptor()
  }

  mutating func resize(view: MTKView, size: CGSize) {
    albedoTexture = Self.makeTexture(
      size: size,
      pixelFormat: .bgra8Unorm,
      label: "Albedo Texture")
    normalTexture = Self.makeTexture(
      size: size,
      pixelFormat: .rgba16Float,
      label: "Normal Texture")
    positionTexture = Self.makeTexture(
      size: size,
      pixelFormat: .rgba16Float,
      label: "Position Texture")
    depthTexture = Self.makeTexture(
      size: size,
      pixelFormat: .depth32Float,
      label: "Depth Texture")
  }

  func draw(
    commandBuffer: MTLCommandBuffer,
    scene: GameScene,
    uniforms: Uniforms,
    params: Params
  ) {
    let textures = [
      albedoTexture,
      normalTexture,
      positionTexture
    ]
    for (index, texture) in textures.enumerated() {
      let attachment =
        descriptor?.colorAttachments[RenderTargetAlbedo.index + index]
      attachment?.texture = texture
      attachment?.loadAction = .clear
      attachment?.storeAction = .store
      attachment?.clearColor =
        MTLClearColor(red: 0.73, green: 0.92, blue: 1, alpha: 1)
    }
    descriptor?.depthAttachment.texture = depthTexture
    descriptor?.depthAttachment.storeAction = .dontCare

    guard let descriptor = descriptor,
    let renderEncoder =
      commandBuffer.makeRenderCommandEncoder(
        descriptor: descriptor) else {
      return
    }
    renderEncoder.label = label
    renderEncoder.setDepthStencilState(depthStencilState)
    renderEncoder.setRenderPipelineState(pipelineState)

    renderEncoder.setFragmentTexture(shadowTexture, index: ShadowTexture.index)

    for model in scene.models {
      renderEncoder.pushDebugGroup(model.name)
      model.render(
        encoder: renderEncoder,
        uniforms: uniforms,
        params: params)
      renderEncoder.popDebugGroup()
    }

    renderEncoder.endEncoding()
  }
}
