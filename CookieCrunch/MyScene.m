
#import "MyScene.h"
#import "RWTWord.h"
#import "RWTLevel.h"
#import "RWTSwap.h"

static const CGFloat TileWidth = 32.0;
static const CGFloat TileHeight = 36.0;

@interface MyScene ()

@property (strong, nonatomic) SKNode *gameLayer;
@property (strong, nonatomic) SKNode *wordsLayer;
@property (strong, nonatomic) SKNode *tilesLayer;

// The column and row numbers of the word that the player first touched
// when he started his swipe movement.
@property (assign, nonatomic) NSInteger swipeFromColumn;
@property (assign, nonatomic) NSInteger swipeFromRow;

// Sprite that is drawn on top of the word that the player is trying to swap.
@property (strong, nonatomic) SKLabelNode *selectionSprite;

@property (strong, nonatomic) SKAction *swapSound;
@property (strong, nonatomic) SKAction *invalidSwapSound;
@property (strong, nonatomic) SKAction *matchSound;
@property (strong, nonatomic) SKAction *fallingWordSound;
@property (strong, nonatomic) SKAction *addWordSound;

@property (strong, nonatomic) SKCropNode *cropLayer;
@property (strong, nonatomic) SKNode *maskLayer;

@end

@implementation MyScene

- (id)initWithSize:(CGSize)size {
  if ((self = [super initWithSize:size])) {

    self.anchorPoint = CGPointMake(0.5, 0.5);

    // Put an image on the background. Because the scene's anchorPoint is
    // (0.5, 0.5), the background image will always be centered on the screen.
    SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"Background"];
    [self addChild:background];

    // Add a new node that is the container for all other layers on the playing
    // field. This gameLayer is also centered in the screen.
    self.gameLayer = [SKNode node];
    self.gameLayer.hidden = YES;
    [self addChild:self.gameLayer];

    CGPoint layerPosition = CGPointMake(-TileWidth*NumColumns/2, -TileHeight*NumRows/2);

    // The tiles layer represents the shape of the level. It contains a sprite
    // node for each square that is filled in.
    self.tilesLayer = [SKNode node];
    self.tilesLayer.position = layerPosition;
    [self.gameLayer addChild:self.tilesLayer];

    // We use a crop layer to prevent words from being drawn across gaps
    // in the level design.
    self.cropLayer = [SKCropNode node];
    [self.gameLayer addChild:self.cropLayer];

    // The mask layer determines which part of the wordsLayer is visible.
    self.maskLayer = [SKNode node];
    self.maskLayer.position = layerPosition;
    self.cropLayer.maskNode = self.maskLayer;

    // This layer holds the RWTWord sprites. The positions of these sprites
    // are relative to the wordsLayer's bottom-left corner.
    self.wordsLayer = [SKNode node];
    self.wordsLayer.position = layerPosition;

    [self.cropLayer addChild:self.wordsLayer];

    // NSNotFound means that these properties have invalid values.
    self.swipeFromColumn = self.swipeFromRow = NSNotFound;

    self.selectionSprite = [SKSpriteNode node];

    [self preloadResources];
  }
  return self;
}

- (void)preloadResources {
  self.swapSound = [SKAction playSoundFileNamed:@"Chomp.wav" waitForCompletion:NO];
  self.invalidSwapSound = [SKAction playSoundFileNamed:@"Error.wav" waitForCompletion:NO];
  self.matchSound = [SKAction playSoundFileNamed:@"Ka-Ching.wav" waitForCompletion:NO];
  self.fallingWordSound = [SKAction playSoundFileNamed:@"Scrape.wav" waitForCompletion:NO];
  self.addWordSound = [SKAction playSoundFileNamed:@"Drip.wav" waitForCompletion:NO];

  [SKLabelNode labelNodeWithFontNamed:@"GillSans-BoldItalic"];
}

#pragma mark - Conversion Routines

// Converts a column,row pair into a CGPoint that is relative to the wordLayer.
- (CGPoint)pointForColumn:(NSInteger)column row:(NSInteger)row {
  return CGPointMake(column*TileWidth + TileWidth/2, row*TileHeight + TileHeight/2);
}

