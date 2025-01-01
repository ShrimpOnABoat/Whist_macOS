////
////  test.swift
////  Whist
////
////  Created by Tony Buffard on 2025-01-01.
////
//
//import SwiftUI
//
//
//struct NoShadowOnPressButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .shadow(radius: configuration.isPressed ? 0 : 5) // Remove shadow when pressed
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Optional: Add a slight scale effect when pressed
//            .animation(.easeInOut(duration: 0.05), value: configuration.isPressed) // Smooth transition
//    }
//}
//
//struct CircularButton: View {
//    let text: String
//    let action: () -> Void
//    let size: CGFloat
//    let backgroundColor: Color
//    
//    init(
//        text: String,
//        size: CGFloat = 60,
//        backgroundColor: Color = .blue,
//        action: @escaping () -> Void
//    ) {
//        self.text = text
//        self.size = size
//        self.backgroundColor = backgroundColor
//        self.action = action
//    }
//    
//    var body: some View {
//        Button(action: action) {
//            ZStack {
//                // Inner filled circle
//                Circle()
//                    .fill(backgroundColor.opacity(0.7))
//                
//                // Outer border to mimic poker chip
//                Circle()
//                    .strokeBorder(lineWidth: size * 0.1) // 10% of the button size
//                    .foregroundColor(backgroundColor.opacity(0.7))
//
//                // Add poker chip notches
//                ForEach(0..<8) { i in
//                    Rectangle()
//                        .fill(Color.white)
//                        .frame(width: size * 0.1, height: size * 0.1)
//                        .offset(y: -size / 2 + size * 0.05) // Move to the edge of the circle
//                        .rotationEffect(Angle(degrees: Double(i) * 45)) // Distribute evenly
//                }
//
//                // Text in the center
//                Text(text)
//                    .font(.system(size: size / 3).bold()) // Adjust font size
//                    .foregroundColor(.white)
//            }
//            .frame(width: size, height: size)
//            .shadow(radius: 5) // Shadow for depth
//        }
//        .buttonStyle(NoShadowOnPressButtonStyle())
//    }
//}
//
//#Preview {
//    CircularButton(
//        text: "10", //\(Int.random(in: 0...10))",
//        size: 80,
//        backgroundColor: .pink,
//        action: {print("coucou")})
//    .frame(width: 100, height: 100)
//}
