//
//  FaceFinderViewController.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 2.10.2025.
//

import AVFoundation
import Vision
import UIKit

//final class FaceFinderViewController: UIViewController {
//    
//    private let camera = CameraService()
//    private var previewView: CameraPreviewView?
//    private let vision = VisionFaceDetector()
//    private let overlay = FaceOverlayView()
//    private var isProcessingFrame = false
//    
//    private var targetValidationState: ValidationState = .awaitingFace
//    private let validationService = FaceValidationService()
//    private var lastFPSTime: CFTimeInterval = 0
//    private var frameCount: Int = 0
//    
//    private var scanStartTime: Date?
//    
//    private let statusLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Preparing camera…"
//        label.textAlignment = .center
//        label.numberOfLines = 2
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let detailStatusLabel: UILabel = {
//        let label = UILabel()
//        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
//        label.textColor = .white
//        label.numberOfLines = 0
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let fpsLabel: UILabel = {
//        let label = UILabel()
//        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
//        label.textColor = .white
//        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
//        label.layer.cornerRadius = 6
//        label.clipsToBounds = true
//        label.text = "FPS: - "
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let rescanButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Rescan", for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
//        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
//        button.setTitleColor(.black, for: .normal)
//        button.layer.cornerRadius = 25
//        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 40, bottom: 10, right: 40)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.isHidden = true
//        return button
//    }()
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .black
//        camera.delegate = self
//        setupUI()
//        authorizeAndStart()
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(orientationChanged),
//                                               name: UIDevice.orientationDidChangeNotification,
//                                               object: nil)
//    }
//    
//    @objc
//    private func orientationChanged() {
//        guard let connection = previewView?.previewLayer.connection else { return }
//        let currentOrientation = UIDevice.current.orientation
//        
//        if #available(iOS 17.0, *) {
//            let angle: Float
//            switch UIDevice.current.orientation {
//            case .portrait: angle = 90
//            case .landscapeRight: angle = 0
//            case .portraitUpsideDown: angle = 270
//            case .landscapeLeft: angle = 180
//            default: angle = 90
//            }
//            connection.videoRotationAngle = CGFloat(angle)
//        } else if connection.isVideoOrientationSupported {
//            switch UIDevice.current.orientation {
//            case .portrait: connection.videoOrientation = .portrait
//            case .landscapeRight: connection.videoOrientation = .landscapeLeft
//            case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
//            case .landscapeLeft: connection.videoOrientation = .landscapeRight
//            default: break
//            }
//        }
//        
//        let rotationAngleRadians = rotationAngle(for: currentOrientation)
//        
//        UIView.animate(withDuration: 0.25) {
//            self.fpsLabel.transform = CGAffineTransform(rotationAngle: rotationAngleRadians)
//            self.statusLabel.transform = CGAffineTransform(rotationAngle: rotationAngleRadians)
//            self.detailStatusLabel.transform = CGAffineTransform(rotationAngle: rotationAngleRadians)
//            self.view.layoutIfNeeded()
//        }
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        UIApplication.shared.isIdleTimerDisabled = true
//    }
//    
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        UIApplication.shared.isIdleTimerDisabled = false
//    }
//    
//    private func setupUI() {
//        view.addSubview(fpsLabel)
//        view.addSubview(overlay)
//        view.addSubview(statusLabel)
//        view.addSubview(rescanButton)
//        view.addSubview(detailStatusLabel)
//        
//        NSLayoutConstraint.activate([
//            fpsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
//            fpsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
//            
//            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
//            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
//            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -100),
//            
//            detailStatusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            detailStatusLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
//            detailStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
//            detailStatusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
//            
//            overlay.topAnchor.constraint(equalTo: view.topAnchor),
//            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            
//            rescanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            rescanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
//        ])
//        
//        overlay.backgroundColor = .clear
//        overlay.isUserInteractionEnabled = false
//        overlay.translatesAutoresizingMaskIntoConstraints = false
//        
//        rescanButton.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)
//    }
//    
//    private func attachPreview() {
//        guard previewView == nil else { return }
//        let preview = CameraPreviewView(session: camera.session)
//        preview.translatesAutoresizingMaskIntoConstraints = false
//        view.insertSubview(preview, at: 0)
//        NSLayoutConstraint.activate([
//            preview.topAnchor.constraint(equalTo: view.topAnchor),
//            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//        ])
//        previewView = preview
//        overlay.previewLayer = preview.previewLayer
//    }
//    
//    private func authorizeAndStart() {
//        camera.requestCameraAccess { [weak self] granted in
//            guard let self else { return }
//            if granted {
//                self.attachPreview()
//                self.orientationChanged()
//                self.camera.start()
//            } else {
//                self.statusLabel.text = "Camera access denied"
//            }
//        }
//    }
//    
//    override func viewDidDisappear(_ animated: Bool) {
//        super.viewDidDisappear(animated)
//        camera.stop()
//    }
//}
//
//extension FaceFinderViewController: CameraServiceDelegate {
//    func cameraSessionState(_ service: CameraService, didChangeRunning isRunning: Bool) {
//        DispatchQueue.main.async {
//            self.statusLabel.isHidden = isRunning && (self.targetValidationState == .scanning(progress: 0) || self.targetValidationState == .complete)
//            
//            if !isRunning {
//                if self.targetValidationState != .complete {
//                    self.statusLabel.text = "Scan cancelled"
//                    self.statusLabel.textColor = .systemRed
//                } else {
//                    self.statusLabel.text = "Scan complete"
//                }
//                
//                self.targetValidationState = .awaitingFace
//            }
//        }
//    }
//    
//    func cameraOrSessionErrors(_ service: CameraService, didFail error: Error) {
//        DispatchQueue.main.async {
//            self.statusLabel.text = "Camera error: \(error.localizedDescription)"
//        }
//    }
//    
//    func cameraLiveFrames(_ service: CameraService,
//                            didOutput sampleBuffer: CMSampleBuffer,
//                            orientation: CGImagePropertyOrientation) {
//        if isProcessingFrame { return }
//        isProcessingFrame = true
//        
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            guard let self else { return }
//            
//            autoreleasepool {
//                
//                guard DemoConfig.enableVision,
//                      let features = try? self.vision.detect(in: sampleBuffer, orientation: orientation) else {
//                    self.isProcessingFrame = false
//                    return
//                }
//                
//                let (newValidationState, shouldStop, results) = self.validationService.process(features: features)
//                
//                DispatchQueue.main.async {
//                    self.overlay.show(faces: features)
//                    self.targetValidationState = newValidationState
//                    self.updateUIForState(newValidationState, results: results)
//                    
//                    if shouldStop {
//                        self.camera.stop()
//                    }
//                }
//            }
//            self.isProcessingFrame = false
//        }
//        
//        DispatchQueue.main.async {
//            self.updateFPSDisplay()
//        }
//    }
//}
//
//extension FaceFinderViewController {
//    func rotationAngle(for deviceOrientation: UIDeviceOrientation) -> CGFloat {
//        switch deviceOrientation {
//        case .portrait:
//            return 0
//        case .landscapeRight:
//            return .pi / 2
//        case .portraitUpsideDown:
//            return .pi
//        case .landscapeLeft:
//            return -.pi / 2
//        default:
//            return 0
//        }
//    }
//    
//    private func updateUIForState(_ state: ValidationState, results: [FaceValidationService.ValidationResult]) {
//        self.statusLabel.isHidden = false
//        self.rescanButton.isHidden = true
//        
//        let successCount = results.filter { $0.passed }.count
//        let totalChecks = results.count
//        let counterText = "\(successCount)/\(totalChecks) OK"
//
//        let detailText = results.map { result in
//            let status = result.passed ? "✅" : "❌"
//            return "\(status) \(result.name)"
//        }.joined(separator: "\n")
//        
//        self.detailStatusLabel.text = detailText
//        
//        switch state {
//        case .awaitingFace:
//            self.statusLabel.text = "Searching for face..."
//            self.statusLabel.textColor = .white
//            self.detailStatusLabel.text = nil
//        
//        case .centerFace(let message):
//            self.statusLabel.text = "\(message)\n\(counterText)"
//            self.statusLabel.textColor = .systemYellow
//            
//        case .eyeError(let message):
//            self.statusLabel.text = "\(message)\n\(counterText)"
//            self.statusLabel.textColor = .systemYellow
//            
//        case .error(let message):
//            self.statusLabel.text = "\(message)\n\(counterText)"
//            self.statusLabel.textColor = .systemRed
//            self.rescanButton.isHidden = false
//
//        case .scanning(let progress):
//            self.statusLabel.text = "Scanning... \(Int(progress * 100))%\n\(counterText)"
//            self.statusLabel.textColor = .systemGreen
//
//        case .complete:
//            self.statusLabel.text = "Scan Complete\n\(counterText)"
//            self.statusLabel.textColor = .systemGreen
//            self.rescanButton.isHidden = false
//        }
//    }
//}
//
//private extension FaceFinderViewController {
//    func updateFPSDisplay() {
//        self.frameCount += 1
//        let now = CACurrentMediaTime()
//        if self.lastFPSTime == 0 { self.lastFPSTime = now }
//        let delta = now - self.lastFPSTime
//        
//        if delta >= 1 {
//            let fps = Int(round(Double(self.frameCount) / delta))
//            self.fpsLabel.text = "FPS: \(fps)"
//            self.lastFPSTime = now
//            self.frameCount = 0
//        }
//    }
//    
//    @objc
//    private func rescanTapped() {
//        targetValidationState = .awaitingFace
//        validationService.resetScan()
//        camera.start()
//        rescanButton.isHidden = true
//        statusLabel.isHidden = false
//        statusLabel.text = "Searching for face..."
//        statusLabel.textColor = .white
//    }
//}
