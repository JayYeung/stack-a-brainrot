//
//  MessagesViewController.swift
//  StackaBrainrot MessagesExtension
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import Messages
import SpriteKit
import GameplayKit

final class MessagesViewController: MSMessagesAppViewController {

    private var currentConversation: MSConversation?
    private var loadedState: GameState?
    
    // Set to true to allow playing both sides for single-device testing
    private let debugMode = true
    
    private var skView: SKView?
    private var scene: GameScene?
    private var dropInProgress = false
    
    // Your Turn notification
    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.alpha = 0
        return v
    }()
    
    private let yourTurnLabel: UILabel = {
        let l = UILabel()
        l.text = "Your Turn!"
        l.font = .systemFont(ofSize: 48, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.alpha = 0
        return l
    }()

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
    
    private let brainrotCountLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        l.textColor = .label
        l.text = "0"
        return l
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
        
        // Reset drop flag when reopening
        dropInProgress = false
        
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

        let sk = SKView()
        sk.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.addSubview(sk)
        
        brainrotCountLabel.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.addSubview(brainrotCountLabel)

        NSLayoutConstraint.activate([
            gameContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            gameContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gameContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gameContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            sk.topAnchor.constraint(equalTo: gameContainerView.topAnchor),
            sk.leadingAnchor.constraint(equalTo: gameContainerView.leadingAnchor),
            sk.trailingAnchor.constraint(equalTo: gameContainerView.trailingAnchor),
            sk.bottomAnchor.constraint(equalTo: gameContainerView.bottomAnchor),
            
            brainrotCountLabel.topAnchor.constraint(equalTo: gameContainerView.safeAreaLayoutGuide.topAnchor, constant: 16),
            brainrotCountLabel.trailingAnchor.constraint(equalTo: gameContainerView.trailingAnchor, constant: -16)
        ])

        // Tap gesture to drop
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapGameView(_:)))
        sk.addGestureRecognizer(tap)

        self.skView = sk
        
        // Setup Your Turn notification
        dimView.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.addSubview(dimView)
        
        yourTurnLabel.translatesAutoresizingMaskIntoConstraints = false
        gameContainerView.addSubview(yourTurnLabel)
        
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: gameContainerView.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: gameContainerView.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: gameContainerView.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: gameContainerView.bottomAnchor),
            
            yourTurnLabel.centerXAnchor.constraint(equalTo: gameContainerView.centerXAnchor),
            yourTurnLabel.centerYAnchor.constraint(equalTo: gameContainerView.centerYAnchor)
        ])
        
        gameContainerView.isHidden = true
    }

    // MARK: - UI Updates
    
    private func ensureScene() {
        guard let skView else { return }
        if scene == nil {
            let s = GameScene(size: skView.bounds.size)
            s.scaleMode = .resizeFill
            skView.presentScene(s)
            scene = s
        }
        
        // Always ensure callback is set
        scene?.onBrainrotFellOff = { [weak self] in
            self?.handleBrainrotFellOff()
        }
    }

    private func refreshUI() {
        guard let state = loadedState else {
            inviteContainerView.isHidden = false
            gameContainerView.isHidden = true
            return
        }

        inviteContainerView.isHidden = true
        gameContainerView.isHidden = false
        
        ensureScene()
        scene?.load(state: state)
        
        brainrotCountLabel.text = "\(state.count)"
        
        // Handle finished state
        if state.phase == .finished {
            let me = localPlayerId()
            let didIWin = state.winner == me
            
            yourTurnLabel.text = didIWin ? "You Win!" : "You Lose!"
            yourTurnLabel.textColor = didIWin ? .systemGreen : .systemRed
            
            UIView.animate(withDuration: 0.3) { [weak self] in
                self?.dimView.alpha = 1
                self?.yourTurnLabel.alpha = 1
            }
            return
        }
        
        // If there's a last drop being replayed, block new drops until it settles
        if state.lastDrop != nil {
            dropInProgress = true
            
            let me = localPlayerId()
            let isMyTurn = debugMode || state.nextPlayer.isEmpty || state.nextPlayer == me
            
            // Show "Your Turn" message after replay settles (only if it's actually your turn)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                self.dropInProgress = false
                
                if isMyTurn {
                    // Reset label style for turn notification
                    self.yourTurnLabel.text = "Your Turn!"
                    self.yourTurnLabel.textColor = .white
                    
                    // Show Your Turn notification
                    UIView.animate(withDuration: 0.3) {
                        self.dimView.alpha = 1
                        self.yourTurnLabel.alpha = 1
                    } completion: { _ in
                        // Hide after 1 second
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            UIView.animate(withDuration: 0.3) {
                                self.dimView.alpha = 0
                                self.yourTurnLabel.alpha = 0
                            }
                        }
                    }
                }
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
            nextPlayer: "",
            blocks: [],
            lastDrop: nil,
            winner: nil,
            rngSeed: UInt64.random(in: 0...UInt64.max)
        )

        let message = MessageCodec.makeMessage(state: state, session: MSSession())
        conversation.insert(message, completionHandler: nil)

        inviteDescriptionLabel.text = "✓ Invite created!\nTap 'Send' then tap the bubble."
        requestPresentationStyle(.compact)
    }

    @objc private func didTapGameView(_ gr: UITapGestureRecognizer) {
        guard var state = loadedState,
              let conversation = currentConversation,
              let selected = conversation.selectedMessage,
              !dropInProgress,  // Prevent multiple drops
              presentationStyle == .expanded  // Only allow drops in expanded view
        else { return }

        let me = localPlayerId()
        let opp = opponentId()
        
        // Auto-start game if pending
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
            requestPresentationStyle(.expanded)
        }
        
        // Don't allow drops if game is finished
        if state.phase == .finished {
            return
        }

        // turn gate
        if !debugMode && !state.nextPlayer.isEmpty && state.nextPlayer != me {
            return
        }

        guard let skView else { return }
        let pt = gr.location(in: skView)
        let nx = max(0, min(1, pt.x / skView.bounds.width)) // 0..1

        // Use seeded RNG for deterministic brainrot selection
        let rng = GKMersenneTwisterRandomSource(seed: state.rngSeed)
        let brainrotId = rng.nextInt(upperBound: 30)
        
        // Update seed for next drop (use nextUniform for UInt64)
        state.rngSeed = UInt64(bitPattern: Int64(rng.nextInt()))

        // Mark drop in progress
        dropInProgress = true
        
        // Capture current settled state BEFORE dropping
        let settledBlocks = scene?.getAllBlocks() ?? []
        
        // update count
        state.count += 1

        // local drop immediately - returns spawn info
        let dropInfo = scene?.dropBrainrot(brainrotId: brainrotId, normalizedX: CGFloat(nx))
        
        // Store drop info for replay
        state.blocks = settledBlocks
        state.lastDrop = dropInfo
        
        // flip turn
        if !state.player1.isEmpty && !state.player2.isEmpty {
            state.nextPlayer = (me == state.player1) ? state.player2 : state.player1
        } else {
            state.nextPlayer = me
        }

        // Wait for physics to settle using velocity-based detection
        checkSettled(after: 0.5, maxWait: 3.0) { [weak self] in
            guard let self = self else { return }
            
            // send message with settled state + last drop
            let session = selected.session ?? MSSession()
            let msg = MessageCodec.makeMessage(state: state, session: session)
            conversation.insert(msg, completionHandler: nil)

            self.loadedState = state
            self.refreshUI()
            self.requestPresentationStyle(.compact)
            
            // Keep dropInProgress = true so you can't drop in minimized view
            // It will reset when view reopens
        }
    }
    
    private func handleBrainrotFellOff() {
        guard var state = loadedState,
              state.phase == .active,
              let conversation = currentConversation,
              let selected = conversation.selectedMessage
        else { return }
        
        let me = localPlayerId()
        let opp = opponentId()
        
        // Current player loses (the one who just dropped)
        // Winner is the other player
        let loser = me
        let winner = (loser == state.player1) ? state.player2 : state.player1
        
        state.phase = .finished
        state.winner = winner
        
        // Send game over message
        let session = selected.session ?? MSSession()
        let msg = MessageCodec.makeMessage(state: state, session: session)
        conversation.insert(msg, completionHandler: nil)
        
        loadedState = state
        refreshUI()
        requestPresentationStyle(.compact)
    }
    
    private func checkSettled(after minDelay: TimeInterval, maxWait: TimeInterval, completion: @escaping () -> Void) {
        let startTime = Date()
        let velocityThreshold: CGFloat = 0.5
        let angularThreshold: CGFloat = 0.1
        
        func checkVelocities() {
            guard let scene = scene else {
                completion()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            
            // Force settle after max wait
            if elapsed >= maxWait {
                completion()
                return
            }
            
            // Don't check until min delay has passed
            if elapsed < minDelay {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkVelocities()
                }
                return
            }
            
            // Check if all brainrots are settled
            var allSettled = true
            for node in scene.children where node.name == "brainrot" {
                if let body = node.physicsBody, body.isDynamic {
                    let vel = body.velocity
                    let speed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy)
                    let angVel = abs(body.angularVelocity)
                    
                    if speed > velocityThreshold || angVel > angularThreshold {
                        allSettled = false
                        break
                    }
                }
            }
            
            if allSettled {
                completion()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkVelocities()
                }
            }
        }
        
        checkVelocities()
    }
}

