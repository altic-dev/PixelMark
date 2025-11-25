//
//  CaptureOutput.swift
//  PixelMark
//
//  Created by PixelMark on 11/23/25.
//

import Foundation
import ScreenCaptureKit
import AVFoundation

class CaptureOutput: NSObject, SCStreamOutput {
    let videoInput: AVAssetWriterInput?
    let audioInput: AVAssetWriterInput?
    let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    let assetWriter: AVAssetWriter?
    private var sessionStarted = false
    
    init(videoInput: AVAssetWriterInput?, audioInput: AVAssetWriterInput?, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?, assetWriter: AVAssetWriter?) {
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.pixelBufferAdaptor = pixelBufferAdaptor
        self.assetWriter = assetWriter
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let assetWriter = assetWriter else { return }
        
        if !sessionStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            assetWriter.startSession(atSourceTime: timestamp)
            sessionStarted = true
        }
        
        guard assetWriter.status == .writing else { return }
        
        switch type {
        case .screen:
            // FUTURE: This is where we can intercept frames to extract cursor position if we want to store it separately.
            // Cursor metadata can be retrieved from sampleBuffer attachments if separate cursor is requested, 
            // or we can just track mouse position using NSEvent if not burned in.
            
            guard
                let adaptor = pixelBufferAdaptor,
                adaptor.assetWriterInput.isReadyForMoreMediaData,
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            else { return }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            adaptor.append(pixelBuffer, withPresentationTime: timestamp)
            
        case .audio:
            // FUTURE: If we want separate audio tracks (e.g. system audio vs mic), we could handle multiple audio inputs here.
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(sampleBuffer)
            }
            
        case .microphone:
            // FUTURE: Handle microphone audio separately if configured.
            break
            
        @unknown default:
            break
        }
    }
}
