//
//  CaptureSessionManager.swift
//  VideoQuickStart
//
//  Created by Erik DANG on 7/1/16.
//  Copyright © 2016 Twilio. All rights reserved.
//

import Foundation


protocol CaptureSessionManagerDelegate {
    func cameraSessionManagerDidCaptureImage(image:UIImage, andData data:NSData)
    func cameraSessionManagerFailedToCaptureImage()
    func cameraSessionManagerDidReportAvailability(deviceAvailability:Bool, forCameraType cameraType:CameraType)
}

class CaptureSessionManager: NSObject {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var captureSession = AVCaptureSession() {
        didSet {
            captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        }
    }
    var stillImageOutput: AVCaptureStillImageOutput?
    var stillImage: UIImage?
    var stillImageData: NSData?
    var activeCamera: AVCaptureDevice?
    var delegate: CaptureSessionManagerDelegate?
    
    func initiateCaptureSessionForCamera(camera:CameraType) {
        for  device in AVCaptureDevice.devices() {
            if device.hasMediaType(AVMediaTypeVideo) {
                switch camera {
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
        var deviceAvailability = true
        var cameraDeviceInput:AVCaptureDeviceInput?
        do {
            cameraDeviceInput = try AVCaptureDeviceInput.init(device: activeCamera)
        } catch {
            print(error)
        }
        if self.captureSession.canAddInput(cameraDeviceInput) {
            self.captureSession.addInput(cameraDeviceInput)
        } else {
            deviceAvailability = false
        }
        
        self.delegate?.cameraSessionManagerDidReportAvailability(deviceAvailability, forCameraType: camera  )
    }
    
    func addVideoPreviewLayer() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
    }
    
    func addStillImageOutput() {
        self.stillImageOutput = AVCaptureStillImageOutput()
        self.stillImageOutput?.highResolutionStillImageOutputEnabled = true
        print(self.stillImageOutput!.availableImageDataCVPixelFormatTypes)
//        let outputSettings = NSDictionary(dictionary: [AVVideoCodecJPEG : AVVideoCodecKey])
        let outputSettings = NSDictionary(object: AVVideoCodecJPEG, forKey: AVVideoCodecKey)
        self.stillImageOutput?.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        self.getOrientationAdaptedCaptureConnection()
        self.captureSession.addOutput(self.stillImageOutput)
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if device.isFocusModeSupported(AVCaptureFocusMode.ContinuousAutoFocus) {
            try! device.lockForConfiguration()
            device.focusMode = .ContinuousAutoFocus
            device.exposureMode = AVCaptureExposureMode.ContinuousAutoExposure
//            device.setExposureTargetBias(12)
//            device.setExposureTargetBias(2, completionHandler:nil)
            device.whiteBalanceMode = AVCaptureWhiteBalanceMode.ContinuousAutoWhiteBalance
            device.unlockForConfiguration()
        }
    }
    
    func captureStillImage() {
        let videoConnection = self.getOrientationAdaptedCaptureConnection()
        if videoConnection != nil {
            self.stillImageOutput?.captureStillImageAsynchronouslyFromConnection(videoConnection, completionHandler: { (imageSampleBuffer, error) in
                if error == nil {
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageSampleBuffer)
                    let image = UIImage(data: imageData)
                    self.stillImage = image
                    self.stillImageData = imageData
                    self.delegate?.cameraSessionManagerDidCaptureImage(image!, andData: imageData)
                } else {
                    print(error)
                }
                
            })
        }
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
    
    func getOrientationAdaptedCaptureConnection() -> AVCaptureConnection? {
        var videoConnection: AVCaptureConnection?
        for connection in self.stillImageOutput?.connections as! [AVCaptureConnection] {
            for port in connection.inputPorts as! [AVCaptureInputPort] {
                if port.mediaType == AVMediaTypeVideo {
                    videoConnection = connection
                    self.assignVideoOrienationForVideoConnection(videoConnection!)
                    break
                }
            }
        }
        return videoConnection
    }
    
    func stop() {
        self.captureSession.stopRunning()
        if self.captureSession.inputs.count > 0 {
            if let input = self.captureSession.inputs[0] as? AVCaptureInput {
                self.captureSession.removeInput(input)
            }
            if self.captureSession.outputs.count > 0 {
                if let output = self.captureSession.outputs[0] as? AVCaptureOutput {
                    self.captureSession.removeOutput(output)
                }
            }
        }
    }
}
