//
//  MovingCard.swift
//  Whist
//
//  Created by Tony Buffard on 2025-02-13.
//

import SwiftUI

// MARK: - MovingCard Class

class MovingCard: Identifiable, ObservableObject {
    let id: UUID = UUID()
    let card: Card
    let from: CardPlace
    let to: CardPlace
    let placeholderCard: Card
    let fromState: CardState
    @Published var toState: CardState? = nil
    
    // Initializer
    init(card: Card,from: CardPlace, to: CardPlace, placeholderCard: Card, fromState: CardState) {
        self.card = card
        self.from = from
        self.to = to
        self.placeholderCard = placeholderCard
        self.fromState = fromState
    }
}
extension MovingCard: CustomStringConvertible {
    var description: String {
        return "\(card)"
    }
}
// MARK: - MovingCardView

struct MovingCardView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var movingCard: MovingCard
    var dynamicSize: DynamicSize
    
    @State private var position: CGPoint = .zero
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var hasAnimated: Bool = false // To ensure animation occurs only once
    @State private var animationDuration: TimeInterval = 0.4
    // Special animation state variables
    @State private var offsetY: CGFloat = 0

    var body: some View {
        // elevate the card a little
        CardView(card: movingCard.card, isSelected: false, canSelect: false, onTap: {}, dynamicSize: dynamicSize)
            .frame(width: dynamicSize.cardWidth, height: dynamicSize.cardHeight)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .position(position)
            .shadow(
                color: Color.black.opacity(0.3),
                radius: movingCard.card.elevation / 4,
                x: movingCard.card.elevation,
                y: movingCard.card.elevation
            )
            .onAppear {
                // Initialize with source transformations
                self.position = movingCard.fromState.position
                self.rotation = movingCard.fromState.rotation
                self.scale = movingCard.fromState.scale
                movingCard.card.elevation = 5
            }
            .onChange(of: movingCard.toState) { _, newToState in
                guard let toState = newToState, !hasAnimated else { return }
                hasAnimated = true

                switch movingCard.card.playAnimationType {
                case .normal:
                    if movingCard.to == .table { movingCard.card.isFaceDown = false } // Show the card if playCard
                    // For normal moves, add a random spin and animate directly to the target state.
                    let randomSpin: Double = {
                        if [.localPlayer, .leftPlayer, .rightPlayer].contains(movingCard.from) {
                            return Double([-360, 0, 360].randomElement() ?? 0)
                        } else {
                            return 0
                        }
                    }()
                    gameManager.playSound(named: "play card")
                    withAnimation(Animation.timingCurve(0.4, 0, 0.2, 1, duration: animationDuration)) {
                        self.rotation = toState.rotation + randomSpin
                        self.scale = toState.scale
                        self.position = toState.position
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        print("Finalizing move for \(movingCard.card) with normal animation")
                        gameManager.finalizeMove(movingCard)
                    }

                case .impact, .failure:
                    // --- Common "Suspense" part: Make the card appear to float higher than before ---
                    let suspenseDuration: TimeInterval = 1
                    withAnimation(.easeOut(duration: suspenseDuration)) {
                        self.scale = 1.3
                        self.rotation = toState.rotation
                        self.position = CGPoint(
                            x: toState.position.x,
                            y: toState.position.y - 60 // raise it higher
                        )
                        movingCard.card.elevation = 20 // bigger shadow while in the air
                        if movingCard.to == .table { movingCard.card.isFaceDown = false } // Show the card if playCard
                    }


                    // Phase 2: After the suspense, perform the special animation.
                    DispatchQueue.main.asyncAfter(deadline: .now() + suspenseDuration) {
                        switch movingCard.card.playAnimationType {
                        case .impact:
                            // 1) Snap down instantly (one-frame drop).
                            withAnimation(.none) {
                                self.scale = toState.scale
                                self.rotation = toState.rotation
                                self.position = toState.position
                                movingCard.card.elevation = 0
                            }

                            // 2) Show cracks or smash overlay. Could be an animated shape or image.
                            gameManager.effectPosition = self.position
                            gameManager.showExplosion = true

                            DispatchQueue.main.asyncAfter(deadline: .now() + suspenseDuration) {
                                gameManager.showExplosion = false
                                // Finalize move
                                gameManager.finalizeMove(movingCard)
                            }
                        case .failure:
                            // 1) Attempt a quick drop, but less abrupt than .impact.
                            withAnimation(.easeOut(duration: 0.25)) {
                                self.scale = 1.0
                                self.rotation = toState.rotation - 5 // slight tilt to show "failed attempt"
                                self.position = CGPoint(
                                    x: toState.position.x,
                                    y: toState.position.y + 10
                                )
                                movingCard.card.elevation = 0
                            }

                            // 2) Add a quick "fizzle out" or "wind" effect:
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                // Show a wind-like swirl
                                gameManager.effectPosition = self.position
                                gameManager.showWindSwirl = true
                                withAnimation(.easeIn(duration: 0.2)) {
                                    self.scale = toState.scale
                                    self.rotation = toState.rotation
                                    self.position = toState.position
                                    movingCard.card.elevation = 0
                                }

                                // 3) Then settle into final position, removing swirl.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    gameManager.showWindSwirl = false
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                        self.scale = toState.scale
                                        self.rotation = toState.rotation
                                        self.position = toState.position
                                        movingCard.card.elevation = 0
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                        gameManager.finalizeMove(movingCard)
                                    }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
    }
}

// MARK: Special play card animations
enum cardAnimationType: Codable {
    case impact   // For a powerful, game-changing move
    case failure  // For when a player is expected to win the trick but doesn’t
    case normal // For all the other cases
}

/// A simple explosion effect for the "impact" animation.
struct ExplosionView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(gradient: Gradient(colors: [.yellow, .orange, .red]),
                               center: .center,
                               startRadius: 0,
                               endRadius: 50)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 3.0
                    opacity = 0
                }
            }
    }
}

