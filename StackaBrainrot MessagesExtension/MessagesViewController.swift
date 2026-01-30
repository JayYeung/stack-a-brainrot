//
//  MessagesViewController.swift
//  StackaBrainrot MessagesExtension
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import Messages

final class MessagesViewController: MSMessagesAppViewController {
    
    private let coordinator = GameCoordinator(debugMode: true)
    private let inviteVC = InviteViewController()
    private let gameVC = GameViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        setupChildViewControllers()
        setupCoordinatorCallbacks()
    }
    
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
    }
    
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
        
        gameVC.onTapAtPosition = { [weak self] normalizedX in
            guard let self else { return }
            let isSceneSettled = self.gameVC.isSceneSettled()
            guard self.coordinator.canDrop(expandedView: self.presentationStyle == .expanded, isSceneSettled: isSceneSettled) else { return }
            
            let lastDrop = self.coordinator.handleDrop(
                normalizedX: normalizedX,
                getAllBlocks: { self.gameVC.getAllBlocks() }
            )
            
            guard let lastDrop else { return }
            
            let actualDrop = self.gameVC.dropBrainrot(brainrotId: lastDrop.brainrotId, normalizedX: normalizedX)
            
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
    
    private func refreshUI(state: GameState?) {
        guard let state else {
            inviteVC.view.isHidden = false
            gameVC.view.isHidden = true
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
            return
        }
        
        if state.lastDrop != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                self.coordinator.resetDropInProgress()
                
                if self.coordinator.shouldShowYourTurn() {
                    self.gameVC.showYourTurnMessage()
                }
            }
        }
    }
}