// Converts a point relative to the wordLayer into column and row numbers.
- (BOOL)convertPoint:(CGPoint)point toColumn:(NSInteger *)column row:(NSInteger *)row {

  // "column" and "row" are output parameters, so they cannot be nil.
  NSParameterAssert(column);
  NSParameterAssert(row);

  // Is this a valid location within the words layer? If yes,
  // calculate the corresponding row and column numbers.
  if (point.x >= 0 && point.x < NumColumns*TileWidth &&
      point.y >= 0 && point.y < NumRows*TileHeight) {

    *column = point.x / TileWidth;
    *row = point.y / TileHeight;
    return YES;

  } else {
    *column = NSNotFound;  // invalid location
    *row = NSNotFound;
    return NO;
  }
}

#pragma mark - Game Setup

- (void)addTiles {
  for (NSInteger row = 0; row < NumRows; row++) {
    for (NSInteger column = 0; column < NumColumns; column++) {

      // If there is a tile at this position, then create a new tile
      // sprite and add it to the mask layer.
      if ([self.level tileAtColumn:column row:row] != nil) {
        SKSpriteNode *tileNode = [SKSpriteNode spriteNodeWithImageNamed:@"MaskTile"];
        tileNode.position = [self pointForColumn:column row:row];
        [self.maskLayer addChild:tileNode];
      }
    }
  }

  // The tile pattern is drawn *in between* the level tiles. That's why
  // there is an extra column and row of them.
  for (NSInteger row = 0; row <= NumRows; row++) {
    for (NSInteger column = 0; column <= NumColumns; column++) {

      BOOL topLeft     = (column > 0)          && (row < NumRows) && [self.level tileAtColumn:column - 1 row:row];
      BOOL bottomLeft  = (column > 0)          && (row > 0)       && [self.level tileAtColumn:column - 1 row:row - 1];
      BOOL topRight    = (column < NumColumns) && (row < NumRows) && [self.level tileAtColumn:column     row:row];
      BOOL bottomRight = (column < NumColumns) && (row > 0)       && [self.level tileAtColumn:column     row:row - 1];

      // The tiles are named from 0 to 15, according to the bitmask that is
      // made by combining these four values.
      NSUInteger value = topLeft | topRight << 1 | bottomLeft << 2 | bottomRight << 3;

      // Values 0 (no tiles), 6 and 9 (two opposite tiles) are not drawn.
      if (value != 0 && value != 6 && value != 9) {
        NSString *name = [NSString stringWithFormat:@"Tile_%lu", (long)value];
        SKSpriteNode *tileNode = [SKSpriteNode spriteNodeWithImageNamed:name];
        CGPoint point = [self pointForColumn:column row:row];
        point.x -= TileWidth/2;
        point.y -= TileHeight/2;
        tileNode.position = point;
        [self.tilesLayer addChild:tileNode];
      }
    }
  }
}

- (void)addSpritesForWords:(NSSet *)words {
  for (RWTWord *word in words) {
      SKLabelNode *wordLabel = [SKLabelNode labelNodeWithFontNamed:@"Moebius Korea Bold"];
      wordLabel.position = [self pointForColumn:word.column row:word.row];
      wordLabel.text = [word spriteName];
      wordLabel.fontColor = [word getWordColor];
      wordLabel.fontSize = 12.0f;
      
      [self.wordsLayer addChild:wordLabel];
      word.sprite = wordLabel;

      // Give each word sprite a small, random delay. Then fade them in.
      word.sprite.alpha = 0;
//      word.sprite.xScale = word.sprite.yScale = 0.5;

      [word.sprite runAction:[SKAction sequence:@[
        [SKAction waitForDuration:0.25 withRange:0.5],
        [SKAction group:@[
            [SKAction fadeInWithDuration:0.25],
            [SKAction scaleTo:1.0 duration:0.25]
      ]]]]];
  }
}

- (void)removeAllWordSprites {
  [self.wordsLayer removeAllChildren];
}

