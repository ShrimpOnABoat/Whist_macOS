//
//  FeltBackgroundView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-04.
//

import SwiftUI

struct FeltBackgroundView: View {
    var feltColor: Color = [
        Color(red: 34/255, green: 139/255, blue: 34/255), // Classic Green
        Color(red: 0/255, green: 0/255, blue: 139/255),   // Deep Blue
        Color(red: 139/255, green: 0/255, blue: 0/255),   // Wine Red
        Color(red: 75/255, green: 0/255, blue: 130/255),  // Royal Purple
        Color(red: 0/255, green: 128/255, blue: 128/255), // Teal
        Color(red: 54/255, green: 69/255, blue: 79/255),  // Charcoal Gray
        Color(red: 205/255, green: 92/255, blue: 0/255),  // Burnt Orange
        Color(red: 34/255, green: 90/255, blue: 34/255),  // Forest Green
        Color(red: 139/255, green: 69/255, blue: 19/255), // Chocolate Brown
        Color(red: 220/255, green: 20/255, blue: 60/255)  // Crimson Red
    ].randomElement() ?? Color(red: 34/255, green: 139/255, blue: 34/255) // Fallback to Classic Green
    var wearIntensity: Double = Double.random(in: 0...1)
    var motifVisibility: Double = Double.random(in: 0...1)
    var patternOpacity: Double = Double.random(in: 0...1)
    var patternScale: CGFloat = CGFloat.random(in: 0.1...0.8)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Base Felt (Soft Plush Texture)
                ZStack {
                    feltColor
                    NoiseOverlay()
                        .blendMode(.overlay)
                }

                // 2. Wear and Tear Layer
                ScratchesOverlay(intensity: wearIntensity)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                SpotsOverlay(intensity: wearIntensity, isLight: true)
                    .blendMode(.colorDodge) //colorDodge lighten
                    .allowsHitTesting(false)
                SpotsOverlay(intensity: wearIntensity, isLight: false)
                    .blendMode(.darken)
                    .allowsHitTesting(false)

                // 3. Motifs / Patterns Layer (soft embossed patterns)
                MotifPatternOverlay(opacity: patternOpacity, scale: patternScale)
                    .opacity(motifVisibility)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)

                // Natural-looking depth with radial gradients
                // Darker edges, slight center highlight
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.black.opacity(0.4)
                    ]),
                    center: .center,
                    startRadius: 50,
                    endRadius: min(geometry.size.width, geometry.size.height) / 1.5
                )
                .blendMode(.multiply)

                // Subtle off-center gradient
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.0),
                        Color.black.opacity(0.2)
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

// MARK: - Base Noise Overlay for Plush Texture
struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            // Create a fine-grained noise pattern with varying sizes and opacities
            let particleCount = Int(size.width * size.height / 40) // Adjust density
            for _ in 0..<particleCount {
                let x = Double.random(in: 0...size.width)
                let y = Double.random(in: 0...size.height)
                
                // Introduce slight variations in size and shape
                let width = Double.random(in: 0.5...3.0)
                let height = Double.random(in: 0.5...3.0)
                
                // Adjust opacity for soft appearance
                let opacity = Double.random(in: 0.05...0.15)
            
                
                // Use a mix of subtle white and black noise for depth
                let isWhiteNoise = Bool.random()
                let color = isWhiteNoise ? Color.white.opacity(opacity) : Color.black.opacity(opacity)
                
                // Render the noise particle
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height)),
                    with: .color(color)
                )
            }
        }
        .drawingGroup() // Optimize for large patterns
    }
}

// MARK: - Wear and Tear Overlay
struct ScratchesOverlay: View {
    var intensity: Double
    
