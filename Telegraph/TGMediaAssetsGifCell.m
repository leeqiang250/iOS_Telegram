#import "TGMediaAssetsGifCell.h"

#import "TGFont.h"

NSString *const TGMediaAssetsGifCellKind = @"TGMediaAssetsGifCellKind";

@interface TGMediaAssetsGifCell ()
{
    UIImageView *_shadowView;
    UILabel *_typeLabel;
}
@end

@implementation TGMediaAssetsGifCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static UIImage *shadowImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 20.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGColorRef colors[2] = {
                CGColorRetain(UIColorRGBA(0x000000, 0.0f).CGColor),
                CGColorRetain(UIColorRGBA(0x000000, 0.8f).CGColor)
            };
            
            CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
            CGFloat locations[2] = {0.0f, 1.0f};
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
            
            CFRelease(colorsArray);
            CFRelease(colors[0]);
            CFRelease(colors[1]);
            
            CGColorSpaceRelease(colorSpace);
            
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, 20.0f), 0);
            
            CFRelease(gradient);
            
            shadowImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _shadowView = [[UIImageView alloc] initWithFrame:CGRectMake(0, frame.size.height - 20, frame.size.width, 20)];
        _shadowView.image = shadowImage;
        [self addSubview:_shadowView];
        
        _typeLabel = [[UILabel alloc] init];
        _typeLabel.textColor = [UIColor whiteColor];
        _typeLabel.backgroundColor = [UIColor clearColor];
        _typeLabel.textAlignment = NSTextAlignmentLeft;
        _typeLabel.font = TGSystemFontOfSize(12.0f);
        _typeLabel.text = @"GIF";
        [_typeLabel sizeToFit];
        [self addSubview:_typeLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _shadowView.frame = (CGRect){ { 0, self.frame.size.height - _shadowView.frame.size.height }, {self.frame.size.width, _shadowView.frame.size.height } };
    _typeLabel.frame = (CGRect){ { 5, _shadowView.frame.origin.y }, {self.frame.size.width - 5 - 4, _shadowView.frame.size.height } };
}

@end
