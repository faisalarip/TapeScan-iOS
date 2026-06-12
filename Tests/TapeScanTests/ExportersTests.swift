// ExportersTests.swift — file-format generation contracts (M6).
//
// Every text format is pinned against FloorPlanModel.sample (6 walls, door +
// window, 3 rooms, 5.2 m × 4.4 m). Binary formats (PDF/PNG) are smoke-tested
// for valid headers; glTF is structurally validated (JSON keys, accessor
// counts, buffer arithmetic) since geometry correctness flows from the
// already-tested FloorPlanModel.

import XCTest
@testable import TapeScan

final class ExportersTests: XCTestCase {

    // MARK: - SVG

    func testSVGStructure() {
        let svg = SVGExporter.svg(for: .sample)
        XCTAssertTrue(svg.hasPrefix("<?xml"))
        XCTAssertTrue(svg.contains("<svg"))
        // viewBox is centimeters: 5.2 m × 4.4 m → 520 × 440.
        XCTAssertTrue(svg.contains("viewBox=\"0 0 520 440\""), "got: \(svg.prefix(300))")
        // One line per wall on the walls layer.
        XCTAssertEqual(svg.components(separatedBy: "class=\"wall\"").count - 1, 6)
        // Openings drawn: 1 door + 1 window.
        XCTAssertEqual(svg.components(separatedBy: "class=\"opening\"").count - 1, 2)
        // Room labels present.
        XCTAssertTrue(svg.contains("LIVING"))
        XCTAssertTrue(svg.contains("</svg>"))
    }

    // MARK: - DXF (R12 ASCII)

    func testDXFStructure() {
        let dxf = DXFExporter.dxf(for: .sample)
        XCTAssertTrue(dxf.hasPrefix("0\nSECTION"))
        XCTAssertTrue(dxf.contains("ENTITIES"))
        XCTAssertTrue(dxf.hasSuffix("EOF\n"))
        // LINE entities: 6 walls + 2 openings.
        XCTAssertEqual(dxf.components(separatedBy: "\nLINE\n").count - 1, 8)
        // Closed POLYLINE per room polygon.
        XCTAssertEqual(dxf.components(separatedBy: "\nPOLYLINE\n").count - 1, 3)
        // Layers named.
        XCTAssertTrue(dxf.contains("WALLS"))
        XCTAssertTrue(dxf.contains("OPENINGS"))
        XCTAssertTrue(dxf.contains("ROOMS"))
        // Millimeter coordinates: the 5.2 m extent appears as 5200.
        XCTAssertTrue(dxf.contains("5200"))
        // Room labels exported as TEXT.
        XCTAssertTrue(dxf.contains("LIVING"))
    }

    // MARK: - CSV

    func testCSVRowsAndQuantities() {
        let csv = CSVExporter.csv(for: .sample, name: "Room 1")
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.first, "TapeScan Export,Room 1")
        XCTAssertTrue(lines.contains("Section,Item,Value,Unit"))
        // 3 room rows + 6 wall rows + 4 quantity rows.
        XCTAssertEqual(lines.filter { $0.hasPrefix("Room,") }.count, 3)
        XCTAssertEqual(lines.filter { $0.hasPrefix("Wall,") }.count, 6)
        XCTAssertEqual(lines.filter { $0.hasPrefix("Quantity,") }.count, 4)
        XCTAssertTrue(csv.contains("Quantity,Floor area,"))
        XCTAssertTrue(csv.contains(",m²"))
    }

    // MARK: - glTF 2.0

    func testGLTFStructuralValidity() throws {
        let data = GLTFExporter.gltf(for: .sample)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any])

        let asset = try XCTUnwrap(json["asset"] as? [String: Any])
        XCTAssertEqual(asset["version"] as? String, "2.0")
        XCTAssertNotNil(json["scenes"]); XCTAssertNotNil(json["nodes"])
        XCTAssertNotNil(json["meshes"])

        let accessors = try XCTUnwrap(json["accessors"] as? [[String: Any]])
        XCTAssertEqual(accessors.count, 2)
        // 6 walls × 8 box corners; 6 walls × 36 indices.
        XCTAssertEqual(accessors[0]["count"] as? Int, 48)
        XCTAssertEqual(accessors[0]["type"] as? String, "VEC3")
        XCTAssertEqual(accessors[1]["count"] as? Int, 216)
        XCTAssertEqual(accessors[1]["type"] as? String, "SCALAR")

        // Buffer arithmetic: positions 48×12 B + indices 216×2 B (4-byte aligned).
        let buffers = try XCTUnwrap(json["buffers"] as? [[String: Any]])
        let byteLength = try XCTUnwrap(buffers[0]["byteLength"] as? Int)
        XCTAssertEqual(byteLength, 48 * 12 + 216 * 2)
        let uri = try XCTUnwrap(buffers[0]["uri"] as? String)
        XCTAssertTrue(uri.hasPrefix("data:application/octet-stream;base64,"))
        let base64 = String(uri.dropFirst("data:application/octet-stream;base64,".count))
        XCTAssertEqual(Data(base64Encoded: base64)?.count, byteLength)
    }

    // MARK: - PDF / PNG smoke

    @MainActor
    func testPDFHasValidHeader() {
        let data = PDFExporter.pdf(for: .sample, name: "Room 1", unit: .metric)
        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertTrue(data.prefix(5).elementsEqual("%PDF-".utf8))
    }

    @MainActor
    func testPNGRendersNonEmpty() throws {
        let data = try XCTUnwrap(PNGExporter.png(for: .sample, unit: .metric))
        XCTAssertGreaterThan(data.count, 1_000)
        // PNG signature.
        XCTAssertTrue(data.prefix(8).elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    // MARK: - ExportService routing

    @MainActor
    func testExportServiceWritesTextFormatsToTempFiles() throws {
        let service = ExportService()
        defer { service.cleanup() }
        for format in [ExportFormat.svg, .dxf, .csv, .gltf] {
            let url = try service.export(plan: .sample, name: "Room 1",
                                         usdzFilename: nil, format: format)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(url.pathExtension, format.fileExtension)
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            XCTAssertGreaterThan(attrs[.size] as? Int ?? 0, 100)
        }
    }

    @MainActor
    func testExportServiceUSDZWithoutCaptureThrows() {
        let service = ExportService()
        defer { service.cleanup() }
        XCTAssertThrowsError(try service.export(plan: .sample, name: "Room 1",
                                                usdzFilename: nil, format: .usdz))
    }
}
