//
//  GameScene.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import SpriteKit

final class GameScene: SKScene {
    
    // Fixed logical scene size for deterministic physics
    static let fixedSize = CGSize(width: 390, height: 844)

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

        // Create explicit walls (no bottom, so brainrots can fall off)
        addWalls()
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
                self?.replayDrop(lastDrop)
            }
        }
    }
    
    private func replayDrop(_ drop: LastDrop) {
        let texName = brainrotTextureNames[drop.brainrotId % brainrotTextureNames.count]
        let node = SKSpriteNode(imageNamed: texName)
        node.name = "brainrot"
        node.userData = ["brainrotId": drop.brainrotId]
        node.setScale(0.5)
        
        // Use exact spawn conditions from state
        let x = frame.minX + CGFloat(drop.spawnX) * frame.width
        let y = frame.minY + CGFloat(drop.spawnY) * frame.height
        node.position = CGPoint(x: x, y: y)
        node.zRotation = CGFloat(drop.spawnRotation)
        
        // Create physics body with shrunk size for better determinism
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex, 
                                            size: CGSize(width: node.size.width * 0.95,
                                                        height: node.size.height * 0.95))
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }
        
        node.physicsBody?.isDynamic = true
        node.physicsBody?.restitution = 0.02
        node.physicsBody?.friction = 1.0
        node.physicsBody?.linearDamping = 0.6
        node.physicsBody?.angularDamping = 1.0
        node.physicsBody?.usesPreciseCollisionDetection = true
        
        // Set exact initial velocities
        node.physicsBody?.velocity = CGVector(dx: drop.velocityX, dy: drop.velocityY)
        node.physicsBody?.angularVelocity = CGFloat(drop.angularVelocity)
        
        addChild(node)
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

    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat) -> LastDrop {
        let normalizedY: CGFloat = (frame.maxY - 40 - frame.minY) / frame.height
        let x = frame.minX + normalizedX * frame.width
        let y = frame.maxY - 40
        let pos = CGPoint(x: x, y: y)
        
        addBrainrot(brainrotId: brainrotId, at: pos, rotation: 0)
        
        return LastDrop(
            brainrotId: brainrotId,
            spawnX: Double(normalizedX),
            spawnY: Double(normalizedY),
            spawnRotation: 0,
            velocityX: 0,
            velocityY: 0,
            angularVelocity: 0
        )
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

        // physics body with shrunk size for better determinism
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex, 
                                            size: CGSize(width: node.size.width * 0.95,
                                                        height: node.size.height * 0.95))
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }

        node.physicsBody?.isDynamic = true
        node.physicsBody?.restitution = 0.02
        node.physicsBody?.friction = 1.0
        node.physicsBody?.linearDamping = 0.6
        node.physicsBody?.angularDamping = 1.0
        node.physicsBody?.usesPreciseCollisionDetection = true

        addChild(node)
    }

    private func addPlatform() {
        let platformWidth = frame.width * 0.8
        let platformHeight: CGFloat = 20
        
        let p = SKSpriteNode(color: .systemGray, size: CGSize(width: platformWidth, height: platformHeight))
        p.position = CGPoint(x: frame.midX, y: frame.minY + 60)

        p.physicsBody = SKPhysicsBody(rectangleOf: p.size)
        p.physicsBody?.isDynamic = false
        p.physicsBody?.restitution = 0.0
        p.physicsBody?.friction = 1.5

        platformNode = p
        addChild(p)
    }
    
    private func addWalls() {
        let wallThickness: CGFloat = 1
        
        // Left wall
        let leftWall = SKSpriteNode(color: .clear, size: CGSize(width: wallThickness, height: frame.height))
        leftWall.position = CGPoint(x: frame.minX, y: frame.midY)
        leftWall.physicsBody = SKPhysicsBody(rectangleOf: leftWall.size)
        leftWall.physicsBody?.isDynamic = false
        leftWall.physicsBody?.restitution = 0.0
        leftWall.physicsBody?.friction = 0.8
        addChild(leftWall)
        
        // Right wall
        let rightWall = SKSpriteNode(color: .clear, size: CGSize(width: wallThickness, height: frame.height))
        rightWall.position = CGPoint(x: frame.maxX, y: frame.midY)
        rightWall.physicsBody = SKPhysicsBody(rectangleOf: rightWall.size)
        rightWall.physicsBody?.isDynamic = false
        rightWall.physicsBody?.restitution = 0.0
        rightWall.physicsBody?.friction = 0.8
        addChild(rightWall)
        
        // Top wall (optional, prevents things escaping upward)
        let topWall = SKSpriteNode(color: .clear, size: CGSize(width: frame.width, height: wallThickness))
        topWall.position = CGPoint(x: frame.midX, y: frame.maxY)
        topWall.physicsBody = SKPhysicsBody(rectangleOf: topWall.size)
        topWall.physicsBody?.isDynamic = false
        topWall.physicsBody?.restitution = 0.0
        topWall.physicsBody?.friction = 0.8
        addChild(topWall)
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
