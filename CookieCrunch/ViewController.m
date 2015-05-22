//
//  ViewController.m
//  wordCrunch
//
//  Created by Matthijs on 25-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

@import AVFoundation;

#import "ViewController.h"
#import "MyScene.h"
#import "RWTLevel.h"

@interface ViewController ()

// The level contains the tiles, the words, and most of the gameplay logic.
@property (strong, nonatomic) RWTLevel *level;

// The scene draws the tiles and word sprites, and handles swipes.
@property (strong, nonatomic) MyScene *scene;

@property (assign, nonatomic) NSUInteger movesLeft;
@property (assign, nonatomic) NSUInteger score;
@property (assign, nonatomic) NSUInteger time;

@property (weak, nonatomic) IBOutlet UILabel *targetLabel;
@property (weak, nonatomic) IBOutlet UILabel *movesLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UIButton *shuffleButton;
@property (weak, nonatomic) IBOutlet UIImageView *gameOverPanel;

@property (strong, nonatomic) UITapGestureRecognizer *tapGestureRecognizer;

@property (strong, nonatomic) AVAudioPlayer *backgroundMusic;

@property (strong, nonatomic) NSTimer* timer;

@end

@implementation ViewController




- (void)viewDidLoad {
  [super viewDidLoad];

  // Configure the view.
  SKView *skView = (SKView *)self.view;
  skView.multipleTouchEnabled = NO;
  
  // Create and configure the scene.
  self.scene = [MyScene sceneWithSize:skView.bounds.size];
  self.scene.scaleMode = SKSceneScaleModeAspectFill;

  // Load the level.
  self.level = [[RWTLevel alloc] initWithFile:@"Level_0"];
  self.scene.level = self.level;
  [self.scene addTiles];

  // This is the swipe handler. MyScene invokes this block whenever it
  // detects that the player performs a swipe.
  id block = ^(RWTSwap *swap) {

    // While words are being matched and new words fall down to fill up
    // the holes, we don't want the player to tap on anything.
    self.view.userInteractionEnabled = NO;

    if ([self.level isPossibleSwap:swap]) {
      [self.level performSwap:swap];
      [self.scene animateSwap:swap completion:^{
        [self handleMatches];
      }];
    } else {
      [self.scene animateInvalidSwap:swap completion:^{
        self.view.userInteractionEnabled = YES;
      }];
    }
  };

  self.scene.swipeHandler = block;

  // Hide the game over panel from the screen.
  self.gameOverPanel.hidden = YES;
  
  // Present the scene.
  [skView presentScene:self.scene];

  // Load and start background music.
  NSURL *url = [[NSBundle mainBundle] URLForResource:@"Mining by Moonlight" withExtension:@"mp3"];
  self.backgroundMusic = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
  self.backgroundMusic.numberOfLoops = -1;
  [self.backgroundMusic play];

    //Set timer.
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                selector:@selector(runTime) userInfo:nil repeats:YES];
    
  // Let's start the game!
  [self beginGame];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

- (void)beginGame {
    self.movesLeft = self.level.maximumMoves;
    self.score = 0;
    self.time = 60;
    [self updateLabels];

  [self.level resetComboMultiplier];
  [self.scene animateBeginGame];
  [self shuffle];
}

- (void)shuffle {
  // Delete the old word sprites, but not the tiles.
  [self.scene removeAllWordSprites];

  // Fill up the level with new words, and create sprites for them.
  NSSet *newWords = [self.level shuffle];
  [self.scene addSpritesForWords:newWords];
}

- (void)handleMatches {
  // This is the main loop that removes any matching words and fills up the
  // holes with new words. While this happens, the user cannot interact with
  // the app.

  // Detect if there are any matches left.
  NSSet *chains = [self.level removeMatches];

  // If there are no more matches, then the player gets to move again.
  if ([chains count] == 0) {
    [self beginNextTurn];
    return;
  }

  // First, remove any matches...
  [self.scene animateMatchedWords:chains completion:^{

    // Add the new scores to the total.
    for (RWTChain *chain in chains) {
      self.score += chain.score;
    }
    [self updateLabels];

    // ...then shift down any words that have a hole below them...
    NSArray *columns = [self.level fillHoles];
    [self.scene animateFallingWords:columns completion:^{

      // ...and finally, add new words at the top.
      NSArray *columns = [self.level topUpwords];
      [self.scene animateNewWords:columns completion:^{

        // Keep repeating this cycle until there are no more matches.
        [self handleMatches];
      }];
    }];
  }];
}

- (void)beginNextTurn {
  [self.level resetComboMultiplier];
  [self.level detectPossibleSwaps];
  self.view.userInteractionEnabled = YES;
  [self decrementMoves];
}

- (void)updateLabels {
  self.targetLabel.text = [NSString stringWithFormat:@"%lu", (long)self.level.targetScore];
  self.movesLabel.text = [NSString stringWithFormat:@"%lu", (long)self.movesLeft];
  self.scoreLabel.text = [NSString stringWithFormat:@"%lu", (long)self.score];
    self.timeLabel.text = [NSString stringWithFormat:@"%lu", (long)self.time];
}

- (void)decrementMoves{
  self.movesLeft--;
  [self updateLabels];

    if (self.score >= self.level.targetScore) {
        self.gameOverPanel.image = [UIImage imageNamed:@"LevelComplete"];
        [self showGameOver];
    } else if (self.movesLeft == 0) {
        self.gameOverPanel.image = [UIImage imageNamed:@"GameOver"];
        [self showGameOver];
    }
}


- (void)runTime {
    self.time--;
    [self updateLabels];
    
    if(self.time == 0) {
        self.gameOverPanel.image = [UIImage imageNamed:@"GameOver"];
        [self.timer invalidate];
        self.timer = nil;
        [self showGameOver];
    }
}



- (void)showGameOver {
  [self.scene animateGameOver];

  self.gameOverPanel.hidden = NO;
  self.scene.userInteractionEnabled = NO;

  self.tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideGameOver)];
  [self.view addGestureRecognizer:self.tapGestureRecognizer];

  self.shuffleButton.hidden = YES;
}

- (void)hideGameOver {
  [self.view removeGestureRecognizer:self.tapGestureRecognizer];
  self.tapGestureRecognizer = nil;

  self.gameOverPanel.hidden = YES;
  self.scene.userInteractionEnabled = YES;

  [self beginGame];

  self.shuffleButton.hidden = NO;
}

- (IBAction)shuffleButtonPressed:(id)sender {
  [self shuffle];

  // Pressing the shuffle button costs a move.
  [self decrementMoves];
}

@end
