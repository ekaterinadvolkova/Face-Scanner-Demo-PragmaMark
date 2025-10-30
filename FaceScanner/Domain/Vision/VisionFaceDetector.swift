//
//  VisionFaceDetector.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 5.10.2025.
//

import Vision
import CoreMedia

struct FaceFeatures {
    let boundingBox: CGRect
    let leftEye: [CGPoint]
    let rightEye: [CGPoint]
    let nose: [CGPoint]
    let outerLips: [CGPoint]
    let faceContour: [CGPoint]
    let roll: CGFloat?
    let yaw:  CGFloat?
    let captureQuality: Float?
}

final class VisionFaceDetector {
    private let requestHandler = VNSequenceRequestHandler()
    private let request = VNDetectFaceLandmarksRequest()

    func detect(in sampleBuffer: CMSampleBuffer,
                orientation: CGImagePropertyOrientation) throws -> [FaceFeatures] {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return [] }
        
        try requestHandler.perform([request], on: pixelBuffer, orientation: orientation)
        
        guard let results = request.results as? [VNFaceObservation],
              !results.isEmpty else { return [] }
        
        return results.map { obs in
            let lm = obs.landmarks
            return FaceFeatures(
                boundingBox: obs.boundingBox,
                leftEye: lm?.leftEye?.normalizedPoints ?? [],
                rightEye: lm?.rightEye?.normalizedPoints ?? [],
                nose: (lm?.nose ?? lm?.noseCrest)?.normalizedPoints ?? [],
                outerLips: lm?.outerLips?.normalizedPoints ?? [],
                faceContour: lm?.faceContour?.normalizedPoints ?? [],
                roll: (obs.roll != nil) ? CGFloat(truncating: obs.roll!) : nil,
                yaw:  (obs.yaw  != nil) ? CGFloat(truncating: obs.yaw!)  : nil,
                captureQuality: obs.faceCaptureQuality
            )
        }
    }
}
