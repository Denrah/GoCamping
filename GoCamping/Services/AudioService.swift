//
//  AudioService.swift
//  GoCamping
//
//  Created by National Team on 15.11.2022.
//

import Foundation
import AVFoundation

class AudioService {
  static let shared = AudioService()
  
  var onRecord: ((Data) -> Void)?
  
  private let player = Player()
  private let recorder = Recorder()
  
  private init() {
    recorder.onRecord = { [weak self] data in
      self?.onRecord?(data)
    }
  }
  
  func setup() {
    player.setup()
    recorder.setup()
  }
  
  func addChunk(data: Data) {
    player.addChunk(chunk: data)
  }
  
  func startRecording() {
    recorder.startRecording()
  }
  
  func stopRecording() {
    recorder.stopRecording()
  }
}

class Recorder {
  var onRecord: ((Data) -> Void)?
  
  private let engine = AVAudioEngine()
  private let mixer = AVAudioMixerNode()
  
  func setup() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.record)
    try? session.setMode(.measurement)
    try? session.setActive(true)
  }
  
  func startRecording() {
    setup()
    
    let input = engine.inputNode
    let inputFormat = input.inputFormat(forBus: 0)
    engine.attach(mixer)
    engine.connect(input, to: mixer, format: inputFormat)
    mixer.installTap(onBus: 0, bufferSize: 1024, format: mixer.inputFormat(forBus: 0)) { [weak self] buffer, _ in
      let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: 1)
      let data = Data(bytes: channels[0], count: Int(buffer.frameCapacity * buffer.format.streamDescription.pointee.mBytesPerFrame))
      self?.onRecord?(data)
    }
    engine.prepare()
    try? engine.start()
  }
  
  func stopRecording() {
    mixer.removeTap(onBus: 0)
    engine.stop()
  }
}

class Player {
  private let engine = AVAudioEngine()
  private let playerNode = AVAudioPlayerNode()
  
  
  func setup() {
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback)
    try? session.setActive(true)
  }
  
  func addChunk(chunk: Data) {
    setup() 
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)
    guard let format = format, let buffer = pcmBuffer(chunk: chunk, format: format) else {
      return
    }
    
    if !engine.isRunning {
      engine.attach(playerNode)
      engine.connect(playerNode, to: engine.mainMixerNode, format: buffer.format)
      engine.prepare()
      do {
        try engine.start()
      } catch {
        print(error)
      }
      playerNode.play()
    }
    
    playerNode.volume = 1
    playerNode.scheduleBuffer(buffer, completionHandler: nil)
  }
  
  private func pcmBuffer(chunk: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
    let streamDescription = format.streamDescription.pointee
    let frameCapacity = UInt32(chunk.count) / streamDescription.mBytesPerFrame
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
    buffer.frameLength = buffer.frameCapacity
    let audioBuffer = buffer.audioBufferList.pointee.mBuffers
    chunk.withUnsafeBytes { address in
      guard let baseAddress = address.baseAddress else {
        return
      }
      audioBuffer.mData?.copyMemory(from: baseAddress, byteCount: Int(audioBuffer.mDataByteSize))
    }
    return buffer
  }
}
