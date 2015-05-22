
#import "RWTChain.h"

@implementation RWTChain {
  NSMutableArray *_words;
}

- (void)addword:(RWTWord *)word {
  if (_words == nil) {
    _words = [NSMutableArray array];
  }
  [_words addObject:word];
}

- (NSArray *)words {
  return _words;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"type:%ld words:%@", (long)self.chainType, self.words];
}

@end
