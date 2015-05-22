
#import <SpriteKit/SpriteKit.h>

@class RWTLevel;
@class RWTSwap;

@interface MyScene : SKScene

@property (strong, nonatomic) RWTLevel *level;

// The scene handles touches. If it recognizes that the user makes a swipe,
// it will call this swipe handler. This is how it communicates back to the
// ViewController that a swap needs to take place. You can also use a delegate
// for this.
@property (copy, nonatomic) void (^swipeHandler)(RWTSwap *swap);

- (void)addSpritesForWords:(NSSet *)words;
- (void)addTiles;
- (void)removeAllWordSprites;

- (void)animateSwap:(RWTSwap *)swap completion:(dispatch_block_t)completion;
- (void)animateInvalidSwap:(RWTSwap *)swap completion:(dispatch_block_t)completion;
- (void)animateMatchedWords:(NSSet *)chains completion:(dispatch_block_t)completion;
- (void)animateFallingWords:(NSArray *)columns completion:(dispatch_block_t)completion;
- (void)animateNewWords:(NSArray *)columns completion:(dispatch_block_t)completion;
- (void)animateGameOver;
- (void)animateBeginGame;

@end
