//
//  SpeakerView.swift
//  GoCamping
//
//  Created by National Team on 15.11.2022.
//

import SwiftUI
import Combine
import NearbyInteraction

class PressButton: UIView {
  var onDidTouchStart: (() -> Void)?
  var onDidTouchEnd: (() -> Void)?
  
  init() {
    super.init(frame: .zero)
    backgroundColor = UIColor(red: 0.408, green: 0.322, blue: 0.279, alpha: 1)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    backgroundColor = UIColor(red: 0.938, green: 0.396, blue: 0.125, alpha: 1)
    onDidTouchStart?()
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    backgroundColor = UIColor(red: 0.408, green: 0.322, blue: 0.279, alpha: 1)
    onDidTouchEnd?()
  }
}

struct PressButtonView: UIViewRepresentable {
  private let view = PressButton()
  
  private var onDidTouchStart: (() -> Void)?
  private var onDidTouchEnd: (() -> Void)?
  
  init(viewModel: SpeakerViewModel) {
    onDidTouchStart = { [weak viewModel] in
      viewModel?.isSpeaking = true
    }
    onDidTouchEnd = { [weak viewModel] in
      viewModel?.isSpeaking = false
    }
  }

  func makeUIView(context: Context) -> PressButton {
    view.onDidTouchStart = onDidTouchStart
    view.onDidTouchEnd = onDidTouchEnd
    return view
  }
  
  func updateUIView(_ uiView: PressButton, context: Context) {
    view.onDidTouchStart = onDidTouchStart
    view.onDidTouchEnd = onDidTouchEnd
  }
}

class SpeakerViewModel: ObservableObject {
  @Published var isSpeaking: Bool = false
  @Published var isReceiving: Bool = false
  @Published var isDisconnected: Bool = false
  @Published var distance: String?
  
  var isTransmitting: Bool {
    isSpeaking || isReceiving
  }
  
  private let audioService = AudioService.shared
  private let mcService = MCService.shared
  private let niService = NIService.shared
  
  private var subscriptions = Set<AnyCancellable>()
  
  func start() {
    niService.start()
    
    audioService.setup()
    audioService.onRecord = { [weak self] data in
      self?.mcService.send(event: .chunk(data: data))
    }
    
    mcService.onDidReceivedEvent = { [weak self] event in
      print(event)
      switch event {
      case .speakStart:
        DispatchQueue.main.async {
          self?.isReceiving = true
        }
      case .speakEnd:
        DispatchQueue.main.async {
          self?.isReceiving = false
        }
      case .chunk(let data):
        self?.audioService.addChunk(data: data)
      case .nearbyToken(let data):
        self?.niService.runSession(data: data)
      }
    }
    
    mcService.$state.receive(on: DispatchQueue.main).sink { [weak self] state in
      self?.isDisconnected = state == .notConnected
    }.store(in: &subscriptions)
    
    niService.$distance.receive(on: DispatchQueue.main).sink { [weak self] distance in
      if let distance = distance {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        self?.distance = "Расстояние: \(formatter.string(from: NSNumber(value: distance)) ?? "-") м."
      } else {
        self?.distance = "Расстояние: ??? м."
      }
    }.store(in: &subscriptions)
    
    if #available(iOS 16.0, *) {
      if !NISession.deviceCapabilities.supportsPreciseDistanceMeasurement {
        distance = "Определение расстояния доступно на устройствах с чипом U1 (iPhone 11 и новее)"
      }
    } else {
      if !NISession.isSupported {
        distance = "Определение расстояния доступно на устройствах с чипом U1 (iPhone 11 и новее)"
      }
    }
        
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if let tokenData = self.niService.discoveryTokenData {
        self.mcService.send(event: .nearbyToken(data: tokenData))
      }
    }
  }
  
  func startRecording() {
    guard !isReceiving else { return }
    mcService.send(event: .speakStart)
    audioService.startRecording()
  }
  
  func stopRecording() {
    mcService.send(event: .speakEnd)
    audioService.stopRecording()
  }
}

struct SpeakerView: View {
  @Binding var screen: Screen
  
  @ObservedObject private var viewModel = SpeakerViewModel()
  
  var body: some View {
    ZStack {
      Color(uiColor: UIColor(red: 0.125, green: 0.094, blue: 0.077, alpha: 1)).ignoresSafeArea()
      VStack {
        HStack {
          Button("Назад") {
            MCService.shared.disconnect()
            screen = .devices
          }.foregroundColor(Color(uiColor: UIColor(red: 1, green: 0.855, blue: 0.75, alpha: 1)))
          Spacer()
        }
        Spacer()
        Text("\(viewModel.distance ?? "")")
          .foregroundColor(.white)
          .multilineTextAlignment(.center)
        Image("antenna")
          .frame(width: 64, height: 64)
          .opacity(viewModel.isTransmitting ? 1 : 0.3)
        ZStack {
          PressButtonView(viewModel: viewModel).frame(width: 240, height: 240)
            .clipShape(Circle())
            .allowsHitTesting(!viewModel.isReceiving)
          Text("Удерживайте,\nчтобы говорить")
            .foregroundColor(.white)
            .fontWeight(.semibold)
            .font(.system(.body, design: .rounded))
            .multilineTextAlignment(.center)
            .allowsHitTesting(false)
        }
        Spacer()
      }.padding(.top, 64)
        .padding(.horizontal, 16)
        .onAppear {
          viewModel.start()
        }.onChange(of: viewModel.isSpeaking) { isSpeaking in
          if isSpeaking {
            viewModel.startRecording()
          } else {
            viewModel.stopRecording()
          }
        }.onChange(of: viewModel.isDisconnected) { isDisconnected in
          if isDisconnected {
            MCService.shared.disconnect()
            screen = .devices
          }
        }
    }
  }
}
