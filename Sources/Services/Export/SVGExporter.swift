// SVGExporter.swift — vector floor plan (M6).
//
// Standalone SVG in centimeter coordinates (plan meters × 100), light
// document styling so the file opens cleanly in browsers and design tools.

import Foundation

public enum SVGExporter {

    public static func svg(for model: FloorPlanModel) -> String {
        let width = Int((model.widthMeters * 100).rounded())
        let height = Int((model.heightMeters * 100).rounded())

        func pt(_ x: Double, _ y: Double) -> String {
            "\(format(x * 100)),\(format(y * 100))"
        }

        var body = ""

        // Room fills + labels.
        for room in model.rooms {
            let n = min(room.polygonX.count, room.polygonY.count)
            guard n >= 3 else { continue }
            let points = (0..<n).map { pt(room.polygonX[$0], room.polygonY[$0]) }
                .joined(separator: " ")
            body += "  <polygon class=\"room\" points=\"\(points)\" fill=\"#f2f4f7\" stroke=\"none\"/>\n"
            let cx = room.polygonX.prefix(n).reduce(0, +) / Double(n) * 100
            let cy = room.polygonY.prefix(n).reduce(0, +) / Double(n) * 100
            body += "  <text x=\"\(format(cx))\" y=\"\(format(cy))\" font-family=\"Menlo, monospace\" font-size=\"14\" fill=\"#8a8f98\" text-anchor=\"middle\">\(room.label)</text>\n"
        }

        // Walls.
        for wall in model.walls {
            body += "  <line class=\"wall\" x1=\"\(format(wall.startX * 100))\" y1=\"\(format(wall.startY * 100))\" x2=\"\(format(wall.endX * 100))\" y2=\"\(format(wall.endY * 100))\" stroke=\"#15171c\" stroke-width=\"\(format(wall.thickness * 100))\" stroke-linecap=\"round\"/>\n"
        }

        // Openings cut through their walls (door = white gap, window = thin line).
        for opening in model.openings {
            guard let wall = model.walls.first(where: { $0.id == opening.wallID }),
                  wall.lengthMeters > 0 else { continue }
            let dx = (wall.endX - wall.startX) / wall.lengthMeters
            let dy = (wall.endY - wall.startY) / wall.lengthMeters
            let x1 = wall.startX + dx * opening.offset
            let y1 = wall.startY + dy * opening.offset
            let x2 = wall.startX + dx * (opening.offset + opening.width)
            let y2 = wall.startY + dy * (opening.offset + opening.width)
            let stroke = opening.kind == .window ? "#9aa3ad" : "#ffffff"
            let strokeWidth = opening.kind == .window
                ? format(wall.thickness * 50)
                : format(wall.thickness * 110)
            body += "  <line class=\"opening\" x1=\"\(format(x1 * 100))\" y1=\"\(format(y1 * 100))\" x2=\"\(format(x2 * 100))\" y2=\"\(format(y2 * 100))\" stroke=\"\(stroke)\" stroke-width=\"\(strokeWidth)\"/>\n"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" width="\(width)" height="\(height)">
          <desc>TapeScan floor plan · 1 unit = 1 cm</desc>
        \(body)</svg>
        """
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
