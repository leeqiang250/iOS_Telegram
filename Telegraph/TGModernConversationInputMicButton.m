/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGModernConversationInputMicButton.h"

#import "TGImageUtils.h"

#import "TGOverlayController.h"
#import "TGOverlayControllerWindow.h"

#import "TGModernButton.h"

static const CGFloat innerCircleRadius = 110.0f;
static const CGFloat outerCircleRadius = innerCircleRadius + 50.0f;
static const CGFloat outerCircleMinScale = innerCircleRadius / outerCircleRadius;

@interface TGModernConversationInputMicWindow : UIWindow
{
    bool _ignoreNextTouch;
}

@property (nonatomic, copy) void (^requestedLockedAction)(void);

@end

@interface TGModernConversationInputLockView : UIView
{
    CALayer *_baseLayer;
    CALayer *_arcLayer;
}

@property (nonatomic, assign) CGFloat lockness;

@end


@interface TGModernConversationInputMicButtonOverlayController : TGOverlayController

@end

@implementation TGModernConversationInputMicButtonOverlayController

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    [self.view.window.layer removeAnimationForKey:@"backgroundColor"];
    [CATransaction begin];
    [CATransaction setDisableActions:true];
    self.view.window.layer.backgroundColor = [UIColor clearColor].CGColor;
    [CATransaction commit];
    
    for (UIView *view in self.view.window.subviews)
    {
        if (view != self.view)
        {
            [view removeFromSuperview];
            break;
        }
    }
}

@end

@interface TGModernConversationInputMicButton () <UIGestureRecognizerDelegate>
{
    CGPoint _touchLocation;
    UIPanGestureRecognizer *_panRecognizer;
    
    CGPoint _lastVelocity;
    
    bool _processCurrentTouch;
    CFAbsoluteTime _lastTouchTime;
    bool _acceptTouchDownAsTouchUp;
    
    UIWindow *_overlayWindow;
    
    UIImageView *_innerCircleView;
    UIImageView *_outerCircleView;
    
    UIView *_innerIconWrapperView;
    UIImageView *_innerIconView;
    
    UIView *_lockPanelWrapperView;
    UIImageView *_lockPanelView;
    UIImageView *_lockArrowView;
    TGModernConversationInputLockView *_lockView;
    UIImage *_previousIcon;
    TGModernButton *_stopButton;
    
    CGFloat _currentScale;
    CGFloat _currentTranslation;
    CGFloat _targetTranslation;
    
    CFAbsoluteTime _animationStartTime;
    
    CADisplayLink *_displayLink;
    CGFloat _currentLevel;
    CGFloat _inputLevel;
    bool _animatedIn;
    
    UIImage *_icon;
}

@end

@implementation TGModernConversationInputMicButton

- (void)setFadeDisabled:(bool)fadeDisabled {
    _fadeDisabled = fadeDisabled;
    _iconView.alpha = fadeDisabled ? 0.5f : 1.0f;
}

- (UIImage *)innerCircleImage {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(innerCircleRadius, innerCircleRadius), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, innerCircleRadius, innerCircleRadius));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

- (UIImage *)outerCircleImage {
    static UIImage *image = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(outerCircleRadius, outerCircleRadius), false, 0.0f);
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, [TGAccentColor() colorWithAlphaComponent:0.2f].CGColor);
        CGContextFillEllipseInRect(context, CGRectMake(0.0f, 0.0f, outerCircleRadius, outerCircleRadius));
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.exclusiveTouch = true;
        self.multipleTouchEnabled = false;
        
        _panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
        _panRecognizer.cancelsTouchesInView = false;
        _panRecognizer.delegate = self;
        [self addGestureRecognizer:_panRecognizer];
        
        _icon = [UIImage imageNamed:@"InputMicRecordingOverlay.png"];
    }
    return self;
}

- (void)panGesture:(UIPanGestureRecognizer *)__unused gestureRecognizer
{
}

