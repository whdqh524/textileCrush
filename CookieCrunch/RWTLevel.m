//
//  RWTLevel.m
//  wordCrunch
//
//  Created by Matthijs on 26-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import "RWTLevel.h"

@interface RWTLevel ()

// The list of swipes that result in a valid swap. Used to determine whether
// the player can make a certain swap, whether the board needs to be shuffled,
// and to generate hints.
@property (strong, nonatomic) NSSet *possibleSwaps;

// The second chain gets twice its regular score, the third chain three times,
// and so on. This multiplier is reset for every next turn.
@property (assign, nonatomic) NSUInteger comboMultiplier;

@end

@implementation RWTLevel {
  // The 2D array that contains the layout of the level.
  RWTTile *_tiles[NumColumns][NumRows];

  // The 2D array that keeps track of where the RWTWords are.
  RWTWord *_words[NumColumns][NumRows];
}

#pragma mark - Level Loading

- (instancetype)initWithFile:(NSString *)filename {
  self = [super init];
  if (self != nil) {
    NSDictionary *dictionary = [self loadJSON:filename];

    // The dictionary contains an array named "tiles". This array contains one
    // element for each row of the level. Each of those row elements in turn is
    // also an array describing the columns in that row. If a column is 1, it
    // means there is a tile at that location, 0 means there is not.

    // Loop through the rows...
    [dictionary[@"tiles"] enumerateObjectsUsingBlock:^(NSArray *array, NSUInteger row, BOOL *stop) {

      // Loop through the columns in the current row...
      [array enumerateObjectsUsingBlock:^(NSNumber *value, NSUInteger column, BOOL *stop) {

        // Note: In Sprite Kit (0,0) is at the bottom of the screen,
        // so we need to read this file upside down.
        NSInteger tileRow = NumRows - row - 1;

        // If the value is 1, create a tile object.
        if ([value integerValue] == 1) {
          _tiles[column][tileRow] = [[RWTTile alloc] init];
        }
      }];
    }];
    
    self.targetScore = [dictionary[@"targetScore"] unsignedIntegerValue];
    self.maximumMoves = [dictionary[@"moves"] unsignedIntegerValue];
  }
  return self;
}

- (NSDictionary *)loadJSON:(NSString *)filename {

  NSString *path = [[NSBundle mainBundle] pathForResource:filename ofType:@"json"];
  if (path == nil) {
    NSLog(@"Could not find level file: %@", filename);
    return nil;
  }

  NSError *error;
  NSData *data = [NSData dataWithContentsOfFile:path options:0 error:&error];
  if (data == nil) {
    NSLog(@"Could not load level file: %@, error: %@", filename, error);
    return nil;
  }

  NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (dictionary == nil || ![dictionary isKindOfClass:[NSDictionary class]]) {
    NSLog(@"Level file '%@' is not valid JSON: %@", filename, error);
    return nil;
  }

  return dictionary;
}

#pragma mark - Game Setup

- (NSSet *)shuffle {
  NSSet *set;

  do {
    // Removes the old words and fills up the level with all new ones.
    set = [self createInitialwords];

    // At the start of each turn we need to detect which words the player can
    // actually swap. If the player tries to swap two words that are not in
    // this set, then the game does not accept this as a valid move.
    // This also tells you whether no more swaps are possible and the game needs
    // to automatically reshuffle.
    [self detectPossibleSwaps];

    //NSLog(@"possible swaps: %@", self.possibleSwaps);

    // If there are no possible moves, then keep trying again until there are.
  }
  while ([self.possibleSwaps count] == 0);

  return set;
}

- (NSSet *)createInitialwords {

  NSMutableSet *set = [NSMutableSet set];

  // Loop through the rows and columns of the 2D array. Note that column 0,
  // row 0 is in the bottom-left corner of the array.
  for (NSInteger row = 0; row < NumRows; row++) {
    for (NSInteger column = 0; column < NumColumns; column++) {

      // Only make a new word if there is a tile at this spot.
      if (_tiles[column][row] != nil) {

        // Pick the word type at random, and make sure that this never
        // creates a chain of 3 or more. We want there to be 0 matches in
        // the initial state.
        NSUInteger wordType;
        do {
          wordType = arc4random_uniform(NumWordTypes) + 1;
        }
        while ((column >= 2 &&
                _words[column - 1][row].wordType == wordType &&
                _words[column - 2][row].wordType == wordType)
            ||
               (row >= 2 &&
                _words[column][row - 1].wordType == wordType &&
                _words[column][row - 2].wordType == wordType));

        // Create a new word and add it to the 2D array.
        RWTWord *word = [self createwordAtColumn:column row:row withType:wordType];

        // Also add the word to the set so we can tell our caller about it.
        [set addObject:word];
      }
    }
  }
  return set;
}

- (RWTWord *)createwordAtColumn:(NSInteger)column row:(NSInteger)row withType:(NSUInteger)wordType {
  RWTWord *word = [[RWTWord alloc] init];
  word.wordType = wordType;
  word.column = column;
  word.row = row;
  _words[column][row] = word;
  return word;
}

