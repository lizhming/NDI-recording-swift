//
//  ImagesToVideoUtils.swift
//  ndi test
//
//  Created by LeeJongMin on 2019/8/13.
//  Copyright © 2019 kyle wilson. All rights reserved.
//

import Foundation
import AVFoundation
import AppKit

typealias CXEMovieMakerCompletion = (URL) -> Void
typealias CXEMovieMakerUIImageExtractor = (AnyObject) -> NSImage?


public class ImagesToVideoUtils: NSObject {
    
//    static let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
//    static let tempPath = paths[0] + "/exprotvideo.mp4"
//    static let fileURL = URL(fileURLWithPath: tempPath)
    
    var assetWriter:AVAssetWriter!
    var writeInput:AVAssetWriterInput!
    var bufferAdapter:AVAssetWriterInputPixelBufferAdaptor!
    var videoSettings:[String : Any]!
    var frameTime:CMTime!
    
    var completionBlock: CXEMovieMakerCompletion?
    var movieMakerUIImageExtractor:CXEMovieMakerUIImageExtractor?
    static var width = 0, height = 0
    
    public class func videoSettings(codec:String, width:Int, height:Int) -> [String: Any]{
        if(Int(width) % 16 != 0){
            print("warning: video settings width must be divisible by 16")
        }
        
        let videoSettings:[String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height]
        self.width = width
        self.height = height
        
        return videoSettings
    }
    
