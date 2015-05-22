//
//  RWTLevel.h
//  wordCrunch
//
//  Created by Matthijs on 26-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import "RWTWord.h"
#import "RWTTile.h"
#import "RWTSwap.h"
#import "RWTChain.h"

static const NSInteger NumColumns = 9;
static const NSInteger NumRows = 9;

@interface RWTLevel : NSObject

@property (assign, nonatomic) NSUInteger targetScore;
@property (assign, nonatomic) NSUInteger maximumMoves;

// Create a level by loading it from a file.
- (instancetype)initWithFile:(NSString *)filename;

// Fills up the level with new RWTWord objects. The level is guaranteed free
// from matches at this point.
// You call this method at the beginning of a new game and whenever the player
// taps the Shuffle button.
// Returns a set containing all the new RWTWord objects.
- (NSSet *)shuffle;

// Returns the word at the specified column and row, or nil when there is none.
- (RWTWord *)wordAtColumn:(NSInteger)column row:(NSInteger)row;

// Determines whether there's a tile at the specified column and row.
- (RWTTile *)tileAtColumn:(NSInteger)column row:(NSInteger)row;

// Swaps the positions of the two words from the RWTSwap object.
- (void)performSwap:(RWTSwap *)swap;

// Determines whether the suggested swap is a valid one, i.e. it results in at
// least one new chain of 3 or more words of the same type.
- (BOOL)isPossibleSwap:(RWTSwap *)swap;

// Recalculates which moves are valid.
- (void)detectPossibleSwaps;

// Detects whether there are any chains of 3 or more words, and removes them
// from the level.
// Returns a set containing RWTChain objects, which describe the RWTWords
// that were removed.
- (NSSet *)removeMatches;

// Detects where there are holes and shifts any words down to fill up those
// holes. In effect, this "bubbles" the holes up to the top of the column.
// Returns an array that contains a sub-array for each column that had holes,
// with the RWTWord objects that have shifted. Those words are already
// moved to their new position. The objects are ordered from the bottom up.
- (NSArray *)fillHoles;

// Where necessary, adds new words to fill up the holes at the top of the
// columns.
// Returns an array that contains a sub-array for each column that had holes,
// with the new RWTWord objects. words are ordered from the top down.
- (NSArray *)topUpwords;

// Should be called at the start of every new turn.
- (void)resetComboMultiplier;

@end