#pragma mark - Detecting Swipes

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

  // Convert the touch location to a point relative to the wordsLayer.
  UITouch *touch = [touches anyObject];
  CGPoint location = [touch locationInNode:self.wordsLayer];

  // If the touch is inside a square, then this might be the start of a
  // swipe motion.
  NSInteger column, row;
  if ([self convertPoint:location toColumn:&column row:&row]) {

    // The touch must be on a word, not on an empty tile.
    RWTWord *word = [self.level wordAtColumn:column row:row];
    if (word != nil) {

      // Remember in which column and row the swipe started, so we can compare
      // them later to find the direction of the swipe. This is also the first
      // word that will be swapped.
      self.swipeFromColumn = column;
      self.swipeFromRow = row;

      [self showSelectionIndicatorForWord:word];
    }
  }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

  // If swipeFromColumn is NSNotFound then either the swipe began outside
  // the valid area or the game has already swapped the words and we need
  // to ignore the rest of the motion.
  if (self.swipeFromColumn == NSNotFound) return;

  UITouch *touch = [touches anyObject];
  CGPoint location = [touch locationInNode:self.wordsLayer];

  NSInteger column, row;
  if ([self convertPoint:location toColumn:&column row:&row]) {

    // Figure out in which direction the player swiped. Diagonal swipes
    // are not allowed.
    NSInteger horzDelta = 0, vertDelta = 0;
    if (column < self.swipeFromColumn) {          // swipe left
      horzDelta = -1;
    } else if (column > self.swipeFromColumn) {   // swipe right
      horzDelta = 1;
    } else if (row < self.swipeFromRow) {         // swipe down
      vertDelta = -1;
    } else if (row > self.swipeFromRow) {         // swipe up
      vertDelta = 1;
    }

    // Only try swapping when the user swiped into a new square.
    if (horzDelta != 0 || vertDelta != 0) {
      [self trySwapHorizontal:horzDelta vertical:vertDelta];
      [self hideSelectionIndicator];

      // Ignore the rest of this swipe motion from now on. Just setting
      // swipeFromColumn is enough; no need to set swipeFromRow as well.
      self.swipeFromColumn = NSNotFound;
    }
  }
}

