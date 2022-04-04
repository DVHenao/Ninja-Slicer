
import SpriteKit

func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func /(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x / scalar, y: point.y / scalar)
}


func sqrt(a: CGFloat) -> CGFloat {
  return CGFloat(sqrtf(Float(a)))
}


extension CGPoint {
  func length() -> CGFloat {
    return sqrt(x*x + y*y)
  }
  
  func normalized() -> CGPoint {
    return self / length()
  }
}

class GameScene: SKScene {
  
  struct PhysicsCategory {
    static let none      : UInt32 = 0
    static let all       : UInt32 = UInt32.max
    static let enemy   : UInt32 = 0b1       // 1
    static let projectile: UInt32 = 0b10      // 2
  }
  
  let player = SKSpriteNode(imageNamed: "player")
  var monstersDestroyed = 0
  
  override func didMove(to view: SKView) {

    backgroundColor = SKColor.blue

    player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)

    addChild(player)
    
    physicsWorld.gravity = .zero
    physicsWorld.contactDelegate = self
    
    run(SKAction.repeatForever(
      SKAction.sequence([
        SKAction.run(addEnemy),
        SKAction.wait(forDuration: 0.7)
        ])
    ))
    
    let backgroundMusic = SKAudioNode(fileNamed: "background-music-aac.caf")
    backgroundMusic.autoplayLooped = true
    addChild(backgroundMusic)
  }
  
  func random() -> CGFloat {
    return CGFloat(Float(arc4random()) / 0xFFFFFFFF)
  }
  
  func random(min: CGFloat, max: CGFloat) -> CGFloat {
    return random() * (max - min) + min
  }
  
  func addEnemy() {
    // Create sprite
    let Enemy = SKSpriteNode(imageNamed: "monster")
    
    Enemy.physicsBody = SKPhysicsBody(rectangleOf: Enemy.size) // 1
    Enemy.physicsBody?.isDynamic = true // 2
    Enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy // 3
    Enemy.physicsBody?.contactTestBitMask = PhysicsCategory.projectile // 4
    Enemy.physicsBody?.collisionBitMask = PhysicsCategory.none // 5
    
    let actualY = random(min: Enemy.size.height/2, max: size.height - Enemy.size.height/2)
    
    Enemy.position = CGPoint(x: size.width + Enemy.size.width/2, y: actualY)
    
    addChild(Enemy)
    
    let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
    

    let actionMove = SKAction.move(to: CGPoint(x: -Enemy.size.width/2, y: actualY), duration: TimeInterval(actualDuration))
    let actionMoveDone = SKAction.removeFromParent()
    let loseAction = SKAction.run() { [weak self] in
      guard let `self` = self else { return }
      let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
      let gameOverScene = GameOverScene(size: self.size, won: false)
      self.view?.presentScene(gameOverScene, transition: reveal)
    }
    Enemy.run(SKAction.sequence([actionMove, loseAction, actionMoveDone]))
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else {
      return
    }
    run(SKAction.playSoundFileNamed("pew-pew-lei.caf", waitForCompletion: false))
    
    let touchLocation = touch.location(in: self)
    
    let projectile = SKSpriteNode(imageNamed: "projectile")
    projectile.position = player.position
    
    projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
    projectile.physicsBody?.isDynamic = true
    projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
    projectile.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
    projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
    projectile.physicsBody?.usesPreciseCollisionDetection = true
    
    let offset = touchLocation - projectile.position
    if offset.x < 0 { return }
    addChild(projectile)
    let direction = offset.normalized()
    let shootAmount = direction * 1000
    let realDest = shootAmount + projectile.position
    
    let actionMove = SKAction.move(to: realDest, duration: 2.0)
    let actionMoveDone = SKAction.removeFromParent()
    projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
  }
  
  func projectileDidCollideWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode) {
    print("Hit")
    projectile.removeFromParent()
    monster.removeFromParent()
    
    monstersDestroyed += 1
    if monstersDestroyed > 30 {
      let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
      let gameOverScene = GameOverScene(size: self.size, won: true)
      view?.presentScene(gameOverScene, transition: reveal)
    }
  }
}

extension GameScene: SKPhysicsContactDelegate {
  func didBegin(_ contact: SKPhysicsContact) {
    
    var firstBody: SKPhysicsBody
    var secondBody: SKPhysicsBody
    if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
      firstBody = contact.bodyA
      secondBody = contact.bodyB
    } else {
      firstBody = contact.bodyB
      secondBody = contact.bodyA
    }
    
    if ((firstBody.categoryBitMask & PhysicsCategory.enemy != 0) &&
      (secondBody.categoryBitMask & PhysicsCategory.projectile != 0)) {
      if let monster = firstBody.node as? SKSpriteNode,
        let projectile = secondBody.node as? SKSpriteNode {
        projectileDidCollideWithMonster(projectile: projectile, monster: monster)
      }
    }
  }
}
