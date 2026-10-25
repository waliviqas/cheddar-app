// Builds the Create ML training folder from the hand-labeled frames.
// For every labeled frame it writes the original plus color copies where only the pucks are recolored,
// so the detector learns a puck's shape instead of its color.
//
// With a crop size, it writes zoomed-in squares around each puck instead of whole frames, because the detector
// shrinks every picture to about 300px and a puck in a full 1920px frame would shrink to a speck.
//
// Run: swift make-training-set.swift <frames folder> <labels-raw.json> <output folder> [copies per frame] [crop size]

import AppKit
import CoreGraphics
import Foundation

struct Box: Codable { let x: Double; let y: Double; let width: Double; let height: Double }
struct Annotation: Codable { let label: String; let coordinates: Box }
struct Entry: Codable { let image: String; let annotations: [Annotation] }

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: swift make-training-set.swift <frames folder> <labels-raw.json> <output folder> [copies per frame] [crop size]")
    exit(1)
}
let framesDir = URL(fileURLWithPath: args[1])
let labelsURL = URL(fileURLWithPath: args[2])
let outDir = URL(fileURLWithPath: args[3])
let copies = args.count > 4 ? Int(args[4]) ?? 3 : 3
let cropSize = args.count > 5 ? Int(args[5]) ?? 0 : 0
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: labelsURL)).filter { !$0.annotations.isEmpty }
var generator = SystemRandomNumberGenerator()
var output: [Entry] = []

// A vivid random color, from fairly dark to fairly light.
func randomColor() -> (Double, Double, Double) {
    let hue = Double.random(in: 0..<1, using: &generator)
    let brightness = Double.random(in: 0.45...1, using: &generator)
    let c = NSColor(hue: hue, saturation: Double.random(in: 0.6...1, using: &generator), brightness: brightness, alpha: 1)
        .usingColorSpace(.deviceRGB)!
    return (c.redComponent, c.greenComponent, c.blueComponent)
}

// Saves one picture with its boxes: the whole frame, or with a crop size, one zoomed-in square per puck,
// placed at a random spot around it. Any other puck mostly inside a square keeps its box too.
func save(_ image: CGImage, as name: String, annotations: [Annotation]) throws {
    guard cropSize > 0 else {
        guard let jpeg = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { return }
        try jpeg.write(to: outDir.appendingPathComponent(name))
        output.append(Entry(image: name, annotations: annotations))
        return
    }
    let size = Double(cropSize), w = Double(image.width), h = Double(image.height)
    for (k, annotation) in annotations.enumerated() {
        let b = annotation.coordinates
        let lowX = max(0, b.x + b.width / 2 + 10 - size), highX = min(w - size, b.x - b.width / 2 - 10)
        let lowY = max(0, b.y + b.height / 2 + 10 - size), highY = min(h - size, b.y - b.height / 2 - 10)
        let left = (lowX <= highX ? Double.random(in: lowX...highX, using: &generator) : max(0, min(w - size, b.x - size / 2))).rounded()
        let top = (lowY <= highY ? Double.random(in: lowY...highY, using: &generator) : max(0, min(h - size, b.y - size / 2))).rounded()
        let square = CGRect(x: left, y: top, width: size, height: size)
        guard let crop = image.cropping(to: square),
              let jpeg = NSBitmapImageRep(cgImage: crop).representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { continue }

        var kept: [Annotation] = []
        for other in annotations {
            let o = other.coordinates
            let rect = CGRect(x: o.x - o.width / 2, y: o.y - o.height / 2, width: o.width, height: o.height)
            let inside = rect.intersection(square)
            guard !inside.isNull, inside.width * inside.height >= 0.6 * rect.width * rect.height else { continue }
            kept.append(Annotation(label: other.label, coordinates: Box(
                x: inside.midX - left, y: inside.midY - top, width: inside.width, height: inside.height)))
        }
        let cropName = name.replacingOccurrences(of: ".jpg", with: "-crop\(k + 1).jpg")
        try jpeg.write(to: outDir.appendingPathComponent(cropName))
        output.append(Entry(image: cropName, annotations: kept))
    }
}

for entry in entries {
    let source = framesDir.appendingPathComponent(entry.image)
    guard let image = NSImage(contentsOf: source)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("skipped, could not read:", entry.image); continue
    }
    let width = image.width, height = image.height

    try save(image, as: entry.image, annotations: entry.annotations)

    for copy in 1...copies {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { continue }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)

        for annotation in entry.annotations {
            let b = annotation.coordinates
            let (tr, tg, tb) = randomColor()
            let minX = max(0, Int(b.x - b.width / 2)), maxX = min(width - 1, Int(b.x + b.width / 2))
            let minY = max(0, Int(b.y - b.height / 2)), maxY = min(height - 1, Int(b.y + b.height / 2))

            var floorColors: [(Double, Double, Double)] = []
            for y in minY...maxY {
                for x in minX...maxX where x == minX || x == maxX || y == minY || y == maxY {
                    let i = (y * width + x) * 4
                    floorColors.append((Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])))
                }
            }

            for y in minY...maxY {
                for x in minX...maxX {
                    let i = (y * width + x) * 4
                    let r = Double(pixels[i]), g = Double(pixels[i + 1]), bl = Double(pixels[i + 2])
                    var nearest = Double.infinity
                    for f in floorColors {
                        let dr: Double = r - f.0, dg: Double = g - f.1, db: Double = bl - f.2
                        nearest = min(nearest, dr * dr + dg * dg + db * db)
                    }
                    let fromFloor = nearest.squareRoot()
                    let puckness = min(1, max(0, (fromFloor - 25) / 50))
                    guard puckness > 0 else { continue }
                    let light = 0.35 + 0.65 * (0.299 * r + 0.587 * g + 0.114 * bl) / 255
                    let nr = tr * 255 * light, ng = tg * 255 * light, nb = tb * 255 * light
                    pixels[i] = UInt8(max(0, min(255, r + (nr - r) * puckness)))
                    pixels[i + 1] = UInt8(max(0, min(255, g + (ng - g) * puckness)))
                    pixels[i + 2] = UInt8(max(0, min(255, bl + (nb - bl) * puckness)))
                }
            }
        }

        guard let recolored = ctx.makeImage() else { continue }
        try save(recolored, as: entry.image.replacingOccurrences(of: ".jpg", with: "-color\(copy).jpg"), annotations: entry.annotations)
    }
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted]
try encoder.encode(output).write(to: outDir.appendingPathComponent("annotations.json"))
print("wrote \(output.count) pictures and annotations.json to \(outDir.path)")
