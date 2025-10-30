//
//  FaceFinderViewController.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 2.10.2025.
//

import AVFoundation
import UIKit

/// First screen: shows live camera preview and exposes Frames per Second (FPS) to prove "high-quality front input"
final class FaceFinderViewController: UIViewController {

    private let camera = CameraService()
    private var previewView: CameraPreviewView?

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing camera…"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let fpsLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.text = "FPS: - "
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var lastFPSTime: CFTimeInterval = 0
    private var frameCount: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        camera.delegate = self
        setupUI()
        authorizeAndStart()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func setupUI() {
        view.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        view.addSubview(fpsLabel)
        NSLayoutConstraint.activate([
            fpsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            fpsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8)
        ])
    }

    private func attachPreview() {
        guard previewView == nil else { return }
        let preview = CameraPreviewView(session: camera.session)
        preview.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(preview, at: 0)
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.topAnchor),
            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        previewView = preview
    }

    private func authorizeAndStart() {
        camera.requestAccess { [weak self] granted in
            guard let self else { return }
            if granted {
                self.attachPreview()
                self.camera.start()
            } else {
                self.statusLabel.text = "Camera access denied"
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        camera.stop()
    }
}

// MARK: - CameraServiceDelegate
extension FaceFinderViewController: CameraServiceDelegate {
    func cameraService(_ service: CameraService, didChangeRunning isRunning: Bool) {
        DispatchQueue.main.async {
            self.statusLabel.isHidden = isRunning
            if !isRunning { self.statusLabel.text = "Camera stopped" }
        }
    }

    func cameraService(_ service: CameraService, didFail error: Error) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Camera error: \(error.localizedDescription)"
        }
    }
    
    func cameraService(_ service: CameraService,
                       didOutput sampleBuffer: CMSampleBuffer,
                       orientation: CGImagePropertyOrientation) {
        DispatchQueue.main.async {
            self.frameCount += 1
            let now = CACurrentMediaTime()
            if self.lastFPSTime == 0 { self.lastFPSTime = now }
            let delta = now - self.lastFPSTime
            if delta >= 1 {
                let fps = Int(round(Double(self.frameCount) / delta))
                self.fpsLabel.text = "FPS: \(fps)"
                self.lastFPSTime = now
                self.frameCount = 0
            }
        }
    }
}
