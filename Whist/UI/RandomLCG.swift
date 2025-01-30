//
//  RandomLCG.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-23.
//


import SwiftUI
import Foundation
import AppKit

// MARK: - Replicate the Random() logic as RandomLCG
struct RandomLCG {
    let m = 2147483647   // 2^31 - 1
    let a = 16807        // 7^5
    let q = 127773       // m / a
    let r = 2836         // m % a
    
    // Current seed
    var seed: Int = 1
    
    mutating func setSeed(_ newSeed: Int) {
        var s = newSeed
        if s <= 0 {
            s = -(s % (m - 1)) + 1
        }
        if s > m - 1 {
            s = m - 1
        }
        seed = s
    }
    
    /// Returns a random Double in [0,1).
    mutating func next() -> Double {
        let res = a * (seed % q) - r * (seed / q)
        seed = (res > 0) ? res : res + m
        return Double(seed) / Double(m)
    }
}

struct PerlinSampler2D {
    let width: Int
    let height: Int
    let period: Int // Period for tiling
    
    // Each cell has (gx, gy) gradient => 2 floats
    var gradients: [CGFloat]
    
    init(width: Int, height: Int, period: Int, randSeed: Int) {
        self.width = width
        self.height = height
        self.period = period
        self.gradients = .init(repeating: 0, count: width * height * 2)
        
        // Initialize gradients with random directions
        var rand = RandomLCG(seed: randSeed)
        for i in stride(from: 0, to: gradients.count, by: 2) {
            let angle = rand.next() * (.pi * 2)
            let x = sin(angle)
            let y = cos(angle)
            gradients[i] = CGFloat(x)
            gradients[i + 1] = CGFloat(y)
        }
    }
    
    /// Dot-product with the gradient at (cellX, cellY), accounting for tiling
    func dot(cellX: Int, cellY: Int, vx: CGFloat, vy: CGFloat) -> CGFloat {
        // Wrap around using modulo with period
        let wrappedX = (cellX % period + period) % period
        let wrappedY = (cellY % period + period) % period
        let idx = (wrappedX + wrappedY * width) * 2 % gradients.count
        
        // Ensure idx is within bounds of the gradients array
        guard idx >= 0 && idx + 1 < gradients.count else {
            return 0 // Return a safe default value
        }
        
        let gx = gradients[idx]
        let gy = gradients[idx + 1]
        return gx * vx + gy * vy
    }
    
    /// Smoothstep (s-curve)
    func sCurve(_ t: CGFloat) -> CGFloat {
        // Equivalent to 6t^5 - 15t^4 + 10t^3
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
    
    /// Linear interpolation
    func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + t * (b - a)
    }
    
    /// Sample Perlin value in [-1, 1] at coordinate (x, y), with tiling
    func getValue(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
        // Integer cells
        let xCell = Int(floor(x)) % period
        let yCell = Int(floor(y)) % period
        
        // Fractional part
        let xFrac = x - floor(x)
        let yFrac = y - floor(y)
        
        // Dot products at the 4 corners
        let v00 = dot(cellX: xCell, cellY: yCell, vx: xFrac, vy: yFrac)
        let v10 = dot(cellX: xCell + 1, cellY: yCell, vx: xFrac - 1, vy: yFrac)
        let v01 = dot(cellX: xCell, cellY: yCell + 1, vx: xFrac, vy: yFrac - 1)
        let v11 = dot(cellX: xCell + 1, cellY: yCell + 1, vx: xFrac - 1, vy: yFrac - 1)
        
        // Interpolate horizontally
        let tx = sCurve(xFrac)
        let vx0 = lerp(v00, v10, tx)
        let vx1 = lerp(v01, v11, tx)
        
        // Interpolate vertically
        let ty = sCurve(yFrac)
        let val = lerp(vx0, vx1, ty)
        
        return val
    }
}

// MARK: - SwiftUI view that generates & draws Perlin noise
struct PerlinNoiseOverlay: View {
    /// Width and height used for sampling. You can tweak these
    /// or match them to the displayed size for 1:1 pixel coverage.
    var noiseWidth: Int = 256
    var noiseHeight: Int = 256
    
    /// “Period” controls the frequency of the noise (bigger => smaller features).
    var period: Int = 64
    
    /// The random seed for reproducible noise.
    var randSeed: Int = 1
    
    /// Whether to draw each noise pixel at 1×1 point, or use a bigger tile.
    /// For large screens, using tileSize > 1 is faster (fewer fills).
    var tileSize: Int = 1
    
    /// Base color for the felt fabric
    var baseColor: Color = Color(red: 34/255, green: 139/255, blue: 34/255)
    
    var method: Int
    var level: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // 1) Create sampler sized to "ceil(width/period), ceil(height/period)"

            let samplerWidth = Int(noiseWidth / period)
            let samplerHeight = Int(noiseHeight / period)
            
            let sampler = PerlinSampler2D(
                width: max(1, samplerWidth),
                height: max(1, samplerHeight),
                period: period,
                randSeed: randSeed
            )
            