- (void)dealloc {
    _displayLink.paused = true;
    [_displayLink removeFromRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (CADisplayLink *)displayLink {
    if (_displayLink == nil) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate)];
        _displayLink.paused = true;
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return _displayLink;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)__unused event
{
    return CGRectContainsPoint(CGRectInset(self.bounds, -10.0f, 0.0f), point);
}

- (UIImage *)icon
{
    return _icon;
}

- (void)setIcon:(UIImage *)icon
{
    _icon = icon;
    _innerIconView.image = icon;
    CGPoint center = _innerIconView.center;
    _innerIconView.frame = CGRectMake(0.0f, 0.0f, icon.size.width, icon.size.height);
    _innerIconView.center = center;
}

- (void)updateOverlay
{
    if (_overlayWindow == nil)
        return;
    
    CGPoint centerPoint = [self.superview convertPoint:self.center toView:_overlayWindow.rootViewController.view];
    _innerCircleView.center = centerPoint;
    _outerCircleView.center = centerPoint;
    _innerIconWrapperView.center = centerPoint;
    
    _lockPanelWrapperView.frame = CGRectMake(floor(centerPoint.x - _lockPanelWrapperView.frame.size.width / 2.0f), floor(centerPoint.y - 122.0f - _lockPanelWrapperView.frame.size.height / 2.0f), _lockPanelWrapperView.frame.size.width, _lockPanelWrapperView.frame.size.height);
    
    _stopButton.frame = CGRectMake(floor(centerPoint.x - _stopButton.frame.size.width / 2.0f), floor(centerPoint.y - 102.0f - _stopButton.frame.size.height / 2.0f), _stopButton.frame.size.width, _stopButton.frame.size.height);
}

