#import "TGTooltipView.h"

#import <QuartzCore/QuartzCore.h>

#import "TGFont.h"
#import "TGImageUtils.h"

@interface TGTooltipView () <UIScrollViewDelegate>
{
    UIImageView *_backgroundView;
    UIImageView *_arrowView;
    UILabel *_textLabel;
    
    CGFloat _arrowLocation;
}

@property (nonatomic, strong) ASHandle *watcherHandle;

@end

@implementation TGTooltipView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.alpha = 0.0f;
        self.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
        
        _numberOfLines = 1;
        
        _maxWidth = 310.0f;
       
        _backgroundView = [[UIImageView alloc] initWithImage:[TGTintedImage([UIImage imageNamed:@"TooltipBackground"], UIColorRGBA(0x252525, 0.96f)) stretchableImageWithLeftCapWidth:9.0f topCapHeight:9.0f]];
        [self addSubview:_backgroundView];
        
        _arrowView = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"TooltipArrow"], UIColorRGBA(0x252525, 0.96f))];
        [self addSubview:_arrowView];
        
        _arrowLocation = 50;
    }
    return self;
}

- (void)setText:(NSString *)text
{
    [self setText:text animated:false];
}

- (void)setText:(NSString *)text animated:(bool)animated
{
    if (_textLabel == nil)
    {
        _textLabel = [[UILabel alloc] init];
        _textLabel.font = TGSystemFontOfSize(14);
        _textLabel.textColor = [UIColor whiteColor];
        _textLabel.userInteractionEnabled = false;
        _textLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_textLabel];
    }
    
    _textLabel.numberOfLines = _numberOfLines;
    
    if (animated)
    {
        UIView *snapshotView = [_textLabel snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = _textLabel.frame;
        [self addSubview:snapshotView];
        
        _textLabel.text = text;
        _textLabel.alpha = 0.0f;
        
        [UIView animateWithDuration:0.2 animations:^
        {
            _textLabel.alpha = 1.0f;
            snapshotView.alpha = 0.0f;
            [self sizeToFit];
            snapshotView.frame = CGRectMake(_textLabel.frame.origin.x, snapshotView.frame.origin.y, snapshotView.frame.size.width, snapshotView.frame.size.height);
        } completion:^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        }];
    }
    else
    {
        _textLabel.text = text;
        
        if (_numberOfLines == 1) {
            [_textLabel sizeToFit];
        } else {
            CGSize textSize = [_textLabel.text sizeWithFont:_textLabel.font constrainedToSize:CGSizeMake(_maxWidth - 20.0f, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
            textSize.width = CGCeil(textSize.width);
            textSize.height = CGCeil(textSize.height);
            _textLabel.frame = CGRectMake(_textLabel.frame.origin.x, _textLabel.frame.origin.y, textSize.width, textSize.height);
        }
    }
}

- (void)sizeToFit
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    
    CGFloat maxWidth = _maxWidth;
    CGFloat inset = 11.0f;

    if (_numberOfLines == 1) {
        [_textLabel sizeToFit];
    } else {
        CGSize textSize = [_textLabel.text sizeWithFont:_textLabel.font constrainedToSize:CGSizeMake(maxWidth - 20.0f, CGFLOAT_MAX) lineBreakMode:NSLineBreakByWordWrapping];
        textSize.width = CGCeil(textSize.width);
        textSize.height = CGCeil(textSize.height);
        _textLabel.frame = CGRectMake(_textLabel.frame.origin.x, _textLabel.frame.origin.y, textSize.width, textSize.height);
    }
    
    CGFloat minArrowX = 10.0f;
    CGFloat maxArrowX = self.frame.size.width - 10.0f;
    
    CGFloat arrowX = CGFloor(_arrowLocation - _arrowView.frame.size.width / 2);
    arrowX = MIN(MAX(minArrowX, arrowX), maxArrowX);
    
    _arrowView.frame = CGRectMake(arrowX + TGScreenPixel, 38.0f - TGScreenPixel, _arrowView.frame.size.width, _arrowView.frame.size.height);
    
    CGFloat backgroundOffset = 19.0f + _textLabel.frame.size.height - 36.0f;
    
    CGFloat backgroundWidth = MIN(maxWidth, _textLabel.frame.size.width + inset * 2.0f);
    
    CGFloat labelWidth = backgroundWidth - inset * 2.0f;
    if (_numberOfLines != 1) {
        labelWidth = _textLabel.frame.size.width;
        backgroundOffset += 1.0f;
    }
    
    CGFloat x = arrowX - (backgroundWidth - _arrowView.frame.size.width) / 2.0f;
    x = MAX(4.0f, MIN(x, self.frame.size.width - backgroundWidth - 4.0f));
    _backgroundView.frame = CGRectMake(x, 2.0f - backgroundOffset, backgroundWidth, 36.0f + backgroundOffset);
    _textLabel.frame = CGRectMake(_backgroundView.frame.origin.x + 12.0f, 12.0f - TGScreenPixel - backgroundOffset, labelWidth, _textLabel.frame.size.height);
    
    self.transform = transform;
}

