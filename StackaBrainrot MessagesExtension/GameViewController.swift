//
//  GameViewController.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    
    // MARK: - Callbacks
    
    var onTapAtPosition: ((CGFloat, CGFloat) -> Void)?
    var onBrainrotFellOff: (() -> Void)?
    
    // MARK: - Properties
    
    private var skView: SKView?
    private var scene: GameScene?
    private var hoverPosition: CGFloat?
    private var hoverRotation: CGFloat = 0
    private var canDrop: Bool = false
    
    // MARK: - UI Elements
    
    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        l.textColor = .label
        l.text = "0"
        return l
    }()
    
    private let dropButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("DROP", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 12
        btn.alpha = 0
        btn.isEnabled = false
        return btn
    }()
    
    private let dimView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        v.alpha = 0
        return v
    }()
    
    private let messageLabel: UILabel = {
        let l = UILabel()
        l.text = "Your Turn!"
        l.font = .systemFont(ofSize: 48, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.alpha = 0
        return l
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        let sk = SKView()
        sk.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sk)
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)
        
        dropButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dropButton)
        
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            sk.topAnchor.constraint(equalTo: view.topAnchor),
            sk.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sk.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sk.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            countLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            countLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            dropButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            dropButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            dropButton.widthAnchor.constraint(equalToConstant: 100),
            dropButton.heightAnchor.constraint(equalToConstant: 44),
            
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView(_:)))
        sk.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(didPanView(_:)))
        sk.addGestureRecognizer(pan)
        
        dropButton.addTarget(self, action: #selector(didTapDropButton), for: .touchUpInside)
        
        self.skView = sk
    }
    
    // MARK: - Scene Management
    
    func ensureScene() {
        guard let skView else { return }
        if scene == nil {
            let s = GameScene(size: GameScene.fixedSize)
            s.scaleMode = .aspectFit
            skView.preferredFramesPerSecond = 60
            skView.presentScene(s)
            scene = s
        }
        
        scene?.onBrainrotFellOff = { [weak self] in
            self?.onBrainrotFellOff?()
        }
    }
    
    // MARK: - State Management
    
    func loadState(_ state: GameState) {
        ensureScene()
        scene?.load(state: state)
        countLabel.text = "\(state.count)"
    }
    
    func setNextBrainrotId(_ id: Int) {
        ensureScene()
        scene?.setNextBrainrotId(id)
    }
    
    func setPaused(_ paused: Bool) {
        skView?.isPaused = paused
    }
    
    // MARK: - UI Control
    
    func showMessage(_ text: String, color: UIColor) {
        messageLabel.text = text
        messageLabel.textColor = color
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.dimView.alpha = 1
            self?.messageLabel.alpha = 1
        }
    }
    
    func showYourTurnMessage() {
        messageLabel.text = "Your Turn!"
        messageLabel.textColor = .white
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.dimView.alpha = 1
            self?.messageLabel.alpha = 1
        } completion: { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.hideMessage()
            }
        }
    }
    
    func hideMessage() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.dimView.alpha = 0
            self?.messageLabel.alpha = 0
        }
    }
    
    // MARK: - Drop Operations
    
    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat, rotation: CGFloat) -> LastDrop? {
        scene?.hideHoverBrainrot()
        return scene?.dropBrainrot(brainrotId: brainrotId, normalizedX: normalizedX, rotation: rotation)
    }
    
    func getAllBlocks() -> [Block] {
        return scene?.getAllBlocks() ?? []
    }
    
    func isSceneSettled() -> Bool {
        return scene?.isSettled ?? false
    }
    
    func setOnSettled(_ callback: @escaping () -> Void) {
        scene?.onSettled = callback
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func didTapView(_ gr: UITapGestureRecognizer) {
        guard canDrop else { return }
        
        // Rotate by 45 degrees (π/4 radians) counter-clockwise
        hoverRotation += .pi / 4
        
        // If we have a position, update the hover with new rotation
        if let pos = hoverPosition {
            scene?.updateHoverBrainrot(at: pos, rotation: hoverRotation)
        }
    }
    
    @objc private func didPanView(_ gr: UIPanGestureRecognizer) {
        guard let skView, canDrop else { return }
        let pt = gr.location(in: skView)
        let nx = max(0, min(1, pt.x / skView.bounds.width))
        
        if gr.state == .began || gr.state == .changed {
            hoverPosition = nx
            scene?.updateHoverBrainrot(at: nx, rotation: hoverRotation)
            
            if dropButton.alpha == 0 {
                UIView.animate(withDuration: 0.2) { [weak self] in
                    self?.dropButton.alpha = 1
                }
            }
            dropButton.isEnabled = true
        }
    }
    
    @objc private func didTapDropButton() {
        guard let nx = hoverPosition else { return }
        
        let rotation = hoverRotation
        
        scene?.hideHoverBrainrot()
        
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.dropButton.alpha = 0
        }
        dropButton.isEnabled = false
        hoverPosition = nil
        hoverRotation = 0
        canDrop = false
        
        onTapAtPosition?(nx, rotation)
    }
    
    // MARK: - Drop Mode Control
    
    func enableDropMode() {
        ensureScene()
        canDrop = true
        hoverPosition = nil
        hoverRotation = 0
        scene?.hideHoverBrainrot()
        dropButton.alpha = 0
        dropButton.isEnabled = false
    }
    
    func disableDropMode() {
        canDrop = false
        hoverPosition = nil
        hoverRotation = 0
        scene?.hideHoverBrainrot()
        
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.dropButton.alpha = 0
        }
        dropButton.isEnabled = false
    }
}
