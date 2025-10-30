//
//  Config.swift
//  FaceScanner
//
//  Created by Ekaterina Volkova on 5.10.2025.
//

import AVFoundation
import Foundation

/// Demo configuration flags and constants
enum DemoConfig {
    
    // MARK: - Feature Toggles
    
    /// Step 2 - Enable Vision-based face detection
    static let enableVision = false
    
    /// Step 3 - Enable ARKit overlays
    static let enableARKit = false
    
    // MARK: - Camera Settings
    
    /// Preferred camera position
    static let defaultCameraPosition: AVCaptureDevice.Position = .front
    
    /// Preferred session preset for Vision (lower resolution = faster)
    static let visionSessionPreset: AVCaptureSession.Preset = .vga640x480
    
    /// Preferred session preset for high-quality demo
    static let highQualityPreset: AVCaptureSession.Preset = .high
    
}
