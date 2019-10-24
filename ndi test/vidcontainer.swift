//
//  vidcontainer.swift
//  ndi test
//
//  Created by kyle wilson on 7/29/19.
//  Copyright © 2019 kyle wilson. All rights reserved.
//

import Cocoa
import ndi
import AVFoundation
import MetalKit

class vidcontainer: NSViewController {
    
    // put video into this view
    @IBOutlet weak var vidView: NSImageView!
    
    //find NDI sources on the network and fill this menu
    @IBOutlet weak var NDIsources: NSPopUpButton!
    
    @IBOutlet weak var statusTextField: NSTextField!
    
    var wrapper = NDIWrapper() // Wrapper
    var mSources = [String]() // NDI Source Array
    var movieMaker : ImagesToVideoUtils?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
    }
    @IBAction func onConnect(_ sender: Any) {
        wrapper.initWrapper() // Initialize the NDI Wrapper
        
        if let sources = wrapper.getNDISources() as? [String] { // get NDI Sources
            mSources = sources
            NDIsources.addItems(withTitles: mSources)
            startCapture(source: sources[0]) // Start the Capturing!!!
        }
    }
    
    @IBAction func Selectedvideoreceiver(_ sender: Any) {
        // when user selects NDI camera source put the video into the vidview
        stopCapture()
        startCapture(source: NDIsources.selectedItem!.title)
    }
    
    var ciImage: CIImage? // CIImage for displaying the current video frame.
    var captureStop = false // Capturing Status
    var recordStop = true // Recording Status
    var width = 0
    var height = 0
    func startCapture(source: String) {
        
        wrapper.startCapture(source) // Start the capture the video from the ndi source.
        captureStop = false // set the capture status
        DispatchQueue.init(label: "Capture-1").async { // Capture Queue
            let pixelBufferAttributes = [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true]
            
            while(!self.captureStop) {
                var pixelBuffer : CVPixelBuffer? = nil
                let outPtr = self.wrapper.getVideoFrame() // get the last video frame
                if outPtr == nil { // not received?
                    continue;
                }
                let width = Int(self.wrapper.width)
                let height = Int(self.wrapper.height)
                let len = width * height  // get width, height from current video frame.
                self.width = width
                self.height = height
                
                
                let bytesPerRow = width * 2
                let ptr = UnsafeBufferPointer(start: outPtr, count: 2 * len)
                _ = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, width, height, kCVPixelFormatType_422YpCbCr8, UnsafeMutableRawPointer(mutating: ptr.baseAddress!), bytesPerRow, nil, nil, pixelBufferAttributes as CFDictionary, &pixelBuffer)
                let image = CIImage.init(cvImageBuffer: pixelBuffer!) // create the ciimage from current video frame buffer.
                self.ciImage = image
                
                if !self.recordStop { // check the recording status.
                    if self.mFirstTime == 0 {
                        self.mFirstTime = self.wrapper.time
                    }
                    self.movieMaker?.record(time: self.wrapper.time - self.mFirstTime, buffer: ptr)
                    DispatchQueue.main.async {
                        self.statusTextField.stringValue = "\(Float(self.wrapper.time - self.mFirstTime) / 10000000)"
                    }
                }
                else {
                    self.mFirstTime = 0
                    ptr.deallocate() // video buffer release!
                }
            }
        }
        DispatchQueue.init(label: "Player-1").async {
            
            let tempContext = CIContext()//(options: nil)
            
            while (!self.captureStop) { //
//                continue;
                if let ciImage = self.ciImage {
                    let cgImg = tempContext.createCGImage(ciImage, from: ciImage.extent)
                    // get cgimage from the ciimage.
                    
                    let image = NSImage(cgImage: cgImg!, size: NSSize(width: ciImage.extent.width, height: ciImage.extent.height))
                    DispatchQueue.main.async {
                        self.vidView.image = image
                        // display the cgimage.
                    }
                    self.ciImage = nil
                }
            }
            
            self.ciImage = nil
            DispatchQueue.main.async {
                self.vidView.image = nil
            }
        }
    
    }
    var mFirstTime: Int64 = 0
    func stopCapture() {
        captureStop = true
        wrapper.stopCapture()
    }
    @IBAction func recordvideo(_ sender: Any) {
        
        /////write code to record video to disk
        
        guard recordStop else {
            return
        }
        
        let settings = ImagesToVideoUtils.videoSettings(codec: AVVideoCodecType.h264.rawValue, width: Int(self.wrapper.width), height: Int(self.wrapper.height))
        // video codec, width, height setting
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let tempPath = paths[0] + "/ex111protvideo.mp4"
        
        movieMaker = ImagesToVideoUtils(videoSettings: settings, filePath: "/Users/lizhongming/Documents/test.mp4")
        
        recordStop = false
    }
    
    
    @IBAction func stoprecording(_ sender: Any) {
    
    /// stop recording video to disk
        if recordStop {
            return
        }
        recordStop = true
        movieMaker?.recordFinish(withCompletion: { url in
            let alert = NSAlert()
            alert.messageText = "Recording finished! \n \(url)"
            alert.runModal()
        })
    }
}
