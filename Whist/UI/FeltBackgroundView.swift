//
//  FeltBackgroundView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-04.
//

import SwiftUI
import simd

// MARK: - Advanced Felt View

//struct AdvancedFeltView: View {
struct FeltBackgroundView: View {
    /// The main base color for the felt.
    var baseColor: Color
    
    /// How strong the radial shading is (0 = none, 1 = quite dark edges).
    var radialShadingStrength: Double = 0.5
    
    /// How heavy the “wear & tear” looks (scratches, spots, etc.).
    var wearIntensity: Double = 0 //.25
    
    /// How visible the random motif pattern is (0 = off, 1 = full).
    var motifVisibility: Double = 0 //.2
    
    /// Scale for the motif shapes.
    var motifScale: CGFloat = 0.3
    
    /// Whether to show the random scratch overlay.
    var showScratches: Bool = false
    
    init(
        baseColor: Color? = nil,
        radialShadingStrength: Double = 0.5,
        wearIntensity: Double = 0,
        motifVisibility: Double = 0,
        motifScale: CGFloat = CGFloat.random(in: 0...1),
        showScratches: Bool = Bool.random()
    ) {
        // Set all parameters using provided values or defaults
        self.baseColor = baseColor ?? [
            Color(red: 34 / 255, green: 139 / 255, blue: 34 / 255), // Classic Green
            Color(red: 0 / 255, green: 0 / 255, blue: 139 / 255),   // Deep Blue
            Color(red: 139 / 255, green: 0 / 255, blue: 0 / 255),   // Wine Red
            Color(red: 75 / 255, green: 0 / 255, blue: 130 / 255),  // Royal Purple
            Color(red: 0 / 255, green: 128 / 255, blue: 128 / 255), // Teal
            Color(red: 54 / 255, green: 69 / 255, blue: 79 / 255),  // Charcoal Gray
            Color(red: 205 / 255, green: 92 / 255, blue: 0 / 255),  // Burnt Orange
            Color(red: 34 / 255, green: 90 / 255, blue: 34 / 255),  // Forest Green
            Color(red: 139 / 255, green: 69 / 255, blue: 19 / 255), // Chocolate Brown
            Color(red: 220 / 255, green: 20 / 255, blue: 60 / 255)  // Crimson Red
        ].randomElement() ?? Color(red: 34 / 255, green: 139 / 255, blue: 34 / 255) // Fallback to Classic Green
        
        self.radialShadingStrength = radialShadingStrength
        self.wearIntensity = wearIntensity
        self.motifVisibility = motifVisibility
        self.motifScale = motifScale
        self.showScratches = showScratches
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Base Perlin Noise – simulates a subtle cloth texture variation
                TilingPerlinView(
                    color: baseColor,
                    noiseWidth: 4096,
                    noiseHeight: 4096,
                    period: 128,
                    randSeed: 553,
                    tileSize: 16,
                    method: 3,
                    level: 0.5,
                    scale: 64
                    )
                .drawingGroup()
                
                // 2. Add normal “speck” noise to give fiber speckles
                NoiseSpecklesOverlay()
                    .blendMode(.overlay)
                
                // 3. Wear & Tear Overlays
                if wearIntensity > 0 {
//                    SpotsOverlay(intensity: wearIntensity, isLight: true)
//                        .blendMode(.colorDodge)
//                        .allowsHitTesting(false)
                    
//                    SpotsOverlay(intensity: wearIntensity, isLight: false)
//                        .blendMode(.darken)
//                        .allowsHitTesting(false)
                    
                    StainsOverlay(
                        beerStainProbability: wearIntensity,
                        beerStainCount: Int(ceil(5 * wearIntensity)),
                        wearSpotProbability: wearIntensity,
                        wearSpotCount: Int(ceil(10 * wearIntensity)),
                        intensity: wearIntensity
                    )
                    .blendMode(.overlay) // overlay
                    
//                    BrushedWearOverlay()
//                        .blendMode(.overlay)
                    
                    if showScratches {
                        ScratchesOverlay(intensity: wearIntensity)
                            .blendMode(.softLight)
                            .allowsHitTesting(false)
                    }
                }
                
                // 4. Optional motif/pattern
                if motifVisibility > 0 {
                    MotifPatternOverlay(scale: motifScale)
                        .opacity(motifVisibility)
                        .blendMode(.softLight)
                }
                
                // 5. Radial shading for depth
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(radialShadingStrength * 0.6)
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: min(geometry.size.width, geometry.size.height) / 1.5
                )
                .blendMode(.multiply)
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .black.opacity(radialShadingStrength * 0.3)
                    ]),
                    center: .init(x: 0.55, y: 0.5),
                    startRadius: 30,
                    endRadius: min(geometry.size.width, geometry.size.height) / 1.6
                )
                .blendMode(.multiply)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }
}


