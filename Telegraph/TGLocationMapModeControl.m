#import "TGLocationMapModeControl.h"

#import "TGFont.h"

@implementation TGLocationMapModeControl

- (instancetype)init
{
    self = [super initWithItems:@[TGLocalized(@"Map.Map"), TGLocalized(@"Map.Satellite"), TGLocalized(@"Map.Hybrid")]];
    if (self != nil)
    {
        [self setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlBackground.png"] forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlSelected.png"] forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlSelected.png"] forState:UIControlStateSelected | UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        [self setBackgroundImage:[UIImage imageNamed:@"ModernSegmentedControlHighlighted.png"] forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
        UIImage *dividerImage = [UIImage imageNamed:@"ModernSegmentedControlDivider.png"];
        [self setDividerImage:dividerImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
        
        [self setTitleTextAttributes:@{UITextAttributeTextColor: TGAccentColor(), UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateNormal];
        [self setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor], UITextAttributeTextShadowColor: [UIColor clearColor], UITextAttributeFont: TGSystemFontOfSize(13)} forState:UIControlStateSelected];
    }
    return self;
}

@end