- (void)resetComboMultiplier {
  self.comboMultiplier = 1;
}

#pragma mark - Detecting Swaps

- (void)detectPossibleSwaps {

  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger row = 0; row < NumRows; row++) {
    for (NSInteger column = 0; column < NumColumns; column++) {

      RWTWord *word = _words[column][row];
      if (word != nil) {

        // Is it possible to swap this word with the one on the right?
        // Note: don't need to check the last column.
        if (column < NumColumns - 1) {

          // Have a word in this spot? If there is no tile, there is no word.
          RWTWord *other = _words[column + 1][row];
          if (other != nil) {
            // Swap them
            _words[column][row] = other;
            _words[column + 1][row] = word;
            
            // Is either word now part of a chain?
            if ([self hasChainAtColumn:column + 1 row:row] ||
                [self hasChainAtColumn:column row:row]) {

              RWTSwap *swap = [[RWTSwap alloc] init];
              swap.wordA = word;
              swap.wordB = other;
              [set addObject:swap];
            }

            // Swap them back
            _words[column][row] = word;
            _words[column + 1][row] = other;
          }
        }

        // Is it possible to swap this word with the one above?
        // Note: don't need to check the last row.
        if (row < NumRows - 1) {

          // Have a word in this spot? If there is no tile, there is no word.
          RWTWord *other = _words[column][row + 1];
          if (other != nil) {
            // Swap them
            _words[column][row] = other;
            _words[column][row + 1] = word;

            // Is either word now part of a chain?
            if ([self hasChainAtColumn:column row:row + 1] ||
                [self hasChainAtColumn:column row:row]) {

              RWTSwap *swap = [[RWTSwap alloc] init];
              swap.wordA = word;
              swap.wordB = other;
              [set addObject:swap];
            }

            // Swap them back
            _words[column][row] = word;
            _words[column][row + 1] = other;
          }
        }
      }
    }
  }

  self.possibleSwaps = set;
}

- (BOOL)hasChainAtColumn:(NSInteger)column row:(NSInteger)row {
  NSUInteger wordType = _words[column][row].wordType;

  NSUInteger horzLength = 1;
  for (NSInteger i = column - 1; i >= 0 && _words[i][row].wordType == wordType; i--, horzLength++) ;
  for (NSInteger i = column + 1; i < NumColumns && _words[i][row].wordType == wordType; i++, horzLength++) ;
  if (horzLength >= 3) return YES;

  NSUInteger vertLength = 1;
  for (NSInteger i = row - 1; i >= 0 && _words[column][i].wordType == wordType; i--, vertLength++) ;
  for (NSInteger i = row + 1; i < NumRows && _words[column][i].wordType == wordType; i++, vertLength++) ;
  return (vertLength >= 3);
}

#pragma mark - Swapping

- (void)performSwap:(RWTSwap *)swap {
  // Need to make temporary copies of these because they get overwritten.
  NSInteger columnA = swap.wordA.column;
  NSInteger rowA = swap.wordA.row;
  NSInteger columnB = swap.wordB.column;
  NSInteger rowB = swap.wordB.row;

  // Swap the words. We need to update the array as well as the column
  // and row properties of the RWTWord objects, or they go out of sync!
  _words[columnA][rowA] = swap.wordB;
  swap.wordB.column = columnA;
  swap.wordB.row = rowA;

  _words[columnB][rowB] = swap.wordA;
  swap.wordA.column = columnB;
  swap.wordA.row = rowB;
}

#pragma mark - Detecting Matches

- (NSSet *)removeMatches {
  NSSet *horizontalChains = [self detectHorizontalMatches];
  NSSet *verticalChains = [self detectVerticalMatches];

  // Note: to detect more advanced patterns such as an L shape, you can see
  // whether a word is in both the horizontal & vertical chains sets and
  // whether it is the first or last in the array (at a corner). Then you
  // create a new RWTChain object with the new type and remove the other two.

  [self removewords:horizontalChains];
  [self removewords:verticalChains];

  [self calculateScores:horizontalChains];
  [self calculateScores:verticalChains];

  return [horizontalChains setByAddingObjectsFromSet:verticalChains];
}

- (NSSet *)detectHorizontalMatches {

  // Contains the RWTWord objects that were part of a horizontal chain.
  // These words must be removed.
  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger row = 0; row < NumRows; row++) {

    // Don't need to look at last two columns.
    // Note: for-loop without increment.
    for (NSInteger column = 0; column < NumColumns - 2; ) {

      // If there is a word/tile at this position...
      if (_words[column][row] != nil) {
        NSUInteger matchType = _words[column][row].wordType;

        // And the next two columns have the same type...
        if (_words[column + 1][row].wordType == matchType
         && _words[column + 2][row].wordType == matchType) {

          // ...then add all the words from this chain into the set.
          RWTChain *chain = [[RWTChain alloc] init];
          chain.chainType = ChainTypeHorizontal;
          do {
            [chain addword:_words[column][row]];
            column += 1;
          }
          while (column < NumColumns && _words[column][row].wordType == matchType);

          [set addObject:chain];
          continue;
        }
      }

      // word did not match or empty tile, so skip over it.
      column += 1;
    }
  }
  return set;
}