    public init(videoSettings: [String: Any], filePath: String) {
        super.init()
        
        
        if(FileManager.default.fileExists(atPath: filePath)){
            guard (try? FileManager.default.removeItem(atPath: filePath)) != nil else {
                print("remove path failed")
                return
            }
        }
        
        self.assetWriter = try! AVAssetWriter(url: URL(fileURLWithPath: filePath), fileType: AVFileType.mp4)
        
        self.videoSettings = videoSettings
        self.writeInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        assert(self.assetWriter.canAdd(self.writeInput), "add failed")
        
        self.assetWriter.add(self.writeInput)
        let bufferAttributes:[String: Any] = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_422YpCbCr8)]
        self.bufferAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: self.writeInput, sourcePixelBufferAttributes: bufferAttributes)
        self.frameTime = CMTimeMake(value: 1, timescale: 5)
        
    }
    func buffer(from image: CIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.extent.width), Int(image.extent.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        return pixelBuffer
    }
    func recordStart() {
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    let ciContext = CIContext()
    var isRecording = false
    func record(time: Int64, buffer: UnsafeBufferPointer<UInt8>) {
        if !isRecording {
            self.assetWriter.startWriting()
            self.assetWriter.startSession(atSourceTime: CMTime.zero)
            isRecording = true
        }
        
        DispatchQueue.init(label: "Media-Queue").async {
            if (self.writeInput.isReadyForMoreMediaData){
                var sampleBuffer:CVPixelBuffer?
                
                //                sampleBuffer = self.buffer(from: frame)
//                self.ciContext.render(frame, to: sampleBuffer!)
                let bytesPerRow = ImagesToVideoUtils.width * 2
                
                let pixelBufferAttributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
                _ = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, ImagesToVideoUtils.width, ImagesToVideoUtils.height, kCVPixelFormatType_422YpCbCr8, UnsafeMutableRawPointer(mutating: buffer.baseAddress!), bytesPerRow, nil, nil, pixelBufferAttributes as CFDictionary, &sampleBuffer)
                
                
                if (sampleBuffer != nil){
                    self.bufferAdapter.append(sampleBuffer!, withPresentationTime: CMTime(value: CMTimeValue(time), timescale: 10000000))
//                    print("record - \(CMTimeValue(time) / 10000000)")
                    buffer.deallocate()
                }
            }
        }
    }
    func recordFinish(withCompletion: @escaping CXEMovieMakerCompletion) {
        self.completionBlock = withCompletion
        DispatchQueue.init(label: "Media-Queue").async {
            print("Finished!")
            self.writeInput.markAsFinished()
            self.assetWriter.finishWriting {
                print("saved")
                DispatchQueue.main.sync {
                    //self.completionBlock?(URL(fileURLWithPath: "<#T##String#>"))
                }
                self.isRecording = false
            }
        }
    }
    func record(frames: [CIImage], times: [Int64], buffers: [UnsafeBufferPointer<UInt8>], withCompletion: @escaping CXEMovieMakerCompletion) {
        self.completionBlock = withCompletion
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)
        
        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        
        self.writeInput.requestMediaDataWhenReady(on: mediaInputQueue){
            var i = 0
            let ciContext = CIContext()
            while (i < buffers.count) {
                if (self.writeInput.isReadyForMoreMediaData){
                    var sampleBuffer:CVPixelBuffer?
                    sampleBuffer = self.buffer(from: frames[i])
                    ciContext.render(frames[i], to: sampleBuffer!)
                    let pixelBufferAttributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
                    let bytesPerRow = ImagesToVideoUtils.width * 2
                    
                    if (sampleBuffer != nil){
                        self.bufferAdapter.append(sampleBuffer!, withPresentationTime: CMTime(value: CMTimeValue(times[i] - times[0]), timescale: 10000000))
                        print("\(i) - \(CMTimeValue(times[i] - times[0]) / 10000000)")
                        //buffers[i].deallocate()
                        i = i + 1
                    }
                }
            }
            
            self.writeInput.markAsFinished()
            self.assetWriter.finishWriting {
                DispatchQueue.main.sync {
//                    self.completionBlock?(ImagesToVideoUtils.fileURL)
                }
            }
            
        }
    }
    
    func createMovieFrom(urls: [URL], withCompletion: @escaping CXEMovieMakerCompletion){
        self.createMovieFromSource(images: urls as [AnyObject], extractor:{(inputObject:AnyObject) ->NSImage? in
            return NSImage(data: try! Data(contentsOf: inputObject as! URL))}, withCompletion: withCompletion)
    }
    
    func createMovieFrom(images: [NSImage], withCompletion: @escaping CXEMovieMakerCompletion){
        self.createMovieFromSource(images: images, extractor: {(inputObject:AnyObject) -> NSImage? in
            return inputObject as? NSImage}, withCompletion: withCompletion)
    }
    
    func createMovieFromSource(images: [AnyObject], extractor: @escaping CXEMovieMakerUIImageExtractor, withCompletion: @escaping CXEMovieMakerCompletion){
        self.completionBlock = withCompletion
        
        self.assetWriter.startWriting()
        self.assetWriter.startSession(atSourceTime: CMTime.zero)
        
        let mediaInputQueue = DispatchQueue(label: "mediaInputQueue")
        var i = 0
        let frameNumber = images.count
        
        self.writeInput.requestMediaDataWhenReady(on: mediaInputQueue){
            while(true){
                if(i >= frameNumber){
                    break
                }
                
                if (self.writeInput.isReadyForMoreMediaData){
                    var sampleBuffer:CVPixelBuffer?
                    autoreleasepool{
                        let img = extractor(images[i])
                        if img == nil{
                            i += 1
                            print("Warning: counld not extract one of the frames")
                            //continue
                        }
                        sampleBuffer = self.newPixelBufferFrom(cgImage: img!.cgImage as! CGImage)
                    }
                    if (sampleBuffer != nil){
                        if(i == 0){
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: CMTime.zero)
                        }else{
                            let value = i - 1
                            let lastTime = CMTimeMake(value: Int64(value), timescale: self.frameTime.timescale)
                            let presentTime = CMTimeAdd(lastTime, self.frameTime)
                            self.bufferAdapter.append(sampleBuffer!, withPresentationTime: presentTime)
                        }
                        i = i + 1
                    }
                }
            }
            self.writeInput.markAsFinished()
            self.assetWriter.finishWriting {
                DispatchQueue.main.sync {
//                    self.completionBlock!(ImagesToVideoUtils.fileURL)
                }
            }
        }
    }
    
    func newPixelBufferFrom(cgImage:CGImage) -> CVPixelBuffer?{
        let options:[String: Any] = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        var pxbuffer:CVPixelBuffer?
        let frameWidth = self.videoSettings[AVVideoWidthKey] as! Int
        let frameHeight = self.videoSettings[AVVideoHeightKey] as! Int
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, frameWidth, frameHeight, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxbuffer)
        assert(status == kCVReturnSuccess && pxbuffer != nil, "newPixelBuffer failed")
        
        CVPixelBufferLockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxdata = CVPixelBufferGetBaseAddress(pxbuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pxdata, width: frameWidth, height: frameHeight, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pxbuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        assert(context != nil, "context is nil")
        
        context!.concatenate(CGAffineTransform.identity)
        context!.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        CVPixelBufferUnlockBaseAddress(pxbuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxbuffer
    }
}
