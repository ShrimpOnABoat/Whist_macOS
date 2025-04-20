//
//  WhistApp.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Entry point of the application.

import SwiftUI
import Firebase
import FirebaseAppCheck

@main
struct WhistApp: App {
    @StateObject var preferences: Preferences
    @StateObject var gameManager: GameManager

    // ADD: AppDelegate needed for GameKit listener on macOS
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Configure Firebase
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        FirebaseApp.configure()

        // Debug: reset stored playerId so identity prompt shows every launch
        UserDefaults.standard.removeObject(forKey: "playerId")

        // Initialize preferences
        let prefs = Preferences()

        // Use singleton instances for signaling and P2P
        let signaling = FirebaseSignalingManager.shared
        let connection = P2PConnectionManager.shared

        // Initialize the core game manager with our custom matchmaking
        let manager = GameManager(connectionManager: connection,
                                  signalingManager: signaling,
                                  preferences: prefs)

        // Wire up state objects
        _preferences = StateObject(wrappedValue: prefs)
        _gameManager = StateObject(wrappedValue: manager)
    }
    
    var body: some Scene {
        WindowGroup {
            if preferences.playerId.isEmpty {
                IdentityPromptView(playerId: $preferences.playerId)
                    .environmentObject(preferences)
            } else {
                ContentView()
                    .environmentObject(gameManager)
                    .environmentObject(preferences)
                    .onAppear {
                        if let window = NSApplication.shared.windows.first {
                            window.contentAspectRatio = NSSize(width: 4, height: 3)
                            gameManager.startNetworkingIfNeeded()

                        }
                    }
            }
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
            Group {
                ScoresMenuCommands()
                if preferences.playerId == "toto" {
                    DatabaseMenuCommands()
                }
            }
        }

        
        Settings {
            PreferencesView()
                .environmentObject(preferences)
        }
        
        // Secondary window for ScoresView with an identifier.
        Window("Scores", id: "ScoresWindow") {
            ScoresView()
                .environmentObject(gameManager)
        }
        .commandsRemoved()
    }
}

struct ScoresMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    
    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button("Voir les scores") {
                openWindow(id: "ScoresWindow")
            }
            .keyboardShortcut("s", modifiers: [.command])
            Divider()
        }
    }
}

struct DatabaseMenuCommands: Commands {
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var gameManager: GameManager
    
    var body: some Commands {
            CommandMenu("Database") {
                Button("Restore Database from Backup") {
                    let backupDirectory = URL(fileURLWithPath: "/Users/tonybuffard/Library/Containers/com.Tony.Whist/Data/Documents/scores/")
                    
                    let scoresManager = ScoresManager()
                    
                    scoresManager.restoreBackup(from: backupDirectory) { restoreResult in
                        switch restoreResult {
                        case .failure(let error):
                            logger.log("Error restoring backup: \(error.localizedDescription)")
                        case .success:
                            logger.log("Database restored successfully.")
                        }
                    }
                }
                
                Button("Clear Saved Game") {
                    gameManager.clearSavedGameState()
                }
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
    @AppStorage("playerId") var playerId: String = ""
    
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
            
            Form {
                Section(header: Text("Identité du joueur")
                            .font(.headline)
                            .padding(.vertical, 4)) {
                    if preferences.playerId.isEmpty {
                        Text("Veuillez choisir votre identité")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Picker("", selection: $preferences.playerId) {
                        ForEach(["dd", "gg", "toto"], id: \.self) { id in
                            Text(id).tag(id)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
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

struct IdentityPromptView: View {
    @Binding var playerId: String
    let identities = ["dd", "gg", "toto"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Choisissez votre identité")
                .font(.headline)
            Picker("Identité", selection: $playerId) {
                ForEach(identities, id: \.self) { id in
                    Text(id).tag(id)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
        }
        .frame(width: 300, height: 150)
        .padding()
    }
}