// Same as the horizontal version but just steps through the array differently.
- (NSSet *)detectVerticalMatches {
  NSMutableSet *set = [NSMutableSet set];

  for (NSInteger column = 0; column < NumColumns; column++) {
    for (NSInteger row = 0; row < NumRows - 2; ) {
      if (_words[column][row] != nil) {
        NSUInteger matchType = _words[column][row].wordType;

        if (_words[column][row + 1].wordType == matchType
         && _words[column][row + 2].wordType == matchType) {

          RWTChain *chain = [[RWTChain alloc] init];
          chain.chainType = ChainTypeVertical;
          do {
            [chain addword:_words[column][row]];
            row += 1;
          }
          while (row < NumRows && _words[column][row].wordType == matchType);

          [set addObject:chain];
          continue;
        }
      }
      row += 1;
    }
  }
  return set;
}

- (void)removewords:(NSSet *)chains {
  for (RWTChain *chain in chains) {
    for (RWTWord *word in chain.words) {
      _words[word.column][word.row] = nil;
    }
  }
}

- (void)calculateScores:(NSSet *)chains {
  // 3-chain is 60 pts, 4-chain is 120, 5-chain is 180, and so on
  for (RWTChain *chain in chains) {
    chain.score = 60 * ([chain.words count] - 2) * self.comboMultiplier;
    self.comboMultiplier++;
  }
}

#pragma mark - Detecting Holes

- (NSArray *)fillHoles {
  NSMutableArray *columns = [NSMutableArray array];

  // Loop through the rows, from bottom to top. It's handy that our row 0 is
  // at the bottom already. Because we're scanning from bottom to top, this
  // automatically causes an entire stack to fall down to fill up a hole.
  // We scan one column at a time.
  for (NSInteger column = 0; column < NumColumns; column++) {

    NSMutableArray *array;
    for (NSInteger row = 0; row < NumRows; row++) {

      // If there is a tile at this position but no word, then there's a hole.
      if (_tiles[column][row] != nil && _words[column][row] == nil) {

        // Scan upward to find a word.
        for (NSInteger lookup = row + 1; lookup < NumRows; lookup++) {
          RWTWord *word = _words[column][lookup];
          if (word != nil) {
            // Swap that word with the hole.
            _words[column][lookup] = nil;
            _words[column][row] = word;
            word.row = row;

            // For each column, we return an array with the words that have
            // fallen down. words that are lower on the screen are first in
            // the array. We need an array to keep this order intact, so the
            // animation code can apply the correct kind of delay.
            if (array == nil) {
              array = [NSMutableArray array];
              [columns addObject:array];
            }
            [array addObject:word];

            // Don't need to scan up any further.
            break;
          }
        }
      }
    }
  }
  return columns;
}

- (NSArray *)topUpwords {
  NSMutableArray *columns = [NSMutableArray array];
  NSUInteger wordType = 0;

  // Detect where we have to add the new words. If a column has X holes,
  // then it also needs X new words. The holes are all on the top of the
  // column now, but the fact that there may be gaps in the tiles makes this
  // a little trickier.
  for (NSInteger column = 0; column < NumColumns; column++) {

    // This time scan from top to bottom. We can end when we've found the
    // first word.
    NSMutableArray *array;
    for (NSInteger row = NumRows - 1; row >= 0 && _words[column][row] == nil; row--) {

      // Found a hole?
      if (_tiles[column][row] != nil) {

        // Randomly create a new word type. The only restriction is that
        // it cannot be equal to the previous type. This prevents too many
        // "freebie" matches.
        NSUInteger newwordType;
        do {
          newwordType = arc4random_uniform(NumWordTypes) + 1;
        } while (newwordType == wordType);
        wordType = newwordType;

        // Create a new word.
        RWTWord *word = [self createwordAtColumn:column row:row withType:wordType];

        // Add the word to the array for this column.
        // Note that we only allocate an array if a column actually has holes.
        // This cuts down on unnecessary allocations.
        if (array == nil) {
          array = [NSMutableArray array];
          [columns addObject:array];
        }
        [array addObject:word];
      }
    }
  }
  return columns;
}

#pragma mark - Querying the Level

- (RWTTile *)tileAtColumn:(NSInteger)column row:(NSInteger)row {
  NSAssert1(column >= 0 && column < NumColumns, @"Invalid column: %ld", (long)column);
  NSAssert1(row >= 0 && row < NumRows, @"Invalid row: %ld", (long)row);

  return _tiles[column][row];
}

- (RWTWord *)wordAtColumn:(NSInteger)column row:(NSInteger)row {
  NSAssert1(column >= 0 && column < NumColumns, @"Invalid column: %ld", (long)column);
  NSAssert1(row >= 0 && row < NumRows, @"Invalid row: %ld", (long)row);

  return _words[column][row];
}

- (BOOL)isPossibleSwap:(RWTSwap *)swap {
  return [self.possibleSwaps containsObject:swap];
}

@end