// MARK: - Noise Speckles Overlay

/// Adds small elliptical speckles of black/white noise, giving a fuzzy/fibrous impression.
struct NoiseSpecklesOverlay: View {
    var densityFactor: Double = 40 // bigger = fewer speckles
    
    var body: some View {
        Canvas { context, size in
            let particleCount = Int(size.width * size.height / densityFactor)
            for _ in 0..<particleCount {
                // Random positions
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                
                // Slight variation in speck size
                let w = Double.random(in: 0.5...3.0)
                let h = Double.random(in: 0.5...3.0)
                
                // Subtle speck opacity
                let opacity = Double.random(in: 0.05...0.15)
                
                // Mix of white or black noise
                let isWhiteNoise = Bool.random()
                let color = isWhiteNoise
                    ? Color.white.opacity(opacity)
                    : Color.black.opacity(opacity)
                
                // Draw a small ellipse
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                    with: .color(color)
                )
            }
        }
    }
}

// MARK: - Wear & Tear Overlays

struct ScratchesOverlay: View {
    var intensity: Double
    
    var body: some View {
        Canvas { context, size in
            // Number of scratch clusters depends on intensity
//            let scratchCount = Int(size.width * size.height * intensity / 15000)
            let scratchCount = Int(ceil(intensity * 5))
            for _ in 0..<scratchCount {
                let startX = Double.random(in: 0...size.width)
                let startY = Double.random(in: 0...size.height)
                let angle = Double.random(in: 0..<360).degreesToRadians
                let clusterWidth = max(2, min(100, randomGaussian(mean: 20, deviation: 15) * (0.5 + intensity / 2)))
                
                // Generate parallel scratches in a cluster
                for offset in stride(from: -clusterWidth / 2, through: clusterWidth / 2, by: Double.random(in: 1...3)) {
                    let length = max(10, min(1000, randomGaussian(mean: 50, deviation: 50) * (0.5 + intensity / 2)))
                    let thickness = Double.random(in: 0.5...2.0)
                    let lineOpacity = max(0.01, min(0.9, randomGaussian(mean: 0.2, deviation: 0.2) * (0.5 + intensity / 2)))
                    
                    let startOffsetX = startX + CGFloat(cos(angle + .pi / 2)) * offset
                    let startOffsetY = startY + CGFloat(sin(angle + .pi / 2)) * offset
                    let endOffsetX = startOffsetX + CGFloat(cos(angle)) * length
                    let endOffsetY = startOffsetY + CGFloat(sin(angle)) * length
                    
                    var scratchPath = Path()
                    scratchPath.move(to: CGPoint(x: startOffsetX, y: startOffsetY))
                    scratchPath.addLine(to: CGPoint(x: endOffsetX, y: endOffsetY))
                    
                    context.stroke(
                        scratchPath,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color.white.opacity(0.5 * lineOpacity), location: 0.0),
                                .init(color: Color.white.opacity(0.8 * lineOpacity), location: 0.5),
                                .init(color: Color.white.opacity(0.5 * lineOpacity), location: 1.0)
                            ]),
                            startPoint: CGPoint(x: startOffsetX, y: startOffsetY),
                            endPoint: CGPoint(x: endOffsetX, y: endOffsetY)
                        ),
                        lineWidth: thickness
                    )
                }
            }
        }
    }
}

struct SpotsOverlay: View {
    var intensity: Double
    var isLight: Bool
    
    var body: some View {
        Canvas { context, size in
            // For “dark” spots, we may want fewer/larger patches, for “light” maybe more/fewer, etc.
            let spotDivider: Double = isLight ? 35000 : 120000
            let spotCount = Int(size.width * size.height * intensity / spotDivider) * 10
            
            for _ in 0..<spotCount {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                let maxSize = max(10, min(200, randomGaussian(mean: 30, deviation: 50) * (0.5 + intensity / 2)))
                let opacity = max(0.05, min(0.15, randomGaussian(mean: 0.1, deviation: 0.02) * (0.5 + intensity / 2)))
                drawSpot(context: &context, size: size, centerX: x, centerY: y, maxSize: maxSize, opacity: opacity, depth: 0)
            }
        }
    }
    
