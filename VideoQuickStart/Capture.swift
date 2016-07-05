//
//  Capture.swift
//  VideoQuickStart
//
//  Created by Erik DANG on 7/5/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import UIKit

class Capture: NSObject {
    var session: AVCaptureSession!
    var input: AVCaptureDeviceInput!
    var output: AVCaptureStillImageOutput!
    var delegate:SecretShotDelegate?
    
    convenience init(cameraType:CameraType) {
        self.init()
        setupSession(cameraType)
    }
    
    func startRunning() {
        session.startRunning()
    }
    
    func setupSession(camera:CameraType) {
        session = AVCaptureSession()
        session.sessionPreset = AVCaptureSessionPresetPhoto
        setCameraType(camera)
        setOutputSetting()
        
//        session.startRunning()
    }
    
    func setOutputSetting() {
        output = AVCaptureStillImageOutput()
        output.outputSettings = [ AVVideoCodecKey: AVVideoCodecJPEG ]
        
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
    }
    
    func setCameraType(cameraType:CameraType) {
        var activeCamera = AVCaptureDevice
            .defaultDeviceWithMediaType(AVMediaTypeVideo)
        for  device in AVCaptureDevice.devices() {
            if device.hasMediaType(AVMediaTypeVideo) {
                switch cameraType {
                case .RearFacingCamera:
                    if device.position == AVCaptureDevicePosition.Back {
                        activeCamera = device as? AVCaptureDevice
                        break
                    }
                case .FrontFacingCamera:
                    if device.position == AVCaptureDevicePosition.Front {
                        activeCamera = device as? AVCaptureDevice
                        break
                    }
                }
            }
        }
        //        activeCamera.automaticallyEnablesLowLightBoostWhenAvailable = true
        if input != nil {
            session.removeInput(input)
        }
        
        do { input = try AVCaptureDeviceInput(device: activeCamera) } catch { return }
        do { try activeCamera.lockForConfiguration() } catch { return }
        if activeCamera.isFocusModeSupported(.ContinuousAutoFocus) {
            activeCamera.focusMode = .ContinuousAutoFocus
        }
        if activeCamera.isExposureModeSupported(.ContinuousAutoExposure) {
            activeCamera.exposureMode = .ContinuousAutoExposure
        }
        if activeCamera.isWhiteBalanceModeSupported(.ContinuousAutoWhiteBalance) {
            activeCamera.whiteBalanceMode = .ContinuousAutoWhiteBalance
        }
        activeCamera.unlockForConfiguration()
        guard session.canAddInput(input) else { return }
        session.addInput(input)
    }
    
    func assignVideoOrienationForVideoConnection(videoConnection:AVCaptureConnection) {
        let newOrientation:AVCaptureVideoOrientation?
        switch UIDevice.currentDevice().orientation {
        case .Portrait:
            newOrientation = .Portrait
            break;
        case .PortraitUpsideDown:
            newOrientation = .PortraitUpsideDown;
            break;
        case .LandscapeLeft:
            newOrientation = .LandscapeRight;
            break;
        case .LandscapeRight:
            newOrientation = .LandscapeLeft;
            break;
        default:
            newOrientation = .Portrait;
        }
        videoConnection.videoOrientation = newOrientation!
    }
    
    func capturePhoto(){
        guard let connection = output.connectionWithMediaType(AVMediaTypeVideo) else { return }
        assignVideoOrienationForVideoConnection(connection)
        var a = 1
        while input.device.adjustingWhiteBalance || input.device.adjustingExposure || input.device.adjustingFocus {
            print("\(a++)")
        }
        output.captureStillImageAsynchronouslyFromConnection(connection) { (sampleBuffer, error) in
            guard sampleBuffer != nil && error == nil else { return}
            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
            guard let img = UIImage(data: imageData) else { return }
            self.session.stopRunning()
            self.delegate?.didCaptureImage(img)
            
        }
    }
}
