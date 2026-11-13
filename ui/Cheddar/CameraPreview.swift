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

        override func layoutSubviews() {
            super.layoutSubviews()
            faceSideways()
        }

        // The camera screen is always sideways (top of the phone to the left), which is the camera's own
        // natural way round, so the picture needs no turn. The feed only exists once the camera is wired.
        func faceSideways() {
            guard let connection = (layer as! AVCaptureVideoPreviewLayer).connection,
                  connection.isVideoRotationAngleSupported(0) else { return }
            connection.videoRotationAngle = 0
        }
    }

    // Builds the view and points its layer at our camera session.
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.layer as! AVCaptureVideoPreviewLayer
        layer.session = session
        layer.videoGravity = .resizeAspectFill
        return view
    }

    // Runs again once the camera is ready, so the picture gets turned as soon as there is one.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.faceSideways()
    }
}
