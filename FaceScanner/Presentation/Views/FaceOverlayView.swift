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
        
        func stroke(points: [CGPoint], color: UIColor) {
            guard points.count > 1 else { return }
            let path = UIBezierPath()
            
            for (_, point) in points.enumerated() {
                guard let boundingBox = faces.first?.boundingBox else { continue }
                
                let absoluteX = boundingBox.origin.x + point.x * boundingBox.width
                let absoluteY = boundingBox.origin.y + point.y * boundingBox.height
                
                let capturePt = CGPoint(x: absoluteX, y: 1 - absoluteY)
                
                let viewPoint = layer.layerPointConverted(fromCaptureDevicePoint: capturePt)
                
                let finalViewPoint = CGPoint(x: rect.width - viewPoint.x, y: viewPoint.y) // Re-introduce X-mirror for final display

                if path.currentPoint.x == 0 && path.currentPoint.y == 0 {
                    path.move(to: finalViewPoint)
                } else {
                    path.addLine(to: finalViewPoint)
                }
            }
            color.setStroke()
            path.stroke()
        }
        
        for face in faces {
            stroke(points: face.faceContour, color: .systemTeal)
            stroke(points: face.leftEye,    color: .systemYellow)
            stroke(points: face.rightEye,   color: .systemYellow)
            stroke(points: face.nose,       color: .systemGreen)
            stroke(points: face.outerLips,  color: .systemRed)
        }
    }
}
