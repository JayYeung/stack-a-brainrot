//
//  GameScene.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import SpriteKit

final class GameScene: SKScene {

    private let brainrotTextureNames = [
        "bear", "buffalo", "chick", "chicken", "cow", "crocodile",
        "dog", "duck", "elephant", "frog", "giraffe", "goat",
        "gorilla", "hippo", "horse", "monkey", "moose", "narwhal",
        "owl", "panda", "parrot", "penguin", "pig", "rabbit",
        "rhino", "sloth", "snake", "walrus", "whale", "zebra"
    ]
    private var platformNode: SKSpriteNode?
    
    var onBrainrotFellOff: (() -> Void)?

    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)

        // Keep a world boundary so stuff bounces within screen for now
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)

        addPlatform()
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Check if any brainrot has fallen off
        let fallenThreshold = frame.minY - 100
        for node in children where node.name == "brainrot" {
            if node.position.y < fallenThreshold {
                node.removeFromParent()
                onBrainrotFellOff?()
            }
        }
    }

    func load(state: GameState) {
        // Clear all brainrots but keep platform
        children
            .filter { $0.name == "brainrot" }
            .forEach { $0.removeFromParent() }

        // Load all settled blocks at their stored positions as static objects
        for block in state.blocks {
            let x = frame.minX + CGFloat(block.x) * frame.width
            let y = frame.minY + CGFloat(block.y) * frame.height
            let node = createStaticBrainrot(brainrotId: block.brainrotId, at: CGPoint(x: x, y: y), rotation: CGFloat(block.rotation))
            addChild(node)
        }
        
        // If there's a last drop, replay it after settling previous blocks
        if let lastDrop = state.lastDrop {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.dropBrainrot(brainrotId: lastDrop.brainrotId, normalizedX: CGFloat(lastDrop.dropX))
            }
        }
    }
    
    private func createStaticBrainrot(brainrotId: Int, at position: CGPoint, rotation: CGFloat) -> SKSpriteNode {
        let texName = brainrotTextureNames[brainrotId % brainrotTextureNames.count]
        let node = SKSpriteNode(imageNamed: texName)
        node.name = "brainrot"
        node.userData = ["brainrotId": brainrotId]  // Store ID for reliable retrieval
        node.setScale(0.5)
        node.position = position
        node.zRotation = rotation
        
        // Physics body but static (no dynamics)
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex, size: node.size)
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }
        
        node.physicsBody?.isDynamic = false
        node.physicsBody?.restitution = 0.1
        node.physicsBody?.friction = 0.8
        
        return node
    }

    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat) -> CGPoint {
        let x = frame.minX + normalizedX * frame.width
        let y = frame.maxY - 40
        let pos = CGPoint(x: x, y: y)
        addBrainrot(brainrotId: brainrotId, at: pos, rotation: 0)
        return pos
    }
    
    private func addBrainrot(brainrotId: Int, at position: CGPoint, rotation: CGFloat) {
        let texName = brainrotTextureNames[brainrotId % brainrotTextureNames.count]
        let node = SKSpriteNode(imageNamed: texName)
        node.name = "brainrot"
        node.userData = ["brainrotId": brainrotId]  // Store ID for reliable retrieval

        // size tuning
        node.setScale(0.5)
        node.position = position
        node.zRotation = rotation

        // physics body based on texture works ok for chunky shapes
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex, size: node.size)
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }

        node.physicsBody?.isDynamic = true
        node.physicsBody?.restitution = 0.1
        node.physicsBody?.friction = 0.8
        node.physicsBody?.linearDamping = 0.2
        node.physicsBody?.angularDamping = 0.3

        addChild(node)
    }

    private func addPlatform() {
        let platformWidth = frame.width * 0.8
        let platformHeight: CGFloat = 20
        
        let p = SKSpriteNode(color: .systemGray, size: CGSize(width: platformWidth, height: platformHeight))
        p.position = CGPoint(x: frame.midX, y: frame.minY + 60)

        p.physicsBody = SKPhysicsBody(rectangleOf: p.size)
        p.physicsBody?.isDynamic = false

        platformNode = p
        addChild(p)
    }
    
    func getAllBlocks() -> [Block] {
        return children
            .filter { $0.name == "brainrot" }
            .compactMap { node -> Block? in
                guard let brainrotId = node.userData?["brainrotId"] as? Int
                else { return nil }
                
                let nx = (node.position.x - frame.minX) / frame.width
                let ny = (node.position.y - frame.minY) / frame.height
                
                return Block(
                    brainrotId: brainrotId,
                    x: Double(nx),
                    y: Double(ny),
                    rotation: Double(node.zRotation)
                )
            }
    }
}
