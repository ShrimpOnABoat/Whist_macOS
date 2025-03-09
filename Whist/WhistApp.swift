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
        .commands {
            Group {
                ScoresMenuCommands()
                DatabaseMenuCommands()
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
    }
    
    // Add your commands in the computed property below.
//    var commands: some Commands {
//        Group {
//            ScoresMenuCommands()
//            DatabaseMenuCommands()
//        }
//    }
}

struct ScoresMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    
    var body: some Commands {
        CommandGroup(replacing: .windowList) {
            Button("Voir les scores") {
                openWindow(id: "ScoresWindow")
            }
            .keyboardShortcut("s", modifiers: [.command])
        }
    }
}

struct DatabaseMenuCommands: Commands {
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
            .keyboardShortcut("r", modifiers: [.command, .shift])
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

// MARK: TEST APP

//import SwiftUI
//import CloudKit
//
//class CloudKitManager: ObservableObject {
//    private let messageRecordType = "Message"
//    private let scoreRecordType = "GameScore"
//    private let cloudKitContainerIdentifier = "iCloud.com.Tony.WhistTest"
//    private let database: CKDatabase
//
//    @Published var fetchedMessage: String = ""
//    @Published var fetchedScores: [GameScore] = []
//
//    init() {
//        let container = CKContainer(identifier: cloudKitContainerIdentifier)
//        self.database = container.privateCloudDatabase
//    }
//
//    func saveMessage(_ message: String) {
//        let record = CKRecord(recordType: messageRecordType)
//        record["text"] = message as CKRecordValue
//
//        database.save(record) { _, error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    let bundleID = Bundle.main.bundleIdentifier ?? "Unknown Bundle ID"
//                    self.fetchedMessage = """
//                    Error saving message:
//                    \(error.localizedDescription)
//                    Bundle ID: \(bundleID)
//                    CloudKit Container: \(self.cloudKitContainerIdentifier)
//                    """
//                    print(self.fetchedMessage)
//                } else {
//                    self.fetchedMessage = "Message saved!"
//                }
//            }
//        }
//    }
//
//    func saveScore(_ score: GameScore) {
//        let record = CKRecord(recordType: scoreRecordType)
//        record["date"] = score.date as CKRecordValue
//        record["gg_score"] = score.ggScore as CKRecordValue
//        record["dd_score"] = score.ddScore as CKRecordValue
//        record["toto_score"] = score.totoScore as CKRecordValue
//        record["gg_position"] = score.ggPosition as CKRecordValue?
//        record["dd_position"] = score.ddPosition as CKRecordValue?
//        record["toto_position"] = score.totoPosition as CKRecordValue?
//        record["gg_consecutive_wins"] = score.ggConsecutiveWins as CKRecordValue?
//        record["dd_consecutive_wins"] = score.ddConsecutiveWins as CKRecordValue?
//        record["toto_consecutive_wins"] = score.totoConsecutiveWins as CKRecordValue?
//
//        database.save(record) { _, error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    let bundleID = Bundle.main.bundleIdentifier ?? "Unknown Bundle ID"
//                    self.fetchedMessage = """
//                    Error saving message:
//                    \(error.localizedDescription)
//                    Bundle ID: \(bundleID)
//                    CloudKit Container: \(self.cloudKitContainerIdentifier)
//                    """
//                    print(self.fetchedMessage)
//                } else {
//                    self.fetchedMessage = "Score saved!"
//                }
//            }
//        }
//    }
//
//    func fetchMessage() {
//        let query = CKQuery(recordType: messageRecordType, predicate: NSPredicate(value: true))
//        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//
//        database.perform(query, inZoneWith: nil) { records, error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    let bundleID = Bundle.main.bundleIdentifier ?? "Unknown Bundle ID"
//                    self.fetchedMessage = """
//                    Error fetching message:
//                    \(error.localizedDescription)
//                    Bundle ID: \(bundleID)
//                    CloudKit Container: \(self.cloudKitContainerIdentifier)
//                    """
//                    print(self.fetchedMessage)
//                } else if let record = records?.first, let text = record["text"] as? String {
//                    self.fetchedMessage = text
//                } else {
//                    self.fetchedMessage = "No message found"
//                }
//            }
//        }
//    }
//
//    func fetchGameScores() {
//        let query = CKQuery(recordType: scoreRecordType, predicate: NSPredicate(value: true))
//        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
//
//        database.perform(query, inZoneWith: nil) { records, error in
//            DispatchQueue.main.async {
//                if let error = error {
//                    let bundleID = Bundle.main.bundleIdentifier ?? "Unknown Bundle ID"
//                    let message = """
//                    Error saving message:
//                    \(error.localizedDescription)
//                    Bundle ID: \(bundleID)
//                    CloudKit Container: \(self.cloudKitContainerIdentifier)
//                    """
//                    print(message)
//                } else {
//                    self.fetchedScores = records?.compactMap { record in
//                        guard let date = record["date"] as? Date,
//                              let ggScore = record["gg_score"] as? Int,
//                              let ddScore = record["dd_score"] as? Int,
//                              let totoScore = record["toto_score"] as? Int else { return nil }
//                        return GameScore(
//                            date: date,
//                            ggScore: ggScore,
//                            ddScore: ddScore,
//                            totoScore: totoScore,
//                            ggPosition: record["gg_position"] as? Int,
//                            ddPosition: record["dd_position"] as? Int,
//                            totoPosition: record["toto_position"] as? Int,
//                            ggConsecutiveWins: record["gg_consecutive_wins"] as? Int,
//                            ddConsecutiveWins: record["dd_consecutive_wins"] as? Int,
//                            totoConsecutiveWins: record["toto_consecutive_wins"] as? Int
//                        )
//                    } ?? []
//                    print("Number of records fetched: \(self.fetchedScores.count)")
//                }
//            }
//        }
//    }
//}
//
//struct ContentView2: View {
//    @StateObject private var cloudKitManager = CloudKitManager()
//    @State private var inputText: String = ""
//
//    var body: some View {
//        VStack(spacing: 20) {
//            TextField("Enter a message", text: $inputText)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//                .padding()
//
//            Button("Save to CloudKit") {
//                cloudKitManager.saveMessage(inputText)
//            }
//            .padding()
//
//            Button("Generate & Save Random GameScore") {
//                let randomScore = GameScore(
//                    date: Date(),
//                    ggScore: Int.random(in: 0...100),
//                    ddScore: Int.random(in: 0...100),
//                    totoScore: Int.random(in: 0...100),
//                    ggPosition: Int.random(in: 1...3),
//                    ddPosition: Int.random(in: 1...3),
//                    totoPosition: Int.random(in: 1...3),
//                    ggConsecutiveWins: Int.random(in: 0...10),
//                    ddConsecutiveWins: Int.random(in: 0...10),
//                    totoConsecutiveWins: Int.random(in: 0...10)
//                )
//                cloudKitManager.saveScore(randomScore)
//            }
//            .padding()
//
//            Button("Fetch from CloudKit") {
//                cloudKitManager.fetchMessage()
//            }
//            .padding()
//
//            Button("Fetch GameScores") {
//                cloudKitManager.fetchGameScores()
//            }
//            .padding()
//
//
//            Text("Fetched Message: \(cloudKitManager.fetchedMessage)")
//                .padding()
//
//            List(cloudKitManager.fetchedScores) { score in
//                VStack(alignment: .leading) {
//                    Text("Date: \(score.date)")
//                    Text("GG Score: \(score.ggScore), DD Score: \(score.ddScore), Toto Score: \(score.totoScore)")
//                }
//            }
//        }
//        .frame(width: 400, height: 600)
//    }
//}
//
//@main
//struct CloudKitApp: App {
//    var body: some Scene {
//        WindowGroup {
//            ContentView2()
//        }
//    }
//}
