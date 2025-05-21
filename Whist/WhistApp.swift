//
//  WhistApp.swift
//  Whist
//
//  Created by Tony Buffard on 2024-11-18.
//  Entry point of the application.

import SwiftUI
import Firebase
import FirebaseAppCheck
import FirebaseAuth

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            Auth.auth().signInAnonymously { authResult, error in
                if let error = error {
                    logger.log("❌ Firebase anonymous sign-in failed: \(error.localizedDescription)")
                } else if let uid = authResult?.user.uid {
                    logger.log("✅ Signed in anonymously with UID: \(uid)")
                }
            }
        }
        logger.log("Firebase UID: \(Auth.auth().currentUser?.uid ?? "nil")")
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings() // Use in-memory cache
        Firestore.firestore().settings = settings
        #if DEBUG // So that I can assign a player for each app
        UserDefaults.standard.removeObject(forKey: "playerId")
        #endif
        
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
            Group {
                if preferences.playerId.isEmpty {
                    IdentityPromptView(playerId: $preferences.playerId)
                } else {
                    ContentView()
                        .onAppear {
                            if let window = NSApplication.shared.windows.first {
                                #if DEBUG
                                window.setFrame(
                                            NSRect(x: window.frame.origin.x,
                                                   y: window.frame.origin.y,
                                                   width: 800,
                                                   height: 600),
                                            display: true
                                        )
                                #endif
                                window.contentAspectRatio = NSSize(width: 4, height: 3)
                                window.minSize = NSSize(width: 800, height: 600)
                            }
                            logger.setLocalPlayer(with: preferences.playerId)
                            PresenceManager.shared.configure(with: preferences.playerId)
                            PresenceManager.shared.startTracking()
                        }
                }
            }
            .environmentObject(preferences)
            .environmentObject(gameManager)
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
            Group {
                ScoresMenuCommands()
                if preferences.playerId == "toto" {
                    DatabaseMenuCommands(preferences: preferences, gameManager: gameManager)
                }
            }
        }
        
        Settings {
            PreferencesView()
                .environmentObject(preferences)
                .environmentObject(gameManager)
        }
        
        // Secondary window for ScoresView with an identifier.
        Window("Scores", id: "ScoresWindow") {
            ScoresView()
                .environmentObject(gameManager)
                .environmentObject(preferences)
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
    let preferences: Preferences
    let gameManager: GameManager
    
    init(preferences: Preferences, gameManager: GameManager) {
        self.preferences = preferences
        self.gameManager = gameManager
    }
    
    var body: some Commands {
        CommandMenu("Database") {
            Button("Restore Database from Backup") {
                let backupDirectory = URL(fileURLWithPath: "/Users/tonybuffard/Library/Containers/com.Tony.Whist/Data/Documents/scores/")

                Task {
                    let scoresManager = ScoresManager.shared // Use shared instance
                    do {
                        try await scoresManager.restoreBackup(from: backupDirectory)
                        // Log success on the main actor
                        await MainActor.run {
                             logger.log("✅ Database restored successfully.")
                        }
                    } catch {
                         // Log error on the main actor
                        await MainActor.run {
                             logger.log("🚨 Error restoring backup: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            Button("Export scores") {
                let exportDirectory = URL(fileURLWithPath: "/Users/tonybuffard/Library/Containers/com.Tony.Whist/Data/Documents/scores/Export")

                Task {
                     let scoresManager = ScoresManager.shared // Use shared instance
                    do {
                         try await scoresManager.exportScoresToLocalDirectory(exportDirectory)
                        // Log success on the main actor
                        await MainActor.run {
                            logger.log("✅ All scores were exported successfully to \(exportDirectory.path).")
                        }
                    } catch {
                         // Log error on the main actor
                         await MainActor.run {
                            logger.log("🚨 Error exporting scores: \(error.localizedDescription)")
                         }
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
    @AppStorage("motif") var motif: Bool = true
    @AppStorage("motifVisibility") var motifVisibility: Double = 0.5
    @AppStorage("patternOpacity") var patternOpacity: Double = 0.5
    @AppStorage("patternScale") private var patternScaleStorage: Double = 0.5
    @AppStorage("enabledRandomColors") private var enabledRandomColorsData: Data?
    #if DEBUG
    @Published var playerId: String = ""
    #else
    @AppStorage("playerId") var playerId: String = ""
    #endif
    
    var patternScale: CGFloat {
        get { CGFloat(patternScaleStorage) }
        set { patternScaleStorage = Double(newValue) }
    }
    
    var currentFelt: Color {
        GameConstants.feltColors[selectedFeltIndex]
    }
    
    // Sauvegarde des couleurs activables pour le tirage aléatoire
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
                Section(header: Text("Détails")
                    .font(.headline)
                    .padding(.vertical, 4)) {
                        Toggle("Usure du tapis", isOn: $preferences.wearIntensity)
                        Toggle("Motifs", isOn: $preferences.motif)
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
