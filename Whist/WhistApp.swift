//
//  WhistApp.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Entry point of the application.

import SwiftUI

@main
struct WhistApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var gameKitManager = GameKitManager()
    @StateObject private var connectionManager = ConnectionManager()
    @StateObject var preferences = Preferences()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .environmentObject(gameKitManager)
                .environmentObject(connectionManager)
                .onAppear {
                    // Establish the delegation relationship
                    gameManager.connectionManager = connectionManager
                    connectionManager.gameManager = gameManager
                    gameKitManager.authenticateLocalPlayer()
                }
        }
        .defaultSize(width: 800, height: 600)
        
        Settings {
            PreferencesView()
                .environmentObject(preferences)
        }
        
        // Secondary window for ScoresView with an identifier.
        Window("Scores", id: "ScoresWindow") {
            ScoresView()
                .environmentObject(gameManager)
        }
    }
    
    // Add your commands in the computed property below.
    var commands: some Commands {
        ScoresMenuCommands()
    }
}

struct ScoresMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    
    var body: some Commands {
        CommandMenu("View") {
            Button("Voir les scores") {
                openWindow(id: "ScoresWindow")
            }
            .keyboardShortcut("s", modifiers: [.command])
        }
    }
}


class Preferences: ObservableObject {
    @AppStorage("selectedFeltIndex") var selectedFeltIndex: Int = 0
    @AppStorage("wearIntensity") var wearIntensity: Double = 0.5
    @AppStorage("motifVisibility") var motifVisibility: Double = 0.5
    @AppStorage("patternOpacity") var patternOpacity: Double = 0.5
    @AppStorage("patternScale") private var patternScaleStorage: Double = 0.5

    var patternScale: CGFloat {
        get { CGFloat(patternScaleStorage) }
        set { patternScaleStorage = Double(newValue) }
    }
    
    var currentFelt: Color {
        GameConstants.feltColors[selectedFeltIndex]
    }
}

struct PreferencesView: View {
    @EnvironmentObject var preferences: Preferences
    @State private var isRandom: Bool = false // State for the checkbox

    var body: some View {
        Form {
            // "Choisir au hasard" Toggle
            Section {
                Toggle("Choisir au hasard", isOn: $isRandom)
            }

            // Felt Color Picker
            Section(header: Text("Couleur du tapis")) {
                HStack {
                    Picker("Couleur du tapis", selection: $preferences.selectedFeltIndex) {
                        ForEach(0..<GameConstants.feltColors.count, id: \.self) { idx in
                            HStack {
                                Circle()
                                    .fill(GameConstants.feltColors[idx])
                                    .frame(width: 20, height: 20)
                                Text(feltName(for: idx))
                            }
                        }
                    }
                    .disabled(isRandom) // Disable when "Choisir au hasard" is checked

                    // Square showing the actual selected color
                    Rectangle()
                        .fill(preferences.currentFelt)
                        .frame(width: 30, height: 30)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.black.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // Other Controls
            Section {
                Slider(value: $preferences.wearIntensity, in: 0...1, step: 0.25) {
                    Text("Intensité de l'usure")
                }
                .disabled(isRandom) // Disable when "Choisir au hasard" is checked
            }

            Section {
                Slider(value: $preferences.motifVisibility, in: 0...1, step: 0.1) {
                    Text("Visibilité du motif")
                }
                .disabled(isRandom) // Disable when "Choisir au hasard" is checked
            }

            Section {
                Slider(value: $preferences.patternScale, in: 0.1...0.8, step: 0.1) {
                    Text("Taille du motif")
                }
                .disabled(isRandom) // Disable when "Choisir au hasard" is checked
            }
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
        .onChange(of: isRandom) { oldValue, newValue in
            if newValue {
                preferences.selectedFeltIndex = Int.random(in: 0..<GameConstants.feltColors.count)
            }
        }
    }

    func feltName(for index: Int) -> String {
        let names = [
            "Vert Classique",
            "Bleu Profond",
            "Rouge Vin",
            "Violet Royal",
            "Sarcelle",
            "Gris Charbon",
            "Orange Brûlé",
            "Vert Forêt",
            "Marron Chocolat",
            "Rouge Écarlate"
        ]
        return names.indices.contains(index) ? names[index] : "Couleur Inconnue"
    }
}