- (void)showInView:(UIView *)view fromRect:(CGRect)rect
{
    [self showInView:view fromRect:rect animated:true];
}

- (void)showInView:(UIView *)__unused view fromRect:(CGRect)rect animated:(bool)animated
{
    CGAffineTransform transform = self.transform;
    self.transform = CGAffineTransformIdentity;
    
    CGRect frame = self.frame;
    frame.origin.y = rect.origin.y - frame.size.height - 14;

    _arrowLocation = CGFloor(rect.origin.x + rect.size.width / 2) - frame.origin.x;
    
    self.frame = frame;
    [self sizeToFit];
    
    self.transform = transform;
    
    self.layer.rasterizationScale = [[UIScreen mainScreen] scale];
    self.layer.shouldRasterize = true;
    
    self.alpha = 1.0f;
    
    if (animated)
    {
        [UIView animateWithDuration:0.142 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            self.transform = CGAffineTransformMakeScale(1.07f, 1.07f);
        } completion:^(BOOL finished)
        {
            if(finished)
            {
                [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
                {
                    self.transform = CGAffineTransformMakeScale(0.967f, 0.967f);
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        [UIView animateWithDuration:0.06 delay:0 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState animations:^
                        {
                            self.transform = CGAffineTransformIdentity;
                        } completion:^(BOOL finished)
                        {
                            if (finished)
                            {
                                self.layer.shouldRasterize = false;
                            }
                        }];
                    }
                }];
            }
        }];
    }
    else
    {
        self.transform = CGAffineTransformIdentity;
        self.alpha = 0.0f;
        [UIView animateWithDuration:0.3 animations:^
        {
            self.alpha = 1.0f;
        }];
    }
}

- (void)hide:(dispatch_block_t)completion
{
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        self.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            self.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
            
            if (completion)
                completion();
        }
    }];
}

@end

#pragma mark -

@interface TGTooltipContainerView ()
{
    bool _skipHitTest;
}
@end

@implementation TGTooltipContainerView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _tooltipView = [[TGTooltipView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, 41.0f)];
        [self addSubview:_tooltipView];
    }
    return self;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (_skipHitTest)
        return nil;
    
    UIView *result = [super hitTest:point withEvent:event];
    UIView *superViewResult = nil;
    if (self.tooltipView.sourceView != nil)
    {
        _skipHitTest = true;
        superViewResult = [self.superview hitTest:[self convertPoint:point toView:self.superview] withEvent:event];
        _skipHitTest = false;
    }
    
    if (self.tooltipView.sourceView != nil && superViewResult == self.tooltipView.sourceView)
        return nil;
    
    if (result == self || result == nil)
    {
        [self hideTooltip];
        return nil;
    }
    
    return result;
}

- (void)showTooltipFromRect:(CGRect)rect
{
    [self showTooltipFromRect:rect animated:true];
}

- (void)showTooltipFromRect:(CGRect)rect animated:(bool)animated
{
    _isShowingTooltip = true;
    _showingTooltipFromRect = rect;
    [_tooltipView showInView:self fromRect:rect animated:animated];
}

- (void)setFrame:(CGRect)frame
{
    if (!CGSizeEqualToSize(frame.size, self.frame.size))
        [self hideTooltip];
    
    [super setFrame:frame];
}

- (void)hideTooltip
{
    if (_isShowingTooltip)
    {
        _isShowingTooltip = false;
        _showingTooltipFromRect = CGRectZero;
        
        [_tooltipView.watcherHandle requestAction:@"tooltipWillHide" options:nil];
        
        [_tooltipView hide:^
        {
            [self removeFromSuperview];
        }];
    }
}

@end