// Model for an individual explosion particle.
struct ExplosionParticleModel: Identifiable {
    let id = UUID()
    let angle: Double        // Direction (in degrees)
    let distance: CGFloat    // How far it will travel
    let duration: Double     // Animation duration
    let color: Color         // Particle color
}

// A single explosion particle view.
struct ExplosionParticleView: View {
    let model: ExplosionParticleModel
    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(model.color)
            .frame(width: 6, height: 6)
            .offset(offset)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Convert angle to radians and compute the offset.
                let radians = model.angle * .pi / 180
                let dx = cos(radians) * model.distance
                let dy = sin(radians) * model.distance
                withAnimation(.easeOut(duration: model.duration)) {
                    offset = CGSize(width: dx, height: dy)
                    opacity = 0
                    scale = 2.0
                }
            }
    }
}

// The complete explosion view with a central flash and multiple particles.
struct ProceduralExplosionView: View {
    private let particles: [ExplosionParticleModel]
    @State private var flashScale: CGFloat = 0.1
    @State private var flashOpacity: Double = 1.0

    // Generate particles procedurally.
    init(particleCount: Int = 30) {
        var tempParticles: [ExplosionParticleModel] = []
        for _ in 0..<particleCount {
            let angle = Double.random(in: 0..<360)
            let distance = CGFloat.random(in: 50...100)
            let duration = Double.random(in: 0.3...0.6)
            let color = [Color.yellow, Color.orange, Color.red, Color.white].randomElement()!
            tempParticles.append(ExplosionParticleModel(angle: angle, distance: distance, duration: duration, color: color))
        }
        self.particles = tempParticles
    }
    
    var body: some View {
        ZStack {
            // Central flash effect using a radial gradient.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white, Color.yellow, Color.orange, Color.red]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 20, height: 20)
                .scaleEffect(flashScale)
                .opacity(flashOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4)) {
                        flashScale = 3.0
                        flashOpacity = 0.0
                    }
                }
            
            // Explosion particles.
            ForEach(particles) { particle in
                ExplosionParticleView(model: particle)
            }
        }
    }
}
struct WindSwirlView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0
    
    var body: some View {
        Image("windSwirl") // e.g. a swirl image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                // Animate the swirl expanding or drifting
                withAnimation(.easeInOut(duration: 0.3)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

struct ProceduralExplosionView_Previews: PreviewProvider {
    static var previews: some View {
        ProceduralExplosionView()
            .frame(width: 300, height: 300)
            .background(Color.black)
    }
}
