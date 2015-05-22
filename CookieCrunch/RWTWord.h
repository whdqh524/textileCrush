//
//  RWTWord.h
//  wordCrunch
//
//  Created by Matthijs on 25-02-14.
//  Copyright (c) 2014 Razeware LLC. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

static const NSUInteger NumWordTypes = 6;

@interface RWTWord : NSObject

@property (assign, nonatomic) NSInteger column;
@property (assign, nonatomic) NSInteger row;
@property (assign, nonatomic) NSUInteger wordType;  // 1 - 6
@property (strong, nonatomic) SKLabelNode *sprite;

- (NSString *)spriteName;
- (NSString *)highlightedSpriteName;
- (UIColor *)getWordColor;

@end
