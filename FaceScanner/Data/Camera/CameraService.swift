//
//  CaameraService.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 2.10.2025.
//

import AVFoundation
import UIKit

// MARK: - Delegate
protocol CameraServiceDelegate: AnyObject {
    /// Live frames for downstream processing (e.g., Vision)
    func cameraService(_ service: CameraService,
                       didOutput sampleBuffer: CMSampleBuffer,
                       orientation: CGImagePropertyOrientation)
    /// Session state
    func cameraService(_ service: CameraService, didChangeRunning isRunning: Bool)
    /// Camera/session errors
    func cameraService(_ service: CameraService, didFail error: Error)
}

// MARK: - Service
final class CameraService: NSObject {

    /// Public capture session (used by preview layer)
    let session = AVCaptureSession()
    weak var delegate: CameraServiceDelegate?

    /// Current camera position (front by default)
    private var position: AVCaptureDevice.Position = DemoConfig.defaultCameraPosition

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput: AVCaptureVideoDataOutput?
    private var orientationObserver: NSObjectProtocol?

    // MARK: Public API

    /// Ask for camera permission
    func requestAccess(_ completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Start capture session
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                guard !self.session.isRunning else { return }
                self.session.startRunning()
                self.startObservingOrientation()
                DispatchQueue.main.async {
                    self.delegate?.cameraService(self, didChangeRunning: true)
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.cameraService(self, didFail: error)
                }
            }
        }
    }

    /// Stop capture session
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
}

// MARK: - Configuration
private extension CameraService {
    func configureIfNeeded() throws {
        guard session.inputs.isEmpty else { return }

        session.beginConfiguration()
        session.sessionPreset = DemoConfig.highQualityPreset

        // Device (front wide-angle)
        let device = try Self.device(for: position)

        // Input
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }

        // Output (frames for processing)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        if session.canAddOutput(output) { session.addOutput(output) }
        let framesQueue = DispatchQueue(label: "camera.frames.queue")
        output.setSampleBufferDelegate(self, queue: framesQueue)
        self.videoOutput = output

        // Connection (orientation + front mirroring)
        if let connection = output.connection(with: .video) {
            applyRotation(on: connection)
        }

        // Basic FPS / exposure tuning
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
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

// MARK: - Orientation (iOS 17+)
private extension CameraService {
    func startObservingOrientation() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self,
                  let connection = self.videoOutput?.connection(with: .video) else { return }
            self.applyRotation(on: connection)
        }
    }

    func stopObservingOrientation() {
        if let obs = orientationObserver {
            NotificationCenter.default.removeObserver(obs)
            orientationObserver = nil
        }
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func applyRotation(on connection: AVCaptureConnection) {
        // Mirror the front camera so preview looks like a mirror
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = (position == .front)
        }

        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }

    /// Map device orientation to rotation angle (degrees)
    static func rotationAngle(for deviceOrientation: UIDeviceOrientation) -> CGFloat {
        switch deviceOrientation {
        case .portrait:           return 90
        case .landscapeRight:     return 0
        case .portraitUpsideDown: return 270
        case .landscapeLeft:      return 180
        default:                  return 90
        }
    }
}

// MARK: - Frames delegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // For front camera in portrait, Vision typically expects `.right`
        delegate?.cameraService(self, didOutput: sampleBuffer, orientation: .right)
    }
}