- (void)trySwapHorizontal:(NSInteger)horzDelta vertical:(NSInteger)vertDelta {

  // We get here after the user performs a swipe. This sets in motion a whole
  // chain of events: 1) swap the words, 2) remove the matching lines, 3)
  // drop new words into the screen, 4) check if they create new matches,
  // and so on.

  NSInteger toColumn = self.swipeFromColumn + horzDelta;
  NSInteger toRow = self.swipeFromRow + vertDelta;

  // Going outside the bounds of the array? This happens when the user swipes
  // over the edge of the grid. We should ignore such swipes.
  if (toColumn < 0 || toColumn >= NumColumns) return;
  if (toRow < 0 || toRow >= NumRows) return;

  // Can't swap if there is no word to swap with. This happens when the user
  // swipes into a gap where there is no tile.
  RWTWord *toWord = [self.level wordAtColumn:toColumn row:toRow];
  if (toWord == nil) return;

  RWTWord *fromWord = [self.level wordAtColumn:self.swipeFromColumn row:self.swipeFromRow];

  // Communicate this swap request back to the ViewController.
  if (self.swipeHandler != nil) {
    RWTSwap *swap = [[RWTSwap alloc] init];
    swap.wordA = fromWord;
    swap.wordB = toWord;

    self.swipeHandler(swap);
  }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {

  // Remove the selection indicator with a fade-out. We only need to do this
  // when the player didn't actually swipe.
  if (self.selectionSprite.parent != nil && self.swipeFromColumn != NSNotFound) {
    [self hideSelectionIndicator];
  }

  // If the gesture ended, regardless of whether if was a valid swipe or not,
  // reset the starting column and row numbers.
  self.swipeFromColumn = self.swipeFromRow = NSNotFound;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
  [self touchesEnded:touches withEvent:event];
}

#pragma mark - Selection Indicator

- (void)showSelectionIndicatorForWord:(RWTWord *)word {

  // If the selection indicator is still visible, then first remove it.
//  if (self.selectionSprite != nil) {
//      [self.selectionSprite removeFromParent];
//  }

  // Add the selection indicator as a child to the word that the player
  // tapped on and fade it in. Note: simply setting the texture on the sprite
  // doesn't give it the correct size; using an SKAction does.
    
    self.selectionSprite = word.sprite;
    
    [word.sprite runAction:[SKAction scaleTo:1.5 duration:0.1]];
}

- (void)hideSelectionIndicator {
    [self.selectionSprite runAction:[SKAction scaleTo:1 duration:0.3]];
}

#pragma mark - Animations

- (void)animateSwap:(RWTSwap *)swap completion:(dispatch_block_t)completion {

  // Put the word you started with on top.
  swap.wordA.sprite.zPosition = 100;
  swap.wordB.sprite.zPosition = 90;

  const NSTimeInterval Duration = 0.3;

  SKAction *moveA = [SKAction moveTo:swap.wordB.sprite.position duration:Duration];
  moveA.timingMode = SKActionTimingEaseOut;
  [swap.wordA.sprite runAction:[SKAction sequence:@[moveA, [SKAction runBlock:completion]]]];

  SKAction *moveB = [SKAction moveTo:swap.wordA.sprite.position duration:Duration];
  moveB.timingMode = SKActionTimingEaseOut;
  [swap.wordB.sprite runAction:moveB];

  [self runAction:self.swapSound];
}

- (void)animateInvalidSwap:(RWTSwap *)swap completion:(dispatch_block_t)completion {
  swap.wordA.sprite.zPosition = 100;
  swap.wordB.sprite.zPosition = 90;

  const NSTimeInterval Duration = 0.2;

  SKAction *moveA = [SKAction moveTo:swap.wordB.sprite.position duration:Duration];
  moveA.timingMode = SKActionTimingEaseOut;

  SKAction *moveB = [SKAction moveTo:swap.wordA.sprite.position duration:Duration];
  moveB.timingMode = SKActionTimingEaseOut;

  [swap.wordA.sprite runAction:[SKAction sequence:@[moveA, moveB, [SKAction runBlock:completion]]]];
  [swap.wordB.sprite runAction:[SKAction sequence:@[moveB, moveA]]];

  [self runAction:self.invalidSwapSound];
}

- (void)animateMatchedWords:(NSSet *)chains completion:(dispatch_block_t)completion {

  for (RWTChain *chain in chains) {
    [self animateScoreForChain:chain];
    for (RWTWord *word in chain.words) {

      if (word.sprite != nil) {
        SKAction *scaleAction = [SKAction scaleTo:0.1 duration:0.3];
        scaleAction.timingMode = SKActionTimingEaseOut;
        [word.sprite runAction:[SKAction sequence:@[scaleAction, [SKAction removeFromParent]]]];

        // It may happen that the same RWTWord object is part of two chains
        // (L-shape match). In that case, its sprite should only be removed
        // once.
        word.sprite = nil;
      }
    }
  }

  [self runAction:self.matchSound];

  // Continue with the game after the animations have completed.
  [self runAction:[SKAction sequence:@[
    [SKAction waitForDuration:0.3],
    [SKAction runBlock:completion]
    ]]];
}

- (void)animateScoreForChain:(RWTChain *)chain {
  // Figure out what the midpoint of the chain is.
  RWTWord *firstWord = [chain.words firstObject];
  RWTWord *lastWord = [chain.words lastObject];
  CGPoint centerPosition = CGPointMake(
    (firstWord.sprite.position.x + lastWord.sprite.position.x)/2,
    (firstWord.sprite.position.y + lastWord.sprite.position.y)/2 - 8);

  // Add a label for the score that slowly floats up.
  SKLabelNode *scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"GillSans-BoldItalic"];
  scoreLabel.fontSize = 16;
  scoreLabel.text = [NSString stringWithFormat:@"%lu", (long)chain.score];
  scoreLabel.position = centerPosition;
  scoreLabel.zPosition = 300;
  [self.wordsLayer addChild:scoreLabel];

  SKAction *moveAction = [SKAction moveBy:CGVectorMake(0, 3) duration:0.7];
  moveAction.timingMode = SKActionTimingEaseOut;
  [scoreLabel runAction:[SKAction sequence:@[
    moveAction,
    [SKAction removeFromParent]
    ]]];
}

