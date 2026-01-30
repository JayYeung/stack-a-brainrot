//
//  MessagesViewController.swift
//  StackaBrainrot MessagesExtension
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import Messages

final class MessagesViewController: MSMessagesAppViewController {
    
    // MARK: - Properties
    
    private let coordinator = GameCoordinator(debugMode: true)
    private let inviteVC = InviteViewController()
    private let gameVC = GameViewController()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupChildViewControllers()
        setupCoordinatorCallbacks()
    }
    
    // MARK: - Messages Extension Lifecycle
    
    override func willBecomeActive(with conversation: MSConversation) {
        coordinator.conversation = conversation
        coordinator.resetDropInProgress()
        
        let state: GameState?
        if let msg = conversation.selectedMessage {
            state = MessageCodec.decodeState(from: msg)
        } else {
            state = nil
        }
        
        coordinator.loadState(state)
        refreshUI(state: state)
    }
    
    override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.didTransition(to: presentationStyle)
        gameVC.setPaused(presentationStyle != .expanded)
        
        if presentationStyle == .expanded {
            if let state = coordinator.conversation?.selectedMessage.flatMap({ MessageCodec.decodeState(from: $0) }) {
                let nextId = coordinator.getNextBrainrotId()
                gameVC.setNextBrainrotId(nextId)
                
                // Wait for scene to settle before enabling drop mode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let self else { return }
                    let isSceneSettled = self.gameVC.isSceneSettled()
                    let canDrop = self.coordinator.canDrop(expandedView: true, isSceneSettled: isSceneSettled)
                    
                    if canDrop {
                        self.gameVC.enableDropMode()
                    } else {
                        self.gameVC.disableDropMode()
                    }
                }
            }
        } else {
            gameVC.disableDropMode()
        }
    }
    
    // MARK: - Setup
    
    private func setupChildViewControllers() {
        addChild(inviteVC)
        inviteVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inviteVC.view)
        inviteVC.didMove(toParent: self)
        
        addChild(gameVC)
        gameVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameVC.view)
        gameVC.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            inviteVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            inviteVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inviteVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inviteVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            gameVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            gameVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        gameVC.view.isHidden = true
    }
    
    private func setupCoordinatorCallbacks() {
        inviteVC.onInviteCreated = { [weak self] in
            guard let self else { return }
            let state = self.coordinator.createInvite()
            self.coordinator.sendInvite(state: state)
            self.inviteVC.showSuccess()
            self.requestPresentationStyle(.compact)
        }
        
        gameVC.onTapAtPosition = { [weak self] normalizedX, rotation in
            guard let self else { return }
            let isSceneSettled = self.gameVC.isSceneSettled()
            guard self.coordinator.canDrop(expandedView: self.presentationStyle == .expanded, isSceneSettled: isSceneSettled) else { return }
            
            let brainrotId = self.coordinator.getNextBrainrotId()
            
            let lastDrop = self.coordinator.handleDrop(
                brainrotId: brainrotId,
                normalizedX: normalizedX,
                getAllBlocks: { self.gameVC.getAllBlocks() }
            )
            
            guard let lastDrop else { return }
            
            let actualDrop = self.gameVC.dropBrainrot(brainrotId: lastDrop.brainrotId, normalizedX: normalizedX, rotation: rotation)
            
            self.gameVC.setOnSettled { [weak self] in
                self?.coordinator.handleSettled(lastDrop: actualDrop)
            }
        }
        
        gameVC.onBrainrotFellOff = { [weak self] in
            self?.coordinator.handleBrainrotFellOff()
        }
        
        coordinator.onStateUpdated = { [weak self] state in
            self?.refreshUI(state: state)
        }
        
        coordinator.onRequestCompact = { [weak self] in
            self?.requestPresentationStyle(.compact)
        }
        
        coordinator.onRequestExpanded = { [weak self] in
            self?.requestPresentationStyle(.expanded)
        }
        
        coordinator.onShowYourTurn = { [weak self] in
            self?.gameVC.showYourTurnMessage()
        }
        
        coordinator.onGameFinished = { [weak self] didIWin in
            let message = didIWin ? "You Win!" : "You Lose!"
            let color: UIColor = didIWin ? .systemGreen : .systemRed
            self?.gameVC.showMessage(message, color: color)
        }
    }
    
    // MARK: - UI Updates
    
    private func refreshUI(state: GameState?) {
        guard let state else {
            inviteVC.view.isHidden = false
            gameVC.view.isHidden = true
            gameVC.disableDropMode()
            return
        }
        
        inviteVC.view.isHidden = true
        gameVC.view.isHidden = false
        gameVC.loadState(state)
        
        if state.phase == .finished {
            let me = coordinator.conversation?.localParticipantIdentifier.uuidString ?? ""
            let didIWin = state.winner == me
            let message = didIWin ? "You Win!" : "You Lose!"
            let color: UIColor = didIWin ? .systemGreen : .systemRed
            gameVC.showMessage(message, color: color)
            gameVC.disableDropMode()
            return
        }
        
        let nextId = coordinator.getNextBrainrotId()
        gameVC.setNextBrainrotId(nextId)
        
        // Temporarily disable drop mode while scene settles
        gameVC.disableDropMode()
        
        if state.lastDrop != nil {
            // Scene is replaying, wait for it to settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                self.coordinator.resetDropInProgress()
                
                if self.coordinator.shouldShowYourTurn() {
                    self.gameVC.showYourTurnMessage()
                }
                
                let nextId = self.coordinator.getNextBrainrotId()
                self.gameVC.setNextBrainrotId(nextId)
                
                // Wait a bit more for scene to fully settle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let isSceneSettled = self.gameVC.isSceneSettled()
                    let canDrop = self.coordinator.canDrop(expandedView: self.presentationStyle == .expanded, isSceneSettled: isSceneSettled)
                    
                    if canDrop {
                        self.gameVC.enableDropMode()
                    }
                }
            }
        } else {
            // No replay needed, enable drop mode after scene settles
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                let isSceneSettled = self.gameVC.isSceneSettled()
                let canDrop = self.coordinator.canDrop(expandedView: self.presentationStyle == .expanded, isSceneSettled: isSceneSettled)
                
                if canDrop {
                    self.gameVC.enableDropMode()
                }
            }
        }
    }
}

