//
//  GameViewController.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    
    var onTapAtPosition: ((CGFloat) -> Void)?
    var onBrainrotFellOff: (() -> Void)?
    
    private var skView: SKView?
    private var scene: GameScene?
    
    private let countLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        l.textColor = .label
        l.text = "0"
        return l
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        let sk = SKView()
        sk.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sk)
        
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countLabel)
        
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
            
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapView(_:)))
        sk.addGestureRecognizer(tap)
        
        self.skView = sk
    }
    
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
    
    func loadState(_ state: GameState) {
        ensureScene()
        scene?.load(state: state)
        countLabel.text = "\(state.count)"
    }
    
    func setPaused(_ paused: Bool) {
        skView?.isPaused = paused
    }
    
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
    
    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat) -> LastDrop? {
        return scene?.dropBrainrot(brainrotId: brainrotId, normalizedX: normalizedX)
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
    
    @objc private func didTapView(_ gr: UITapGestureRecognizer) {
        guard let skView else { return }
        let pt = gr.location(in: skView)
        let nx = max(0, min(1, pt.x / skView.bounds.width))
        onTapAtPosition?(nx)
    }
}
