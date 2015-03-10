//
//  ViewController.swift
//  Vinito
//
//  Created by Sommer Panage on 3/6/15.
//  Copyright (c) 2015 Sommer Panage. All rights reserved.
//

import UIKit
import AVFoundation
import AVKit

class ViewController: UIViewController, AVCaptureFileOutputRecordingDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var doneButton: UIButton!
    
    private let captureSession = AVCaptureSession()
    private let sessionQueue = dispatch_queue_create("com.codepath.vinito.sessionqueue", nil)
    private let captureQueue = dispatch_queue_create("com.codepath.vinito.capturequeue", nil)
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let captureOutput = AVCaptureMovieFileOutput()
    private var currentAssets = [AVAsset]()

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if captureSession.inputs.count == 0 {
            dispatch_async(sessionQueue, { () -> Void in
                // Setup Input
                let device = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
                let input = AVCaptureDeviceInput.deviceInputWithDevice(device, error: nil) as AVCaptureDeviceInput?
                if (self.captureSession.canAddInput(input)) {
                    self.captureSession.addInput(input)
                } else {
                    println("Failed to add input")
                }
                
                if (self.captureSession.canAddOutput(self.captureOutput)) {
                    self.captureSession.addOutput(self.captureOutput)
                } else {
                    println("Failed to add output")
                }
                self.captureSession.startRunning()

            })
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewLayer.superlayer.bounds
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        doneButton.enabled = false
        
        // Setup Preview
        previewLayer.session = captureSession
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewView.layer.insertSublayer(previewLayer, atIndex: 0)
    }

    @IBAction func onPreviewLongPress(sender: UILongPressGestureRecognizer) {
        if sender.state == .Began {
            self.view.backgroundColor = UIColor.redColor()
            dispatch_async(captureQueue, { () -> Void in
                self.captureOutput.startRecordingToOutputFileURL(ViewController.getTemporaryFileURL(), recordingDelegate: self)
            })
        } else if sender.state == .Ended {
            self.view.backgroundColor = UIColor.whiteColor()
            dispatch_async(captureQueue, { () -> Void in
                self.captureOutput.stopRecording()
            })
        }
    }
    
    private class func getTemporaryFileURL() -> NSURL {
        let guid = NSUUID().UUIDString
        let outputFile = "video_\(guid).mp4"
        let outputDirectory = NSTemporaryDirectory()
        let outputPath = outputDirectory.stringByAppendingPathComponent(outputFile)
        let outputURL = NSURL.fileURLWithPath(outputPath)
        
        assert(!NSFileManager.defaultManager().fileExistsAtPath(outputPath), "Could not setup an output file. File exists.")
        
        return outputURL!
    }
    
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        println("File saved! \(outputFileURL)")
        currentAssets.append(AVAsset.assetWithURL(outputFileURL) as AVAsset)
        doneButton.enabled = true
        
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        super.prepareForSegue(segue, sender: sender)
        let playerVC = segue.destinationViewController as AVPlayerViewController
        doneButton.enabled = false
        
        var counter = currentAssets.count
        for asset in currentAssets {
            asset.loadValuesAsynchronouslyForKeys(["duration"], completionHandler: { () -> Void in
                var error: NSError?
                assert(asset.statusOfValueForKey("duration", error: &error) == .Loaded, "Failed to load clip duration")
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    counter -= 1
                    if (counter == 0) {
                        self.composeVideoForPlayer(playerVC)
                        self.currentAssets.removeAll(keepCapacity: true)
                    }
                })
                
            })
        }
    }
    
    // We should be doing this work in the backgroud most likely, but since it's very simple we're safe on the main queue
    private func composeVideoForPlayer(viewController: AVPlayerViewController) {
        let composition = AVMutableComposition()
        var startTime = kCMTimeZero
        for asset in currentAssets {
            let range = CMTimeRangeMake(kCMTimeZero, asset.duration)
            var error: NSError?
            composition.insertTimeRange(range, ofAsset: asset, atTime: startTime, error: &error)
            startTime = CMTimeAdd(startTime, asset.duration)
            startTime = CMTimeAdd(startTime, CMTimeMake(1, startTime.timescale))
        }
        
        // Rotate to the orientation we recorded in. Note this code doesn't deal with cropping.
        let compositionVideoTrack = composition.tracksWithMediaType(AVMediaTypeVideo).last as AVMutableCompositionTrack
        let assetBasisTrack = currentAssets[0].tracksWithMediaType(AVMediaTypeVideo).last as AVAssetTrack
        compositionVideoTrack.preferredTransform = assetBasisTrack.preferredTransform
        
        viewController.player = AVPlayer(playerItem: AVPlayerItem(asset: composition))
    }

}

