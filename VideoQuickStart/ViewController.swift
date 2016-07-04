//
//  ViewController.swift
//  VideoQuickStart
//
//  Created by Kevin Whinnery on 12/16/15.
//  Copyright © 2015 Twilio. All rights reserved.
//

import MapKit
import UIKit

class ViewController: UIViewController {
    // MARK: View Controller Members
    
    // Configure access token manually for testing, if desired! Create one manually in the console
    // at https://www.twilio.com/user/account/video/dev-tools/testing-tools
    // eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzk1ODU3NjYzYWU0OTY1NjE3M2M5ZmQ4OWMyM2I2MmQ5LTE0Njc2MDA2NjMiLCJpc3MiOiJTSzk1ODU3NjYzYWU0OTY1NjE3M2M5ZmQ4OWMyM2I2MmQ5Iiwic3ViIjoiQUMzYmI0ODQ4YzEwMzFkNTk1NTFhYTYyODU4MDdiNzg4MSIsImV4cCI6MTQ2NzYwNDI2MywiZ3JhbnRzIjp7ImlkZW50aXR5IjoiZXJpayIsInJ0YyI6eyJjb25maWd1cmF0aW9uX3Byb2ZpbGVfc2lkIjoiVlM5NGRkOWQ5Y2EzYjBmNGQzZGNkY2YxZjA0ODZlNDgyNyJ9fX0.1y4sPrBHBWH9ummPO4uw97ULViItwuAAMxR_Qd2ks_k
    
    var accessToken = "Token"
    
    // Configure remote URL to fetch token from
    //"http://junest.xyz/test/token.php"
    var tokenUrl = "http://junest.xyz/test/token.php"
    
    // Video SDK components
    var accessManager: TwilioAccessManager?
    var client: TwilioConversationsClient?
    var localMedia: TWCLocalMedia?
    var camera: TWCCameraCapturer?
    var conversation: TWCConversation?
    var incomingInvite: TWCIncomingInvite?
    var outgoingInvite: TWCOutgoingInvite?
    var remoteVideoTrack: TWCVideoTrack?
    var localVideoTrack: TWCLocalVideoTrack?
    var imagePicker = UIImagePickerController()
    var locationManager:CLLocationManager!
    var currentLocation:CLLocation?
    
    // MARK: UI Element Outlets and handles
    var alertController: UIAlertController?
    @IBOutlet weak var remoteMediaView: UIView!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var localMediaView: UIView!
    @IBOutlet weak var identityLabel: UILabel!
    @IBOutlet weak var hangupButton: UIButton!
    @IBOutlet weak var timerLabel: MZTimerLabel!
    @IBOutlet weak var flipCameraButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        addToWindow()
        // Configure access token either from server or manually
        // If the default wasn't changed, try fetching from server
        locationSetup()
        if self.accessToken == "Token" {
            // If the token wasn't configured manually, try to fetch it from server
            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
            let session = NSURLSession(configuration: config, delegate: nil, delegateQueue: nil)
            let url = NSURL(string: self.tokenUrl)
            timerLabel.hidden = true
            let request  = NSMutableURLRequest(URL: url!)
            request.HTTPMethod = "GET"
            
            // Make HTTP request
            session.dataTaskWithRequest(request, completionHandler: { data, response, error in
                if (data != nil) {
                    // Parse result JSON
                    let json = JSON(data: data!)
                    self.accessToken = json["token"].stringValue
                    // Update UI and client on main thread
                    dispatch_async(dispatch_get_main_queue()) {
                        self.initializeClient()
                    }
                } else {
                    print("Error fetching token :\(error)")
                }
            }).resume()
        } else {
            // If token was manually set, initialize right away
            self.initializeClient()
        }
        