- (void)animateIn {
    if (!_locked)
        _lockView.lockness = 0.0f;
    
    _animatedIn = true;
    _animationStartTime = CACurrentMediaTime();
    
    if (_overlayWindow == nil) {
        _overlayWindow = [[TGModernConversationInputMicWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        _overlayWindow.windowLevel = 1000000000.0f;
        _overlayWindow.rootViewController = [[TGModernConversationInputMicButtonOverlayController alloc] init];
        
        __weak TGModernConversationInputMicButton *weakSelf = self;
        ((TGModernConversationInputMicWindow *)_overlayWindow).requestedLockedAction = ^
        {
            __strong TGModernConversationInputMicButton *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            id<TGModernConversationInputMicButtonDelegate> delegate = strongSelf.delegate;
            if ([delegate respondsToSelector:@selector(micButtonInteractionRequestedLockedAction)])
                [delegate micButtonInteractionRequestedLockedAction];
        };
        
        static dispatch_once_t onceToken;
        static UIImage *panelBackgroundView;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(38.0f, 38.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGRect rect = CGRectMake(TGScreenPixel / 2.0f, TGScreenPixel / 2.0f, 38.0f - TGScreenPixel, 38.0 - TGScreenPixel);
            CGFloat radius = 38.0f / 2.0f;
            
            CGFloat minx = CGRectGetMinX(rect), midx = CGRectGetMidX(rect), maxx = CGRectGetMaxX(rect);
            CGFloat miny = CGRectGetMinY(rect), midy = CGRectGetMidY(rect), maxy = CGRectGetMaxY(rect);
            
            CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
            CGContextSetStrokeColorWithColor(context, TGAccentColor().CGColor);
            CGContextSetLineWidth(context, TGScreenPixel);
            
            CGContextMoveToPoint(context, minx, midy);
            CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
            CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
            CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
            CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius);
            CGContextClosePath(context);
            
            CGContextSetFillColorWithColor(context, UIColorRGB(0xf7f7f7).CGColor);
            CGContextSetStrokeColorWithColor(context, UIColorRGB(0xb2b2b2).CGColor);
            CGContextDrawPath(context, kCGPathFillStroke);
            
            panelBackgroundView = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:19 topCapHeight:19];
            UIGraphicsEndImageContext();
        });
        
        _lockPanelWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 77.0f)];
        _lockPanelWrapperView.userInteractionEnabled = false;
        [_overlayWindow.rootViewController.view addSubview:_lockPanelWrapperView];
        
        _lockPanelView = [[UIImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 77.0f)];
        _lockPanelView.image = panelBackgroundView;
        [_lockPanelWrapperView addSubview:_lockPanelView];
        
        _lockArrowView = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"VideoRecordArrow"], UIColorRGB(0x9597a0))];
        _lockArrowView.frame = CGRectMake(floor((_lockPanelView.frame.size.width - _lockArrowView.frame.size.width) / 2.0f), 54.0f, _lockArrowView.frame.size.width, _lockArrowView.frame.size.height);
        [_lockPanelView addSubview:_lockArrowView];
        
        _lockView = [[TGModernConversationInputLockView alloc] init];
        _lockView.frame = CGRectMake(floor((_lockPanelView.frame.size.width - _lockView.frame.size.width) / 2.0f), 6.0f, _lockView.frame.size.width, _lockView.frame.size.height);
        [_lockPanelView addSubview:_lockView];

        _innerCircleView = [[UIImageView alloc] initWithImage:[self innerCircleImage]];
        _innerCircleView.alpha = 0.0f;
        [_overlayWindow.rootViewController.view addSubview:_innerCircleView];
        
        _outerCircleView = [[UIImageView alloc] initWithImage:[self outerCircleImage]];
        _outerCircleView.alpha = 0.0f;
        [_overlayWindow.rootViewController.view addSubview:_outerCircleView];
        
        _innerIconView = [[UIImageView alloc] initWithImage:_icon];
    
        _innerIconWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 30.0f, 30.0f)];
        _innerIconWrapperView.alpha = 0.0f;
        _innerIconWrapperView.userInteractionEnabled = false;
        [_innerIconWrapperView addSubview:_innerIconView];
        
        [_overlayWindow.rootViewController.view addSubview:_innerIconWrapperView];
        
        _stopButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 38.0f, 38.0f)];
        _stopButton.adjustsImageWhenHighlighted = false;
        _stopButton.exclusiveTouch = true;
        static dispatch_once_t onceToken2;
        static UIImage *stopButtonImage;
        dispatch_once(&onceToken2, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(38.0f, 38.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextSetFillColorWithColor(context, UIColorRGB(0xf7f7f7).CGColor);
            CGContextSetStrokeColorWithColor(context, UIColorRGB(0xb2b2b2).CGColor);
            CGContextSetLineWidth(context, TGScreenPixel);
            
            CGRect rect1 = CGRectMake(TGScreenPixel / 2.0f, TGScreenPixel / 2.0f, 38.0f - TGScreenPixel, 38.0 - TGScreenPixel);
            CGContextFillEllipseInRect(context, rect1);
            CGContextStrokeEllipseInRect(context, rect1);
            
            CGRect iconRect = CGRectInset(rect1, 12.0f, 12.0f);
            CGFloat radius = 1.0f;
            
            CGFloat minx = CGRectGetMinX(iconRect), midx = CGRectGetMidX(iconRect), maxx = CGRectGetMaxX(iconRect);
            CGFloat miny = CGRectGetMinY(iconRect), midy = CGRectGetMidY(iconRect), maxy = CGRectGetMaxY(iconRect);
            
            CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
            
            CGContextMoveToPoint(context, minx, midy);
            CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
            CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
            CGContextAddArcToPoint(context, maxx, maxy, midx, maxy, radius);
            CGContextAddArcToPoint(context, minx, maxy, minx, midy, radius);
            CGContextClosePath(context);
            
            CGContextSetFillColorWithColor(context, TGAccentColor().CGColor);
            CGContextDrawPath(context, kCGPathFill);
            
            stopButtonImage = [UIGraphicsGetImageFromCurrentImageContext() stretchableImageWithLeftCapWidth:19 topCapHeight:19];
            UIGraphicsEndImageContext();
        });
        [_stopButton setImage:stopButtonImage forState:UIControlStateNormal];
        _stopButton.userInteractionEnabled = false;
        _stopButton.alpha = 0.0f;
        [_stopButton addTarget:self action:@selector(stopPressed) forControlEvents:UIControlEventTouchUpInside];
        [_overlayWindow.rootViewController.view addSubview:_stopButton];
    }
    
    _overlayWindow.userInteractionEnabled = _blocking;
    _overlayWindow.hidden = false;
    
    _stopButton.userInteractionEnabled = false;
    
    dispatch_block_t block = ^{
        [self updateOverlay];
    };
    
    block();
    dispatch_async(dispatch_get_main_queue(), block);
    
    _innerIconWrapperView.transform = CGAffineTransformIdentity;
    _innerCircleView.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
    _outerCircleView.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
    _innerCircleView.alpha = 0.2f;
    _outerCircleView.alpha = 0.2f;
    
    _lockPanelWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, 100.0f);
    _lockPanelWrapperView.alpha = 0.0f;
    
    if (iosMajorVersion() >= 8) {
        [UIView animateWithDuration:0.50 delay:0.0 usingSpringWithDamping:0.55f initialSpringVelocity:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
            _innerCircleView.transform = CGAffineTransformIdentity;
            _outerCircleView.transform = CGAffineTransformMakeScale(outerCircleMinScale, outerCircleMinScale);
            
            _lockPanelWrapperView.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        [UIView animateWithDuration:0.1 animations:^{
            _innerCircleView.alpha = 1.0f;
            self.iconView.alpha = 0.0f;
            _innerIconWrapperView.alpha = 1.0f;
            _outerCircleView.alpha = 1.0f;
            
            _lockPanelWrapperView.alpha = 1.0f;
        }];
    }
    else {
        [UIView animateWithDuration:0.2 animations:^
        {
            _lockPanelWrapperView.transform = CGAffineTransformIdentity;
            _lockPanelWrapperView.alpha = 1.0f;
        }];
    }
    [self displayLink].paused = false;
}

