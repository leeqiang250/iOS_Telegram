#import "TGCameraInterfaceAssets.h"

@implementation TGCameraInterfaceAssets

+ (UIColor *)normalColor
{
    return [UIColor whiteColor];
}

+ (UIColor *)accentColor
{
    return UIColorRGB(0xffcc00);
}

+ (UIColor *)redColor
{
    return UIColorRGB(0xf53333);
}

+ (UIColor *)panelBackgroundColor
{
    return [UIColor blackColor];
}

+ (UIColor *)transparentPanelBackgroundColor
{
    return [UIColor colorWithWhite:0.0f alpha:0.5];
}

+ (UIFont *)normalFontOfSize:(CGFloat)size
{
    return [UIFont fontWithName:@"DINAlternate-Bold" size:size];
}

@end
