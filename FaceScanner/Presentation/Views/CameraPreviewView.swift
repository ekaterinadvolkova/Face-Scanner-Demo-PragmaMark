//
//  CameraPreview.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 3.10.2025.
//

import UIKit
import AVFoundation

/// UIView that renders live AVCaptureSession
final class CameraPreviewView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        isAccessibilityElement = true
        accessibilityIdentifier = "camera_preview"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
