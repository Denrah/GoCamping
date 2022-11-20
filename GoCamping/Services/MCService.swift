//
//  MCService.swift
//  GoCamping
//
//  Created by National Team on 12.11.2022.
//

import MultipeerConnectivity
import Combine

enum MCEvent: Codable {
  case speakStart, speakEnd, chunk(data: Data), nearbyToken(data: Data)
}

private extension String {
  static let serviceType = "go-camping-app"
}

protocol MCServiceDelegate: AnyObject {
  func mcService(_ service: MCService, didReceiveInvitationFrom peer: MCPeerID)
}

class MCService: NSObject, ObservableObject {
  weak var delegate: MCServiceDelegate?
  
  static let shared = MCService()
  
  var displayName: String = UIDevice.current.name
  
  var onDidReceivedEvent: ((MCEvent) -> Void)?
  
  @Published private(set) var foundPeers = Set<MCPeerID>()
  @Published private(set) var state: MCSessionState?
  
  private var peerID: MCPeerID?
  private var session: MCSession?
  private var advertiser: MCNearbyServiceAdvertiser?
  private var browser: MCNearbyServiceBrowser?
  
  private var invitationHandler: ((Bool, MCSession?) -> Void)?
  
  private override init() {
  }
  
  func start(with name: String) {
    let peerID = MCPeerID(displayName: name)
    self.peerID = peerID
    
    foundPeers.removeAll()
    
    session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
    session?.delegate = self
    
    advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: .serviceType)
    advertiser?.delegate = self
    
    browser = MCNearbyServiceBrowser(peer: peerID, serviceType: .serviceType)
    browser?.delegate = self
    
    startObserving()
  }
  
  func startObserving() {
    advertiser?.startAdvertisingPeer()
    browser?.startBrowsingForPeers()
  }
  
  func stopObserving() {
    advertiser?.stopAdvertisingPeer()
    browser?.stopBrowsingForPeers()
  }
  
  func handleInvitation(accept: Bool) {
    invitationHandler?(accept, session)
  }
  
  func invite(peer: MCPeerID) {
    guard let session = session else { return }
    state = nil
    browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
  }
  
  func send(event: MCEvent) {
    guard let data = try? JSONEncoder().encode(event) else {
      return
    }
    try? session?.send(data, toPeers: Array(foundPeers), with: .reliable)
  }
  
  func disconnect() {
    session?.disconnect()
    state = nil
  }
}

// MARK: - MCSessionDelegate

extension MCService: MCSessionDelegate {
  func session(_ session: MCSession,
               peer peerID: MCPeerID,
               didChange state: MCSessionState) {
    self.state = state
    
    if state == .notConnected {
      session.disconnect()
    }
  }
  
  func session(_ session: MCSession,
               didReceive data: Data,
               fromPeer peerID: MCPeerID) {
    guard let event = try? JSONDecoder().decode(MCEvent.self, from: data) else {
      return
    }
    onDidReceivedEvent?(event)
  }
  
  func session(_ session: MCSession,
               didReceive stream: InputStream,
               withName streamName: String,
               fromPeer peerID: MCPeerID) {
    
  }
  
  func session(_ session: MCSession,
               didStartReceivingResourceWithName resourceName: String,
               fromPeer peerID: MCPeerID,
               with progress: Progress) {
    
  }
  
  func session(_ session: MCSession,
               didFinishReceivingResourceWithName resourceName: String,
               fromPeer peerID: MCPeerID,
               at localURL: URL?,
               withError error: Error?) {
    
  }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MCService: MCNearbyServiceAdvertiserDelegate {
  func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                  didReceiveInvitationFromPeer peerID: MCPeerID,
                  withContext context: Data?,
                  invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    self.invitationHandler = invitationHandler
    delegate?.mcService(self, didReceiveInvitationFrom: peerID)
  }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MCService: MCNearbyServiceBrowserDelegate {
  func browser(_ browser: MCNearbyServiceBrowser,
               foundPeer peerID: MCPeerID,
               withDiscoveryInfo info: [String : String]?) {
    foundPeers.insert(peerID)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser,
               lostPeer peerID: MCPeerID) {
    foundPeers.remove(peerID)
  }
}
