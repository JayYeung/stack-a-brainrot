//
//  GameCoordinator.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import Foundation
import Messages
import GameplayKit

final class GameCoordinator {
    
    // MARK: - Properties
    
    private let debugMode: Bool
    private var currentState: GameState?
    private var dropInProgress = false
    
    weak var conversation: MSConversation?
    
    var onStateUpdated: ((GameState) -> Void)?
    var onRequestCompact: (() -> Void)?
    var onRequestExpanded: (() -> Void)?
    var onShowYourTurn: (() -> Void)?
    var onGameFinished: ((Bool) -> Void)?
    
    // MARK: - Initialization
    
    init(debugMode: Bool = true) {
        self.debugMode = debugMode
    }
    
    // MARK: - State Management
    
    func loadState(_ state: GameState?) {
        currentState = state
        dropInProgress = false
    }
    
    // MARK: - Game Creation
    
    func createInvite() -> GameState {
        let state = GameState(
            gameId: UUID().uuidString,
            phase: .pending,
            count: 0,
            player1: "",
            player2: "",
            nextPlayer: "",
            blocks: [],
            lastDrop: nil,
            winner: nil,
            rngSeed: UInt64.random(in: 0...UInt64.max)
        )
        return state
    }
    
    func sendInvite(state: GameState) {
        guard let conversation else { return }
        let message = MessageCodec.makeMessage(state: state, session: MSSession())
        conversation.insert(message, completionHandler: nil)
    }
    
    // MARK: - Game Validation
    
    func shouldShowYourTurn() -> Bool {
        guard let state = currentState, state.lastDrop != nil else { return false }
        let me = localPlayerId()
        let isMyTurn = debugMode || state.nextPlayer.isEmpty || state.nextPlayer == me
        return isMyTurn
    }
    
    func canDrop(expandedView: Bool, isSceneSettled: Bool) -> Bool {
        guard let state = currentState else { return false }
        guard !dropInProgress else { return false }
        guard expandedView else { return false }
        guard state.phase != .finished else { return false }
        guard isSceneSettled else { return false }
        
        let me = localPlayerId()
        if !debugMode && !state.nextPlayer.isEmpty && state.nextPlayer != me {
            return false
        }
        
        return true
    }
    
    func getNextBrainrotId() -> Int {
        guard let state = currentState else { return 0 }
        let rng = GKMersenneTwisterRandomSource(seed: state.rngSeed)
        return rng.nextInt(upperBound: 200)
    }
    
    // MARK: - Drop Handling
    
    func handleDrop(brainrotId: Int, normalizedX: CGFloat, getAllBlocks: () -> [Block]) -> LastDrop? {
        guard var state = currentState else { return nil }
        guard let conversation else { return nil }
        guard let selected = conversation.selectedMessage else { return nil }
        
        let me = localPlayerId()
        let opp = opponentId()
        
        if state.phase == .pending {
            state.phase = .active
            state.player1 = me
            state.player2 = opp
            state.nextPlayer = me
            state.count = 0
            state.blocks = []
            state.lastDrop = nil
            state.winner = nil
            state.rngSeed = UInt64.random(in: 0...UInt64.max)
            onRequestExpanded?()
        }
        
        let rng = GKMersenneTwisterRandomSource(seed: state.rngSeed)
        _ = rng.nextInt(upperBound: 30)  // Consume the RNG to stay in sync
        state.rngSeed = UInt64(bitPattern: Int64(rng.nextInt()))
        
        dropInProgress = true
        
        let settledBlocks = getAllBlocks()
        state.count += 1
        state.blocks = settledBlocks
        
        if !state.player1.isEmpty && !state.player2.isEmpty {
            state.nextPlayer = (me == state.player1) ? state.player2 : state.player1
        } else {
            state.nextPlayer = me
        }
        
        currentState = state
        
        return LastDrop(
            brainrotId: brainrotId,
            spawnX: Double(normalizedX),
            spawnY: 0,
            spawnRotation: 0,
            velocityX: 0,
            velocityY: 0,
            angularVelocity: 0
        )
    }
    
    func handleSettled(lastDrop: LastDrop?) {
        guard var state = currentState else { return }
        guard let conversation else { return }
        guard let selected = conversation.selectedMessage else { return }
        
        state.lastDrop = lastDrop
        
        let session = selected.session ?? MSSession()
        let msg = MessageCodec.makeMessage(state: state, session: session)
        conversation.insert(msg, completionHandler: nil)
        
        currentState = state
        onStateUpdated?(state)
        onRequestCompact?()
    }
    
    // MARK: - Game End
    
    func handleBrainrotFellOff() {
        guard var state = currentState else { return }
        guard state.phase == .active else { return }
        guard let conversation else { return }
        guard let selected = conversation.selectedMessage else { return }
        
        let me = localPlayerId()
        let loser = me
        let winner = (loser == state.player1) ? state.player2 : state.player1
        
        state.phase = .finished
        state.winner = winner
        
        let session = selected.session ?? MSSession()
        let msg = MessageCodec.makeMessage(state: state, session: session)
        conversation.insert(msg, completionHandler: nil)
        
        currentState = state
        let didIWin = state.winner == me
        onGameFinished?(didIWin)
        onRequestCompact?()
    }
    
    func resetDropInProgress() {
        dropInProgress = false
    }
    
    // MARK: - Private Helpers
    
    private func localPlayerId() -> String {
        conversation?.localParticipantIdentifier.uuidString ?? ""
    }
    
    private func opponentId() -> String {
        conversation?.remoteParticipantIdentifiers.first?.uuidString ?? ""
    }
}