            // 2) Draw the noise
            //    We’ll iterate over the target `noiseWidth` × `noiseHeight`,
            //    sample the Perlin value, convert to grayscale, and fill a rect.
            for y in stride(from: 0, to: noiseHeight, by: tileSize) {
                for x in stride(from: 0, to: noiseWidth, by: tileSize) {
                    // scaled sample coordinates
                    var val = sampler.getValue(
                        CGFloat(x) / CGFloat(period),
                        CGFloat(y) / CGFloat(period)
                    )
                    
                    //                    let normalized = max(0, min(1, (val + 1) / 2))
                    if method == 1 { val = compressValueExp(val, exponent: level) }
                    if method == 2 { val = compressValueLinear(val, factor: level) }
                    if method == 3 { val = compressValueTanh(val, factor: level) }
                    let normalized = val / 2 + 1
                    
                    
                    // Multiply each channel by the normalized factor
                    let color = baseColor
                        .opacity(1.0)
                        .withRGBMultiplication(normalized)
                    
                    // Fill tileSize × tileSize rectangle at (x, y)
                    let rect = CGRect(
                        x: CGFloat(x),
                        y: CGFloat(y),
                        width: CGFloat(tileSize),
                        height: CGFloat(tileSize)
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: CGFloat(noiseWidth), height: CGFloat(noiseHeight))
        // You can remove the .frame(...) if you want the view to dynamically resize.
    }
    
    func compressValueExp(_ value: CGFloat, exponent: CGFloat) -> CGFloat {
        let sign: CGFloat = value < 0 ? -1 : 1
        return sign * pow(abs(value), exponent)
    }
    func compressValueLinear(_ value: CGFloat, factor: CGFloat) -> CGFloat {
        return value * factor
    }
    func compressValueTanh(_ value: CGFloat, factor: CGFloat) -> CGFloat {
        return tanh(value * factor)
    }
}


struct TilingPerlinView: View {
    var color: Color
    var noiseWidth: Int
    var noiseHeight: Int
    var period: Int
    var randSeed: Int
    var tileSize: Int
    var method: Int
    var level: CGFloat
    var scale: CGFloat
    
    @State private var renderedImage: Image? // Holds the rendered image
    
    var body: some View {
        let perlinView = PerlinNoiseOverlay(
            noiseWidth: noiseWidth,
            noiseHeight: noiseHeight,
            period: period,
            randSeed: randSeed,
            tileSize: tileSize,
            baseColor: color,
            method: method,
            level: level
        )
        
        // Render the PerlinNoiseOverlay into a CGImage
        if let renderedImage = TilingPerlinView.renderContentToCGImage(perlinView: perlinView) {
            return AnyView(
                Image(decorative: renderedImage, scale: scale, orientation: .up)
                    .resizable(resizingMode: .tile)
//                    .frame(width: 1024, height: 1024)
            )
        } else {
            return AnyView(Text("Failed to render image"))
        }
    }
    
    static func renderContentToCGImage(perlinView: PerlinNoiseOverlay) -> CGImage? {
        let renderer = ImageRenderer(content: perlinView.frame(width: 4096, height: 4096))
        return renderer.cgImage
    }
}

struct PerlinNoiseOverlay_Previews: PreviewProvider {
    
    static var previews: some View {
        
        let color = Color(red: 0, green: 128/255, blue: 128/255)
        let noiseWidth = 4096
        let noiseHeight = 4096
        let period = 128
        let randSeed = Int.random(in: 1...10000)
        let tileSize = 64
        let method = 0
        let level: CGFloat = 1
        let scale: CGFloat = 64
        
        let parameters = """
        Noise Width: \(noiseWidth)
        Noise Height: \(noiseHeight)
        Period: \(period)
        Random Seed: \(randSeed)
        Tile Size: \(tileSize)
        Method: \(method)
        Level: \(level)
        Scale: \(scale)
        """
        
        let tilingView = TilingPerlinView(
            color: color,
            noiseWidth: noiseWidth,
            noiseHeight: noiseHeight,
            period: period,
            randSeed: randSeed,
            tileSize: tileSize,
            method: method,
            level: level,
            scale: scale
        )
        
        return ZStack(alignment: .topLeading) {
            tilingView
                .frame(width: 1024, height: 1024) // Adjust frame size for preview
                .border(Color.gray, width: 1) // Optional border for visualization
            
            VStack {
                Text(parameters)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
                
                Spacer()
                
                
                // Save Button
                Button("Save as Image") {
                    // Call the snapshot() extension on TilingPerlinView
                    guard let nsImage = tilingView.snapshot() else {
                        logWithTimestamp("Snapshot failed")
                        return
                    }
                    
                    // Convert NSImage -> CGImage
                    guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        logWithTimestamp("Failed to create CGImage")
                        return
                    }
                    
                    // Convert CGImage -> NSBitmapImageRep -> Data
                    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                    guard let data = bitmapRep.representation(using: .png, properties: [:]) else {
                        logWithTimestamp("Failed to create PNG data")
                        return
                    }
                    
                    let fileURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("\(method)_\(level) - \(period) - \(tileSize) - \(scale).png")
                    
                    do {
                        try data.write(to: fileURL)
                        logWithTimestamp("Image saved to \(fileURL.path)")
                    } catch {
                        logWithTimestamp("Failed to save image: \(error)")
                    }
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.leading)
                
                Spacer()
            }
        }
    }
}

