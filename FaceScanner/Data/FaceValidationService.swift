//
//  FaceValidationService.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 2.10.2025.
//

import Foundation
import CoreGraphics

enum ValidationState: Equatable {
    case awaitingFace
    case centerFace(message: String)
    case eyeError(message: String)
    case scanning(progress: Double)
    case complete
    case error(message: String)
}

final class FaceValidationService {
    
    private let validationDuration: TimeInterval = 3.0
    private let minFaceWidth: CGFloat = 0.25
    private let centerSlack: CGFloat = 0.25
    private let frameMargin: CGFloat = 0.07
    private let maxRollDeg: CGFloat = 35
    private let maxYawDeg: CGFloat = 45
    private let minLandmarkCount = (eye: 6, lips: 8, contour: 10, nose: 3)
    private let minEyeOpennessRatio: CGFloat = 0.080
    private let maxHeadRotationDegreeYLine: CGFloat = 45
    
    private var scanStartTime: Date?
    
    public func resetScan() {
        self.scanStartTime = nil
    }
    
    func process(features: [FaceFeatures]) -> (state: ValidationState, shouldStop: Bool, results: [ValidationResult]) {
        let state = checkAllConditions(faces: features)
        let results = compileValidationResults(face: features.first)
        
        return (state, state == .complete, results)
    }

    private func checkAllConditions(faces: [FaceFeatures]) -> ValidationState {
        guard faces.count == 1, let face = faces.first else {
            scanStartTime = nil; return .awaitingFace
        }
        
        if let message = checkObscurementError(face: face) {
            scanStartTime = nil; return .error(message: message)
        }
        
        if let message = positionError(face: face) {
            scanStartTime = nil; return .centerFace(message: message)
        }
        
        if let message = poseError(face: face) {
            scanStartTime = nil; return .error(message: message)
        }

        if let message = getEyeOpennessError(face: face) {
            scanStartTime = nil; return .eyeError(message: message)
        }
        
        if scanStartTime == nil { scanStartTime = Date() }
        let elapsed = Date().timeIntervalSince(scanStartTime!)
        let progress = min(elapsed / validationDuration, 1.0)
        
        return (progress >= 1.0) ? .complete : .scanning(progress: progress)
    }
}

extension FaceValidationService {
    
    struct ValidationResult {
        let name: String
        let passed: Bool
    }
    
    private func compileValidationResults(face: FaceFeatures?) -> [ValidationResult] {
        guard let face = face else { return [] }
        
        return [
            ValidationResult(name: "Eyes Open", passed: getEyeOpennessError(face: face) == nil),
            ValidationResult(name: "Visible Face", passed: checkObscurementError(face: face) == nil),
            ValidationResult(name: "Position/Size", passed: positionError(face: face) == nil),
            ValidationResult(name: "Pose Straight", passed: poseError(face: face) == nil),
        ]
    }
    
    private func checkObscurementError(face: FaceFeatures) -> String? {
        if face.outerLips.count < minLandmarkCount.lips || face.nose.count < minLandmarkCount.nose ||
           face.leftEye.count < minLandmarkCount.eye || face.rightEye.count < minLandmarkCount.eye {
             return "Keep your nose and mouth visible."
        }
        
        guard hasCriticalLandmarks(face) else {
            return "Make sure your full face is visible (eyes, nose, lips)."
        }
        return nil
    }
    
    private func positionError(face: FaceFeatures) -> String? {
        let bb = face.boundingBox
        guard bb.width >= minFaceWidth else { return "Move closer and center your face." }

        let centeredX = abs(bb.midX - 0.5) <= centerSlack
        let centeredY = abs(bb.midY - 0.5) <= centerSlack
        
        let marginCheck = bb.minX > frameMargin && bb.maxX < 1 - frameMargin &&
                          bb.minY > frameMargin && bb.maxY < 1 - frameMargin
        
        guard centeredX && centeredY else { return "Center your face in the frame." }
        guard marginCheck else { return "Make sure your full face is visible (eyes, nose, lips)." }
        
        return nil
    }

    private func poseError(face: FaceFeatures) -> String? {
        if let yaw = face.yaw {
            let yawDeg = abs(yaw * 180 / .pi)
            
            if yawDeg > maxHeadRotationDegreeYLine {
                return "Face the camera directly (Yaw: \(String(format: "%.0f", yawDeg))°)."
            }
        }
        
        guard let lc = center(of: face.leftEye, in: face.boundingBox),
              let rc = center(of: face.rightEye, in: face.boundingBox) else { return "Keep both eyes visible." }
        
        let dx = rc.x - lc.x
        let dy = rc.y - lc.y
        let dist = hypot(dx, dy)
        
        guard dist > 0.10 else { return "Face the camera directly." }
        
        return nil
    }
    
    private func getEyeOpennessError(face: FaceFeatures) -> String? {
        if face.leftEye.count < minLandmarkCount.eye || face.rightEye.count < minLandmarkCount.eye {
             return "Keep your eyes visible."
        }
        
        func spreadOK(_ pts: [CGPoint]) -> Bool {
            guard pts.count >= 3 else { return false }
            let xs = pts.map{$0.x}; let ys = pts.map{$0.y}
            let w = (xs.max()! - xs.min()!)
            let h = (ys.max()! - ys.min()!)
            return w > 0.05 && h > 0.02
        }
        
        if !spreadOK(face.leftEye)  || !spreadOK(face.rightEye) {
            return "Open your eyes."
       }
        
        return nil
    }
    
    private func hasCriticalLandmarks(_ f: FaceFeatures) -> Bool {
        guard f.outerLips.count >= minLandmarkCount.lips,
              f.faceContour.count >= minLandmarkCount.contour else { return false }
        
        func spreadOK(_ pts: [CGPoint]) -> Bool {
            guard pts.count >= 3 else { return false }
            let xs = pts.map{$0.x}; let ys = pts.map{$0.y}
            let w = (xs.max()! - xs.min()!)
            let h = (ys.max()! - ys.min()!)
            return w > 0.05 && h > 0.02
        }
        
        return spreadOK(f.faceContour) && spreadOK(f.outerLips)
    }

    private func isEyeOpen(_ pts: [CGPoint], _ faceHeight: CGFloat, tolerance: CGFloat) -> Bool {
        guard pts.count >= 4 else { return false }
        let maxY = pts.map { $0.y }.max()!
        let minY = pts.map { $0.y }.min()!
        let eyeOpennessAbs = (maxY - minY) * faceHeight
        
        let requiredMinOpenness = tolerance * faceHeight
        
        return eyeOpennessAbs >= requiredMinOpenness
    }
    
    private func center(of points: [CGPoint], in bb: CGRect) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let ax = points.reduce(0) { $0 + $1.x } / CGFloat(points.count)
        let ay = points.reduce(0) { $0 + $1.y } / CGFloat(points.count)
        return CGPoint(x: bb.origin.x + ax * bb.width, y: bb.origin.y + ay * bb.height)
    }
}
