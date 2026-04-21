import SwiftUI
import MultipeerConnectivity

struct ContentView: View {
    
    @StateObject private var peerManager = PeerConnectionManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Golf Caddy Companion")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        Text("Status: \(peerManager.connectionStatus)")
                            .foregroundColor(peerManager.connectionStatus == "Connected" ? .green : .secondary)
                        
                        Text("Connected To: \(peerManager.connectedPeerName)")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(16)
                    
                    if peerManager.foundPeers.isEmpty {
                        Text("No nearby iPads found yet.")
                            .foregroundColor(.secondary)
                    } else {
                        List(peerManager.foundPeers, id: \.self) { peer in
                            Button {
                                peerManager.invite(peer)
                            } label: {
                                HStack {
                                    Text(peer.displayName)
                                    Spacer()
                                    Text("Connect")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .frame(height: 250)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Start Browsing") {
                            peerManager.startBrowsing()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Disconnect") {
                            peerManager.disconnect()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    if let data = peerManager.latestGolfData {
                        VStack(spacing: 16) {
                            Text("Live Round Data")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 10) {
                                dataRow(title: "Hole", value: "\(data.holeNumber) / \(data.totalHoles)")
                                dataRow(title: "Par", value: "\(data.par)")
                                dataRow(title: "Front", value: "\(data.frontYards) yd")
                                dataRow(title: "Center", value: "\(data.centerYards) yd")
                                dataRow(title: "Back", value: "\(data.backYards) yd")
                                dataRow(title: "Hole Score", value: "\(data.currentScore)")
                                dataRow(title: "Total Score", value: "\(data.totalScore)")
                                
                                if let pinDistance = data.pinDistance {
                                    dataRow(title: "Pin", value: "\(pinDistance) yd")
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(16)
                        
                        companionControls(data: data)
                    } else {
                        VStack(spacing: 8) {
                            Text("No golf data received yet.")
                                .font(.headline)
                            Text("Connect to the iPad and open the main golf screen.")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(16)
                    }
                }
                .padding()
            }
            .navigationTitle("Companion")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func companionControls(data: GolfSyncData) -> some View {
        VStack(spacing: 16) {
            Text("Remote Controls")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                Button("Previous Hole") {
                    let newIndex = data.holeNumber - 2
                    if newIndex >= 0 {
                        peerManager.sendHoleChange(holeIndex: newIndex)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(data.holeNumber <= 1)
                
                Button("Next Hole") {
                    let newIndex = data.holeNumber
                    if newIndex < data.totalHoles {
                        peerManager.sendHoleChange(holeIndex: newIndex)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(data.holeNumber >= data.totalHoles)
            }
            
            VStack(spacing: 12) {
                Text("Adjust Score")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Button {
                        let newScore = data.currentScore - 1
                        peerManager.sendScoreUpdate(
                            holeIndex: data.holeNumber - 1,
                            score: newScore
                        )
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                    }
                    
                    Text("\(data.currentScore)")
                        .font(.system(size: 34, weight: .bold))
                        .frame(minWidth: 50)
                    
                    Button {
                        let newScore = data.currentScore + 1
                        peerManager.sendScoreUpdate(
                            holeIndex: data.holeNumber - 1,
                            score: newScore
                        )
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }
    
    private func dataRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    ContentView()
}
