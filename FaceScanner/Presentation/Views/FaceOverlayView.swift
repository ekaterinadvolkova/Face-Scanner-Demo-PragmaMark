//  FaceOverlayView.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 5.10.2025.
//

import UIKit
import AVFoundation

final class FaceOverlayView: UIView {
    private var faces: [FaceFeatures] = []
    weak var previewLayer: AVCaptureVideoPreviewLayer?
    func show(faces: [FaceFeatures]) { self.faces = faces; setNeedsDisplay() }
    
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(),
              let layer = previewLayer else { return }
        ctx.setLineWidth(2)
        
        // Helper function that draws one set of landmarks (e.g., the eyes or the mouth)
        func stroke(points: [CGPoint], color: UIColor) {
            guard points.count > 1 else { return }
            let path = UIBezierPath()
            
            for (index, point) in points.enumerated() {
                // Safety check: assuming all points belong to the same first face
                guard let boundingBox = faces.first?.boundingBox else { continue }
                
                // 1. Convert landmark point relative to face box to ABSOLUTE normalized coords (0..1, BL origin)
                let absoluteX = boundingBox.origin.x + point.x * boundingBox.width
                let absoluteY = boundingBox.origin.y + point.y * boundingBox.height
                
                // 2. Create the Capture Device Point (Normalized 0..1, TL origin)
                // Manually applies Y-flip for Vision -> Capture space transfer.
                let capturePt = CGPoint(x: absoluteX, y: 1 - absoluteY)
                
                // 3. Convert to View Point (Layer handles rotation/scale)
                let viewPoint = layer.layerPointConverted(fromCaptureDevicePoint: capturePt)
                
                // 4. Final adjustment: Re-mirror the X coordinate for correct front camera display.
                let finalViewPoint = CGPoint(x: rect.width - viewPoint.x, y: viewPoint.y)

                if index == 0 {
                    path.move(to: finalViewPoint)
                } else {
                    path.addLine(to: finalViewPoint)
                }
            }
            color.setStroke()
            path.stroke()
        }
        
        // Draw all landmarks for the first face detected
        for face in faces {
            stroke(points: face.faceContour, color: .systemTeal)
            stroke(points: face.leftEye,    color: .systemYellow)
            stroke(points: face.rightEye,   color: .systemYellow)
            stroke(points: face.nose,       color: .systemGreen)
            stroke(points: face.outerLips,  color: .systemRed)
        }
    }
}
