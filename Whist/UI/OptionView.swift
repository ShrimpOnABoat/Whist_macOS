//
//  OptionView.swift
//  Whist
//
//  Created by Tony Buffard on 2024-12-09.
//

import SwiftUI

struct NoShadowOnPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .shadow(radius: configuration.isPressed ? 0 : 5) // Remove shadow when pressed
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Optional: Add a slight scale effect when pressed
            .animation(.easeInOut(duration: 0.05), value: configuration.isPressed) // Smooth transition
    }
}

struct CircularButton: View {
    let text: String
    let action: () -> Void
    let size: CGFloat
    let backgroundColor: Color
    
    init(
        text: String,
        size: CGFloat = 60,
        backgroundColor: Color = .blue,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.size = size
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Inner filled circle
                Circle()
                    .fill(backgroundColor.opacity(0.7))
                
                // Outer border to mimic poker chip
                Circle()
                    .strokeBorder(lineWidth: size * 0.1) // 10% of the button size
                    .foregroundColor(backgroundColor.opacity(0.7))

                // Add poker chip notches
                ForEach(0..<8) { i in
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: size * 0.1, height: size * 0.1)
                        .offset(y: -size / 2 + size * 0.05) // Move to the edge of the circle
                        .rotationEffect(Angle(degrees: Double(i) * 45)) // Distribute evenly
                }

                // Text in the center
                Text(text)
                    .font(.system(size: size / 3).bold()) // Adjust font size
                    .foregroundColor(.white)
            }
            .frame(width: size, height: size)
            .shadow(radius: size / 15) // Shadow for depth
        }
        .buttonStyle(NoShadowOnPressButtonStyle())
    }
}

struct OptionsView: View {
    @EnvironmentObject var gameManager: GameManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Choisis une mise :")
                .font(.title)
                .padding(.bottom, 20)
            
            // Compute rows dynamically
            let numbers = Array(0...max(gameManager.gameState.round - 2, 1))
            let firstRow = Array(numbers.prefix(6)) // Up to 6 buttons in the first row
            let secondRow = Array(numbers.dropFirst(6)) // Remaining buttons in the second row
            let size: CGFloat = 40
            let backgroundColor: Color = [
                .red, .orange, .yellow, .green, .mint, .teal,
                .cyan, .blue, .indigo, .purple, .pink, .brown, .gray
            ].randomElement() ?? .blue
            
            VStack(spacing: 20) {
                // First Row
                HStack(spacing: 20) {
                    ForEach(firstRow, id: \.self) { number in
                        CircularButton(
                            text: "\(number)",
                            size: size,
                            backgroundColor: backgroundColor,
                            action: { gameManager.choseBet(bet: number) }
                        )
                    }
                }
                
                // Second Row (only if there are numbers left)
                if !secondRow.isEmpty {
                    HStack(spacing: 20) {
                        ForEach(secondRow, id: \.self) { number in
                            CircularButton(
                                text: "\(number)",
                                size: size,
                                backgroundColor: backgroundColor,
                                action: { gameManager.choseBet(bet: number) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
        .shadow(radius: 10)
    }
}

// MARK: - Preview

struct OptionsView_Previews: PreviewProvider {
    static var previews: some View {
        let gameManager = GameManager()
        gameManager.setupPreviewGameState()
        
        gameManager.gameState.round = 12

        return OptionsView()
            .environmentObject(gameManager)
            .previewDisplayName("Options View Preview")
            .previewLayout(.sizeThatFits)
    }
}