- (void)animateOut {
    _locked = false;
    _animatedIn = false;
    _displayLink.paused = true;
    _currentLevel = 0.0f;
    _currentTranslation = 0.0f;
    _targetTranslation = 0.0f;
    _currentScale = 1.0f;
    [UIView animateWithDuration:0.18 animations:^{
        _innerCircleView.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
        _outerCircleView.transform = CGAffineTransformMakeScale(0.2f, 0.2f);
        _innerCircleView.alpha = 0.0f;
        _outerCircleView.alpha = 0.0f;
        self.iconView.alpha = 1.0f;
        _innerIconWrapperView.alpha = 0.0f;
        
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 100.0f);
        transform = CGAffineTransformScale(transform, 0.2f, 0.2f);
        
        if (![_lockPanelWrapperView.layer.animationKeys containsObject:@"transform"])
            _lockPanelWrapperView.transform = transform;
        
        _lockPanelWrapperView.alpha = 0.0f;
        
        _stopButton.alpha = 0.0f;
    } completion:^(BOOL finished) {
        if (finished || [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) {
            _overlayWindow.hidden = true;
        }
        
        if (_previousIcon != nil)
            [self setIcon:_previousIcon];
        _previousIcon = nil;
    }];
}

- (void)animateLock {
    _lockView.lockness = 1.0f;
    
    UIView *snapshotView = [_innerIconView snapshotViewAfterScreenUpdates:false];
    snapshotView.frame = _innerIconView.frame;
    [_innerIconWrapperView insertSubview:snapshotView atIndex:0];
    
    _previousIcon = _innerIconView.image;
    [self setIcon:[UIImage imageNamed:@"RecordSendIcon"]];
    
    _innerIconView.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
    _innerIconView.alpha = 0.0f;
    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
    {
        _innerIconView.transform = CGAffineTransformIdentity;
        snapshotView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
    } completion:^(__unused BOOL finished) {
        [snapshotView removeFromSuperview];
    }];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        snapshotView.alpha = 0.0f;
        _innerIconView.alpha = 1.0f;
        
        _lockPanelView.frame = CGRectMake(_lockPanelView.frame.origin.x, 39.0f, _lockPanelView.frame.size.width, 77.0f - 39.0f);
        _lockView.transform = CGAffineTransformMakeTranslation(0.0f, -11.0f);
        _lockArrowView.transform = CGAffineTransformMakeTranslation(0.0f, -39.0f);
        _lockArrowView.alpha = 0.0f;
    }];

    TGDispatchAfter(0.45, dispatch_get_main_queue(), ^
    {
        [UIView animateWithDuration:0.2 delay:0.0 options:7 << 16 animations:^
        {
            _lockPanelWrapperView.transform = CGAffineTransformMakeTranslation(0.0f, 120.0f);
        } completion:^(__unused BOOL finished)
        {
            _lockPanelWrapperView.alpha = 0.0f;
            _lockPanelView.frame = CGRectMake(_lockPanelView.frame.origin.x, 0.0f, _lockPanelView.frame.size.width, 77.0f);
            _lockView.transform = CGAffineTransformIdentity;
            _lockArrowView.transform = CGAffineTransformIdentity;
            _lockArrowView.alpha = 1.0f;
        }];
    });
    
    _stopButton.userInteractionEnabled = true;
    [UIView animateWithDuration:0.25 delay:0.56 options:kNilOptions animations:^
    {
        _stopButton.alpha = 1.0f;
    } completion:nil];
}

