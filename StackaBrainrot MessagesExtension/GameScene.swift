//
//  GameScene.swift
//  StackaBrainrot
//
//  Created by Jay Yeung on 1/29/26.
//

import SpriteKit

final class GameScene: SKScene {
    
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
    
    private var hoverBrainrot: SKSpriteNode?
    private var nextBrainrotId: Int = 0
    
    private var settleFrameCount = 0
    private let settleFramesRequired = 30  // ~0.5s at 60fps
    private var pendingReplayDrop: LastDrop?
    private var pendingLiveDrop: (brainrotId: Int, normalizedX: CGFloat)?
    private var baseBlocksFrozenFrames = 0
    private var dropFrameCounter = 0
    private var droppedNodeName: String?
    
    private(set) var isSettled: Bool = false

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
        if baseBlocksFrozenFrames > 0 {
            baseBlocksFrozenFrames -= 1
            if baseBlocksFrozenFrames == 0 {
                for node in children where node.name == "brainrot" && node.userData?["isBaseBlock"] as? Bool == true {
                    node.physicsBody?.isDynamic = true
                }
            }
            return
        }
        
        if let drop = pendingReplayDrop {
            pendingReplayDrop = nil
            spawnReplayDrop(drop)
            settleFrameCount = 0
            isSettled = false
            return
        }
        
        if let drop = pendingLiveDrop {
            pendingLiveDrop = nil
            let x = frame.minX + drop.normalizedX * frame.width
            let y = frame.maxY - 40
            let node = createBrainrot(brainrotId: drop.brainrotId, at: CGPoint(x: x, y: y), rotation: 0)
            node.userData?["isDropping"] = true
            droppedNodeName = node.name
            dropFrameCounter = 0
            addChild(node)
            settleFrameCount = 0
            isSettled = false
            return
        }
        
        dropFrameCounter += 1
        if dropFrameCounter == 15, let nodeName = droppedNodeName {
            for node in children where node.name == nodeName && node.userData?["isDropping"] as? Bool == true {
                node.userData?["isDropping"] = false
                if let body = node.physicsBody {
                    body.restitution = 0.01
                    body.linearDamping = 0.7
                    body.angularDamping = 1.5
                }
            }
            droppedNodeName = nil
        }
        
        let velocityThreshold: CGFloat = 0.5
        let angularThreshold: CGFloat = 0.1
        
