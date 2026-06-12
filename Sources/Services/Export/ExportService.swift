// ExportService.swift — generates shareable files from a saved room (M6).
//
// Each export writes into a per-session temp directory handed to the share
// sheet; `cleanup()` removes it when the export screen closes. The quota
// decision lives in ExportView — this service only produces files.

import Foundation
import UIKit

/// Everything TapeScan exports. The breadth IS the marketing: competitors
/// gate DXF/3D behind $120+/yr tiers.
public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case gltf, svg, png, pdf, dxf, csv, usdz

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gltf: return "glTF"
        case .svg:  return "SVG"
        case .png:  return "PNG"
        case .pdf:  return "PDF"
        case .dxf:  return "DXF"
        case .csv:  return "CSV"
        case .usdz: return "USDZ"
        }
    }

    public var detail: String {
        switch self {
        case .gltf: return "3D model"
        case .svg:  return "Vector plan"
        case .png:  return "Image"
        case .pdf:  return "Document"
        case .dxf:  return "AutoCAD"
        case .csv:  return "Spreadsheet"
        case .usdz: return "3D capture"
        }
    }

    public var icon: String {
        switch self {
        case .gltf: return "cube3d"
        case .svg:  return "ruler2"
        case .png:  return "grid"
        case .pdf:  return "download"
        case .dxf:  return "layers"
        case .csv:  return "ruler2"
        case .usdz: return "room"
        }
    }

    public var fileExtension: String { rawValue }
}

public enum ExportError: LocalizedError {
    /// The room has no stored 3D capture (e.g. synced from another device).
    case usdzUnavailable
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .usdzUnavailable:
            return "This room has no 3D capture on this device — rescan to export USDZ."
        case .generationFailed(let message):
            return message
        }
    }
}

@MainActor
public final class ExportService {

    private let directory: URL

    public init() {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TapeScanExports-\(UUID().uuidString)", isDirectory: true)
    }

    /// Generates one file and returns its temp URL, ready for the share sheet.
    public func export(plan: FloorPlanModel,
                       name: String,
                       usdzFilename: String?,
                       format: ExportFormat,
                       unit: MeasureUnit = .metric) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = directory.appendingPathComponent("\(safeName).\(format.fileExtension)")
        try? FileManager.default.removeItem(at: url)

        switch format {
        case .svg:
            try SVGExporter.svg(for: plan).write(to: url, atomically: true, encoding: .utf8)
        case .dxf:
            try DXFExporter.dxf(for: plan).write(to: url, atomically: true, encoding: .utf8)
        case .csv:
            try CSVExporter.csv(for: plan, name: name).write(to: url, atomically: true, encoding: .utf8)
        case .gltf:
            let data = GLTFExporter.gltf(for: plan)
            guard !data.isEmpty else { throw ExportError.generationFailed("glTF generation failed.") }
            try data.write(to: url)
        case .pdf:
            try PDFExporter.pdf(for: plan, name: name, unit: unit).write(to: url)
        case .png:
            guard let data = PNGExporter.png(for: plan, unit: unit) else {
                throw ExportError.generationFailed("PNG rendering failed.")
            }
            try data.write(to: url)
        case .usdz:
            guard let usdzFilename else { throw ExportError.usdzUnavailable }
            let source = RoomScanService.roomsDirectory.appendingPathComponent(usdzFilename)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw ExportError.usdzUnavailable
            }
            try FileManager.default.copyItem(at: source, to: url)
        }
        return url
    }

    /// Remove this session's temp exports (call when the export UI closes).
    public func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