    var body: some View {
        Canvas { context, size in
            // Add scratches with parallel lines
            let scratchCount = Int(size.width * size.height * intensity / 15000)
            for _ in 0..<scratchCount {
                let startX = Double.random(in: 0...size.width)
                let startY = Double.random(in: 0...size.height)
                let angle = Double.random(in: 0...360).degreesToRadians
                let clusterWidth = max(2, min(100, randomGaussian(mean: 20, deviation: 15) * (0.5 + intensity / 2)))
                
                // Generate parallel scratches in a cluster
                for offset in stride(from: -clusterWidth / 2, through: clusterWidth / 2, by: Double.random(in: 1...3)) {
                    // Generate a length value using a Gaussian distribution
                    let length = max(10, min(1000, randomGaussian(mean: 50, deviation: 50) * (0.5 + intensity / 2)))
                    let thickness = Double.random(in: 0.5...2.0)
                    let lineOpacity = max(0.01, min(0.9, randomGaussian(mean: 0.2, deviation: 0.2) * (0.5 + intensity / 2)))
                    
                    let startOffsetX = startX + CGFloat(cos(angle + .pi / 2)) * offset + CGFloat.random(in: -25...25)
                    let startOffsetY = startY + CGFloat(sin(angle + .pi / 2)) * offset + CGFloat.random(in: -25...25)
                    
                    let endOffsetX = startOffsetX + CGFloat(cos(angle)) * length
                    let endOffsetY = startOffsetY + CGFloat(sin(angle)) * length
                    
                    // Create a scratch path
                    var scratchPath = Path()
                    scratchPath.move(to: CGPoint(x: startOffsetX, y: startOffsetY))
                    scratchPath.addLine(to: CGPoint(x: endOffsetX, y: endOffsetY))
                    
                    context.stroke(
                        scratchPath,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: Color.white.opacity(0.5 * lineOpacity), location: 0.0), // Higher starting opacity
                                .init(color: Color.white.opacity(0.8 * lineOpacity), location: 0.3), // Peak opacity
                                .init(color: Color.white.opacity(0.8 * lineOpacity), location: 0.7), // Peak opacity
                                .init(color: Color.white.opacity(0.5 * lineOpacity), location: 1.0)  // Fade out
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
    var isLight: Bool = true
    let maxRecursionDepth = 1 // Maximum levels of recursion
    
    var body: some View {
        Canvas { context, size in
            //            let spotDivider = max(3000, min(20000, randomGaussian(mean: 10000, deviation: 3000)))
            let spotDivider: Double = isLight ? 35000 : 120000
            let spotCount = Int(size.width * size.height * intensity / spotDivider)
            let inclusionArea: CGFloat = 0.5
            
            // Generate faded patches
            for _ in 0..<spotCount {
                let x = Bool.random() ? size.width * CGFloat.random(in: 0...inclusionArea): size.width * (1 - CGFloat.random(in: 0...inclusionArea)) // Double.random(in: 0...size.width)
                let y = Bool.random() ? size.height * CGFloat.random(in: 0...inclusionArea) : size.height * (1 - CGFloat.random(in: 0...inclusionArea)) // Double.random(in: 0...size.height)
                let maxSize = max(10, min(200, randomGaussian(mean: 30, deviation: 50) * (0.5 + intensity / 2)))
                let opacity = max(0.05, min(0.15, randomGaussian(mean: 0.1, deviation: 0.02) * (0.5 + intensity / 2)))
                
                drawSpot(context: &context, size: size, centerX: x, centerY: y, maxSize: maxSize, opacity: opacity, depth: 0)
            }
        }
    }
    
    private func drawSpot(context: inout GraphicsContext, size: CGSize, centerX: Double, centerY: Double, maxSize: Double, opacity: Double, depth: Int) {
        // Generate the base shape for the spot
        let path = generateOrganicShape(centerX: centerX, centerY: centerY, maxSize: maxSize)
        
        // Multiply opacity for children
        let adjustedOpacity = max(0.01, min(1.0, opacity * pow(0.8, Double(depth))))
        
        // Draw the current spot with adjusted opacity
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
        
        // Recursive Spot Generation
        if depth < maxRecursionDepth && Bool.random(probability: 0.1) { // 20% chance for spawning children
            let childX = centerX + Double.random(in: -maxSize / 2...maxSize / 2)
            let childY = centerY + Double.random(in: -maxSize / 2...maxSize / 2)
            let childMaxSize = maxSize * Double.random(in: 0.5...0.8) // Smaller child spots
            
            drawSpot(
                context: &context,
                size: size,
                centerX: childX,
                centerY: childY,
                maxSize: childMaxSize,
                opacity: adjustedOpacity, // Pass the adjusted opacity
                depth: depth + 1
            )
        }
    }
    // Helper function to generate organic shapes
    private func generateOrganicShape(centerX: Double, centerY: Double, maxSize: Double) -> Path {
        var path = Path()
        let points = Int.random(in: 6...10)
        let radius = maxSize / 2
        
        for i in 0..<points {
            let angle = Double(i) * (360.0 / Double(points)).degreesToRadians
            let distanceVariation = radius * Double.random(in: -0.1...0.1) // +/- 15% randomization
            let distance = radius + distanceVariation
            
            let x = centerX + CGFloat(cos(angle)) * distance
            let y = centerY + CGFloat(sin(angle)) * distance
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    
    // A helper to slightly vary the color based on whether it’s “light” or “dark”
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

// MARK: - Motif Pattern Overlay
struct MotifPatternOverlay: View {
    var opacity: Double
    var scale: CGFloat
    private let motifSymbols = [
        "star.fill", "heart.fill", "moon.fill",
        "leaf.fill", "snowflake", "waveform.path.ecg", "music.note", "suit.spade.fill", "suit.heart.fill", "suit.diamond.fill",
        "suit.club.fill", "pawprint.fill", "wand.and.stars", "sparkles",
        "circle.grid.hex", "gearshape.fill",
        "globe", "camera.metering.spot",
        "building.columns.fill",
        "ant.fill", "face.smiling"
    ]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let motifSize: CGFloat = 30 * scale
                let space: CGFloat = 0.1 * motifSize
                let xCount = Int(size.width / (motifSize + space)) + 1
                let yCount = Int(size.height / (motifSize + space)) + 1
                
                // Choose a random motif from the system symbols
                let randomSymbol = motifSymbols.randomElement() ?? "circle.fill"
                let motifImage = Image(systemName: randomSymbol)

                for xIndex in 0..<xCount {
                    for yIndex in 0..<yCount {
                        let x = CGFloat(xIndex) * (motifSize + space) + motifSize / 2
                        let y = CGFloat(yIndex) * (motifSize + space) + ((xIndex % 2 == 0) ? 0 : motifSize / 2)
                        
                        context.transform = context.transform
                            .translatedBy(x: x, y: y)

                        // Render the motif
                        let rect = CGRect(x: -motifSize / 2, y: -motifSize / 2, width: motifSize, height: motifSize)
                        context.opacity = opacity
                        context.draw(
                            motifImage,
                            in: rect
                        )

                        // Reset transformations
                        context.transform = context.transform
                            .translatedBy(x: -x, y: -y)
                    }
                }
            }
        }
    }
}

// MARK: - Helpers
extension Double {
    var degreesToRadians: CGFloat {
        return CGFloat(self * .pi / 180)
    }
}

func randomGaussian(mean: Double, deviation: Double) -> Double {
    let u1 = Double.random(in: 0...1)
    let u2 = Double.random(in: 0...1)
    let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
    return mean + z * deviation
}

// MARK: - Preview
struct FeltBackgroundView_Previews: PreviewProvider {
    static var previews: some View {
        FeltBackgroundView()
        .previewDisplayName("High-Quality Felt Surface")
        .previewLayout(.fixed(width: 800, height: 600))
        .padding()
    }
}
