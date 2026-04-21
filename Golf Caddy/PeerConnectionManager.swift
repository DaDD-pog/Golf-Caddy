import Foundation
import MultipeerConnectivity
import Combine
import UIKit

struct GolfSyncData: Codable {
    let holeNumber: Int
    let totalHoles: Int
    let par: Int
    let frontYards: Int
    let centerYards: Int
    let backYards: Int
    let currentScore: Int
    let totalScore: Int
    let pinDistance: Int?
}

struct ScoreUpdateMessage: Codable {
    let id: UUID
    let holeIndex: Int
    let score: Int
}

struct HoleChangeMessage: Codable {
    let id: UUID
    let holeIndex: Int
}

struct SyncEnvelope: Codable {
    let type: String
    let golfData: GolfSyncData?
    let scoreUpdate: ScoreUpdateMessage?
    let holeChange: HoleChangeMessage?
}

class PeerConnectionManager: NSObject, ObservableObject {
    
    private let serviceType = "golf-caddy"
    
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    @Published var connectedPeerName: String = "None"
    @Published var connectionStatus: String = "Not Connected"
    @Published var foundPeers: [MCPeerID] = []
    
    @Published var latestGolfData: GolfSyncData?
    @Published var receivedScoreUpdate: ScoreUpdateMessage?
    @Published var receivedHoleChange: HoleChangeMessage?
    
    override init() {
        super.init()
        
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session.delegate = self
    }
    
    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        connectionStatus = "Hosting..."
    }
    
    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        if session.connectedPeers.isEmpty {
            connectionStatus = "Not Connected"
            connectedPeerName = "None"
        }
    }
    
    func startBrowsing() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        connectionStatus = "Browsing..."
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        
        if session.connectedPeers.isEmpty {
            connectionStatus = "Not Connected"
            connectedPeerName = "None"
        }
    }
    
    func invite(_ peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 15)
        connectionStatus = "Connecting..."
    }
    
    func disconnect() {
        stopBrowsing()
        stopHosting()
        session.disconnect()
        foundPeers = []
        connectedPeerName = "None"
        connectionStatus = "Not Connected"
        latestGolfData = nil
        receivedScoreUpdate = nil
        receivedHoleChange = nil
    }
    
    func sendGolfData(_ data: GolfSyncData) {
        let envelope = SyncEnvelope(
            type: "golfData",
            golfData: data,
            scoreUpdate: nil,
            holeChange: nil
        )
        sendEnvelope(envelope)
    }
    
    func sendScoreUpdate(holeIndex: Int, score: Int) {
        let message = ScoreUpdateMessage(
            id: UUID(),
            holeIndex: holeIndex,
            score: score
        )
        
        let envelope = SyncEnvelope(
            type: "scoreUpdate",
            golfData: nil,
            scoreUpdate: message,
            holeChange: nil
        )
        sendEnvelope(envelope)
    }
    
    func sendHoleChange(holeIndex: Int) {
        let message = HoleChangeMessage(
            id: UUID(),
            holeIndex: holeIndex
        )
        
        let envelope = SyncEnvelope(
            type: "holeChange",
            golfData: nil,
            scoreUpdate: nil,
            holeChange: message
        )
        sendEnvelope(envelope)
    }
    
    private func sendEnvelope(_ envelope: SyncEnvelope) {
        guard !session.connectedPeers.isEmpty else { return }
        
        do {
            let encodedData = try JSONEncoder().encode(envelope)
            try session.send(encodedData, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Failed to send data: \(error.localizedDescription)")
        }
    }
}

extension PeerConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                self.connectionStatus = "Not Connected"
                self.connectedPeerName = "None"
            case .connecting:
                self.connectionStatus = "Connecting..."
                self.connectedPeerName = peerID.displayName
            case .connected:
                self.connectionStatus = "Connected"
                self.connectedPeerName = peerID.displayName
            @unknown default:
                self.connectionStatus = "Unknown"
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let envelope = try JSONDecoder().decode(SyncEnvelope.self, from: data)
            
            DispatchQueue.main.async {
                switch envelope.type {
                case "golfData":
                    self.latestGolfData = envelope.golfData
                case "scoreUpdate":
                    self.receivedScoreUpdate = envelope.scoreUpdate
                case "holeChange":
                    self.receivedHoleChange = envelope.holeChange
                default:
                    break
                }
            }
        } catch {
            print("Failed to decode data: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {}
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {}
}

extension PeerConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
            self.connectedPeerName = peerID.displayName
        }
        
        invitationHandler(true, session)
    }
}

extension PeerConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            if !self.foundPeers.contains(peerID) {
                self.foundPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.foundPeers.removeAll { $0 == peerID }
        }
    }
}