- (void)stopPressed
{
    _stopButton.userInteractionEnabled = false;
    
    id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(micButtonInteractionStopped)])
        [delegate micButtonInteractionStopped];
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [UIView animateWithDuration:0.2 animations:^
        {
            _stopButton.alpha = 0.0f;
        }];
    });
}

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if ([super beginTrackingWithTouch:touch withEvent:event])
    {
        if (_acceptTouchDownAsTouchUp || _locked)
        {
            _locked = false;
            _acceptTouchDownAsTouchUp = false;
            _processCurrentTouch = false;
            
            [self _commitCompleted];
        }
        else
        {
            _lastVelocity = CGPointZero;
            
            if (ABS(CFAbsoluteTimeGetCurrent() - _lastTouchTime) < 0.4)
            {
                _processCurrentTouch = false;
                return false;
            }
            else
            {
                _processCurrentTouch = true;
                _lastTouchTime = CFAbsoluteTimeGetCurrent();
                
                id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(micButtonInteractionBegan)])
                    [delegate micButtonInteractionBegan];
                
                _touchLocation = [touch locationInView:self];
            }
        }
        
        return true;
    }
    
    return false;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if ([super continueTrackingWithTouch:touch withEvent:event])
    {
        _lastVelocity = [_panRecognizer velocityInView:self];
        
        if (_processCurrentTouch)
        {
            CGFloat distanceX = MIN(0.0f, [touch locationInView:self].x - _touchLocation.x);
            CGFloat distanceY = MIN(0.0f, [touch locationInView:self].y - _touchLocation.y);
            
            if (fabs(distanceX) > fabs(distanceY))
                distanceY = 0.0f;
            else
                distanceX = 0.0f;
            
            if (fabs(distanceY) < 5.0f)
            {
                distanceY = 0.0f;
                _targetTranslation = 0.0f;
            }
            else
            {
                distanceY += 5.0f;
            }
                
            CGPoint value = CGPointMake(MAX(0.0f, MIN(1.0f, (-distanceX) / 300.0f)), MAX(0.0f, MIN(1.0f, (-distanceY) / 300.0f)));
            
            CGPoint velocity = [_panRecognizer velocityInView:self];

            if (CACurrentMediaTime() > _animationStartTime + 0.50) {
                CGFloat scale = MAX(0.4f, MIN(1.0f, 1.0f - value.x));
                if (scale > 0.8f) {
                    scale = 1.0f;
                } else {
                    scale /= 0.8f;
                }
                
                _currentScale = scale;
                
                _targetTranslation = distanceY;
                CGFloat targetLockness = _locked ? 1.0f : MIN(1.0f, fabs(_targetTranslation) / 105.0f);
                _lockView.lockness = targetLockness;
                _lockView.transform = CGAffineTransformMakeTranslation(0.0f, -11.0f * targetLockness);
                
                _lockPanelView.frame = CGRectMake(_lockPanelView.frame.origin.x, 39.0f * targetLockness, _lockPanelView.frame.size.width, 77.0f - 39.0f * targetLockness);
                
                _lockArrowView.alpha = MAX(0.0f, 1.0f - targetLockness * 1.6f);
                _lockArrowView.transform = CGAffineTransformMakeTranslation(0.0f, -39.0f * targetLockness);
            }
            
            if (distanceX < -100.0f)
            {
                id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(micButtonInteractionCancelled:)])
                    [delegate micButtonInteractionCancelled:velocity];
                
                _targetTranslation = 0.0f;
                
                return false;
            }
            
            if (distanceY < -110.0f)
            {
                [self _commitLocked];
                
                return false;
            }
            
            id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(micButtonInteractionUpdate:)])
                [delegate micButtonInteractionUpdate:value];
        
            return true;
        }
    }
    
    return false;
}