        // Style nav bar elements
        self.navigationController?.navigationBar.barTintColor = UIColor.darkGrayColor()
        self.navigationController?.navigationBar.tintColor = UIColor.whiteColor()
        self.navigationController?.navigationBar.titleTextAttributes =
            [NSForegroundColorAttributeName : UIColor.whiteColor()]
    }
    
    func addToWindow() {
        guard let  window = UIApplication.sharedApplication().keyWindow else { return }
//        window.translatesAutoresizingMaskIntoConstraints = false
        let view = UIButton(frame: CGRectMake(50,50,50,50))
        view.setTitle("AA", forState: UIControlState.Normal)
        view.setTitle("BBBBBB", forState: UIControlState.Highlighted)
        view.addTarget(self, action: #selector(ViewController.inra), forControlEvents: .TouchUpInside)
        view.backgroundColor = UIColor.blueColor()
        window.addSubview(view)
        view.center = (window.center)
    }
    
    func inra()  {
        print("vvvv")
    }
    func locationSetup() {
        locationManager = CLLocationManager()
        if #available(iOS 9.0, *) {
            locationManager.allowsBackgroundLocationUpdates = false
        } else {
            // Fallback on earlier versions
        }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
        print(CLLocationManager.authorizationStatus().rawValue)
    }
    
    // Once access token is set, initialize the Conversations SDK and display the identity of the
    // current user
    func initializeClient() {
        // Set up Twilio Conversations client
        self.accessManager = TwilioAccessManager(token:self.accessToken, delegate:self);
        self.client = TwilioConversationsClient(accessManager: self.accessManager!, delegate: self);
        self.client?.listen()
        let audio = TWCAudioOutput.Speaker
        TwilioConversationsClient.setAudioOutput(audio)
        self.localMedia = TWCLocalMedia(delegate: self)
        self.camera = TWCCameraCapturer(delegate: self, source: .FrontCamera)
        self.startPreview()
        self.identityLabel.text = self.client?.identity
    }
    
    func videoCaptureConstraints () -> TWCVideoConstraints {
        if (Platform.isLowPerformanceDevice) {
            return TWCVideoConstraints(maxSize: TWCVideoConstraintsSize480x360, minSize: TWCVideoConstraintsSize480x360, maxFrameRate: 15, minFrameRate: 15)
        } else {
            return TWCVideoConstraints(maxSize: TWCVideoConstraintsSize1280x960, minSize: TWCVideoConstraintsSize960x540, maxFrameRate: 30, minFrameRate: 0)
        }
    }
    
    func reAddVideoPreviewAfterShooting() {
        startPreview()
        self.remoteVideoTrack?.attach(self.remoteMediaView)
    }
    
    func startPreview() {
        // Setup local media preview
        let localVideoTrack = TWCLocalVideoTrack(capturer: self.camera!, constraints: self.videoCaptureConstraints())
        if((self.camera) != nil && Platform.isSimulator != true) {
            self.localMedia!.addTrack(localVideoTrack)
            self.localVideoTrack = localVideoTrack
            self.camera!.videoTrack?.attach(self.videoView)
            self.camera!.videoTrack?.delegate = self;
            // Start the preview.
            self.camera!.startPreview();
            self.videoView.addSubview((self.camera!.previewView)!)
            self.videoView.reloadInputViews()
            print("xxxx",self.camera?.previewDimensions.height,self.camera?.previewDimensions.width)
            self.camera!.previewView?.frame = self.localMediaView!.bounds
            self.camera!.previewView?.contentMode = .ScaleAspectFit
            self.camera!.previewView?.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        }
    }
    
    // MARK: UI Controls
    @IBAction func flipCameraAction() {
        camera?.flipCamera()
    }
    
    func showAlert() {
        let alert = UIAlertController(title: "Alert", message: "Go to setting to enable location detection", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: { (UIAlertAction) -> Void in
            
        }))
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (UIAlertAction) -> Void in
            let openSettingsUrl = NSURL(string: UIApplicationOpenSettingsURLString)
            UIApplication.sharedApplication().openURL(openSettingsUrl!)
        }))
        self.presentViewController(alert, animated: true, completion: { () -> Void in
            
        })
    }
    
    @IBAction func takePhotoAction() {
//        Remove local
        if let videoTrack = self.localVideoTrack {
            self.localMedia?.removeTrack(videoTrack)
        }
        self.camera?.stopPreview()
        self.camera?.videoTrack?.detach(self.videoView)
        self.camera!.previewView?.removeFromSuperview()
        
        //Remove remote 
        self.remoteVideoTrack?.detach(self.remoteMediaView)
        
        
//        imagePicker.delegate = self
//        imagePicker.allowsEditing = false
//        imagePicker.sourceType = .Camera
//        imagePicker.cameraDevice = .Rear
//        imagePicker.cameraCaptureMode = .Photo
//        imagePicker.showsCameraControls = false
//        self.presentViewController(imagePicker, animated: true) { 
//            self.imagePicker.takePicture()
//        }
//        self.presentViewController(imagePicker, animated: true, completion: nil)
        
        ShotManager.getInstance.delegate = self
        ShotManager.getInstance.shot()
//        let screen = self.camera!.previewView! as UIView
//        UIGraphicsBeginImageContextWithOptions(screen.bounds.size, true, 0.0)
////        screen.drawViewHierarchyInRect(screen.frame, afterScreenUpdates: false)
//        screen.layer.renderInContext(UIGraphicsGetCurrentContext()!)
//        let img:UIImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        reAddVideoPreviewAfterShooting()
        
    }
    
    @IBAction func flashLightHandleAction() {
        let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
        if let device = device where (device.hasTorch) {
            do {
                try device.lockForConfiguration()
                if (device.torchMode == AVCaptureTorchMode.On) {
                    device.torchMode = AVCaptureTorchMode.Off
                } else {
                    try device.setTorchModeOnWithLevel(1.0)
                }
                device.unlockForConfiguration()
            } catch {
                print(error)
            }
        }
    }
    
    @IBAction func invite(sender: AnyObject) {
        self.alertController = UIAlertController(title: "Invite User",
                                                 message: "Enter the identity of the user you'd like to call.",
                                                 preferredStyle: UIAlertControllerStyle.Alert)
        
        self.alertController?.addTextFieldWithConfigurationHandler({ textField in
            textField.placeholder = "SomeIdentity"
        })
        
        let action: UIAlertAction = UIAlertAction(title: "invite",
                                                  style: UIAlertActionStyle.Default) { action in
                                                    let invitee = self.alertController?.textFields!.first?.text!
                                                    self.outgoingInvite = self.client?.inviteToConversation(invitee!, localMedia:self.localMedia!)
                                                    { conversation, err in
                                                        if err == nil {
                                                            conversation!.delegate = self
                                                            self.conversation = conversation
                                                        } else {
                                                            print("error creating conversation")
                                                            print(err)
                                                        }
                                                    }
        }
        
        self.alertController?.addAction(action)
        self.presentViewController(self.alertController!, animated: true, completion: nil)
    }
    
    @IBAction func hangup(sender: AnyObject) {
        print("disconnect")
        self.conversation?.disconnect()
        timerLabel.pause()
        timerLabel.reset()
    }
}

