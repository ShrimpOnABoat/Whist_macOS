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
    @State private var shadowRadius: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @State private var showExplosion: Bool = false
    
    var body: some View {
        CardView(card: movingCard.card, isSelected: false, canSelect: false, onTap: {}, dynamicSize: dynamicSize)
            .frame(width: dynamicSize.cardWidth, height: dynamicSize.cardHeight)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .position(position)
            .onAppear {
                // Initialize with source transformations
                self.position = movingCard.fromState.position
                self.rotation = movingCard.fromState.rotation
                self.scale = movingCard.fromState.scale
            }
            .onChange(of: movingCard.toState) { _, newToState in
                guard let toState = newToState, !hasAnimated else { return }
                hasAnimated = true

                switch movingCard.card.playAnimationType {
                case .normal:
                    // For normal moves, add a random spin and animate directly to the target state.
                    let randomSpin: Double = {
                        if [.localPlayer, .leftPlayer, .rightPlayer].contains(movingCard.from) {
                            return Double([-360, 0, 360].randomElement() ?? 0)
                        } else {
                            return 0
                        }
                    }()
                    gameManager.playSound(named: "play card")
                    withAnimation(.easeOut(duration: animationDuration)) {
                        self.rotation = toState.rotation + randomSpin
                        self.scale = toState.scale
                        self.position = toState.position
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                        print("Finalizing move for \(movingCard.card) with normal animation")
                        gameManager.finalizeMove(movingCard)
                    }

                case .impact, .failure:
                    // Use a longer animation duration for special animations.
//                    self.animationDuration = 1

                    // Phase 1: Suspense phase — the card slightly rises and enlarges.
                    withAnimation(.easeIn(duration: animationDuration * 0.5)) {
                        self.scale = 1.2
                        self.rotation = 0 // You can adjust this if you want a different suspense rotation.
                        // Move the card upward for a suspense effect.
                        self.position = CGPoint(
                            x: movingCard.fromState.position.x,
                            y: movingCard.fromState.position.y - 30
                        )
                    }

                    // Phase 2: After the suspense, perform the special animation.
                    DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.5) {
                        switch movingCard.card.playAnimationType {
                        case .impact:
                            // Impact animation: the card lands with an exaggerated scale and then an explosion appears.
                            withAnimation(.easeOut(duration: animationDuration * 0.25)) {
                                self.scale = 1.8
                                self.rotation = toState.rotation
                                self.position = toState.position
                            }
                            // Trigger explosion effect after landing.
                            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.25) {
                                self.showExplosion = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.25) {
                                    self.showExplosion = false
                                    print("Finalizing move for \(movingCard.card) with impact")
                                    gameManager.finalizeMove(movingCard)
                                }
                            }
                        case .failure:
                            // Failure animation: the card undershoots (with a slight bounce) then corrects to its final state.
                            withAnimation(.interpolatingSpring(stiffness: 100, damping: 5)) {
                                self.scale = 0.9
                                self.rotation = toState.rotation
                                self.position = CGPoint(
                                    x: toState.position.x,
                                    y: toState.position.y + 10
                                )
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.25) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.4, blendDuration: 0)) {
                                    self.scale = toState.scale
                                    self.rotation = toState.rotation
                                    self.position = toState.position
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration * 0.25) {
                                    print("Finalizing move for \(movingCard.card) with failure")
                                    gameManager.finalizeMove(movingCard)
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
enum cardAnimationType {
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
