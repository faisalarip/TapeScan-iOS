// MeasureBackdrop.swift — selects the camera layer for the Measure screens.
//
// Simulator: the stylized SwiftUI CameraBackdrop stand-in (plus optional
// decorative FeaturePoints). Device: the live ARView camera feed owned by
// ARKitMeasureService — fake feature points are never drawn over a real feed.

import SwiftUI
#if !targetEnvironment(simulator)
import RealityKit
#endif

struct MeasureBackdrop: View {
    let service: any ARMeasureService
    let accent: Color
    var warmth: Double = 0
    let mesh: Bool
    let gridAlpha: Double
    var showFeaturePoints: Bool = false

    var body: some View {
        #if targetEnvironment(simulator)
        simulatedBackdrop
        #else
        if let arkit = service as? ARKitMeasureService {
            ARViewContainer(arView: arkit.arView)
                .ignoresSafeArea()
        } else {
            simulatedBackdrop
        }
        #endif
    }

    private var simulatedBackdrop: some View {
        ZStack {
            CameraBackdrop(accent: accent,
                           warmth: warmth,
                           mesh: mesh,
                           gridAlpha: gridAlpha)
            if showFeaturePoints {
                FeaturePoints(accent: accent)
            }
        }
    }
}

#if !targetEnvironment(simulator)
/// Hosts the service-owned ARView. The service controls the session; this
/// representable only embeds the view.
private struct ARViewContainer: UIViewRepresentable {
    let arView: ARView

    func makeUIView(context: Context) -> ARView { arView }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
#endif
