//
//  MTKCIImageView.swift
//  ndi test
//
//  Created by LeeJongMin on 2019/8/13.
//  Copyright © 2019 kyle wilson. All rights reserved.
//

import Foundation
import MetalKit
import Metal

class MTKCIImageView: MTKView {
    
    var image: CIImage? {
        didSet {
            self.draw()
        }
    }
    
    var originalImageExtent: CGRect = CGRect.zero {
        didSet {
            
        }
    }
    
    var scale: CGFloat {
        
        return max(self.frame.width / originalImageExtent.width, self.frame.height / originalImageExtent.height)
    }
    
    func update() {
        
        guard let img = image, destRect.size.width <= img.extent.size.width && destRect.size.height <= img.extent.size.height else {
            return
        }
        
        self.draw()
    }
    
    let context: CIContext
    let commandQueue: MTLCommandQueue
    
    convenience init(frame: CGRect) {
        let device = MTLCreateSystemDefaultDevice()
        self.init(frame: frame, device: device)
    }
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        guard let device = device else {
            fatalError("Can't use Metal")
        }
        commandQueue = device.makeCommandQueue(maxCommandBufferCount: 5)!
        context = CIContext(mtlDevice: device, options: [CIContextOption.useSoftwareRenderer:false])
        super.init(frame: frameRect, device: device)
        
        self.framebufferOnly = false
        self.enableSetNeedsDisplay = false
        self.isPaused = true
        self.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
//        JEDump(rect, "Draw Use Metal")
        
        
        guard let image = self.image else {
            return
        }
        
        let dRect = destRect
        
        let drawImage: CIImage
        
        if dRect == image.extent {
            drawImage = image
        } else {
            let scale = max(dRect.height / image.extent.height, dRect.width / image.extent.width)
            drawImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        
        let commandBuffer = commandQueue.makeCommandBufferWithUnretainedReferences()
        guard let texture = self.currentDrawable?.texture else {
            return
        }
        guard let colorSpace = drawImage.colorSpace else { //?? CGColorSpaceCreateDeviceRGB()
            return
        }
        
        context.render(drawImage, to: texture, commandBuffer: commandBuffer, bounds: dRect, colorSpace: colorSpace)
        
        commandBuffer?.present(self.currentDrawable!)
        commandBuffer?.commit()
    }
    
    private var destRect: CGRect {
        
        let scale: CGFloat = 1
        
//        if NSScreen.mainScreen.scale == 3 {
//            // BUG?
//            scale = 2.0 * (2.0 / NSScreen.mainScreen.scale) * 2
//        } else {
//            scale = NSScreen.mainScreen.scale
//        }
        let destRect = self.bounds.applying(CGAffineTransform(scaleX: scale, y: scale))
        
        return destRect
    }
}