    private let maxRecursionDepth = 1
    
    private func drawSpot(context: inout GraphicsContext,
                          size: CGSize,
                          centerX: Double,
                          centerY: Double,
                          maxSize: Double,
                          opacity: Double,
                          depth: Int)
    {
        // Generate shape
        let path = generateOrganicShape(centerX: centerX, centerY: centerY, maxSize: maxSize)
        let adjustedOpacity = max(0.01, min(1.0, opacity * pow(0.8, Double(depth))))
        
        context.drawLayer { layerContext in
            layerContext.fill(
                path,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: baseColor(isLight: isLight)
                            .opacity(opacity * 1.0), location: 0.0),
                        .init(color: baseColor(isLight: isLight)
                            .opacity(opacity * 0.4), location: 0.8),
                        .init(color: Color.clear, location: 1.0)
                    ]),
                    center: CGPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endRadius: maxSize / 2
                )
            )
        }
        
        // Possibly add “child” spots
        if depth < maxRecursionDepth && Bool.random(probability: 0.1) {
            let childX = centerX + Double.random(in: -maxSize / 2...maxSize / 2)
            let childY = centerY + Double.random(in: -maxSize / 2...maxSize / 2)
            let childMaxSize = maxSize * Double.random(in: 0.4...0.8)
            
            drawSpot(
                context: &context,
                size: size,
                centerX: childX,
                centerY: childY,
                maxSize: childMaxSize,
                opacity: adjustedOpacity,
                depth: depth + 1
            )
        }
    }
    
    private func generateOrganicShape(centerX: Double, centerY: Double, maxSize: Double) -> Path {
        var path = Path()
        let points = Int.random(in: 6...10)
        let radius = maxSize / 2
        
        for i in 0..<points {
            let angle = Double(i) * (360.0 / Double(points)).degreesToRadians
            let distanceVariation = radius * Double.random(in: -0.1...0.1)
            let distance = radius + distanceVariation
            
            let x = centerX + Double(cos(angle)) * distance
            let y = centerY + Double(sin(angle)) * distance
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    private func baseColor(isLight: Bool) -> Color {
        if isLight {
            // Off-white for the highlights
            return Color(white: 0.9)
        } else {
            // Off-black for the darker patches
            return Color(white: 0.1)
        }
    }
}

// MARK: - Motif Pattern

struct MotifPatternOverlay: View {
    var scale: CGFloat
    
    /// Example set: add any SF Symbols you like
    private let motifSymbols = [
        "star.fill", "heart.fill", "moon.fill", "leaf.fill", "snowflake",
        "suit.spade.fill", "suit.heart.fill", "suit.diamond.fill", "suit.club.fill",
        "pawprint.fill", "wand.and.stars", "sparkles",
        "gearshape.fill", "globe", "camera.metering.spot"
    ]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let motifSize: CGFloat = 30 * scale
                let spacing: CGFloat = motifSize * 0.1
                let xCount = Int(size.width / (motifSize + spacing)) + 1
                let yCount = Int(size.height / (motifSize + spacing)) + 1
                let randomSymbol = motifSymbols.randomElement() ?? "circle.fill"
                let motifImage = Image(systemName: randomSymbol)
                
                for xIndex in 0..<xCount {
                    for yIndex in 0..<yCount {
                        let x = CGFloat(xIndex) * (motifSize + spacing) + motifSize / 2
                        let y = CGFloat(yIndex) * (motifSize + spacing)
                            + (xIndex % 2 == 0 ? 0 : motifSize / 2)

                        context.draw(
                            motifImage,
                            at: CGPoint(x: x, y: y),
                            anchor: .center
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Perlin Noise Implementation

fileprivate func perlinNoise(_ x: Double, _ y: Double) -> Double {
    // A very simple Perlin-like function using "random gradient" approach.
    // For production apps, consider a well-tested Perlin library or more advanced noise.
    // This example is purely for demonstration.
    
    // Floor to get the integer grid corners
    let xi = Int(floor(x)) & 255
    let yi = Int(floor(y)) & 255
    
    // Relative x, y within the cell
    let xf = x - floor(x)
    let yf = y - floor(y)
    
    // Fetch random gradients at the four corners
    let topRight     = grad(hash: perm[xi + 1 + perm[yi + 1]], x: xf - 1, y: yf - 1)
    let topLeft      = grad(hash: perm[xi + 0 + perm[yi + 1]], x: xf - 0, y: yf - 1)
    let bottomRight  = grad(hash: perm[xi + 1 + perm[yi + 0]], x: xf - 1, y: yf - 0)
    let bottomLeft   = grad(hash: perm[xi + 0 + perm[yi + 0]], x: xf - 0, y: yf - 0)
    
    // Smooth interpolation
    let u = fade(xf)
    let v = fade(yf)
    
    // Interpolate along x, then y
    let lerpBottom = lerp(bottomLeft, bottomRight, u)
    let lerpTop    = lerp(topLeft, topRight, u)
    let value      = lerp(lerpBottom, lerpTop, v)
    
    // value in [-1, 1]
    return value
}

// MARK: - Utilities for Perlin

/// A classic Perlin “fade” function that smooths t in [0,1].
fileprivate func fade(_ t: Double) -> Double {
    return t * t * t * (t * (t * 6 - 15) + 10)
}

/// Linear interpolation
fileprivate func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    return a + t * (b - a)
}

/// Dot product with a pseudo-random gradient
fileprivate func grad(hash: Int, x: Double, y: Double) -> Double {
    // 8 possible gradient directions in 2D
    switch hash & 7 {
    case 0: return  x + y
    case 1: return  x - y
    case 2: return -x + y
    case 3: return -x - y
    case 4: return  x
    case 5: return -x
    case 6: return  y
    default: return -y
    }
}

/// Precomputed permutation array for pseudo-random gradients
fileprivate let perm: [Int] = {
    let p: [Int] = Array(0...255)
    // For demonstration, a fixed shuffle. Could randomize for seeds.
    return (p + p)
}()

// MARK: - Extensions & Helpers

extension Double {
    var degreesToRadians: CGFloat { CGFloat(self * .pi / 180) }
}

/// A naive Gaussian random generator using the Box-Muller transform
func randomGaussian(mean: Double, deviation: Double) -> Double {
    let u1 = Double.random(in: 0...1)
    let u2 = Double.random(in: 0...1)
    let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    return mean + z * deviation
}

/// Probability-based Bool.random
//extension Bool {
//    /// e.g. `Bool.random(probability: 0.3)` => ~30% chance of `true`.
//    static func random(probability: Double) -> Bool {
//        return Double.random(in: 0...1) < probability
//    }
//}

// MARK: - Color Tweaks

extension Color {
    /// Shift the hue by a certain fraction (e.g., 0.1 => shift hue by ~36 degrees)
    func shiftHue(by fraction: Double) -> Color {
        var (h, s, b, a) = hsba
        h += fraction
        // wrap around
        if h < 0 { h += 1 }
        if h > 1 { h -= 1 }
        return Color(hue: h, saturation: s, brightness: b, opacity: a)
    }
    
    /// Adjust brightness by adding a fraction in [-1, +1].
    func brightness(_ delta: Double) -> Color {
        var (h, s, b, a) = hsba
        b += delta
        b = b.clamped(to: 0...1)
        return Color(hue: h, saturation: s, brightness: b, opacity: a)
    }
    
    /// Decompose Color into (hue, saturation, brightness, alpha).
    private var hsba: (Double, Double, Double, Double) {
        // SwiftUI doesn’t give a direct HSBA accessor, so let’s do a small workaround:
        #if canImport(UIKit)
        // On iOS, we can use UIColor
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b), Double(a))
        #elseif canImport(AppKit)
        // On macOS, we can do something similar with NSColor
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        converted.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b), Double(a))
        #else
        // Fallback
        return (0, 0, 0, 1)
        #endif
    }
}

