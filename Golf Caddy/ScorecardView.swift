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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Scorecard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Total: \(totalScore)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
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
                            
                            HStack(spacing: 12) {
                                Button {
                                    scores[index] -= 1
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                }
                                
                                Text("\(scores[index])")
                                    .font(.title2)
                                    .frame(minWidth: 30)
                                
                                Button {
                                    scores[index] += 1
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
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
