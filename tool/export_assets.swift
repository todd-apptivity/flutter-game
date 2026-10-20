// Export generated artwork to Flame's exact horizontal-strip dimensions.
// Usage: swift tool/export_assets.swift manifest.json destination-directory
// Uses nearest-neighbor sampling and preserves the original alpha channel.
import Foundation
import AppKit

struct Asset: Decodable {
    let name: String
    let size: Int
    let frames: Int
    let source: String
}

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("Expected manifest and destination") }
let assets = try JSONDecoder().decode([Asset].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let destination = URL(fileURLWithPath: args[2], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

for asset in assets {
    guard let input = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: asset.source))) else { fatalError(asset.source) }
    precondition(input.bitsPerSample == 8 && input.samplesPerPixel == 4 && !input.bitmapFormat.contains(.alphaFirst), "Expected 8-bit RGBA source")
    var pixel = [Int](repeating: 0, count: 4)
    let width = input.pixelsWide, height = input.pixelsHigh
    let cell = width / asset.frames
    var x0 = cell, y0 = height, x1 = 0, y1 = 0
    for y in 0..<height {
        for x in 0..<width {
            input.getPixel(&pixel, atX: x, y: y)
            if pixel[3] > 127 {
                x0 = min(x0, x % cell); x1 = max(x1, x % cell)
                y0 = min(y0, y); y1 = max(y1, y)
            }
        }
    }
    let tile = asset.name == "floor_tile"
    let padding = asset.size <= 12 ? 1 : 2
    let side = tile ? Double(width) : Double(max(x1 - x0 + 1, y1 - y0 + 1)) * Double(asset.size) / Double(asset.size - padding * 2)
    let centerX = tile ? Double(width) / 2 : Double(x0 + x1 + 1) / 2
    let centerY = tile ? Double(height) / 2 : Double(y0 + y1 + 1) / 2
    let output = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: asset.size * asset.frames, pixelsHigh: asset.size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bitmapFormat: .alphaNonpremultiplied, bytesPerRow: 0, bitsPerPixel: 0)!
    var clear = 0, visible = 0
    for frame in 0..<asset.frames {
        for y in 0..<asset.size {
            for x in 0..<asset.size {
                let sx = Int(floor(centerX + (Double(x) + 0.5 - Double(asset.size) / 2) * side / Double(asset.size)))
                let sy = Int(floor(centerY + (Double(y) + 0.5 - Double(asset.size) / 2) * side / Double(asset.size)))
                pixel = [0, 0, 0, 0]
                if sx >= 0 && sx < cell && sy >= 0 && sy < height {
                    input.getPixel(&pixel, atX: sx + frame * cell, y: sy)
                    if !input.bitmapFormat.contains(.alphaNonpremultiplied) && pixel[3] > 0 {
                        for channel in 0..<3 { pixel[channel] = min(255, pixel[channel] * 255 / pixel[3]) }
                    }
                }
                output.setPixel(&pixel, atX: x + frame * asset.size, y: y)
                if pixel[3] == 0 { clear += 1 } else { visible += 1 }
            }
        }
    }
    guard clear > 0 && visible > 0 else { fatalError("Missing transparency or artwork: \(asset.name)") }
    let url = destination.appendingPathComponent(asset.name + ".png")
    try output.representation(using: .png, properties: [:])!.write(to: url)
    print("\(asset.name): \(output.pixelsWide)x\(output.pixelsHigh), \(asset.frames) frames, \(clear) clear / \(visible) visible pixels")
}
