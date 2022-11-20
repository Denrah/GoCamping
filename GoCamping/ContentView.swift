//
//  ContentView.swift
//  GoCamping
//
//  Created by National Team on 12.11.2022.
//

import SwiftUI

enum Screen {
  case name
  case devices
  case speaker
}

struct ContentView: View {
  @State var screen: Screen = .name
  
  var body: some View {
    switch screen {
    case .name:
      NameInputView(screen: $screen)
    case .devices:
      DevicesListView(screen: $screen)
    case .speaker:
      SpeakerView(screen: $screen)
    }
  }
}