// MARK: TWCLocalMediaDelegate
extension ViewController: TWCLocalMediaDelegate {
    func localMedia(media: TWCLocalMedia, didAddVideoTrack videoTrack: TWCVideoTrack) {
        let videoRender = TWCVideoViewRenderer()
        videoTrack.addRenderer(videoRender)
        print("added media track")
    }
    
    func localMedia(media: TWCLocalMedia, didFailToAddVideoTrack videoTrack: TWCVideoTrack, error: NSError) {
        print(error)
    }
}

// MARK: TWCVideoTrackDelegate
extension ViewController: TWCVideoTrackDelegate {
    func videoTrack(track: TWCVideoTrack, dimensionsDidChange dimensions: CMVideoDimensions) {
        print("video dimensions changed \(dimensions)")
    }
}

// MARK: TwilioAccessManagerDelegate
extension ViewController: TwilioAccessManagerDelegate {
    func accessManagerTokenExpired(accessManager: TwilioAccessManager!) {
        print("access token has expired")
    }
    
    func accessManager(accessManager: TwilioAccessManager!, error: NSError!) {
        print("Access manager error:")
        print(error)
    }
}

// MARK: TwilioConversationsClientDelegate
extension ViewController: TwilioConversationsClientDelegate {
    func conversationsClient(conversationsClient: TwilioConversationsClient,
                             didFailToStartListeningWithError error: NSError) {
        print("failed to start listening:")
        print(error)
    }
    
    // Automatically accept any invitation
    func conversationsClient(conversationsClient: TwilioConversationsClient,
                             didReceiveInvite invite: TWCIncomingInvite) {
        print(invite.from)
        let confirmInviteAlert = UIAlertController(title: "Accept invite", message: "An incoming video call from \(invite.from). Accept ?", preferredStyle: UIAlertControllerStyle.Alert)
        confirmInviteAlert.addAction(UIAlertAction(title: "No", style: UIAlertActionStyle.Default, handler: { (UIAlertAction) in
            invite.reject()
        }))
        confirmInviteAlert.addAction(UIAlertAction(title: "Yes", style: UIAlertActionStyle.Cancel, handler: { (UIAlertAction) in
            invite.acceptWithLocalMedia(self.localMedia!) { conversation, error in
                self.conversation = conversation
                self.conversation!.delegate = self
                
            }
        }))
        
        self.presentViewController(confirmInviteAlert, animated: true, completion: nil)
    }
}

