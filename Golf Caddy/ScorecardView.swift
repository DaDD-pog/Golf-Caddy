import SwiftUI

struct ScorecardView: View {
    let holes: [Hole]
    @Binding var scores: [Int]
    
    var totalScore: Int {
        scores.reduce(0, +)
    }
    
    var totalPar: Int {
        holes.reduce(0) { $0 + $1.par }
    }
    
    var totalRelativeScore: Int {
        holes.enumerated().reduce(0) { partial, item in
            let index = item.offset
            let hole = item.element
            
            guard index < scores.count else { return partial }
            return partial + (scores[index] - hole.par)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Scorecard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Total: \(formattedRelativeScore(totalRelativeScore))")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(relativeScoreColor(totalRelativeScore))
                    
                    Text("Strokes: \(totalScore)")
                        .foregroundColor(.secondary)
                    
                    Text("Course Par: \(totalPar)")
                        .foregroundColor(.secondary)
                }
                .padding(.top)
                
                List {
                    ForEach(Array(holes.enumerated()), id: \.element.id) { index, hole in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hole \(hole.number)")
                                    .font(.headline)
                                Text("Par \(hole.par)")
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(formattedRelativeScore(scores[index] - hole.par))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(relativeScoreColor(scores[index] - hole.par))
                                
                                HStack(spacing: 12) {
                                    Button {
                                        scores[index] -= 1
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                    }
                                    
                                    Text("\(scores[index])")
                                        .font(.title3)
                                        .frame(minWidth: 30)
                                    
                                    Button {
                                        scores[index] += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Scorecard")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func formattedRelativeScore(_ value: Int) -> String {
        if value > 0 {
            return "+\(value)"
        } else {
            return "\(value)"
        }
    }
    
    private func relativeScoreColor(_ value: Int) -> Color {
        if value < 0 {
            return .green
        } else if value > 0 {
            return .red
        } else {
            return .primary
        }
    }
}

#Preview {
    ScorecardView(
        holes: [
            Hole(number: 1, par: 4, frontLatitude: 0, frontLongitude: 0, centerLatitude: 0, centerLongitude: 0, backLatitude: 0, backLongitude: 0),
            Hole(number: 2, par: 3, frontLatitude: 0, frontLongitude: 0, centerLatitude: 0, centerLongitude: 0, backLatitude: 0, backLongitude: 0),
            Hole(number: 3, par: 5, frontLatitude: 0, frontLongitude: 0, centerLatitude: 0, centerLongitude: 0, backLatitude: 0, backLongitude: 0)
        ],
        scores: .constant([4, 3, 5])
    )
}
