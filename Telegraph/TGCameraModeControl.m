#import "TGCameraModeControl.h"

#import "TGCameraInterfaceAssets.h"

#import "UIControl+HitTestEdgeInsets.h"

const CGFloat TGCameraModeControlVerticalInteritemSpace = 29.0f;

@interface TGCameraModeControl ()
{
    UIImageView *_dotView;
    UIControl *_wrapperView;
    
    CGFloat _kerning;
    NSArray *_buttons;
    
    UIView *_maskView;
    CAGradientLayer *_maskLayer;
}
@end

@implementation TGCameraModeControl

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        static UIImage *dotImage = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(6, 6), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();

            CGContextSetFillColorWithColor(context, [TGCameraInterfaceAssets accentColor].CGColor);
            CGContextFillEllipseInRect(context, CGRectMake(0, 0, 6, 6));

            dotImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _dotView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 6, 6)];
        _dotView.image = dotImage;
        //[self addSubview:_dotView];
        
        if (frame.size.width > frame.size.height)
            _kerning = 3.5f;
        else
            _kerning = 2.0f;
        
        _maskView = [[UIView alloc] initWithFrame:self.bounds];
        _maskView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_maskView];
        
        _wrapperView = [[UIControl alloc] initWithFrame:CGRectZero];
        _wrapperView.backgroundColor = [UIColor clearColor];
        _wrapperView.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
        _wrapperView.opaque = false;
        [_maskView addSubview:_wrapperView];
        
        _buttons = @
        [
         [self _createButtonForMode:PGCameraModeVideo title:TGLocalized(@"Camera.VideoMode")],
         [self _createButtonForMode:PGCameraModePhoto title:TGLocalized(@"Camera.PhotoMode")],
         [self _createButtonForMode:PGCameraModeSquare title:TGLocalized(@"Camera.SquareMode")],
        // [self _createButtonForMode:PGCameraModeClip title:TGLocalized(@"Camera.MomentMode")]
        ];
        
        for (UIButton *button in _buttons)
            [_wrapperView addSubview:button];
        
        if (frame.size.width > frame.size.height)
        {
            CGFloat leftOffset = 0;
            for (UIButton *button in _buttons)
            {
                button.frame = CGRectMake(leftOffset, 0, CGFloor(button.frame.size.width), 20.0f);
                leftOffset += button.frame.size.width + [TGCameraModeControl _buttonHorizontalSpacing];
            }
            
            _wrapperView.frame = CGRectMake(0, 0, leftOffset - [TGCameraModeControl _buttonHorizontalSpacing], 20);
            
            _maskLayer = [CAGradientLayer layer];
            _maskLayer.colors = @[ (id)[UIColor clearColor].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor whiteColor].CGColor, (id)[UIColor clearColor].CGColor ];
            _maskLayer.locations = @[ @0.0f, @0.33f, @0.67f, @1.0f ];
            _maskLayer.startPoint = CGPointMake(0.0f, 0.5f);
            _maskLayer.endPoint = CGPointMake(1.0f, 0.5f);
            _maskView.layer.mask = _maskLayer;
        }
        else
        {
            CGFloat topOffset = 0;
            for (UIButton *button in _buttons)
            {
                button.frame = CGRectMake(0, topOffset, CGFloor(button.frame.size.width), CGFloor(button.frame.size.height));
                topOffset += button.frame.size.height + TGCameraModeControlVerticalInteritemSpace;
            }
            
            _wrapperView.frame = CGRectMake(33, 0, self.frame.size.width, topOffset - TGCameraModeControlVerticalInteritemSpace);
        }
        
        self.cameraMode = PGCameraModePhoto;
    }
    return self;
}

+ (UIFont *)_buttonFont
{
    return [UIFont fontWithName:@"SFCompactText-Regular" size:14];
}

+ (CGFloat)_buttonHorizontalSpacing
{
    //return 22;
    return 19;
}

+ (CGFloat)_buttonVerticalSpacing
{
    return 19;
}

