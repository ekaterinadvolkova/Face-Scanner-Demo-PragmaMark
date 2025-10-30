//
//  ARFaceTrackerViewController.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 20.10.2025.
//

import UIKit
import ARKit
import SceneKit
import CoreGraphics

final class ARFaceTrackerViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    private var sceneView: ARSCNView = {
        let view = ARSCNView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let validationDuration: TimeInterval = 3.0
    private var scanStartTime: Date?
    
    private enum ARValidationState {
        case initializing
        case compliant
        case scanning(progress: Double)
        case complete
        case error(message: String)
    }
    private var currentState: ARValidationState = .initializing
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.text = "Initializing AR Tracking..."
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let rescanButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Rescan", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 25
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 40, bottom: 10, right: 40)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        
        rescanButton.addTarget(self, action: #selector(rescanTapped), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard ARFaceTrackingConfiguration.isSupported else {
            currentState = .error(message: "AR requires TrueDepth Camera (iPhone X or later).")
            updateStatusLabel()
            return
        }
        
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        
        currentState = .initializing
        updateStatusLabel()
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    private func setupUI() {
        view.addSubview(sceneView)
        view.addSubview(statusLabel)
        view.addSubview(rescanButton)
        
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            
            rescanButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rescanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc
    private func rescanTapped() {
        scanStartTime = nil
        rescanButton.isHidden = true
        currentState = .initializing
        
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        }
        updateStatusLabel()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let device = sceneView.device,
              anchor is ARFaceAnchor else { return nil }
        
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        
        node.geometry?.firstMaterial?.fillMode = .lines
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        if let faceGeometry = node.geometry as? ARSCNFaceGeometry {
            faceGeometry.update(from: faceAnchor.geometry)
        }
        
        let pose = faceAnchor.transform.eulerAngles()
        let rollDeg = pose.z * 180 / Float.pi
        let yawDeg = pose.y * 180 / Float.pi
        let leftEyeBlink = faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0
        let rightEyeBlink = faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0
        
        let maxTilt: Float = 10.0 // 10 degrees is easily achievable and very stable
        let maxTurn: Float = 15.0
        let maxBlink: Float = 0.2 // If blink value is below 20%, eyes are considered open.
        
        let isRollStraight = abs(rollDeg) < maxTilt
        let isYawFrontal = abs(yawDeg) < maxTurn
        let areEyesOpen = (leftEyeBlink < maxBlink) && (rightEyeBlink < maxBlink)
        
        let allCompliant = isRollStraight && isYawFrontal && areEyesOpen
        
        if !allCompliant {
            scanStartTime = nil
            rescanButton.isHidden = true
            
            if !areEyesOpen {
                currentState = .error(message: "Keep your eyes open (Left: \(String(format: "%.1f", leftEyeBlink)), Right: \(String(format: "%.1f", rightEyeBlink))).")
            } else if !isRollStraight {
                currentState = .error(message: "Hold your head straight (Roll: \(String(format: "%.0f", rollDeg))°).")
            } else if !isYawFrontal {
                currentState = .error(message: "Face the camera directly (Yaw: \(String(format: "%.0f", yawDeg))°).")
            } else {
                currentState = .compliant
            }
        } else {
            if scanStartTime == nil { currentState = .compliant; scanStartTime = Date() }
            let elapsed = Date().timeIntervalSince(scanStartTime!)
            let progress = min(elapsed / validationDuration, 1.0)
            
            if progress >= 1.0 {
                currentState = .complete
                sceneView.session.pause()
                rescanButton.isHidden = false
            } else {
                currentState = .scanning(progress: progress)
            }
        }
        
        DispatchQueue.main.async {
            self.updateStatusLabel()
        }
    }
}


extension matrix_float4x4 {
    func eulerAngles() -> simd_float3 {
        let sy = sqrt(self.columns.0.x * self.columns.0.x + self.columns.1.x * self.columns.1.x)
        let singular = sy < 1e-6
        
        var x, y, z: Float
        if !singular {
            x = atan2(self.columns.2.y, self.columns.2.z)
            y = atan2(-self.columns.2.x, sy)
            z = atan2(self.columns.1.x, self.columns.0.x)
        } else {
            x = atan2(-self.columns.1.z, self.columns.1.y)
            y = atan2(-self.columns.2.x, sy)
            z = 0
        }
        return simd_float3(x: x, y: y, z: z)
    }
}

private extension ARFaceTrackerViewController {
    func updateStatusLabel() {
        var statusText = ""
        var statusColor: UIColor = .white
        
        switch currentState {
        case .initializing:
            statusText = "Initializing AR Tracking..."
            statusColor = .white
        case .compliant:
            statusText = "✅ Position Stable. Starting Scan."
            statusColor = .systemGreen
        case .scanning(let progress):
            let percentage = Int(progress * 100)
            statusText = "SCANNING... \(percentage)% COMPLETE"
            statusColor = .systemGreen
        case .complete:
            statusText = "✅ VALIDATION SUCCESSFUL! (3D Stable)"
            statusColor = .systemGreen
            rescanButton.isHidden = false
        case .error(let message):
            statusText = "❌ Validation Failed: \(message)"
            statusColor = .systemRed
            rescanButton.isHidden = false
        }
        
        self.statusLabel.text = statusText
        self.statusLabel.textColor = statusColor
        self.statusLabel.isHidden = false
    }
}
