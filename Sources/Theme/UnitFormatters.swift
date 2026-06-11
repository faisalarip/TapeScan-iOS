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

    /// Trade-grade imperial length: feet + inches to the nearest 1/16″ with
    /// the fraction reduced to lowest terms (`12′ 3 5/8″`). Metric callers
    /// fall through to the standard decimal form so call sites can use one
    /// entry point for primary length readouts.
    public static func lengthFractional(_ meters: Double, unit: MeasureUnit) -> String {
        guard unit == .imperial else { return length(meters, unit) }
        // Work in integer sixteenths of an inch so foot/inch carries are exact.
        let sixteenths = Int((meters / 0.0254 * 16).rounded())
        let feet = sixteenths / 192
        var remainder = sixteenths % 192
        let inches = remainder / 16
        remainder %= 16

        var fraction = ""
        if remainder > 0 {
            var numerator = remainder, denominator = 16
            while numerator.isMultiple(of: 2) { numerator /= 2; denominator /= 2 }
            fraction = "\(numerator)/\(denominator)"
        }

        var inchPart = ""
        if inches > 0 && !fraction.isEmpty { inchPart = "\(inches) \(fraction)″" }
        else if inches > 0 { inchPart = "\(inches)″" }
        else if !fraction.isEmpty { inchPart = "\(fraction)″" }

        if feet > 0 && !inchPart.isEmpty { return "\(feet)′ \(inchPart)" }
        if feet > 0 { return "\(feet)′" }
        if !inchPart.isEmpty { return inchPart }
        return "0″"
    }
}
