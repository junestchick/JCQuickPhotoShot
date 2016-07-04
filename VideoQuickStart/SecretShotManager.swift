//
//  SecretShotManager.swift
//  VideoQuickStart
//
//  Created by Erik DANG on 7/1/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import Foundation
import ImageIO
import AVFoundation

enum CameraType {
    case FrontFacingCamera
    case RearFacingCamera
}

protocol SecretShotDelegate {
    func didCaptureImage(image:UIImage)
    func didCaptureImageWithData(imageData:NSData)
}

class ShotManager: NSObject {
    static let getInstance = ShotManager(cameraType: CameraType.RearFacingCamera)
    var captureManager:CaptureSessionManager?
    var delegate: SecretShotDelegate?
    
    convenience init(cameraType:CameraType) {
        self.init()
        setupCaptureManager(cameraType)
        self.captureManager?.captureSession.startRunning()
        
    }
    func shot() {
        self.captureManager?.captureStillImage()
    }
    
    private func setupCaptureManager(camera:CameraType) {
        if let currentCameraInput = self.captureManager?.captureSession.inputs[0] as? AVCaptureInput {
            self.captureManager?.captureSession.removeInput(currentCameraInput)
        }
//        self.captureManager = nil
        self.captureManager = CaptureSessionManager()
        self.captureManager?.captureSession.beginConfiguration()
        captureManager?.delegate = self
        captureManager?.initiateCaptureSessionForCamera(camera)
        captureManager?.addStillImageOutput()
        captureManager?.addVideoPreviewLayer()
        captureManager?.captureSession.commitConfiguration()
        
    }
}

extension ShotManager:CaptureSessionManagerDelegate {
    func cameraSessionManagerDidCaptureImage(image: UIImage, andData data: NSData) {
        self.delegate?.didCaptureImage(image)
        self.delegate?.didCaptureImageWithData(data)
    }
    
    func cameraSessionManagerFailedToCaptureImage() {
        
    }
    
    func cameraSessionManagerDidReportAvailability(deviceAvailability:Bool, forCameraType cameraType:CameraType) {
        
    }
}