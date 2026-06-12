// PDFExporter.swift — dimensioned A4 plan document (M6).
//
// Landscape A4: title block, the scaled plan with walls/openings, and the
// auto-quantities panel (the renovation math, printed — benchmark parity).

import UIKit

public enum PDFExporter {

    @MainActor
    public static func pdf(for model: FloorPlanModel, name: String, unit: MeasureUnit) -> Data {
        let page = CGRect(x: 0, y: 0, width: 842, height: 595)   // A4 landscape (pt)
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        return renderer.pdfData { context in
            context.beginPage()

            // Title block.
            let title = "\(name) — Floor Plan"
            title.draw(at: CGPoint(x: 40, y: 32), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.black,
            ])
            let subtitle = "Scanned \(model.capturedAt.formatted(date: .abbreviated, time: .omitted)) · Made with TapeScan"
            subtitle.draw(at: CGPoint(x: 40, y: 60), withAttributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray,
            ])

            // Plan area (left ~70%): fit + center.
            let planRect = CGRect(x: 40, y: 96, width: 540, height: 450)
            drawPlan(model, in: planRect, context: context.cgContext, unit: unit)

            // Quantities panel (right).
            let q = model.quantities
            let rows: [(String, String)] = [
                ("Floor area", UnitFormat.area(q.floorAreaSquareMeters, unit)),
                ("Perimeter", UnitFormat.lengthFractional(q.perimeterMeters, unit: unit)),
                ("Wall area (net)", UnitFormat.area(q.wallAreaSquareMeters, unit)),
                ("Volume", UnitFormat.volume(q.volumeCubicMeters, unit)),
                ("Wall height", UnitFormat.lengthFractional(model.wallHeightMeters, unit: unit)),
                ("Plan size", "\(UnitFormat.lengthFractional(model.widthMeters, unit: unit)) × \(UnitFormat.lengthFractional(model.heightMeters, unit: unit))"),
            ]
            "QUANTITIES".draw(at: CGPoint(x: 620, y: 100), withAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: UIColor.gray,
            ])
            for (index, row) in rows.enumerated() {
                let y = 124 + CGFloat(index) * 34
                row.0.draw(at: CGPoint(x: 620, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.darkGray,
                ])
                row.1.draw(at: CGPoint(x: 620, y: y + 12), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: UIColor.black,
                ])
            }
        }
    }

    @MainActor
    private static func drawPlan(_ model: FloorPlanModel, in rect: CGRect,
                                 context: CGContext, unit: MeasureUnit) {
        guard model.widthMeters > 0, model.heightMeters > 0 else { return }
        let scale = min(rect.width / model.widthMeters, rect.height / model.heightMeters)
        let ox = rect.minX + (rect.width - model.widthMeters * scale) / 2
        let oy = rect.minY + (rect.height - model.heightMeters * scale) / 2
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }

        // Room fills + labels.
        for room in model.rooms {
            let n = min(room.polygonX.count, room.polygonY.count)
            guard n >= 3 else { continue }
            context.saveGState()
            context.beginPath()
            context.move(to: point(room.polygonX[0], room.polygonY[0]))
            for i in 1..<n { context.addLine(to: point(room.polygonX[i], room.polygonY[i])) }
            context.closePath()
            context.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor)
            context.fillPath()
            context.restoreGState()

            let cx = room.polygonX.prefix(n).reduce(0, +) / Double(n)
            let cy = room.polygonY.prefix(n).reduce(0, +) / Double(n)
            let label = "\(room.label)  ·  \(UnitFormat.area(room.polygonAreaSquareMeters, unit))"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.gray,
            ]
            let size = label.size(withAttributes: attributes)
            label.draw(at: CGPoint(x: point(cx, cy).x - size.width / 2,
                                   y: point(cx, cy).y - size.height / 2),
                       withAttributes: attributes)
        }

        // Walls.
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineCap(.round)
        for wall in model.walls {
            context.setLineWidth(max(2, wall.thickness * scale))
            context.beginPath()
            context.move(to: point(wall.startX, wall.startY))
            context.addLine(to: point(wall.endX, wall.endY))
            context.strokePath()
        }

        // Openings: white gaps (door) / thin gray (window).
        for opening in model.openings {
            guard let wall = model.walls.first(where: { $0.id == opening.wallID }),
                  wall.lengthMeters > 0 else { continue }
            let dx = (wall.endX - wall.startX) / wall.lengthMeters
            let dy = (wall.endY - wall.startY) / wall.lengthMeters
            let from = point(wall.startX + dx * opening.offset,
                             wall.startY + dy * opening.offset)
            let to = point(wall.startX + dx * (opening.offset + opening.width),
                           wall.startY + dy * (opening.offset + opening.width))
            context.setStrokeColor(opening.kind == .window
                                   ? UIColor.gray.cgColor
                                   : UIColor.white.cgColor)
            context.setLineWidth(opening.kind == .window
                                 ? max(1, wall.thickness * scale * 0.5)
                                 : max(3, wall.thickness * scale * 1.2))
            context.beginPath()
            context.move(to: from)
            context.addLine(to: to)
            context.strokePath()
        }
    }
}