- (UIButton *)_createButtonForMode:(PGCameraMode)mode title:(NSString *)title
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, 20)];
    button.backgroundColor = [UIColor clearColor];
    button.exclusiveTouch = true;
    button.hitTestEdgeInsets = UIEdgeInsetsMake(-10, -10, -10, -10);
    button.tag = mode;
    button.titleLabel.font = [TGCameraInterfaceAssets normalFontOfSize:13];
    [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets normalColor], NSKernAttributeName: @(_kerning) }] forState:UIControlStateNormal];
    [button setAttributedTitle:[[NSAttributedString alloc] initWithString:title attributes:@{ NSForegroundColorAttributeName: [TGCameraInterfaceAssets accentColor], NSKernAttributeName: @(_kerning) }] forState:UIControlStateSelected];
    [button setAttributedTitle:[button attributedTitleForState:UIControlStateSelected] forState:UIControlStateHighlighted | UIControlStateSelected];
    [button sizeToFit];
    [button addTarget:self action:@selector(buttonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    return button;
}

- (void)setCameraMode:(PGCameraMode)mode
{
    _cameraMode = mode;
    [self setCameraMode:mode animated:false];
}

- (void)setCameraMode:(PGCameraMode)mode animated:(bool)animated
{
    _cameraMode = mode;
    
    CGFloat targetPosition = 0;
    CGRect targetFrame = CGRectZero;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        targetPosition = [self _buttonForMode:self.cameraMode].center.x - _wrapperView.frame.size.width / 2;
        targetFrame = CGRectMake((self.frame.size.width - _wrapperView.frame.size.width) / 2 - targetPosition + 1, (self.frame.size.height - _wrapperView.frame.size.height) / 2, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    }
    else
    {
        targetPosition = [self _buttonForMode:self.cameraMode].center.y - _wrapperView.frame.size.height / 2;
        targetFrame = CGRectMake(33, (self.frame.size.height - _wrapperView.frame.size.height) / 2 - targetPosition + 1, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    }

    if (animated)
    {
        self.userInteractionEnabled = false;
        [self _updateButtonsHighlight];
        
        [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseInOut animations:^
        {
            _wrapperView.frame = targetFrame;
            
            if (self.frame.size.width > self.frame.size.height)
                [self _layoutItemTransformationsForTargetFrame:targetFrame];
        } completion:^(BOOL finished)
        {
            if (finished)
                self.userInteractionEnabled = true;
        }];
    }
    else
    {
        [self _updateButtonsHighlight];
        
        if (self.frame.size.width > self.frame.size.height)
            [self _layoutItemTransformationsForTargetFrame:targetFrame];

        _wrapperView.frame = targetFrame;
    }
}

- (void)_layoutItemTransformationsForTargetFrame:(CGRect)targetFrame
{
    CGFloat targetCenter = targetFrame.origin.x - self.frame.size.width / 2;

    for (UIButton *button in _buttons)
        button.layer.transform = [self _transformForItemWithOffset:targetCenter + button.center.x];
}

- (CATransform3D)_transformForItemWithOffset:(CGFloat)offset
{
    CGFloat angle = ABS(offset / _wrapperView.frame.size.width * 0.99f);
    CGFloat sign = offset > 0 ? 1.0f : -1.0f;
    
    CATransform3D transform = CATransform3DTranslate(CATransform3DIdentity, -28 * angle * angle * sign, 0.0f, 0.0f);
    transform = CATransform3DRotate(transform, angle, 0.0f, sign, 0.0f);
    return transform;
}

- (UIButton *)_currentModeButton
{
    return [self _buttonForMode:_cameraMode];
}

- (UIButton *)_buttonForMode:(PGCameraMode)mode
{
    for (UIButton *button in _wrapperView.subviews)
    {
        if (button.tag == mode)
            return button;
    }
    
    return nil;
}

- (void)_updateButtonsHighlight
{
    for (UIButton *button in _buttons)
        button.selected = (_cameraMode == button.tag);
}

- (void)buttonPressed:(UIButton *)sender
{
    PGCameraMode previousMode = self.cameraMode;
    [self setCameraMode:(int)sender.tag animated:true];
    
    if ((PGCameraMode)sender.tag != previousMode && self.modeChanged != nil)
        self.modeChanged((PGCameraMode)sender.tag, previousMode);
}

- (void)setHidden:(BOOL)hidden
{
    self.alpha = hidden ? 0.0f : 1.0f;
    super.hidden = hidden;
}

- (void)setHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        super.hidden = false;
        self.userInteractionEnabled = false;
        
        [UIView animateWithDuration:0.25f animations:^
        {
            self.alpha = hidden ? 0.0f : 1.0f;
        } completion:^(BOOL finished)
        {
            self.userInteractionEnabled = true;
             
            if (finished)
                self.hidden = hidden;
        }];
    }
    else
    {
        self.alpha = hidden ? 0.0f : 1.0f;
        super.hidden = hidden;
    }
}

#pragma mark - Layout

- (void)layoutSubviews
{
    if (self.frame.size.width > self.frame.size.height)
    {
        _dotView.frame = CGRectMake((self.frame.size.width - _dotView.frame.size.width) / 2, self.frame.size.height / 2 - 12, _dotView.frame.size.width, _dotView.frame.size.height);
        _maskLayer.frame = CGRectMake(0, 0, _maskView.frame.size.width, _maskView.frame.size.height);
    }
    else
    {
        _dotView.frame = CGRectMake(13, (self.frame.size.height - _dotView.frame.size.height) / 2, _dotView.frame.size.width, _dotView.frame.size.height);
    }
}

@end
