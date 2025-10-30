//
//  CameraServiceDelegate.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 26.10.2025.
//

import AVFoundation
import UIKit

protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService,
                       didOutput sampleBuffer: CMSampleBuffer,
                       orientation: CGImagePropertyOrientation)
    func cameraService(_ service: CameraService, didChangeRunning isRunning: Bool)
    func cameraService(_ service: CameraService, didFail error: Error)
}


final class CameraService: NSObject {

    let session = AVCaptureSession()
    weak var delegate: CameraServiceDelegate?

    private var position: AVCaptureDevice.Position = DemoConfig.defaultCameraPosition
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var orientationObserver: NSObjectProtocol?

    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.delegate?.cameraService(self, didChangeRunning: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.cameraService(self, didFail: error)
                }
            }
        }
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(handleDeviceOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
    }
    
    @objc private func handleDeviceOrientation() {
        sessionQueue.async { [weak self] in self?.applyCurrentOrientation() }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            self.stopObservingOrientation()
            DispatchQueue.main.async {
                self.delegate?.cameraService(self, didChangeRunning: false)
            }
        }
    }

    func setPreset(_ preset: AVCaptureSession.Preset) {
        sessionQueue.async { [weak self] in
            guard let self, self.session.canSetSessionPreset(preset) else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = preset
            self.session.commitConfiguration()
        }
    }
}

private extension CameraService {
    func configureIfNeeded() throws {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = DemoConfig.highQualityPreset

        let device = try Self.device(for: position)

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        if session.canAddOutput(output) { session.addOutput(output) }
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frames.queue"))
        self.videoOutput = output

        if let connection = output.connection(with: .video) {
            applyRotation(on: connection)
        }

        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.unlockForConfiguration()

        session.commitConfiguration()
    }

    static func device(for position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: position
        )
        if let device = discovery.devices.first { return device }
        throw NSError(domain: "CameraService", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Camera device not found"])
    }
}

private extension CameraService {
    func stopObservingOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        if let obs = orientationObserver {
            NotificationCenter.default.removeObserver(obs)
            orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func applyRotation(on connection: AVCaptureConnection) {
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = (position == .front)
        }

        if #available(iOS 17.0, *) {
            let angle = switch UIDevice.current.orientation {
            case .portrait:           90
            case .landscapeRight:     0     // home button (or dynamic island) on right
            case .portraitUpsideDown: 270
            case .landscapeLeft:      180   // home/dynamic island on left
            default:                  90
            }
            connection.videoRotationAngle = CGFloat(Float(angle))
        } else {
            if connection.isVideoOrientationSupported {
                if let newOrientation = videoOrientation(from: UIDevice.current.orientation) {
                    connection.videoOrientation = newOrientation
                }
            }
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let exif = exifOrientation(from: connection)
        delegate?.cameraService(self, didOutput: sampleBuffer, orientation: exif)
    }
}

extension CameraService {
    private func exifOrientation(from connection: AVCaptureConnection) -> CGImagePropertyOrientation {
        if #available(iOS 17.0, *) {
            let angle = Int(round(connection.videoRotationAngle)) % 360
            switch angle {
            case 90:   return .left          // portrait
            case 270:  return .right         // portrait upside down
            case 0:    return .down          // landscapeRight
            case 180:  return .up            // landscapeLeft
            default:   return .left
            }
        } else {
            switch connection.videoOrientation {
            case .portrait:            return .left
            case .portraitUpsideDown:  return .right
            case .landscapeRight:      return .down
            case .landscapeLeft:       return .up
            @unknown default:          return .left
            }
        }
    }
    
    private func videoOrientation(from device: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
        switch device {
        case .portrait:            return .portrait
        case .portraitUpsideDown:  return .portraitUpsideDown
        case .landscapeLeft:       return .landscapeRight
        case .landscapeRight:      return .landscapeLeft
        default:                   return nil
        }
    }

    private func applyCurrentOrientation() {
        guard let new = videoOrientation(from: UIDevice.current.orientation),
              let connection = videoOutput?.connection(with: .video) else { return }

        if connection.isVideoOrientationSupported { connection.videoOrientation = new }
        if connection.isVideoMirroringSupported  { connection.isVideoMirrored  = (position == .front) }
    }
}
