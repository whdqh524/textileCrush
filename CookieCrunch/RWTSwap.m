//
//  RWTSwap.m
//  wordCrunch
//
//  Created by Matthijs on 26-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import "RWTSwap.h"
#import "RWTWord.h"

@implementation RWTSwap

// By overriding this method you can use [NSSet containsObject:] to look for
// a matching RWTSwap object in that collection.
- (BOOL)isEqual:(id)object {

  // You can only compare this object against other RWTSwap objects.
  if (![object isKindOfClass:[RWTSwap class]]) return NO;

  // Two swaps are equal if they contain the same word, but it doesn't
  // matter whether they're called A in one and B in the other.
  RWTSwap *other = (RWTSwap *)object;
  return (other.wordA == self.wordA && other.wordB == self.wordB) ||
         (other.wordB == self.wordA && other.wordA == self.wordB);
}

// If you override isEqual: you also need to override hash. The rule is that
// if two objects are equal, then their hashes must also be equal.
- (NSUInteger)hash {
  return [self.wordA hash] ^ [self.wordB hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ swap %@ with %@", [super description], self.wordA, self.wordB];
}

@end
