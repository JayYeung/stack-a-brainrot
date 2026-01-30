//
//  MessagesViewController.swift
//  StackaBrainrot MessagesExtension
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import Messages

final class MessagesViewController: MSMessagesAppViewController {

    private var currentConversation: MSConversation?
    private var loadedState: GameState?
    
    // Set to true to allow playing both sides for single-device testing
    private let debugMode = true

    // MARK: - Invite UI
    
    private let inviteContainerView = UIView()
    
    private let inviteTitleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.text = "Stack a Brainrot"
        return l
    }()
    
    private let inviteDescriptionLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.text = "Challenge a friend!"
        l.textColor = .secondaryLabel
        return l
    }()

    private lazy var inviteButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Invite"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        let b = UIButton(configuration: config)
        b.addTarget(self, action: #selector(didTapInvite), for: .touchUpInside)
        return b
    }()

    // MARK: - Game UI
    
    private let gameContainerView = UIView()
    
    private let gameStatusLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.text = "Game"
        return l
    }()

    private lazy var startGameButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Start Game"
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemGreen
        let b = UIButton(configuration: config)
        b.addTarget(self, action: #selector(didTapPlay), for: .touchUpInside)
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupInviteUI()
        setupGameUI()
    }
    
    override func willBecomeActive(with conversation: MSConversation) {
        currentConversation = conversation
        
        if let msg = conversation.selectedMessage,
           let state = MessageCodec.decodeState(from: msg) {
            loadedState = state
        } else {
            loadedState = nil
        }

        refreshUI()
    }

    // MARK: - Setup
    
    private func setupInviteUI() {
        inviteContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inviteContainerView)
        
        let stack = UIStackView(arrangedSubviews: [inviteTitleLabel, inviteDescriptionLabel, inviteButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        inviteContainerView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            inviteContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            inviteContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inviteContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inviteContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stack.centerXAnchor.constraint(equalTo: inviteContainerView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: inviteContainerView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: inviteContainerView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: inviteContainerView.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupGameUI() {
        gameContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gameContainerView)
        
        let stack = UIStackView(arrangedSubviews: [gameStatusLabel, startGameButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            gameContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            gameContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stack.centerXAnchor.constraint(equalTo: gameContainerView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: gameContainerView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: gameContainerView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: gameContainerView.trailingAnchor, constant: -20)
        ])
        
        gameContainerView.isHidden = true
    }

    // MARK: - UI Updates

    private func refreshUI() {
        guard let state = loadedState else {
            inviteContainerView.isHidden = false
            gameContainerView.isHidden = true
            return
        }

        inviteContainerView.isHidden = true
        gameContainerView.isHidden = false

        let me = localPlayerId()
        let isMyTurn = debugMode || state.nextPlayer.isEmpty || state.nextPlayer == me

        switch state.phase {
        case .pending:
            gameStatusLabel.text = "Game Invite Received!\nReady to begin?"
            startGameButton.setTitle("Start Game", for: .normal)
            startGameButton.isEnabled = true

        case .active:
            if isMyTurn {
                gameStatusLabel.text = "Your Turn!\nCount: \(state.count)"
                startGameButton.setTitle("Play (\(state.count) → \(state.count + 1))", for: .normal)
                startGameButton.isEnabled = true
            } else {
                gameStatusLabel.text = "Opponent's Turn\nCount: \(state.count)\n\nWaiting for them to play..."
                startGameButton.setTitle("Waiting...", for: .normal)
                startGameButton.isEnabled = false
            }
        }
    }

    // MARK: - Helpers

    private func localPlayerId() -> String {
        currentConversation?.localParticipantIdentifier.uuidString ?? ""
    }

    private func opponentId() -> String {
        currentConversation?.remoteParticipantIdentifiers.first?.uuidString ?? ""
    }

    // MARK: - Actions

    @objc private func didTapInvite() {
        guard let conversation = currentConversation else { return }

        let state = GameState(
            gameId: UUID().uuidString,
            phase: .pending,
            count: 0,
            player1: "",
            player2: "",
            nextPlayer: ""
        )

        let message = MessageCodec.makeMessage(state: state, session: MSSession())
        conversation.insert(message, completionHandler: nil)

        inviteDescriptionLabel.text = "✓ Invite created!\nTap 'Send' then tap the bubble."
        requestPresentationStyle(.compact)
    }

    @objc private func didTapPlay() {
        guard let conversation = currentConversation,
              let selected = conversation.selectedMessage,
              var state = loadedState
        else { return }

        let me = localPlayerId()
        let opp = opponentId()

        switch state.phase {
        case .pending:
            state.phase = .active
            state.player1 = me
            state.player2 = opp
            state.count = 1
            state.nextPlayer = opp.isEmpty ? me : opp

        case .active:
            if !debugMode && !state.nextPlayer.isEmpty && state.nextPlayer != me {
                gameStatusLabel.text = "⚠️ Not your turn!\nWait for opponent to play."
                return
            }
            
            state.count += 1
            
            if !state.player1.isEmpty && !state.player2.isEmpty {
                state.nextPlayer = (me == state.player1) ? state.player2 : state.player1
            } else {
                state.nextPlayer = me
            }
        }

        let session = selected.session ?? MSSession()
        let message = MessageCodec.makeMessage(state: state, session: session)
        conversation.insert(message, completionHandler: nil)

        loadedState = state
        refreshUI()
        
        let moveType = state.count == 1 ? "Game started!" : "Move made!"
        gameStatusLabel.text = "✓ \(moveType)\nCount: \(state.count)\n\nTap 'Send' to complete your turn."
        requestPresentationStyle(.compact)
    }
}

