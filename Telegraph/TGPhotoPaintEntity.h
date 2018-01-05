#import <Foundation/Foundation.h>

@interface TGPhotoPaintEntity : NSObject <NSCopying>
{
    NSInteger _uuid;
}

@property (nonatomic, assign) NSInteger uuid;
@property (nonatomic, assign) CGPoint position;
@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign, getter=isMirrored) bool mirrored;

- (instancetype)duplicate;

@end
