//
//  WhistApp.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Entry point of the application.

import SwiftUI

@main
struct WhistApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // to quickly catch an invitation if the app wasn't launched already

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
                .environmentObject(preferences)
                .onAppear {
                    // Establish the delegation relationship
                    gameManager.connectionManager = connectionManager
                    connectionManager.gameManager = gameManager
#if !TEST_MODE
                    gameKitManager.connectionManager = connectionManager
                    gameKitManager.authenticateLocalPlayer() { name, image in
                        guard let localPlayerID = GCPlayerIdAssociation[name] else {
                            logger.log("No matching PlayerId for \(name)")
                            return
                        }
                        connectionManager.setLocalPlayerID(localPlayerID)
                        gameManager.updatePlayer(localPlayerID, isLocal: true, name: name, image: image)
                    }
#endif
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
    // Utiliser un toggle pour l'intensité de l'usure, activé par défaut
    @AppStorage("wearIntensity") var wearIntensity: Bool = true
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
    
    // Sauvegarde des couleurs activables pour le tirage aléatoire
    @AppStorage("enabledRandomColors") private var enabledRandomColorsData: Data?
    
    var enabledRandomColors: [Bool] {
        get {
            if let data = enabledRandomColorsData,
               let decoded = try? JSONDecoder().decode([Bool].self, from: data),
               decoded.count == GameConstants.feltColors.count {
                return decoded
            } else {
                // Initialiser avec toutes les couleurs sélectionnées par défaut
                return Array(repeating: true, count: GameConstants.feltColors.count)
            }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                enabledRandomColorsData = data
            }
        }
    }
}

struct PreferencesView: View {
    @EnvironmentObject var preferences: Preferences

    var body: some View {
        VStack {
            Form {
                // Section pour les couleurs du tapis
                Section(header: Text("Couleurs du tapis")
                            .font(.headline)
                            .padding(.vertical, 4)) {
                    ForEach(0..<GameConstants.feltColors.count, id: \.self) { idx in
                        Toggle(isOn: Binding<Bool>(
                            get: { preferences.enabledRandomColors.indices.contains(idx) ? preferences.enabledRandomColors[idx] : false },
                            set: { newValue in
                                var current = preferences.enabledRandomColors
                                if current.indices.contains(idx) {
                                    current[idx] = newValue
                                } else {
                                    current = Array(repeating: false, count: GameConstants.feltColors.count)
                                    current[idx] = newValue
                                }
                                preferences.enabledRandomColors = current
                            }
                        )) {
                            HStack {
                                Circle()
                                    .fill(GameConstants.feltColors[idx])
                                    .frame(width: 20, height: 20)
                                Text(feltName(for: idx))
                            }
                        }
                    }
                }
                
                // Section pour le toggle de l'usure du tapis
                Section(header: Text("Usure du tapis")
                            .font(.headline)
                            .padding(.vertical, 4)) {
                    Toggle("Intensité de l'usure", isOn: $preferences.wearIntensity)
                }
            }
            
            // Bouton pour rafraîchir le background
            Button("Rafraîchir le tapis") {
                // Récupérer les indices des couleurs activées
                let enabledIndices = preferences.enabledRandomColors.enumerated().compactMap { (index, isEnabled) in
                    isEnabled ? index : nil
                }
                // Si au moins une couleur est sélectionnée, on choisit aléatoirement l'une d'entre elles
                if let newIndex = enabledIndices.randomElement() {
                    preferences.selectedFeltIndex = newIndex
                }
            }
            .padding(.top)
        }
        .padding()
        // Ajuste la taille de la fenêtre à son contenu
        .fixedSize()
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