// MARK: StainsOverlay

struct StainsOverlay: View {
    /// Probability (0–1) of a beer stain appearing at all
    var beerStainProbability: Double = 0.4
    
    /// Max number of beer stains. Set to 0 if you don’t want them.
    var beerStainCount: Int = 2
    
    /// Probability (0–1) of a repeated-use wear spot (light or dark patch)
    var wearSpotProbability: Double = 0.6
    
    /// Max number of wear spots
    var wearSpotCount: Int = 3
    
    /// Strength of the effect (0 => almost invisible, 1 => normal)
    var intensity: Double = 1.0
    
    var body: some View {
        Canvas { context, size in
            // 1) Draw beer / liquid stains
            if Double.random(in: 0...1) < beerStainProbability {
                let count = Int.random(in: 1...beerStainCount)
                for _ in 0..<count {
                    drawBeerStain(context: &context, size: size)
                }
            }
            
            // 2) Draw repeated-wear spots
//            if Double.random(in: 0...1) < wearSpotProbability {
//                let count = Int.random(in: 1...wearSpotCount)
//                for _ in 0..<count {
//                    drawWearSpot(context: &context, size: size)
//                }
//            }
        }
        .drawingGroup()
    }
    
    // MARK: - 1) Beer / Liquid Stains
    
