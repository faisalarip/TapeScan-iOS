// CSVExporter.swift — measurements + quantities spreadsheet export (M6).
//
// SI values to two decimals; pros feed these straight into estimates.

import Foundation

public enum CSVExporter {

    public static func csv(for model: FloorPlanModel, name: String) -> String {
        var lines: [String] = []
        lines.append("TapeScan Export,\(escape(name))")
        lines.append("Section,Item,Value,Unit")

        for room in model.rooms {
            lines.append("Room,\(escape(room.label)),\(format(room.polygonAreaSquareMeters)),m²")
        }
        for (index, wall) in model.walls.enumerated() {
            lines.append("Wall,Wall \(index + 1),\(format(wall.lengthMeters)),m")
        }

        let q = model.quantities
        lines.append("Quantity,Perimeter,\(format(q.perimeterMeters)),m")
        lines.append("Quantity,Floor area,\(format(q.floorAreaSquareMeters)),m²")
        lines.append("Quantity,Wall area (net of openings),\(format(q.wallAreaSquareMeters)),m²")
        lines.append("Quantity,Volume,\(format(q.volumeCubicMeters)),m³")

        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func escape(_ field: String) -> String {
        field.contains(",") || field.contains("\"")
            ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            : field
    }
}
