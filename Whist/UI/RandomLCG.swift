import SwiftUI
import Foundation

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

// MARK: - PerlinSampler2D replicates your Perlin gradient logic
struct PerlinSampler2D {
    let width: Int
    let height: Int
    
    // Each cell has (gx, gy) gradient => 2 floats
    var gradients: [CGFloat]
    
    init(width: Int, height: Int, randSeed: Int) {
        self.width = width
        self.height = height
        self.gradients = .init(repeating: 0, count: width * height * 2)
        
        // Initialize gradients with random directions
        var rand = RandomLCG(seed: randSeed)
        for i in stride(from: 0, to: gradients.count, by: 2) {
            let angle = rand.next() * (.pi * 2)
            let x = sin(angle)
            let y = cos(angle)
            gradients[i] = CGFloat(x)
            gradients[i+1] = CGFloat(y)
        }
    }
    
    /// Dot-product with the gradient at (cellX, cellY)
    func dot(cellX: Int, cellY: Int, vx: CGFloat, vy: CGFloat) -> CGFloat {
        let idx = (cellX + cellY * width) * 2
        let gx = gradients[idx]
        let gy = gradients[idx + 1]
        return gx * vx + gy * vy
    }
    
    /// Smoothstep (s-curve)
    func sCurve(_ t: CGFloat) -> CGFloat {
        // Equivalent to 3t^2 - 2t^3
        return t * t * (3 - 2 * t)
    }
    
    /// Linear interpolation
    func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + t * (b - a)
    }
    
    /// Sample Perlin value in [-1, 1] at coordinate (x, y)
    func getValue(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
        // integer cells
        let xCell = Int(floor(x))
        let yCell = Int(floor(y))
        
        // fractional part
        let xFrac = x - floor(x)
        let yFrac = y - floor(y)
        
        // wrap around edges
        let x1 = (xCell == width - 1)  ? 0 : (xCell + 1)
        let y1 = (yCell == height - 1) ? 0 : (yCell + 1)
        
        // Dot products at the 4 corners
        let v00 = dot(cellX: xCell, cellY: yCell, vx: xFrac,       vy: yFrac)
        let v10 = dot(cellX: x1,     cellY: yCell, vx: xFrac - 1,  vy: yFrac)
        let v01 = dot(cellX: xCell,  cellY: y1,    vx: xFrac,      vy: yFrac - 1)
        let v11 = dot(cellX: x1,     cellY: y1,    vx: xFrac - 1,  vy: yFrac - 1)
        
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
    var period: CGFloat = 64
    
    /// The random seed for reproducible noise.
    var randSeed: Int = 1
    
    /// Whether to draw each noise pixel at 1×1 point, or use a bigger tile.
    /// For large screens, using tileSize > 1 is faster (fewer fills).
    var tileSize: Int = 1
    
    var body: some View {
        Canvas { context, size in
            // 1) Create sampler sized to "ceil(width/period), ceil(height/period)"
            let samplerWidth = Int(ceil(CGFloat(noiseWidth) / period))
            let samplerHeight = Int(ceil(CGFloat(noiseHeight) / period))
            
            let sampler = PerlinSampler2D(
                width: max(1, samplerWidth),
                height: max(1, samplerHeight),
                randSeed: randSeed
            )
            
            // 2) Draw the noise
            //    We’ll iterate over the target `noiseWidth` × `noiseHeight`,
            //    sample the Perlin value, convert to grayscale, and fill a rect.
            for y in stride(from: 0, to: noiseHeight, by: tileSize) {
                for x in stride(from: 0, to: noiseWidth, by: tileSize) {
                    // scaled sample coordinates
                    let val = sampler.getValue(
                        CGFloat(x) / period,
                        CGFloat(y) / period
                    )
                    // Map [-1, 1] to [0,1]
                    let normalized = (val + 1) / 2
                    // Convert to 0...1 gray
                    let gray = max(0, min(1, normalized))
                    
                    // Convert gray to SwiftUI Color
                    let color = Color(
                        red: Double(gray),
                        green: Double(gray),
                        blue: Double(gray)
                    )
                    
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
}

struct PerlinNoiseOverlay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // A small Perlin patch
            PerlinNoiseOverlay(
                noiseWidth: 256,
                noiseHeight: 256,
                period: 32,
                randSeed: 1234,
                tileSize: 1
            )
            .border(Color.gray, width: 1)
            
            // A larger tile size => faster rendering, chunkier
            PerlinNoiseOverlay(
                noiseWidth: 256,
                noiseHeight: 256,
                period: 64,
                randSeed: 555,
                tileSize: 4
            )
            .border(Color.gray, width: 1)
        }
        .padding()
    }
}