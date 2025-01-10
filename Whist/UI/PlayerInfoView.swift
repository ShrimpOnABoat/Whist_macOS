//
//  PlayerInvoView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-04.
//

import SwiftUI

struct PlayerInfoView: View {
    @EnvironmentObject var gameManager: GameManager
    @ObservedObject var player: Player
    let isDealer: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        VStack {
            let dealerSize: CGFloat = 30
            // Tricks Display
            if player.tablePosition != .local {
                VStack {
                    // Player Image and Dealer Button
                    ZStack {
                        PlayerImageView(player: player)
                            .padding(.trailing, 12)
                        
                        // Show the dealer button if this player is the dealer
                        if isDealer {
                            DealerButton(size: dealerSize)
                                .offset(x: (player.tablePosition == .left) ? 50 : -50, y: -20) // Adjust based on table position
                                .matchedGeometryEffect(id: "dealerButton", in: namespace)
                                .animation(.easeInOut, value: isDealer) // Smooth transition
                        }
                    }
                    
                    // Tricks Display
                    let roundIndex = gameManager.gameState.round - 1
                    if player.announcedTricks.indices.contains(roundIndex) {
                        
                        // Announced Tricks
                        let announcedTricks = player.announcedTricks[roundIndex]
                        let madeTricks = player.madeTricks[roundIndex]
                        
                        VStack(spacing: 0) { // Center cards and placeholders
                            ForEach(0..<announcedTricks, id: \.self) { index in
                                if index * 3 + 2 < player.trickCards.count {
                                    ZStack {
                                        ForEach(0..<3, id: \.self) { cardIndex in
                                            TransformableCardView(card: player.trickCards[index * 3 + cardIndex], scale: 1/3, rotation: 90)
                                        }
                                    }
                                } else {
                                    // Placeholder for missing tricks
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 2))
                                        .opacity(0.8)
                                        .blendMode(.multiply)
                                        .frame(width: 30, height: 20)
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center) // Center the cards under the image
                        
                        // Extra Tricks (Made but not Announced)
                        if madeTricks > announcedTricks {
                            VStack(spacing: 0) { // Center extra tricks
                                ForEach(0..<(madeTricks - announcedTricks), id: \.self) { index in
                                    let extraIndex = (index + announcedTricks) * 3
                                    if extraIndex + 2 < player.trickCards.count {
                                        ZStack {
                                            ForEach(0..<3, id: \.self) { cardIndex in
                                                TransformableCardView(card: player.trickCards[extraIndex + cardIndex], scale: 1/3, rotation: 90)
                                            }
                                        }
                                        .hueRotation(Angle(degrees: 90)) // Highlight extra tricks
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center) // Center the extra tricks
                        }
                    } else {
                        // Placeholder if no tricks were announced or made
                        HStack {
                            Spacer() // Ensure alignment stays centered
                            EmptyView()
                            Spacer()
                        }
                    }
                }
            } else {
                HStack(alignment: .center) {
                    // Player Image and Dealer Button
                    ZStack {
                        // Player Image
                        PlayerImageView(player: player)
                        
                        // Dealer Button (overlaid)
                        if isDealer {
                            DealerButton(size: dealerSize)
                                .matchedGeometryEffect(id: "dealerButton", in: namespace)
                                .offset(x: -80, y: -30) // Adjust this offset to position the button relative to the image
                                .animation(.easeInOut, value: isDealer) // Smooth transition
                        }
                    }
                    
                    // Cards and Empty Spaces (vertically centered)
                    HStack {
                        if player.announcedTricks.indices.contains(gameManager.gameState.round - 1) {
                            // Announced Tricks
                            ForEach(0..<player.announcedTricks[gameManager.gameState.round - 1], id: \.self) { index in
                                if index < (player.trickCards.count / 3) {
                                    ZStack {
                                        TransformableCardView(card: player.trickCards[index], scale: 1/3)
                                        TransformableCardView(card: player.trickCards[index+1], scale: 1/3)
                                        TransformableCardView(card: player.trickCards[index+2], scale: 1/3)
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 2))
                                        .opacity(0.8)
                                        .blendMode(.multiply)
                                        .frame(width: 20, height: 30)
                                        .background(Color.white.opacity(0.2))
                                }
                            }
                            
                            // Extra Tricks (Made but not Announced)
                            if player.madeTricks[gameManager.gameState.round - 1] > player.announcedTricks[gameManager.gameState.round - 1] {
                                ForEach(0..<(player.madeTricks[gameManager.gameState.round - 1] - player.announcedTricks[gameManager.gameState.round - 1]), id: \.self) { index in
                                    ZStack {
                                        let realIndex = 3 * (index + player.announcedTricks[gameManager.gameState.round - 1])
                                        
                                        TransformableCardView(card: player.trickCards[realIndex], scale: 1/3)
                                        TransformableCardView(card: player.trickCards[realIndex+1], scale: 1/3)
                                        TransformableCardView(card: player.trickCards[realIndex+2], scale: 1/3)
                                    }
                                    .hueRotation(Angle(degrees: 90))
                                }
                            }
                        } else {
                            EmptyView()
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center) // Vertically center the cards
                }
            }
        }
        .padding()
    }
}

// MARK: - Previews

struct PlayerInfoView_Previews: PreviewProvider {
    static var previews: some View {
        @Namespace var cardAnimationNamespace
        // Initialize GameManager and set up the preview game state
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        // Extract players from the game state
        let localPlayer = gameManager.gameState.localPlayer!
        let leftPlayer = gameManager.gameState.leftPlayer!
        let rightPlayer = gameManager.gameState.rightPlayer!
        
        // Create previews for each player
        return Group {
            PlayerInfoView(player: localPlayer, isDealer: true, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Local Player - Horizontal")
            
            PlayerInfoView(player: leftPlayer, isDealer: true, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Left Player - Vertical")
            
            PlayerInfoView(player: rightPlayer, isDealer: true, namespace: cardAnimationNamespace)
                .environmentObject(gameManager)
                .previewDisplayName("Right Player - Vertical")
        }
        .previewLayout(.sizeThatFits)
        .padding()
        .background(Color.gray)
    }
}

struct PlayerImageView: View {
    @EnvironmentObject var gameManager: GameManager
    let player: Player
    
    var body: some View {
        VStack {
            // Player Picture
            if player.connected {
                (player.image ?? Image(systemName: "person.crop.circle"))
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
            } else {
                Image(systemName: "person.crop.circle.badge.xmark")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.red)
                    .clipShape(Circle())
            }
            
            // Player Username
            Text(player.username)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}