    private func drawBeerStain(context: inout GraphicsContext, size: CGSize) {
        // Randomly choose one of the regions for the stain center
        let region = Int.random(in: 0...2) // 0 = left, 1 = right, 2 = bottom
        let centerX: Double
        let centerY: Double

        switch region {
        case 0: // 30% on the left
            centerX = Double.random(in: 0...(size.width * 0.3))
            centerY = Double.random(in: 0...size.height)
        case 1: // 30% on the right
            centerX = Double.random(in: size.width * 0.7...size.width)
            centerY = Double.random(in: 0...size.height)
        case 2: // 30% on the bottom
            centerX = Double.random(in: 0...size.width)
            centerY = Double.random(in: size.height * 0.7...size.height)
        default:
            fatalError("Unexpected region value")
        }
        
        let ringRadius = Double.random(in: 10...25)
        let ringThickness = ringRadius * Double.random(in: 0.05...0.10) // 5–15% of radius
        let ringOpacity = 0.3 * intensity
        let drinkColors = [
            Color(red: 54 / 255, green: 39 / 255, blue: 24 / 255), // Espresso Brown
            Color(red: 101 / 255, green: 67 / 255, blue: 33 / 255), // Mocha Brown
            Color(red: 78 / 255, green: 52 / 255, blue: 46 / 255), // Dark Roast
            Color(red: 191 / 255, green: 128 / 255, blue: 64 / 255), // Cola Caramel
            Color(red: 220 / 255, green: 170 / 255, blue: 85 / 255), // Honey Amber
            Color(red: 128 / 255, green: 0 / 255, blue: 64 / 255), // Merlot
            Color(red: 94 / 255, green: 38 / 255, blue: 51 / 255), // Bordeaux
            Color(red: 139 / 255, green: 0 / 255, blue: 38 / 255), // Classic Burgundy
            Color(red: 210 / 255, green: 150 / 255, blue: 75 / 255) , // Amber Lager
            Color(red: 140 / 255, green: 105 / 255, blue: 60 / 255) , // Dark Malt
            Color(red: 0.5, green: 0.35, blue: 0.0), // Brownish beer color
            Color(red: 205 / 255, green: 133 / 255, blue: 63 / 255), // Chai Brown
            Color(red: 168 / 255, green: 114 / 255, blue: 45 / 255), // Spiced Amber
            Color(red: 255 / 255, green: 102 / 255, blue: 0 / 255) , // Orange Juice
            Color(red: 255 / 255, green: 182 / 255, blue: 193 / 255), // Pink Grapefruit
            Color(red: 255 / 255, green: 69 / 255, blue: 0 / 255)  , // Blood Orange
            Color(red: 160 / 255, green: 82 / 255, blue: 45 / 255), // Aged Oak
            Color(red: 205 / 255, green: 127 / 255, blue: 50 / 255), // Honey Whiskey
            Color(red: 184 / 255, green: 115 / 255, blue: 51 / 255) // Golden Bourbon
        ]
        
        let ringColor = drinkColors.randomElement() ?? Color.black
        
        // Some random lumps / irregularities
        let lumpsCount = Int.random(in: 3...6)
        
        context.drawLayer { layerContext in
            // Draw the ring
            var ringPath = Path()
            ringPath.addArc(
                center: CGPoint(x: centerX, y: centerY),
                radius: ringRadius,
                startAngle: .degrees(0),
                endAngle: .degrees(360),
                clockwise: false
            )
            
            // stroke the ring with a thick line
            layerContext.stroke(
                ringPath,
                with: .color(ringColor.opacity(ringOpacity)),
                style: StrokeStyle(lineWidth: ringThickness, lineCap: .round, lineJoin: .round)
            )
            
            // Optionally add lumps or small arcs around the ring
            for _ in 0..<lumpsCount {
                let lumpAngle = Double.random(in: 0..<360).degreesToRadians
                let lumpArcAngle = Double.random(in: 10..<40) // degrees
                var lumpPath = Path()
                
                lumpPath.addArc(
                    center: CGPoint(x: centerX, y: centerY),
                    radius: ringRadius + Double.random(in: -5...5),
                    startAngle: .radians(lumpAngle),
                    endAngle: .radians(lumpAngle + lumpArcAngle.toRadians),
                    clockwise: Bool.random()
                )
                
                // stroke lumps with a slightly darker or lighter color
                let lumpOpacity = Double.random(in: 0.1...0.2) * intensity
                layerContext.stroke(
                    lumpPath,
                    with: .color(ringColor.opacity(lumpOpacity)),
                    style: StrokeStyle(lineWidth: Double.random(in: 3...8), lineCap: .round)
                )
            }
            
            // Fill the center with a subtle radial gradient to simulate a faint puddle
            let fillOpacity = 0.05 * intensity
            let fillColor = ringColor.opacity(fillOpacity)
            let fillGradient = Gradient(stops: [
                .init(color: fillColor, location: 0.0),
                .init(color: Color.clear, location: 1.0)
            ])
            layerContext.fill(
                Path(ellipseIn: CGRect(
                    x: centerX - ringRadius,
                    y: centerY - ringRadius,
                    width: ringRadius * 2,
                    height: ringRadius * 2
                )),
                with: .radialGradient(
                    fillGradient,
                    center: CGPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endRadius: ringRadius
                )
            )
        }
    }
    
