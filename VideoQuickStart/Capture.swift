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
        } else if activeCamera.isFocusModeSupported(.AutoFocus) {
            activeCamera.focusMode = .AutoFocus
        } else if activeCamera.isFocusModeSupported(.Locked){
            activeCamera.focusMode = .Locked
        }
        if activeCamera.isExposureModeSupported(.ContinuousAutoExposure) {
            activeCamera.exposureMode = .ContinuousAutoExposure
        } else if activeCamera.isExposureModeSupported(.AutoExpose) {
            activeCamera.exposureMode = .AutoExpose
        } else if activeCamera.isExposureModeSupported(.Locked) {
            activeCamera.exposureMode = .Locked
        }
        if activeCamera.isWhiteBalanceModeSupported(.ContinuousAutoWhiteBalance) {
            activeCamera.whiteBalanceMode = .ContinuousAutoWhiteBalance
        } else if activeCamera.isWhiteBalanceModeSupported(.AutoWhiteBalance) {
            activeCamera.whiteBalanceMode = .AutoWhiteBalance
        } else if activeCamera.isWhiteBalanceModeSupported(.Locked){
            activeCamera.whiteBalanceMode = .Locked
        }
        
//        activeCamera.setExposureTargetBias(2, completionHandler: <#T##((CMTime) -> Void)!##((CMTime) -> Void)!##(CMTime) -> Void#>)
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
        while input.device.adjustingWhiteBalance || input.device.adjustingExposure || input.device.adjustingFocus {
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) { () -> Void in
            if connection.active {
                self.output.captureStillImageAsynchronouslyFromConnection(connection) { (sampleBuffer, error) in
                    guard sampleBuffer != nil && error == nil else { return}
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sampleBuffer)
                    guard let img = UIImage(data: imageData) else { return }
                    self.session.stopRunning()
                    self.delegate?.didCaptureImage(img)
                }
        }
        }
    }
}
