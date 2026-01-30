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
    var velocityX: Double
    var velocityY: Double
    var angularVelocity: Double
}

struct LastDrop: Codable {
    var brainrotId: Int
    var spawnX: Double   // normalized 0...1
    var spawnY: Double   // normalized 0...1
    var spawnRotation: Double
    var velocityX: Double
    var velocityY: Double
    var angularVelocity: Double
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
    
    var rngSeed: UInt64      // for deterministic randomness
}