- (void)cancelTrackingWithEvent:(UIEvent *)event
{
    if (_processCurrentTouch)
    {
        _currentTranslation = 0.0f;
        
        TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
        {
            [self _commitLocked];
        });
    }
    
    [super cancelTrackingWithEvent:event];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    if (_processCurrentTouch)
    {
        _targetTranslation = 0.0f;
        
        CGPoint velocity = _lastVelocity;
        id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
        if (velocity.x < -400.0f)
        {
            if ([delegate respondsToSelector:@selector(micButtonInteractionCancelled:)])
                [delegate micButtonInteractionCancelled:_lastVelocity];
        }
        else if (velocity.y < -400.0f)
        {
            [self _commitLocked];
        }
        else
        {
            [self _commitCompleted];
        }
    }
    
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void)_commitLocked
{
    id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
    
    bool shouldLock = true;
    if ([delegate respondsToSelector:@selector(micButtonShouldLock)])
        shouldLock = [delegate micButtonShouldLock];
    
    if (!shouldLock)
        return;
    
    if ([delegate respondsToSelector:@selector(micButtonInteractionLocked)])
        [delegate micButtonInteractionLocked];
    
    _locked = true;
    _targetTranslation = 0.0f;
    
    [self animateLock];
}

- (void)_commitCompleted
{
    id<TGModernConversationInputMicButtonDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(micButtonInteractionCompleted:)])
        [delegate micButtonInteractionCompleted:_lastVelocity];
}

- (void)displayLinkUpdate {
    NSTimeInterval t = CACurrentMediaTime();
    if (t > _animationStartTime + 0.5) {
        _currentLevel = _currentLevel * 0.8f + _inputLevel * 0.2f;
        
        _currentTranslation = MIN(0.0, _currentTranslation * 0.7f + _targetTranslation * 0.3f);
        
        CGFloat outerScale = outerCircleMinScale + _currentLevel * (1.0f - outerCircleMinScale);
        CGAffineTransform translation = CGAffineTransformMakeTranslation(0.0f, _currentTranslation);
        CGAffineTransform transform = CGAffineTransformScale(translation, outerScale, outerScale);
        
        _outerCircleView.transform = transform;
    
        _innerIconWrapperView.transform = translation;
        
        if (_lockPanelWrapperView.layer.animationKeys.count == 0)
            _lockPanelWrapperView.transform = translation;
        
        transform = CGAffineTransformScale(translation, _currentScale, _currentScale);
        _innerCircleView.transform = transform;
    }
}

