
@class RWTWord;

typedef NS_ENUM(NSUInteger, ChainType) {
  ChainTypeHorizontal,
  ChainTypeVertical,

  // Note: add any other shapes you want to detect to this list.
  //ChainTypeL,
  //ChainTypeT,
};

@interface RWTChain : NSObject

// The RWTWords that are part of this chain.
@property (strong, nonatomic, readonly) NSArray *words;

// Whether this chain is horizontal or vertical.
@property (assign, nonatomic) ChainType chainType;

// How many points this chain is worth.
@property (assign, nonatomic) NSUInteger score;

- (void)addword:(RWTWord *)word;

@end
