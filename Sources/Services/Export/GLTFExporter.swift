// GLTFExporter.swift — glTF 2.0 3D export from the parametric plan (M6).
//
// Polycam charges $149.99/yr for pro 3D formats; TapeScan ships glTF in the
// base product. Walls extrude to `wallHeightMeters` boxes in a single mesh:
// one .gltf JSON with the geometry buffer embedded base64 (no sidecar files,
// shares cleanly through the share sheet). glTF is y-up right-handed: plan
// (x, y) maps to world (x, up, z).

import Foundation

public enum GLTFExporter {

    public static func gltf(for model: FloorPlanModel) -> Data {
        var positions: [Float] = []
        var indices: [UInt16] = []

        let height = Float(model.wallHeightMeters)

        for wall in model.walls {
            let sx = Float(wall.startX), sz = Float(wall.startY)
            let ex = Float(wall.endX), ez = Float(wall.endY)
            let length = max(0.001, Float(wall.lengthMeters))
            // Unit perpendicular in the plan, scaled to half thickness.
            let px = -(ez - sz) / length * Float(wall.thickness / 2)
            let pz = (ex - sx) / length * Float(wall.thickness / 2)

            let base = UInt16(positions.count / 3)
            // 8 box corners: bottom ring then top ring.
            let corners: [(Float, Float, Float)] = [
                (sx - px, 0, sz - pz), (sx + px, 0, sz + pz),
                (ex + px, 0, ez + pz), (ex - px, 0, ez - pz),
                (sx - px, height, sz - pz), (sx + px, height, sz + pz),
                (ex + px, height, ez + pz), (ex - px, height, ez - pz),
            ]
            for (x, y, z) in corners { positions += [x, y, z] }

            // 12 triangles (bottom, top, 4 sides).
            let faces: [UInt16] = [
                0, 2, 1, 0, 3, 2,          // bottom
                4, 5, 6, 4, 6, 7,          // top
                0, 1, 5, 0, 5, 4,          // start cap
                1, 2, 6, 1, 6, 5,          // +perp side
                2, 3, 7, 2, 7, 6,          // end cap
                3, 0, 4, 3, 4, 7,          // −perp side
            ]
            indices += faces.map { base + $0 }
        }

        // Binary buffer: positions (float32) then indices (uint16).
        var buffer = Data()
        positions.withUnsafeBytes { buffer.append(contentsOf: $0) }
        indices.withUnsafeBytes { buffer.append(contentsOf: $0) }

        let vertexCount = positions.count / 3
        let positionsBytes = positions.count * 4
        let indicesBytes = indices.count * 2

        var minP = [Float.greatestFiniteMagnitude, .greatestFiniteMagnitude, .greatestFiniteMagnitude]
        var maxP = [-Float.greatestFiniteMagnitude, -.greatestFiniteMagnitude, -.greatestFiniteMagnitude]
        for i in stride(from: 0, to: positions.count, by: 3) {
            for axis in 0..<3 {
                minP[axis] = min(minP[axis], positions[i + axis])
                maxP[axis] = max(maxP[axis], positions[i + axis])
            }
        }
        if vertexCount == 0 { minP = [0, 0, 0]; maxP = [0, 0, 0] }

        let json: [String: Any] = [
            "asset": ["version": "2.0", "generator": "TapeScan"],
            "scene": 0,
            "scenes": [["nodes": [0]]],
            "nodes": [["mesh": 0, "name": "FloorPlanWalls"]],
            "meshes": [[
                "name": "Walls",
                "primitives": [[
                    "attributes": ["POSITION": 0],
                    "indices": 1,
                    "mode": 4,
                ]],
            ]],
            "accessors": [
                [
                    "bufferView": 0,
                    "componentType": 5126,        // FLOAT
                    "count": vertexCount,
                    "type": "VEC3",
                    "min": minP,
                    "max": maxP,
                ],
                [
                    "bufferView": 1,
                    "componentType": 5123,        // UNSIGNED_SHORT
                    "count": indices.count,
                    "type": "SCALAR",
                ],
            ],
            "bufferViews": [
                ["buffer": 0, "byteOffset": 0, "byteLength": positionsBytes, "target": 34962],
                ["buffer": 0, "byteOffset": positionsBytes, "byteLength": indicesBytes, "target": 34963],
            ],
            "buffers": [[
                "byteLength": buffer.count,
                "uri": "data:application/octet-stream;base64," + buffer.base64EncodedString(),
            ]],
        ]

        return (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
    }
}
