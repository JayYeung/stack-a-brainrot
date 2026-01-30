//
//  GameState.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import Foundation
import CoreGraphics

enum GamePhase: String, Codable {
    case pending
    case active
    case finished
}

struct Block: Codable {
    var brainrotId: Int
    var x: Double       // normalized 0...1
    var y: Double       // normalized 0...1
    var rotation: Double // radians
}

struct LastDrop: Codable {
    var brainrotId: Int
    var dropX: Double   // normalized 0...1
}

struct GameState: Codable {
    var gameId: String
    var phase: GamePhase
    var count: Int

    var player1: String
    var player2: String
    var nextPlayer: String

    var blocks: [Block]      // settled positions of all blocks BEFORE last drop
    var lastDrop: LastDrop?  // the most recent drop to replay
    var winner: String?      // player who won (loser's brainrot fell off)
}
