import AVFoundation
import SwiftUI

/*
This view's only job is: show the user what the camera sees.
*/
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    // A plain UIKit view whose backing layer is the camera feed.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    // Builds the view and points its layer at our camera session.
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.layer as! AVCaptureVideoPreviewLayer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        return view
    }

    // Nothing changes after setup, so there is nothing to update.
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
