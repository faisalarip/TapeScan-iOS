// PNGExporter.swift — raster plan image via ImageRenderer (M6).

import SwiftUI

public enum PNGExporter {

    /// Renders the styled FloorPlan view at 3× on the app's dark canvas.
    @MainActor
    public static func png(for model: FloorPlanModel, unit: MeasureUnit) -> Data? {
        let view = ZStack {
            Color(hex: "#101216")
            FloorPlan(model: model,
                      accent: AccentOption.blue.color,
                      unit: unit)
                .padding(28)
        }
        .frame(width: 640, height: 560)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }
}