    // MARK: - 2) Repeated-Use Wear Spots
    
    private func drawWearSpot(context: inout GraphicsContext, size: CGSize) {
        let centerX = Double.random(in: 0...size.width)
        let centerY = Double.random(in: 0...size.height)
        
        // radius for the entire worn area
        let maxRadius = Double.random(in: 40...150)
        let rotationAngle = Double.random(in: 0..<360).degreesToRadians
        
        // A shape that’s possibly elliptical
        // We'll treat an ellipse or a random polygon, then fill with a gradient that lightens/darkens
        context.drawLayer { layerContext in
            // Step 1. Make the path
            let path = generateEllipticalOrBlobbyPath(
                centerX: centerX,
                centerY: centerY,
                radius: maxRadius,
                angle: rotationAngle
            )
            
            // Step 2. The color shift
            //    Some wear is lighter, some is darker, so pick one randomly
            let lighten = true //Bool.random()
            // Worn color offset
            let colorStrength = Double.random(in: 0.1...0.4) * intensity
            // For a "beer ring," I'd have gone with browns. But for wear, we can do
            // a subtle black or white overlay. Let's do gray overlay to lighten/darken
            let overlayColor = lighten ? Color.white : Color.black
            
            // Step 3. Fill with radial gradient
            let wornGradient = Gradient(stops: [
                .init(color: overlayColor.opacity(colorStrength * 0.7), location: 0.0),
                .init(color: overlayColor.opacity(colorStrength * 0.2), location: 0.5),
                .init(color: Color.clear, location: 1.0),
            ])
            
            layerContext.fill(
                path,
                with: .radialGradient(
                    wornGradient,
                    center: CGPoint(x: centerX, y: centerY),
                    startRadius: 0,
                    endRadius: maxRadius
                )
            )
        }
    }
    
