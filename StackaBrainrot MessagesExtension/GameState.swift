//
//  GameState.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import Foundation

enum GamePhase: String, Codable {
    case pending
    case active
}

struct GameState: Codable {
    var gameId: String
    var phase: GamePhase
    var count: Int
    var player1: String
    var player2: String
    var nextPlayer: String
}
