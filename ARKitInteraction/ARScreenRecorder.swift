//
//  ARScreenRecorder.swift
//  ARKitInteraction
//
//  Created by Luo,Huanyu on 2017/10/9.
//  Copyright © 2017年 Apple. All rights reserved.
//

import ARKit
import Photos

fileprivate let VideoSize = UIScreen.main.bounds.size

final class ARScreenRecorder {
    
    static let shared = ARScreenRecorder()
    
    private init() {
        setup()
    }
    
    private(set) var isRecording: Bool = false
    
    func render(frame: ARFrame) {
        renderQueue.sync {
            objc_sync_enter(self)
            if isRecording  {
                var hasFrame = false
                
                if sceneInput.isReadyForMoreMediaData, let pool = sceneInputAdaptor.pixelBufferPool {
                    let image = self.renderer.snapshot(atTime: CFTimeInterval(CFTimeInterval(frameCount) / 60),
                                                       with: VideoSize,
                                                       antialiasingMode: .none)
                    let sceneBuffer = pixelBuffer(withSize: VideoSize ,fromImage: image, usingBufferPool: pool)
                    sceneInputAdaptor.append(sceneBuffer, withPresentationTime: CMTime(value: frameCount, timescale: 60))
                    hasFrame = true
                }
                
                if cameraInput.isReadyForMoreMediaData {
                    cameraInputAdaptor.append(frame.capturedImage, withPresentationTime: CMTime(value: frameCount, timescale: 60))
                    hasFrame = true
                }
                
                if hasFrame {
                    frameCount += 1
                }
            }
            objc_sync_exit(self)
        }
    }
    
    private var frameCount: CMTimeValue = 0
    private let renderQueue = DispatchQueue(label: "com.arkit.videorecording")
    
    private var assetWriter: AVAssetWriter?
    private var cameraInput: AVAssetWriterInput!
    private var cameraInputAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    private var sceneInput: AVAssetWriterInput!
    private var sceneInputAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    
    private let renderer: SCNRenderer = SCNRenderer(device: nil, options: nil)
    private var sceneView: SCNView!

    private func createVideoFilePath() -> String {
        return NSTemporaryDirectory() + "/\(Int(Date().timeIntervalSince1970)).mp4"
//        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first! + "/\(Int(Date().timeIntervalSince1970)).mp4"
    }
    
    private let attributes: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: VideoSize.width,
        kCVPixelBufferHeightKey as String: VideoSize.height
    ]

    private func setup() {
        cameraInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: VideoSize.height, AVVideoHeightKey: VideoSize.width])
        cameraInput.transform = .init(rotationAngle: .pi*0.5)
        cameraInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: cameraInput, sourcePixelBufferAttributes: attributes)
        
        sceneInput = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: VideoSize.width, AVVideoHeightKey: VideoSize.height])
        sceneInputAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: sceneInput, sourcePixelBufferAttributes: attributes)
        
        renderer.autoenablesDefaultLighting = true
    }
    
    private var path: String!
    
    func startRecording(with sceneView: SCNView) {
        frameCount = 0
        path = createVideoFilePath()
        self.sceneView = sceneView
        renderer.scene = sceneView.scene
        assetWriter = try? AVAssetWriter(url: URL(fileURLWithPath: path), fileType: .m4v)
        assetWriter?.add(sceneInput)
        assetWriter?.add(cameraInput)
        guard let writer = assetWriter else {
            return
        }
        isRecording = true
        writer.startWriting()
        writer.startSession(atSourceTime: kCMTimeZero)
        print("Start Writing.")
    }
    
    func stopRecording(_ completion: ((Bool) -> Void)? = nil) {
        if isRecording {
            isRecording = false
            assetWriter?.finishWriting {
                print("Finish Writing.")
                self.saveFileToCameraRoll(completion)
            }
        }
    }
    
    private func saveFileToCameraRoll(_ completion: ((Bool) -> Void)? = nil) {
        DispatchQueue.global(qos: .utility).async {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: self.path))
            }) { (done, err) in
                completion?(err == nil)
                if err != nil {
                    print("Error creating video file in library")
                    print(err.debugDescription)
                } else {
                    print("Done writing asset to the user's photo library")
                }
            }
        }
    }
    
    
    private func pixelBuffer(withSize size: CGSize, fromImage image: UIImage, usingBufferPool pool: CVPixelBufferPool) -> CVPixelBuffer {
        
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
            bitsPerComponent: 8,
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
    
}