    /// Generate a slightly elliptical or “blobby” shape
    private func generateEllipticalOrBlobbyPath(centerX: Double, centerY: Double, radius: Double, angle: Double) -> Path {
        var path = Path()
        
        // random # of lumps for a more organic shape
        let lumps = Int.random(in: 3...6)
        
        for i in 0..<lumps {
            let fraction = Double(i) / Double(lumps)
            let theta = fraction * 2 * Double.pi
            
            // vary the radius a bit
            let localRadius = radius + Double.random(in: -0.2...0.2) * radius
            
            // rotate shape by angle
            let rotated = theta + angle
            
            let x = centerX + cos(rotated) * localRadius
            let y = centerY + sin(rotated) * (localRadius * Double.random(in: 0.7...1.0)) // elliptical
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
}

/// A SwiftUI view that overlays "brushed wear" marks on a fabric.
struct BrushedWearOverlay: View {
    /// How many separate brush passes to draw. More passes => heavier wear.
    var brushPassCount: Int = 15
    
    /// Range for brush stroke size
    var minStrokeSize: CGFloat = 80
    var maxStrokeSize: CGFloat = 200
    
    /// Probability that a stroke is “lighter” vs. “darker.”
    /// e.g. 0.7 => 70% chance to lighten, 30% to darken.
    var lightenProbability: Double = 0.7
    
    /// Overall intensity. 0 => no effect, 1 => normal.
    /// Past 1 => stronger effect.
    var intensity: Double = 1.0
    
    /// If true, some brush strokes become arcs instead of straight lines
    var allowCurvedStrokes: Bool = true
    
    /// Possibly fix a random seed if you want repeatable results
    // var seed: Int?
    
    var body: some View {
        Canvas { context, size in
            for _ in 0..<brushPassCount {
                drawBrushedPass(context: &context, size: size)
            }
        }
        .drawingGroup()
        // The blendMode can help integrate the wear with the fabric color:
        // e.g. .multiply, .overlay, .screen, etc.
        // .overlay often works decently for wear
        // so you might do .blendMode(.overlay)
    }
    
    /// Draws one brushed stroke or arc.
    private func drawBrushedPass(context: inout GraphicsContext, size: CGSize) {
        // 1) Choose a random center or start point
        let center = CGPoint(
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: 0...size.height)
        )
        
        // 2) Random direction (angle) and length
        let angle = Double.random(in: 0..<360).degreesToRadians
        let brushWidth = CGFloat.random(in: minStrokeSize/2 ... maxStrokeSize/2)
        let brushLength = CGFloat.random(in: minStrokeSize ... maxStrokeSize)
        
        // 3) Possibly curve the brush stroke
        let isCurved = allowCurvedStrokes && Bool.random(probability: 0.5)
        
        // 4) Decide lighten or darken
        let lighten = Bool.random(probability: lightenProbability)
        
        // 5) Base color shift:
        // For cloth wear, we often lighten it (fibers get “fuzzy” or bleached),
        // but sometimes repeated friction can darken with grime.
        let overlayColor = lighten ? Color.white : Color.black
        // Pick a random alpha based on intensity
        let alpha = Double.random(in: 0.05...0.2) * intensity
        
        // 6) Build a shape for the brush stroke
        context.drawLayer { layerContext in
            let path: Path = isCurved
                ? buildArcPath(center: center, length: brushLength, width: brushWidth, angle: angle)
                : buildStraightStroke(center: center, length: brushLength, width: brushWidth, angle: angle)
            
            // Optionally add some noise or lumps inside that shape
            // (for an even more textured, random look).
            
            // 7) Fill the shape with a gradient or uniform overlay
            let fadeGradient = Gradient(stops: [
                // Start: near-center => maximum effect
                .init(color: overlayColor.opacity(alpha), location: 0.0),
                // Mid => partial effect
                .init(color: overlayColor.opacity(alpha * 0.5), location: 0.7),
                // Edge => fade to clear
                .init(color: Color.clear, location: 1.0),
            ])
            
            // Use radial or linear gradient. For a brush stroke, linear might be more realistic:
            // We'll do a linear gradient aligned with the stroke direction.
            
            // To get a linear gradient’s angle, define start/end in the stroke bounding box
            let bounds = path.boundingRect
            // For simplicity, pick the boundingRect center as start, plus some offset as end
            let startPt = CGPoint(x: bounds.midX, y: bounds.midY)
            // offset in direction of angle
            let endPt = CGPoint(
                x: startPt.x + cos(angle)*bounds.width,
                y: startPt.y + sin(angle)*bounds.height
            )
            
            layerContext.fill(
                path,
                with: .linearGradient(
                    fadeGradient,
                    startPoint: startPt,
                    endPoint: endPt
                )
            )
        }
    }
    
    /// Builds a straight stroke shape—like a rectangle angled at `angle`.
    private func buildStraightStroke(center: CGPoint,
                                     length: CGFloat,
                                     width: CGFloat,
                                     angle: CGFloat) -> Path
    {
        var path = Path()
        
        // We'll define a rectangle centered at `center`, oriented by `angle`.
        let halfLen = length / 2
        let halfWid = width / 2
        
        // The rectangle corners in local coords (angle = 0)
        let p1 = CGPoint(x: -halfLen, y: -halfWid)
        let p2 = CGPoint(x:  halfLen, y: -halfWid)
        let p3 = CGPoint(x:  halfLen, y:  halfWid)
        let p4 = CGPoint(x: -halfLen, y:  halfWid)
        
        // We'll rotate each corner around (0,0), then translate to `center`.
        path.move(to: rotatePoint(p1, by: angle, around: .zero).offset(by: center))
        path.addLine(to: rotatePoint(p2, by: angle, around: .zero).offset(by: center))
        path.addLine(to: rotatePoint(p3, by: angle, around: .zero).offset(by: center))
        path.addLine(to: rotatePoint(p4, by: angle, around: .zero).offset(by: center))
        path.closeSubpath()
        
        return path
    }
    
    /// Builds a gently curved stroke shape.
    private func buildArcPath(center: CGPoint,
                              length: CGFloat,
                              width: CGFloat,
                              angle: CGFloat) -> Path
    {
        var path = Path()
        
        // We'll approximate a curved stroke by an arc or wedge shape.
        // For example, define an arc that covers `length` degrees or so.
        
        let halfLen = Double(length / 2)
        let radius = halfLen / Double.random(in: 0.3...0.8) // choose a radius so the arc covers ~the stroke length
        
        // We’ll pick an arc center offset from the main center.
        // This is purely to get a somewhat random arc shape.
        let arcCenterOffset = CGPoint(x: 0, y: -CGFloat(radius))
        
        // The arc angles
        let arcSpan = CGFloat.random(in: 40...120) // degrees of arc
        let startAngle = -arcSpan/2
        let endAngle   =  arcSpan/2
        
        // The “outer” arc path
        var arcPath = Path()
        arcPath.addArc(
            center: arcCenterOffset,
            radius: CGFloat(radius),
            startAngle: Angle(degrees: Double(startAngle)),
            endAngle:   Angle(degrees: Double(endAngle)),
            clockwise: false
        )
        
        // We'll offset up/down by “width” to create a thicker wedge
        // Then close the shape. This is approximate, but it looks somewhat like a wide arc.
        let transformUp   = CGAffineTransform(translationX: 0, y: -(width/2))
        let transformDown = CGAffineTransform(translationX: 0, y:  (width/2))
        
        let topArc   = arcPath.applying(transformUp)
        let bottomArc = arcPath.reversedPath().applying(transformDown)
        
        // Merge them
        var wedge = topArc
        wedge.addPath(bottomArc)
        wedge.closeSubpath()
        
        // Now rotate that wedge by `angle`, then shift it so that the wedge’s
        // center is at `center`.
        let rotate = CGAffineTransform(rotationAngle: angle)
        let shift  = CGAffineTransform(translationX: center.x, y: center.y)
        
        return wedge.applying(rotate).applying(shift)
    }
}

/// Helper: rotate a point by `angle` around `origin`
fileprivate func rotatePoint(_ point: CGPoint, by angle: CGFloat, around origin: CGPoint) -> CGPoint {
    let dx = point.x - origin.x
    let dy = point.y - origin.y
    let cosA = cos(angle)
    let sinA = sin(angle)
    let rx = dx * cosA - dy * sinA
    let ry = dx * sinA + dy * cosA
    return CGPoint(x: rx + origin.x, y: ry + origin.y)
}

/// Helper: offset a point by a given center
fileprivate extension CGPoint {
    func offset(by center: CGPoint) -> CGPoint {
        CGPoint(x: self.x + center.x, y: self.y + center.y)
    }
}

extension Comparable {
    /// Utility to clamp a value within a range
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

// MARK: - Preview

struct AdvancedFeltView_Previews: PreviewProvider {
    static var previews: some View {
        FeltBackgroundView(
            baseColor: Color(red: 34/255, green: 139/255, blue: 34/255),
            radialShadingStrength: 0.4,
            wearIntensity: 1,
            motifVisibility: 0.2,
            motifScale: 1,
            showScratches: true
        )
        .previewLayout(.sizeThatFits)
        .padding()
        .frame(width: 600, height: 400)
        .previewDisplayName("Advanced Felt Surface")
    }
}
