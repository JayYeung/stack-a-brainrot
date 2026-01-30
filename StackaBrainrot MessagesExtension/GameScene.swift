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
    
    var onBrainrotFellOff: (() -> Void)?
    var onSettled: (() -> Void)?
    
    private var settleFrameCount = 0
    private let settleFramesRequired = 30  // ~0.5s at 60fps
    private var pendingReplayDrop: LastDrop?

    override func didMove(to view: SKView) {
        backgroundColor = .systemBackground
        physicsWorld.gravity = CGVector(dx: 0, dy: -12)
        addPlatform()
    }
    
    override func update(_ currentTime: TimeInterval) {
        let fallenThreshold = frame.minY - 100
        for node in children where node.name == "brainrot" {
            if node.position.y < fallenThreshold {
                node.removeFromParent()
                onBrainrotFellOff?()
            }
        }
    }
    
    override func didSimulatePhysics() {
        if let drop = pendingReplayDrop {
            pendingReplayDrop = nil
            spawnReplayDrop(drop)
            settleFrameCount = 0
            return
        }
        
        let velocityThreshold: CGFloat = 0.5
        let angularThreshold: CGFloat = 0.1
        
        var allSettled = true
        for node in children where node.name == "brainrot" {
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
            settleFrameCount += 1
            if settleFrameCount >= settleFramesRequired {
                if settleFrameCount == settleFramesRequired {
                    onSettled?()
                }
            }
        } else {
            settleFrameCount = 0
        }
    }

    func load(state: GameState) {
        children
            .filter { $0.name == "brainrot" }
            .forEach { $0.removeFromParent() }

        for block in state.blocks {
            let x = frame.minX + CGFloat(block.x) * frame.width
            let y = frame.minY + CGFloat(block.y) * frame.height
            let node = createBrainrot(brainrotId: block.brainrotId, at: CGPoint(x: x, y: y), rotation: CGFloat(block.rotation))
            
            node.physicsBody?.isDynamic = true
            node.physicsBody?.velocity = .zero
            node.physicsBody?.angularVelocity = 0
            
            addChild(node)
        }
        
        if let lastDrop = state.lastDrop {
            pendingReplayDrop = lastDrop
        }
        
        settleFrameCount = 0
    }
    
    private func spawnReplayDrop(_ drop: LastDrop) {
        let x = frame.minX + CGFloat(drop.spawnX) * frame.width
        let y = frame.minY + CGFloat(drop.spawnY) * frame.height
        let node = createBrainrot(brainrotId: drop.brainrotId, at: CGPoint(x: x, y: y), rotation: CGFloat(drop.spawnRotation))
        
        node.physicsBody?.isDynamic = true
        node.physicsBody?.velocity = CGVector(dx: drop.velocityX, dy: drop.velocityY)
        node.physicsBody?.angularVelocity = CGFloat(drop.angularVelocity)
        
        addChild(node)
    }
    
    private func createBrainrot(brainrotId: Int, at position: CGPoint, rotation: CGFloat) -> SKSpriteNode {
        let texName = brainrotTextureNames[brainrotId % brainrotTextureNames.count]
        let node = SKSpriteNode(imageNamed: texName)
        node.name = "brainrot"
        node.userData = ["brainrotId": brainrotId]
        node.setScale(0.5)
        node.position = position
        node.zRotation = rotation
        
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex,
                                            size: CGSize(width: node.size.width * 0.95,
                                                        height: node.size.height * 0.95))
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }
        
        node.physicsBody?.isDynamic = true
        node.physicsBody?.restitution = 0.01
        node.physicsBody?.friction = 0.9
        node.physicsBody?.linearDamping = 0.5
        node.physicsBody?.angularDamping = 0.9
        node.physicsBody?.usesPreciseCollisionDetection = true
        
        return node
    }

    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat) -> LastDrop {
        let normalizedY: CGFloat = (frame.maxY - 40 - frame.minY) / frame.height
        let x = frame.minX + normalizedX * frame.width
        let y = frame.maxY - 40
        
        let node = createBrainrot(brainrotId: brainrotId, at: CGPoint(x: x, y: y), rotation: 0)
        addChild(node)
        
        settleFrameCount = 0
        
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
    
    private func addPlatform() {
        let platformWidth = frame.width * 0.8
        let platformHeight: CGFloat = 20
        
        let p = SKSpriteNode(color: .systemGray, size: CGSize(width: platformWidth, height: platformHeight))
        p.position = CGPoint(x: frame.midX, y: frame.minY + 60)

        p.physicsBody = SKPhysicsBody(rectangleOf: p.size)
        p.physicsBody?.isDynamic = false
        p.physicsBody?.restitution = 0.0
        p.physicsBody?.friction = 1.5
        
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
