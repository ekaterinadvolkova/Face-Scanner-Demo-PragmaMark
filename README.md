# Face-Scanner-Demo-PragmaMark

This repository contains the demo project from my PragmaMark talk — a step-by-step exploration of how to build a **Face Scanner** on iOS using **AVFoundation**, **Vision**, and **ARKit**.

The goal of this project is to demonstrate how a face can be detected, validated, and tracked in real-time — and how to make it perform smoothly under realistic conditions.

---

## 🧭 Project Structure

Each branch represents a working step in the evolution of the scanner:

| Branch | Description |
|--------|-------------|
| `step-1` | **Camera Setup** — Front camera, mirrored preview, and frame delivery |
| `step-2` | **2D Face Detection** — Vision requests, bounding boxes, landmarks, and face overlays |
| `step-3` | **3D Face Detection** — ARKit face detection |

---

## 🧠 Tech Stack

- **AVFoundation** — real-time camera capture  
- **Vision** — face observation and landmarks detection  
- **ARKit** — 3D face mesh tracking  
- **Swift 5** + **UIKit**
- FPS optimization & concurrency handling (GCD)

---

## 🧩 Performance Focus

- Background queues for frame processing  
- Vision requests reuse and throttling  
- FPS measurement & latency handling  
- Efficient mapping between coordinate systems  

---

## 🗣️ About the Talk

This project was presented live during my **PragmaMark** talk to show how to combine Apple frameworks into a responsive and reliable face scanning pipeline.

If you attended the session — thank you for joining!  
If not, you can explore each branch to see how the scanner evolves step by step.

---

## 💬 Questions?

You can join the **[Discussions](https://github.com/YOUR_USERNAME/FaceScanner-Demo/discussions)** page to ask follow-up questions or share ideas.  
Or simply scan the QR code from my slides to get in touch directly.

---

### 📄 License

MIT License © 2025 Ekaterina Volkova  
This project is open for educational and non-commercial use.

---
