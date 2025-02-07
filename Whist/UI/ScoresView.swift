//
//  ScoresView.swift
//  Whist
//
//  Created by Tony Buffard on 2025-02-06.
//  Updated by ChatGPT on 2025-02-06.
//

import SwiftUI

struct ScoresView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedTab: ScoreTab = .summary

    var body: some View {
        VStack {
            // Year selection controls
            HStack {
                Button(action: { selectedYear -= 1 }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(BorderlessButtonStyle())

                Text(String(selectedYear))
                    .font(.title)
                    .bold()

                Button(action: { selectedYear += 1 }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding()

            // Tab selection: Summary vs Details
            Picker("Mode", selection: $selectedTab) {
                Text("Résumé").tag(ScoreTab.summary)
                Text("Détails").tag(ScoreTab.details)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)

            // Display content based on the selected tab
            if selectedTab == .summary {
                SummaryView(year: selectedYear)
            } else {
                DetailedScoresView(year: selectedYear)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 700, minHeight: 500)
    }
}

enum ScoreTab {
    case summary, details
}

// MARK: - Summary (Résumé) View

struct MonthlySummary: Identifiable {
    let id = UUID()
    let month: String
    let ggPoints: Int
    let ddPoints: Int
    let totoPoints: Int
    let ggTally: Int
    let ddTally: Int
    let totoTally: Int
}

struct SummaryView: View {
    let year: Int

    // Compute the monthly summaries by grouping games per month and awarding points:
    var monthlySummaries: [MonthlySummary] {
        computeMonthlySummaries(for: year)
    }

    // Compute overall totals from the monthly summaries.
    var total: (gg: Int, dd: Int, toto: Int, ggTally: Int, ddTally: Int, totoTally: Int) {
        var total = (gg: 0, dd: 0, toto: 0, ggTally: 0, ddTally: 0, totoTally: 0)
        for summary in monthlySummaries {
            total.gg += summary.ggPoints
            total.dd += summary.ddPoints
            total.toto += summary.totoPoints
            total.ggTally += summary.ggTally
            total.ddTally += summary.ddTally
            total.totoTally += summary.totoTally
        }
        return total
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Scores pour \(String(year))")
                .font(.headline)
                .padding(.bottom, 5)

            // Table header row
            HStack {
                Text("Mois").frame(width: 100, alignment: .leading)
                Spacer()
                Text("GG").frame(width: 40, alignment: .center)
                Text("DD").frame(width: 40, alignment: .center)
                Text("Toto").frame(width: 40, alignment: .center)
                Rectangle()
                    .frame(width: 1, height: 20)
                    .foregroundColor(.gray)
                    .opacity(0.5)
                Text("GG").frame(width: 40, alignment: .center)
                Text("DD").frame(width: 40, alignment: .center)
                Text("Toto").frame(width: 40, alignment: .center)
            }
            .font(.subheadline)
            .padding(.vertical, 4)

            Divider()

            // Data rows
            ForEach(monthlySummaries) { summary in
                HStack {
                    Text(summary.month).frame(width: 100, alignment: .leading)
                    Spacer()
                    Text("\(summary.ggPoints)").frame(width: 40, alignment: .center)
                    Text("\(summary.ddPoints)").frame(width: 40, alignment: .center)
                    Text("\(summary.totoPoints)").frame(width: 40, alignment: .center)
                    Rectangle()
                        .frame(width: 1, height: 20)
                        .foregroundColor(.gray)
                        .opacity(0.5)
                    Text("\(summary.ggTally)")
                        .frame(width: 40, alignment: .center)
                        .background(Color.yellow.opacity(0.3))
                    Text("\(summary.ddTally)")
                        .frame(width: 40, alignment: .center)
                        .background(Color.yellow.opacity(0.3))
                    Text("\(summary.totoTally)")
                        .frame(width: 40, alignment: .center)
                        .background(Color.yellow.opacity(0.3))
                }
                .padding(.vertical, 2)
            }

            Divider()

            // Total row
            HStack {
                Text("Total").frame(width: 100, alignment: .leading)
                Spacer()
                Text("\(total.gg)").frame(width: 40, alignment: .center)
                Text("\(total.dd)").frame(width: 40, alignment: .center)
                Text("\(total.toto)").frame(width: 40, alignment: .center)
                Text("\(total.ggTally)").frame(width: 40, alignment: .center)
                Text("\(total.ddTally)").frame(width: 40, alignment: .center)
                Text("\(total.totoTally)").frame(width: 40, alignment: .center)
            }
            .font(.headline)
            .padding(.vertical, 4)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.windowBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1))
    }
}

/// Computes the monthly summaries for the given year by loading the scores and grouping them.
/// Update the monthly summaries function to use the new point calculation.
func computeMonthlySummaries(for year: Int) -> [MonthlySummary] {
    let scores = ScoresManager.shared.loadScores(for: year)
    let monthNames = [
        1: "Janvier", 2: "Février", 3: "Mars", 4: "Avril",
        5: "Mai", 6: "Juin", 7: "Juillet", 8: "Août",
        9: "Septembre", 10: "Octobre", 11: "Novembre", 12: "Décembre"
    ]

    var monthlyData: [Int: (gg: Int, dd: Int, toto: Int)] = [:]

    for score in scores {
        let calendar = Calendar.current
        guard calendar.component(.year, from: score.date) == year else { continue }
        let gameMonth = calendar.component(.month, from: score.date)
        
        if monthlyData[gameMonth] == nil {
            monthlyData[gameMonth] = (0, 0, 0)
        }
        
        let points = calculateGamePoints(for: score)
        monthlyData[gameMonth]!.gg += points.gg
        monthlyData[gameMonth]!.dd += points.dd
        monthlyData[gameMonth]!.toto += points.toto
    }

    var summaries: [MonthlySummary] = []
    for (month, points) in monthlyData {
        let tallies = calculateTallies(for: points)
        if let monthName = monthNames[month] {
            summaries.append(MonthlySummary(month: monthName,
                                            ggPoints: points.gg,
                                            ddPoints: points.dd,
                                            totoPoints: points.toto,
                                            ggTally: tallies.gg,
                                            ddTally: tallies.dd,
                                            totoTally: tallies.toto))
        }
    }
    // Sort summaries in month order.
    let order = ["Janvier", "Février", "Mars", "Avril", "Mai", "Juin",
                 "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"]
    summaries.sort { order.firstIndex(of: $0.month)! < order.firstIndex(of: $1.month)! }
    return summaries
}

/// Calculate the game points for a single GameScore according to tie-breaking rules.
func calculateGamePoints(for game: GameScore) -> (gg: Int, dd: Int, toto: Int) {
    // If position information is available, use it.
    if let ggPos = game.ggPosition, let ddPos = game.ddPosition, let totoPos = game.totoPosition {
        let positions = [("gg", ggPos), ("dd", ddPos), ("toto", totoPos)]
        let sorted = positions.sorted { $0.1 < $1.1 } // lower is better
        var points = (gg: 0, dd: 0, toto: 0)
        // First gets 2 points, second gets 1, third gets 0.
        switch sorted[0].0 {
        case "gg": points.gg = 2
        case "dd": points.dd = 2
        case "toto": points.toto = 2
        default: break
        }
        switch sorted[1].0 {
        case "gg": points.gg = 1
        case "dd": points.dd = 1
        case "toto": points.toto = 1
        default: break
        }
        return points
    } else {
        // Positions not available, so use score values.
        let scores: [(String, Int)] = [("gg", game.ggScore), ("dd", game.ddScore), ("toto", game.totoScore)]
        let sorted = scores.sorted { $0.1 > $1.1 } // descending order (highest first)
        
        // Case 1: All three scores are tied.
        if sorted[0].1 == sorted[1].1 && sorted[1].1 == sorted[2].1 {
            return (gg: 2, dd: 2, toto: 2)
        }
        // Case 2: Tie for first (top two are equal).
        else if sorted[0].1 == sorted[1].1 {
            var points = (gg: 0, dd: 0, toto: 0)
            // Award 2 points to any player whose score equals the top score; the remaining player gets 0.
            for entry in scores {
                if entry.1 == sorted[0].1 {
                    switch entry.0 {
                    case "gg": points.gg = 2
                    case "dd": points.dd = 2
                    case "toto": points.toto = 2
                    default: break
                    }
                }
            }
            return points
        }
        // Case 3: Tie for second (i.e. first is clear, but second and third are equal).
        else if sorted[1].1 == sorted[2].1 {
            var points = (gg: 0, dd: 0, toto: 0)
            // Clear winner gets 2 points.
            switch sorted[0].0 {
            case "gg": points.gg = 2
            case "dd": points.dd = 2
            case "toto": points.toto = 2
            default: break
            }
            // Both tied players get 1 point each.
            for entry in sorted[1...2] {
                switch entry.0 {
                case "gg": points.gg = 1
                case "dd": points.dd = 1
                case "toto": points.toto = 1
                default: break
                }
            }
            return points
        }
        // Case 4: No ties.
        else {
            var points = (gg: 0, dd: 0, toto: 0)
            switch sorted[0].0 {
            case "gg": points.gg = 2
            case "dd": points.dd = 2
            case "toto": points.toto = 2
            default: break
            }
            switch sorted[1].0 {
            case "gg": points.gg = 1
            case "dd": points.dd = 1
            case "toto": points.toto = 1
            default: break
            }
            // Third automatically gets 0.
            return points
        }
    }
}

/// Given the total points for a month, calculate the tally for each player.
/// The highest gets 2 points and the second highest gets 1 point.
func calculateTallies(for points: (gg: Int, dd: Int, toto: Int)) -> (gg: Int, dd: Int, toto: Int) {
    let values = [points.gg, points.dd, points.toto]
    let sorted = values.sorted(by: >)
    let tallyFor = { (score: Int) -> Int in
        if score == sorted[0] {
            return 2
        } else if score == sorted[1] {
            return 1
        } else {
            return 0
        }
    }
    return (gg: tallyFor(points.gg),
            dd: tallyFor(points.dd),
            toto: tallyFor(points.toto))
}

// MARK: - Detailed Scores View

struct DetailedScoresView: View {
    let year: Int

    // Loads all game scores for the given year.
    var detailedScores: [GameScore] {
        let allScores = ScoresManager.shared.loadScores(for: year)
        let calendar = Calendar.current
        return allScores.filter { calendar.component(.year, from: $0.date) == year }
                        .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Détails des scores pour \(String(year))")
                .font(.headline)
                .padding(.bottom, 5)

            // Table header
            HStack {
                Text("Date").frame(width: 100, alignment: .leading)
                Spacer()
                Text("GG").frame(width: 50, alignment: .center)
                Text("DD").frame(width: 50, alignment: .center)
                Text("Toto").frame(width: 50, alignment: .center)
            }
            .font(.subheadline)
            .padding(.vertical, 4)

            Divider()

            List(detailedScores) { score in
                HStack {
                    Text(dateFormatter.string(from: score.date))
                        .frame(width: 100, alignment: .leading)
                    Spacer()
                    
                    // Use the helper function to compute the points for the game,
                    // which incorporates tie-breaking rules using positions if available.
                    let gamePoints = calculateGamePoints(for: score)
                    
                    // Highlighting: blue for a 2-point (winner), green for 1-point, default for 0.
                    let ggColor: Color = (gamePoints.gg == 2) ? .blue : (gamePoints.gg == 1 ? .green : .primary)
                    let ddColor: Color = (gamePoints.dd == 2) ? .blue : (gamePoints.dd == 1 ? .green : .primary)
                    let totoColor: Color = (gamePoints.toto == 2) ? .blue : (gamePoints.toto == 1 ? .green : .primary)
                    
                    Text("\(score.ggScore)")
                        .frame(width: 50, alignment: .center)
                        .foregroundColor(ggColor)
                    Text("\(score.ddScore)")
                        .frame(width: 50, alignment: .center)
                        .foregroundColor(ddColor)
                    Text("\(score.totoScore)")
                        .frame(width: 50, alignment: .center)
                        .foregroundColor(totoColor)
                }
            }
        }
        .padding()
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()

// MARK: - Preview

struct ScoresView_Previews: PreviewProvider {
    static var previews: some View {
        ScoresView()
            .environmentObject(GameManager())
    }
}
