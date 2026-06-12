// DXFExporter.swift — AutoCAD R12 ASCII export (M6).
//
// The competitive parity format: what contractors open in AutoCAD/ArchiCAD.
// R12 ASCII needs no libraries — LINE entities for walls/openings, closed
// POLYLINEs for room polygons, TEXT for labels, on named layers. Units are
// MILLIMETERS; the y axis flips (CAD y-up vs plan y-down).

import Foundation

public enum DXFExporter {

    public static func dxf(for model: FloorPlanModel) -> String {
        var out = ""

        func group(_ code: Int, _ value: String) {
            out += "\(code)\n\(value)\n"
        }

        // Plan y-down → CAD y-up, meters → mm.
        func x(_ v: Double) -> String { String(format: "%.1f", v * 1000) }
        func y(_ v: Double) -> String { String(format: "%.1f", (model.heightMeters - v) * 1000) }

        // HEADER
        group(0, "SECTION"); group(2, "HEADER")
        group(9, "$INSUNITS"); group(70, "4")   // millimeters
        group(0, "ENDSEC")

        // TABLES → layers
        group(0, "SECTION"); group(2, "TABLES")
        group(0, "TABLE"); group(2, "LAYER"); group(70, "4")
        for (name, color) in [("WALLS", 7), ("OPENINGS", 1), ("ROOMS", 8), ("LABELS", 3)] {
            group(0, "LAYER"); group(2, name)
            group(70, "0"); group(62, "\(color)"); group(6, "CONTINUOUS")
        }
        group(0, "ENDTAB")
        group(0, "ENDSEC")

        // ENTITIES
        group(0, "SECTION"); group(2, "ENTITIES")

        for wall in model.walls {
            group(0, "LINE"); group(8, "WALLS")
            group(10, x(wall.startX)); group(20, y(wall.startY)); group(30, "0.0")
            group(11, x(wall.endX)); group(21, y(wall.endY)); group(31, "0.0")
        }

        for opening in model.openings {
            guard let wall = model.walls.first(where: { $0.id == opening.wallID }),
                  wall.lengthMeters > 0 else { continue }
            let dx = (wall.endX - wall.startX) / wall.lengthMeters
            let dy = (wall.endY - wall.startY) / wall.lengthMeters
            group(0, "LINE"); group(8, "OPENINGS")
            group(10, x(wall.startX + dx * opening.offset))
            group(20, y(wall.startY + dy * opening.offset)); group(30, "0.0")
            group(11, x(wall.startX + dx * (opening.offset + opening.width)))
            group(21, y(wall.startY + dy * (opening.offset + opening.width))); group(31, "0.0")
        }

        for room in model.rooms {
            let n = min(room.polygonX.count, room.polygonY.count)
            guard n >= 3 else { continue }
            group(0, "POLYLINE"); group(8, "ROOMS")
            group(66, "1"); group(70, "1")      // vertices follow; closed
            for i in 0..<n {
                group(0, "VERTEX"); group(8, "ROOMS")
                group(10, x(room.polygonX[i])); group(20, y(room.polygonY[i])); group(30, "0.0")
            }
            group(0, "SEQEND")

            let cx = room.polygonX.prefix(n).reduce(0, +) / Double(n)
            let cy = room.polygonY.prefix(n).reduce(0, +) / Double(n)
            group(0, "TEXT"); group(8, "LABELS")
            group(10, x(cx)); group(20, y(cy)); group(30, "0.0")
            group(40, "150.0")                  // 150 mm text height
            group(1, room.label)
        }

        group(0, "ENDSEC")
        group(0, "EOF")
        return out
    }
}