- (void)animateFallingWords:(NSArray *)columns completion:(dispatch_block_t)completion {
  __block NSTimeInterval longestDuration = 0;

  for (NSArray *array in columns) {

    [array enumerateObjectsUsingBlock:^(RWTWord *word, NSUInteger idx, BOOL *stop) {
      CGPoint newPosition = [self pointForColumn:word.column row:word.row];

      // The further away from the hole you are, the bigger the delay
      // on the animation.
      NSTimeInterval delay = 0.05 + 0.15*idx;

      // Calculate duration based on far word has to fall (0.1 seconds
      // per tile).
      NSTimeInterval duration = ((word.sprite.position.y - newPosition.y) / TileHeight) * 0.1;
      longestDuration = MAX(longestDuration, duration + delay);

      SKAction *moveAction = [SKAction moveTo:newPosition duration:duration];
      moveAction.timingMode = SKActionTimingEaseOut;
      [word.sprite runAction:[SKAction sequence:@[
        [SKAction waitForDuration:delay],
        [SKAction group:@[moveAction, self.fallingWordSound]]]]];
    }];
  }

  // Wait until all the words have fallen down before we continue.
  [self runAction:[SKAction sequence:@[
    [SKAction waitForDuration:longestDuration],
    [SKAction runBlock:completion]
    ]]];
}

- (void)animateNewWords:(NSArray *)columns completion:(dispatch_block_t)completion {

  // We don't want to continue with the game until all the animations are
  // complete, so we calculate how long the longest animation lasts, and
  // wait that amount before we trigger the completion block.
  __block NSTimeInterval longestDuration = 0;

  for (NSArray *array in columns) {

    // The new sprite should start out just above the first tile in this column.
    // An easy way to find this tile is to look at the row of the first word
    // in the array, which is always the top-most one for this column.
    NSInteger startRow = ((RWTWord *)[array firstObject]).row + 1;

    [array enumerateObjectsUsingBlock:^(RWTWord *word, NSUInteger idx, BOOL *stop) {

      // Create a new sprite for the word.
        SKLabelNode *wordLabel = [SKLabelNode labelNodeWithFontNamed:@"Moebius Korea Bold"];
        wordLabel.position = [self pointForColumn:word.column row:word.row];
        wordLabel.text = [word spriteName];
        wordLabel.fontColor = [word getWordColor];
        wordLabel.fontSize = 12.0f;
      [self.wordsLayer addChild:wordLabel];
      word.sprite = wordLabel;

      // Give each word that's higher up a longer delay, so they appear to
      // fall after one another.
      NSTimeInterval delay = 0.1 + 0.2*([array count] - idx - 1);

      // Calculate duration based on far the word has to fall.
      NSTimeInterval duration = (startRow - word.row) * 0.1;
      longestDuration = MAX(longestDuration, duration + delay);

      // Animate the sprite falling down. Also fade it in to make the sprite
      // appear less abruptly.
      CGPoint newPosition = [self pointForColumn:word.column row:word.row];
      SKAction *moveAction = [SKAction moveTo:newPosition duration:duration];
      moveAction.timingMode = SKActionTimingEaseOut;
      word.sprite.alpha = 0;
      [word.sprite runAction:[SKAction sequence:@[
        [SKAction waitForDuration:delay],
        [SKAction group:@[
          [SKAction fadeInWithDuration:0.05], moveAction, self.addWordSound]]]]];
    }];
  }

  // Wait until the animations are done before we continue.
  [self runAction:[SKAction sequence:@[
    [SKAction waitForDuration:longestDuration],
    [SKAction runBlock:completion]
    ]]];
}

- (void)animateGameOver {
  SKAction *action = [SKAction moveBy:CGVectorMake(0, -self.size.height) duration:0.3];
  action.timingMode = SKActionTimingEaseIn;
  [self.gameLayer runAction:action];
}

- (void)animateBeginGame {
  self.gameLayer.hidden = NO;

  self.gameLayer.position = CGPointMake(0, self.size.height);
  SKAction *action = [SKAction moveBy:CGVectorMake(0, -self.size.height) duration:0.3];
  action.timingMode = SKActionTimingEaseOut;
  [self.gameLayer runAction:action];
}

@end
