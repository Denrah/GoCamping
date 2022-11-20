//
//  NameInputView.swift
//  GoCamping
//
//  Created by National Team on 13.11.2022.
//

import SwiftUI

struct NameInputView: View {
  @Binding var screen: Screen
  
  @State var text: String = ""
  
  var body: some View {
    ZStack {
      Color(uiColor: UIColor(red: 0.125, green: 0.094, blue: 0.077, alpha: 1)).ignoresSafeArea()
      VStack {
        HStack {
          Text("Имя устройства")
            .font(.system(.largeTitle, design: .rounded))
            .fontWeight(.bold)
            .foregroundColor(Color(uiColor: UIColor(red: 1, green: 0.855, blue: 0.75, alpha: 1)))
          Spacer()
        }
        TextField("Мой iPhone", text: $text)
          .frame(height: 56)
          .padding(.horizontal, 16)
          .background(Color.white.opacity(0.7))
          .cornerRadius(8)
        Button {
          MCService.shared.displayName = text
          screen = .devices
        } label: {
          Spacer()
          Text("Продолжить")
            .foregroundColor(.white)
            .fontWeight(.semibold)
            .font(.system(.body, design: .rounded))
          Spacer()
        }.frame(height: 56)
          .background(Color(uiColor: UIColor(red: 0.938, green: 0.396, blue: 0.125, alpha: 1)))
          .cornerRadius(8)
          .disabled(text.isEmpty)
        Spacer()
        HStack {
          Spacer()
        }
      }.padding(.top, 64)
        .padding(.horizontal, 16)
    }
  }
}