- (void)addMicLevel:(CGFloat)level {
    _inputLevel = level;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)__unused gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)__unused otherGestureRecognizer {
    return true;
}

@end


@implementation TGModernConversationInputLockView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:CGRectMake(frame.origin.x, frame.origin.y, 38.0f, 38.0f)];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)setLockness:(CGFloat)lockness
{
    _lockness = lockness;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rrect = CGRectMake(rect.size.width / 2.0f - 6.0f, 6.0, 12.0f, 33.0);
    CGFloat radius = 6.0;

    CGFloat minx = CGRectGetMinX(rrect);
    CGFloat midx = CGRectGetMidX(rrect);
    CGFloat maxx = CGRectGetMaxX(rrect);
    
    CGFloat miny = CGRectGetMinY(rrect) + _lockness * 6.0f;
    CGFloat midy = CGRectGetMidY(rrect);
    
    UIColor *color = UIColorRGB(0x9597a0);
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    
    CGFloat lineWidth = 1.5f;
    CGFloat scale = (int)TGScreenScaling();
    if (scale >= 3.0)
        lineWidth = 5.0f / 3.0f;
    
    CGContextSetLineWidth(context, lineWidth);
    
    CGContextMoveToPoint(context, minx, midy);
    CGContextAddArcToPoint(context, minx, miny, midx, miny, radius);
    CGContextAddArcToPoint(context, maxx, miny, maxx, midy, radius);
    CGContextAddLineToPoint(context, maxx, midy + (-6.0f * (1.0f - _lockness)));
    CGContextDrawPath(context, kCGPathStroke);
    
    CGContextSetBlendMode(context, kCGBlendModeClear);

    CGContextSetBlendMode(context, kCGBlendModeNormal);
    
    CGContextStrokeEllipseInRect(context, CGRectMake(rect.size.width / 2.0f - 8.0f, rect.size.height - 18.0f, 16.0f, 16.0f));
    
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillEllipseInRect(context, CGRectMake(rect.size.width / 2.0f - 2.0f, rect.size.height - 12.0f, 4.0f, 4.0f));
}

@end


@implementation TGModernConversationInputMicWindow

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *firstResult = [self.subviews.firstObject hitTest:point withEvent:event];
    if ([firstResult isKindOfClass:[UIControl class]])
        return firstResult;
    
    if (!self.userInteractionEnabled)
        return nil;
 
    UIView *blockingResult = [super hitTest:point withEvent:event];
    
    __block bool block = false;
    if (_ignoreNextTouch)
    {
        _ignoreNextTouch = false;
        return blockingResult;
    }
    
    NSArray *windows = [UIApplication sharedApplication].windows;
    [windows enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIWindow *window, __unused NSUInteger index, BOOL *stop)
    {
        if ([window isKindOfClass:[TGModernConversationInputMicWindow class]])
            return;
        
        UIView *result = [window hitTest:point withEvent:event];
        if (result.tag == 0xbeef || result.superview.tag == 0xbeef)
        {
            *stop = true;
            return;
        }
        
        bool shouldBlock = [result isKindOfClass:[UINavigationBar class]] || [result.superview isKindOfClass:[UINavigationBar class]] || result.tag == -1;
        if (shouldBlock)
        {
            block = true;
            *stop = true;
        }
    }];
    
    if (block)
    {
        _ignoreNextTouch = true;
        if (self.requestedLockedAction != nil)
            self.requestedLockedAction();
        
        return blockingResult;
    }
    
    return nil;
}

@end
