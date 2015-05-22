//
//  RWTWord.m
//  WordCrunch
//
//  Created by Matthijs on 25-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import "RWTWord.h"

@implementation RWTWord

- (NSString *)spriteName {
  static NSString * const spriteNames[] = {
    @"빨강",
    @"주황",
    @"노랑",
    @"초록",
    @"파랑",
    @"보라",
  };

  return spriteNames[self.wordType - 1];
}

- (NSString *)highlightedSpriteName {
  static NSString * const highlightedSpriteNames[] = {
    @"빨강-Highlighted",
    @"주황-Highlighted",
    @"노랑-Highlighted",
    @"초록-Highlighted",
    @"파랑-Highlighted",
    @"보라-Highlighted",
  };

  return highlightedSpriteNames[self.wordType - 1];
}

- (UIColor *) getWordColor {
    static NSString * const wordColorHexCodes[] = {
        @"ff0000",
        @"ff6600",
        @"ffff00",
        @"00ff00",
        @"00ffff",
        @"ff66ff"
    };
    NSString *hexString = wordColorHexCodes[arc4random_uniform(NumWordTypes)];
    
    unsigned int hex;
    
    [[NSScanner scannerWithString:hexString] scanHexInt:&hex];
    int red = (hex >> 16) & 0xFF;
    int green = (hex >> 8) & 0xFF;
    int blue = (hex >> 0) & 0xFF;
    
    return [UIColor colorWithRed:red / 255.0f green:green/255.0f blue:blue/255.0f alpha:1.0f];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"type:%ld square:(%ld,%ld)", (long)self.wordType, (long)self.column, (long)self.row];
}

@end
