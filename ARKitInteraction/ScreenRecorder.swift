//
//  ARScreenRecorder.swift
//  ARKitInteraction
//
//  Created by Luo,Huanyu on 2017/10/9.
//  Copyright © 2017年 Apple. All rights reserved.
//

import ARKit
import Photos


class ARScreenRecorder {
    
    static let shared = ARScreenRecorder()
    
    var sceneView: SCNView!
    
    private init() {
        setup()
    }
    
    private(set) var isRecording: Bool = false
    
    func render(frame: ARFrame) {
        frameOutputQueue.sync {
            objc_sync_enter(self)
            if self.isRecording  {
                if self.sceneInput.isReadyForMoreMediaData, let pool = self.sceneInputAdaptor.pixelBufferPool {
                    let image = self.renderer.snapshot(atTime: CFTimeInterval(CFTimeInterval(frameCount) / 60),
                                                       with: UIScreen.main.bounds.size,
                                                       antialiasingMode: .multisampling4X)
                    let sceneBuffer = self.pixelBuffer(withSize: UIScreen.main.bounds.size ,fromImage: image, usingBufferPool: pool)
                    self.sceneInputAdaptor.append(sceneBuffer, withPresentationTime: CMTime(value: frameCount, timescale: 60))
                }
                if self.cameraInput.isReadyForMoreMediaData {
                    self.cameraInputAdaptor.append(frame.capturedImage, withPresentationTime: CMTime(value: frameCount, timescale: 60))
                    frameCount += 1
                }
            }
            objc_sync_exit(self)
        }
    }
    
    func pixelBuffer(withSize size: CGSize, fromImage image: UIImage, usingBufferPool pool: CVPixelBufferPool) -> CVPixelBuffer {
        
        var pixelBufferOut: CVPixelBuffer?
        
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOut)
        
        if status != kCVReturnSuccess {
            fatalError("CVPixelBufferPoolCreatePixelBuffer() failed")
        }
        
        let pixelBuffer = pixelBufferOut!
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        let data = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: Int(8),
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )
        
        assert(context != nil, "Could not create context from pixel buffer")
        
        context?.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        context?.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        
        return pixelBuffer
    }
    
    private let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: UIScreen.main.bounds.width,
        kCVPixelBufferHeightKey as String: UIScreen.main.bounds.height
    ]
    
    private var frameCount: CMTimeValue = 0
    private let frameOutputQueue = DispatchQueue(label: "com.arkit.videorecording")
    
    private var assetWriter: AVAssetWriter?
    private var cameraInput: AVAssetWriterInput!
    private var cameraInputAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var sceneInput: AVAssetWriterInput!
    private var sceneInputAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    var renderer: SCNRenderer!


    
    private func createVideoFilePath() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/\(Int(Date().timeIntervalSince1970)).mp4"
    }
    
    func setup() {
        cameraInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: UIScreen.main.bounds.height, AVVideoHeightKey: UIScreen.main.bounds.width])
        cameraInput.transform = .init(rotationAngle: .pi*0.5)
        cameraInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: cameraInput, sourcePixelBufferAttributes: nil)
        
        sceneInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: UIScreen.main.bounds.width, AVVideoHeightKey: UIScreen.main.bounds.height])
        sceneInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: sceneInput, sourcePixelBufferAttributes: attributes)
        
        renderer = SCNRenderer(device: nil, options: nil)
        renderer.autoenablesDefaultLighting = true
    }
    
    private var path: String  {
        return createVideoFilePath()
    }
    
    func startRecording() {
        renderer.scene = self.sceneView.scene
        assetWriter = try? AVAssetWriter(url: URL(fileURLWithPath: path), fileType: .mp4)
        assetWriter?.add(cameraInput)
        assetWriter?.add(sceneInput)
        guard let writer = assetWriter else {
            return
        }
        isRecording = true
        writer.startWriting()
        writer.startSession(atSourceTime: kCMTimeZero)
        print("Start Writing.")
    }
    
    func stopRecording() {
        if isRecording {
            self.isRecording = false
            self.assetWriter?.finishWriting {
                print("Finish Writing.")
                self.saveFileToCameraRoll()
            }
        }
    }
    
    func saveFileToCameraRoll() {
        DispatchQueue.global(qos: .utility).async {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: self.path))
            }) { (done, err) in
                if err != nil {
                    print("Error creating video file in library")
                    print(err.debugDescription)
                } else {
                    print("Done writing asset to the user's photo library")
                }
            }
        }
    }
    
}
