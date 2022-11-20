//
//  NIService.swift
//  GoCamping
//
//  Created by National Team on 16.11.2022.
//

import Foundation
import NearbyInteraction

class NIService: NSObject {
  @Published var distance: Float?
  
  static let shared = NIService()
  
  private var session: NISession?
  
  var discoveryTokenData: Data? {
    guard let token = session?.discoveryToken,
          let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
      return nil
    }
    
    return data
  }
  
  func start() {
    session = NISession()
    session?.delegate = self
  }
  
  private override init() {
  }
  
  func runSession(data: Data) {
    guard let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
      return
    }
    let configuration = NINearbyPeerConfiguration(peerToken: token)
    session?.run(configuration)
  }
}

extension NIService: NISessionDelegate {
  func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
    distance = nearbyObjects.first?.distance
  }
}
