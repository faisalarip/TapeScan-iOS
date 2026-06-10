// UnitFormatters.swift — pure metric/imperial value formatters.
// Ported verbatim from ui.jsx (fmtLen / fmtArea / fmtVol / fmtAng).

import Foundation

/// Stateless measurement formatters. All take SI inputs (meters / m² / m³ / degrees)
/// and a ``MeasureUnit`` and return the exact display strings from the design.
public enum UnitFormat {

    /// Length. Metric: `"%.2f m"`. Imperial: feet+inches `"12′ 11″"`
    /// (`ft = floor(in/12)`, `in = round(remainder)`, with 12″ carry to the next foot).
    public static func length(_ meters: Double, _ unit: MeasureUnit) -> String {
        if unit == .imperial {
            let totalInches = meters * 39.3701
            var ft = Int(floor(totalInches / 12.0))
            var inch = Int((totalInches - Double(ft) * 12.0).rounded())
            if inch == 12 { ft += 1; inch = 0 }
            return "\(ft)′ \(inch)″"
        }
        return String(format: "%.2f m", meters)
    }

    /// Area. Metric: `"%.2f m²"`. Imperial: `"%.1f ft²"` (× 10.7639).
    public static func area(_ squareMeters: Double, _ unit: MeasureUnit) -> String {
        unit == .imperial
            ? String(format: "%.1f ft²", squareMeters * 10.7639)
            : String(format: "%.2f m²", squareMeters)
    }

    /// Volume. Metric: `"%.2f m³"`. Imperial: `"%.1f ft³"` (× 35.315).
    public static func volume(_ cubicMeters: Double, _ unit: MeasureUnit) -> String {
        unit == .imperial
            ? String(format: "%.1f ft³", cubicMeters * 35.315)
            : String(format: "%.2f m³", cubicMeters)
    }

    /// Angle. Always `"%.1f°"` regardless of unit system.
    public static func angle(_ degrees: Double) -> String {
        String(format: "%.1f°", degrees)
    }
}