// MARK: TWCConversationDelegate
extension ViewController: TWCConversationDelegate {
    func conversation(conversation: TWCConversation,
                      didConnectParticipant participant: TWCParticipant) {
        self.navigationItem.title = participant.identity
        participant.delegate = self
        timerLabel.hidden = false
        timerLabel.start()
        UIApplication.sharedApplication().idleTimerDisabled = true
        print("aaa",TwilioConversationsClient.audioOutput().rawValue)
        
    }
    
    func conversation(conversation: TWCConversation,
                      didDisconnectParticipant participant: TWCParticipant) {
        self.navigationItem.title = "participant left"
        timerLabel.pause()
        timerLabel.reset()
        UIApplication.sharedApplication().idleTimerDisabled = false
        
    }
    
    func conversationsClientDidStopListeningForInvites(conversationsClient: TwilioConversationsClient, error: NSError?) {
        print("conversationsClientDidStopListeningForInvites")
    }
    
    func conversation(conversation: TWCConversation, didFailToConnectParticipant participant: TWCParticipant, error: NSError) {
        print("didFailToConnectParticipant")
    }
    func conversationEnded(conversation: TWCConversation) {
        self.navigationItem.title = "no call connected"
        //        self.conversation = nil
        // Restart the preview.
        self.localMedia = TWCLocalMedia(delegate: self)
        self.camera = TWCCameraCapturer(delegate: self, source: .FrontCamera)
        self.startPreview()
    }
}

// MARK: TWCParticipantDelegate
extension ViewController: TWCParticipantDelegate {
    func participant(participant: TWCParticipant, addedVideoTrack videoTrack: TWCVideoTrack) {
        let videoRender = TWCVideoViewRenderer()
        videoRender.renderFrame(TWCI420Frame())
        videoTrack.attach(self.remoteMediaView)
        self.remoteVideoTrack = videoTrack
        print("addedVideoTrack")
        
    }
    
    func participant(participant: TWCParticipant, addedAudioTrack audioTrack: TWCAudioTrack) {
        print("addedAudioTrack")
    }
    
    func participant(participant: TWCParticipant, removedVideoTrack videoTrack: TWCVideoTrack) {
        videoTrack.detach(self.remoteMediaView)
        print("removedVideoTrack")
    }
    
    func conversationsClientDidStartListeningForInvites(conversationsClient: TwilioConversationsClient) {
        print(conversationsClient.identity)
    }
    
}

//MARK: UIImagePickerDelegate
extension ViewController:UIImagePickerControllerDelegate,UINavigationControllerDelegate {
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            print("picked")
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
        UIImageWriteToSavedPhotosAlbum(pickedImage, nil, nil, nil)
            }
        }
        dispatch_async(dispatch_get_main_queue()) { 
            self.dismissViewControllerAnimated(true, completion: nil)
            self.reAddVideoPreviewAfterShooting()
        }
        
    }
    
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        print("chose")
        self.localMediaView.layoutSubviews()
        dismissViewControllerAnimated(true, completion: nil)
        reAddVideoPreviewAfterShooting()
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        dismissViewControllerAnimated(true, completion: nil)
        reAddVideoPreviewAfterShooting()
    }
}

extension ViewController:TWCCameraCapturerDelegate {
    
}

extension ViewController:CLLocationManagerDelegate {
    func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        switch status {
        case .NotDetermined:
            manager.requestWhenInUseAuthorization()
            break
        case .AuthorizedWhenInUse:
            manager.startUpdatingLocation()
            break
        case .AuthorizedAlways:
            manager.startUpdatingLocation()
            break
        case .Restricted:
            showAlert()
            break
        case .Denied:
            showAlert()
            break
        }
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }
    
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        print(error)
    }
}

extension Double {
        /// Rounds the double to decimal places value
        func roundToPlaces(places:Int) -> Double {
            let divisor = pow(10.0, Double(places))
            return round(self * divisor) / divisor
        }
}

extension ViewController:SecretShotDelegate {
    func didCaptureImage(image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        reAddVideoPreviewAfterShooting()
    }
    
    func didCaptureImageWithData(imageData: NSData) {
        
    }
}