        var allSettled = true
        for node in children where node.name == "brainrot" {
            if let body = node.physicsBody, body.isDynamic {
                if abs(body.angularVelocity) > 6 {
                    body.angularVelocity = 6 * (body.angularVelocity > 0 ? 1 : -1)
                }
                
                let vel = body.velocity
                let speed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy)
                let angVel = abs(body.angularVelocity)
                
                if speed > velocityThreshold || angVel > angularThreshold {
                    allSettled = false
                }
            }
        }
        
        if allSettled {
            settleFrameCount += 1
            if settleFrameCount >= settleFramesRequired {
                isSettled = true
                if settleFrameCount == settleFramesRequired {
                    onSettled?()
                }
            }
        } else {
            settleFrameCount = 0
            isSettled = false
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
            
            node.physicsBody?.isDynamic = false
            node.userData?["isBaseBlock"] = true
            node.physicsBody?.velocity = CGVector(dx: block.velocityX, dy: block.velocityY)
            node.physicsBody?.angularVelocity = CGFloat(block.angularVelocity)
            
            addChild(node)
        }
        
        if !state.blocks.isEmpty {
            baseBlocksFrozenFrames = 1
        }
        
        if let lastDrop = state.lastDrop {
            pendingReplayDrop = lastDrop
        }
        
        settleFrameCount = 0
        isSettled = false
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
        node.userData = NSMutableDictionary()
        node.userData?["brainrotId"] = brainrotId
        node.setScale(0.65)
        node.position = position
        node.zRotation = rotation
        
        if let tex = node.texture {
            node.physicsBody = SKPhysicsBody(texture: tex,
                                            size: CGSize(width: node.size.width * 0.90,
                                                        height: node.size.height * 0.90))
        } else {
            node.physicsBody = SKPhysicsBody(rectangleOf: node.size)
        }
        
        node.physicsBody?.isDynamic = true
        
        let isDropping = node.userData?["isDropping"] as? Bool ?? false
        if isDropping {
            node.physicsBody?.restitution = 0.0
            node.physicsBody?.linearDamping = 0.9
            node.physicsBody?.angularDamping = 1.8
        } else {
            node.physicsBody?.restitution = 0.01
            node.physicsBody?.linearDamping = 0.7
            node.physicsBody?.angularDamping = 1.5
        }
        
        node.physicsBody?.friction = 1.3
        node.physicsBody?.usesPreciseCollisionDetection = true
        
        return node
    }

    func dropBrainrot(brainrotId: Int, normalizedX: CGFloat) -> LastDrop {
        let normalizedY: CGFloat = (frame.maxY - 40 - frame.minY) / frame.height
        
        // Queue drop to spawn on next didSimulatePhysics (same as replay)
        pendingLiveDrop = (brainrotId: brainrotId, normalizedX: normalizedX)
        
        settleFrameCount = 0
        isSettled = false
        
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

        p.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: platformWidth, height: platformHeight + 4))
        p.physicsBody?.isDynamic = false
        p.physicsBody?.restitution = 0.0
        p.physicsBody?.friction = 2.0
        p.physicsBody?.linearDamping = 0
        p.physicsBody?.angularDamping = 0
        
        addChild(p)
    }
    
    func getAllBlocks() -> [Block] {
        let blocks = children
            .filter { $0.name == "brainrot" }
            .compactMap { node -> Block? in
                guard let brainrotId = node.userData?["brainrotId"] as? Int
                else { return nil }
                
                let nx = (node.position.x - frame.minX) / frame.width
                let ny = (node.position.y - frame.minY) / frame.height
                let vx = node.physicsBody?.velocity.dx ?? 0
                let vy = node.physicsBody?.velocity.dy ?? 0
                let av = node.physicsBody?.angularVelocity ?? 0
                
                let quantize = { (val: CGFloat, scale: CGFloat) -> Double in
                    return Double((val * scale).rounded() / scale)
                }
                
                return Block(
                    brainrotId: brainrotId,
                    x: quantize(nx, 1000),
                    y: quantize(ny, 1000),
                    rotation: quantize(node.zRotation, 10000),
                    velocityX: quantize(vx, 1000),
                    velocityY: quantize(vy, 1000),
                    angularVelocity: quantize(av, 1000)
                )
            }
        
        return blocks.sorted {
            if abs($0.y - $1.y) > 0.001 { return $0.y < $1.y }
            if abs($0.x - $1.x) > 0.001 { return $0.x < $1.x }
            return $0.brainrotId < $1.brainrotId
        }
    }
    
    func setNextBrainrotId(_ id: Int) {
        nextBrainrotId = id
    }
    
    func updateHoverBrainrot(at normalizedX: CGFloat) {
        let x = frame.minX + normalizedX * frame.width
        let y = frame.maxY - 120
        
        if hoverBrainrot == nil {
            let texName = brainrotTextureNames[nextBrainrotId % brainrotTextureNames.count]
            let node = SKSpriteNode(imageNamed: texName)
            node.name = "hover"
            node.setScale(0.65)
            node.alpha = 0.8
            node.zPosition = 1000
            hoverBrainrot = node
            addChild(node)
        }
        
        hoverBrainrot?.position = CGPoint(x: x, y: y)
        hoverBrainrot?.alpha = 0.8
    }
    
    func hideHoverBrainrot() {
        hoverBrainrot?.removeFromParent()
        hoverBrainrot = nil
    }
}
