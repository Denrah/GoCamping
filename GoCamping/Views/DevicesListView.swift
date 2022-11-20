//
//  DevicesListView.swift
//  GoCamping
//
//  Created by National Team on 12.11.2022.
//

import SwiftUI
import Combine
import MultipeerConnectivity

class DevicesListViewModel: ObservableObject {
  @Published private(set) var peers: [MCPeerID] = []
  @Published var isAlertPresented = false
  @Published var isRejectAlertPresented = false
  @Published private(set) var invitingPeerName = ""
  @Published private(set) var goNext = false
  
  private let service = MCService.shared
  private var subscriptions = Set<AnyCancellable>()
  
  init() {
    service.delegate = self
    service.$foundPeers.sink { [weak self] peers in
      self?.peers = Array(peers)
    }.store(in: &subscriptions)
    service.$state.receive(on: DispatchQueue.main).sink { [weak self] state in
      switch state {
      case .connected:
        self?.goNext = true
      case .notConnected:
        self?.isRejectAlertPresented = true
      default:
        break
      }
    }.store(in: &subscriptions)
  }
  
  func start() {
    peers.removeAll()
    service.start(with: service.displayName)
  }
  
  func invite(peer: MCPeerID) {
    service.invite(peer: peer)
  }
  
  func acceptInvite() {
    service.handleInvitation(accept: true)
    goNext = true
  }
  
  func rejectInvite() {
    service.handleInvitation(accept: false)
  }
  
  func stop() {
    service.stopObserving()
  }
}

// MARK: - MCServiceDelegate

extension DevicesListViewModel: MCServiceDelegate {
  func mcService(_ service: MCService, didReceiveInvitationFrom peer: MCPeerID) {
    isAlertPresented = true
    invitingPeerName = peer.displayName
  }
}

struct DevicesListView: View {
  @Binding var screen: Screen
  @ObservedObject private var viewModel = DevicesListViewModel()
  
  init(screen: Binding<Screen>) {
    _screen = screen
  }
  
  var body: some View {
    ZStack {
      Color(uiColor: UIColor(red: 0.125, green: 0.094, blue: 0.077, alpha: 1)).ignoresSafeArea()
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack {
          HStack {
            Text("Устройства")
              .font(.system(.largeTitle, design: .rounded))
              .fontWeight(.bold)
              .foregroundColor(Color(uiColor: UIColor(red: 1, green: 0.855, blue: 0.75, alpha: 1)))
            Spacer()
          }
          ForEach(Array(viewModel.peers).indices, id: \.self) { index in
            ZStack {
              Color.black.opacity(0.5).cornerRadius(8)
              HStack {
                Text(viewModel.peers[index].displayName)
                  .font(.system(.body, design: .rounded))
                  .foregroundColor(Color(uiColor: UIColor(red: 1, green: 0.855, blue: 0.75, alpha: 1)))
                Spacer()
              }.padding(16)
              
            }.onTapGesture {
              viewModel.invite(peer: viewModel.peers[index])
            }
          }
        }.padding(16)
          .alert("\(viewModel.invitingPeerName) хочет начать с вами переговариваться!",
                 isPresented: $viewModel.isAlertPresented) {
            Button("Принять") {
              viewModel.acceptInvite()
            }
            Button("Отклонить", role: .cancel) {
              viewModel.rejectInvite()
            }
          }
      }.alert("Собеседник отказался от приглашения общаться",
              isPresented: $viewModel.isRejectAlertPresented) {
        Button("ОК") {
          
        }
      }
    }.onAppear {
      viewModel.start()
    }.onChange(of: viewModel.goNext) { newValue in
      if newValue {
        screen = .speaker
        viewModel.stop()
      }
    }
  }
}
