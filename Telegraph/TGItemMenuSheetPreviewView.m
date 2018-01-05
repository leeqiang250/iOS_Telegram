#import "TGItemMenuSheetPreviewView.h"
#import "TGMenuSheetView.h"

#import "TGImageUtils.h"
#import "TGAppDelegate.h"

#import "TGHacks.h"
#import <objc/runtime.h>

const CGFloat TGItemMenuSheetPreviewLockThreshold = 45.0f;
const CGFloat TGItemMenuSheetPreviewLockVelocityThreshold = 800.0f;
const CGFloat TGItemMenuSheetPreviewPeekScale = 0.95f;
const CGFloat TGItemMenuSheetPreviewArrowVisibleThreshold = -24.0f;

typedef enum
{
    TGItemMenuTransitionTypeSimplified,
    TGItemMenuTransitionTypeLegacy
} TGItemMenuTransitionType;

@interface TGItemMenuSheetPreviewView () <UIGestureRecognizerDelegate>
{
    UIView *_blurView;
    UIView *_blurDimView;
    
    UIImageView *_shadowView;
    
    UIButton *_dismissButton;
    
    UIImageView *_arrowView;
    TGMenuSheetView *_mainSheetView;
    TGMenuSheetView *_actionsSheetView;
    
    bool _actionsWerePresented;
    bool _actionsAnimatingDismiss;
    
    bool _dismissByVelocity;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
    CGPoint _gestureStartLocation;
    bool _wasPanning;
    bool _shouldPassPanOffset;
    TGMenuSheetItemView *_panHandlingItemView;
    bool _actionsWerePresentedOnGestureStart;
}
@end

@implementation TGItemMenuSheetPreviewView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        TGItemMenuTransitionType type = [self _transitionType];
        if (type != TGItemMenuTransitionTypeLegacy)
        {
            UIBlurEffect *effect = nil;
            if (type == TGItemMenuTransitionTypeSimplified)
                effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
            
            _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
            [self addSubview:_blurView];
            
            if (type == TGItemMenuTransitionTypeSimplified)
                _blurView.alpha = 0.0f;
            
            [self.dimView removeFromSuperview];
            
            _blurDimView = [[UIView alloc] initWithFrame:self.bounds];
            _blurDimView.alpha = 0.0f;
            _blurDimView.backgroundColor = UIColorRGBA(0x000000, 0.1f);
            [self addSubview:_blurDimView];
        }
        else
        {
            self.dimView.backgroundColor = UIColorRGBA(0x000000, 0.2f);
        }
    }
    return self;
}

- (instancetype)initWithMainItemViews:(NSArray *)mainItemViews actionItemViews:(NSArray *)actionItemViews
{
    self = [self initWithFrame:CGRectZero];
    if (self != nil)
    {
        [self setupWithMainItemViews:mainItemViews actionItemViews:actionItemViews];
    }
    return self;
}

- (void)setupWithMainItemViews:(NSArray *)mainItemViews actionItemViews:(NSArray *)actionItemViews
{
    [self bringSubviewToFront:self.wrapperView];
    
    [_containerView removeFromSuperview];
    _containerView = [[UIView alloc] init];
    [self.wrapperView addSubview:_containerView];
    
    bool requiresShadow = mainItemViews.count > 0;
    for (TGMenuSheetItemView *itemView in mainItemViews)
    {
        if (itemView.requiresClearBackground)
        {
            requiresShadow = false;
            break;
        }
    }
    
    if (requiresShadow && _shadowView == nil)
    {
        _shadowView = [[UIImageView alloc] init];
        _shadowView.image = [[UIImage imageNamed:@"PreviewSheetShadow"] resizableImageWithCapInsets:UIEdgeInsetsMake(42.0f, 42.0f, 42.0f, 42.0f)];
        [_containerView addSubview:_shadowView];
    }
    
    [_dismissButton removeFromSuperview];
    _dismissButton = [[UIButton alloc] initWithFrame:self.bounds];
    _dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_dismissButton addTarget:self action:@selector(dismissButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [_containerView addSubview:_dismissButton];
    
    [_mainSheetView removeFromSuperview];
    _mainSheetView = [[TGMenuSheetView alloc] initWithItemViews:mainItemViews sizeClass:UIUserInterfaceSizeClassCompact dark:false];
    
    __weak TGItemMenuSheetPreviewView *weakSelf = self;
    void (^menuRelayout)(void) = ^
    {
        __strong TGItemMenuSheetPreviewView *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        strongSelf->_mainSheetView.frame = [strongSelf _mainViewFrameExpanded:strongSelf.presentActionsImmediately];
    };
    _mainSheetView.menuRelayout = menuRelayout;
    
    
    [_arrowView removeFromSuperview];
    _arrowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"PreviewUpArrow"]];
    _arrowView.alpha = 0.0f;
    [_mainSheetView addSubview:_arrowView];
    
    if (actionItemViews.count > 0)
    {
        [_actionsSheetView removeFromSuperview];
        _actionsSheetView = [[TGMenuSheetView alloc] initWithItemViews:actionItemViews sizeClass:UIUserInterfaceSizeClassCompact dark:false];
        _actionsSheetView.hidden = true;
    }
}

- (void)setActionItemViews:(NSArray *)__unused actionsView animated:(bool)__unused animated
{
    
}

- (TGItemMenuTransitionType)_transitionType
{
    static dispatch_once_t onceToken;
    static TGItemMenuTransitionType type;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if (iosMajorVersion() < 8 || (NSInteger)screenSize.height == 480)
            type = TGItemMenuTransitionTypeLegacy;
        else
            type = TGItemMenuTransitionTypeSimplified;
    });
    
    return type;
}

- (void)dismissButtonPressed
{
    [self performDismissal];
}

- (void)prepareSheetViews
{
    CGSize referenceSize = TGAppDelegateInstance.rootController.applicationBounds.size;
    CGFloat minSide = MIN(referenceSize.width, referenceSize.height);
    _mainSheetView.menuWidth = minSide;
    _actionsSheetView.menuWidth = minSide;
    
    [_containerView addSubview:_mainSheetView];
    if (_actionsSheetView != nil)
        [_containerView addSubview:_actionsSheetView];
    
    _mainSheetView.frame = [self _mainViewFrameExpanded:self.presentActionsImmediately];
    _shadowView.frame = [self _shadowFrame];
    [_mainSheetView layoutSubviews];
    
    _actionsSheetView.frame = [self _actionsViewFrameExpanded:false];
    [_actionsSheetView layoutSubviews];
    
    _arrowView.frame = CGRectMake((_mainSheetView.frame.size.width - _arrowView.frame.size.width) / 2.0f, -14.0f, _arrowView.frame.size.width, _arrowView.frame.size.height);
    
    [_mainSheetView menuWillAppearAnimated:true];
    [_actionsSheetView menuWillAppearAnimated:true];
}

- (CGRect)_shadowFrame
{
    CGRect frame = _mainSheetView.frame;
    frame.origin.x -= 6.5f;
    frame.size.width += 13.0f;
    frame.origin.y -= 6.0f;
    frame.size.height += 13.0f;
    return frame;
}

- (void)animateAppear
{
    self.wrapperView.frame = self.bounds;
    
    _containerView.frame = self.wrapperView.bounds;
    [self prepareSheetViews];
    
    [super animateAppear];
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (self.presentActionsImmediately)
        {
            [_mainSheetView menuDidAppearAnimated:true];
            [_actionsSheetView menuDidAppearAnimated:true];
            
            [self _initializeInternalGestureRecognizer];
        }
    };
    
    if (!self.dontBlurOnPresentation || self.presentActionsImmediately)
    {
        [TGHacks setApplicationStatusBarAlpha:0.0f];
        [self performAppearBackgroundTransition:completionBlock];
    }
    
    if (self.presentActionsImmediately)
    {
        [self addSubview:_actionsSheetView];
        [self _presentActions:nil];
    }
}

- (void)animateDismiss:(void (^)())completion
{
    [self.wrapperView addSubview:_containerView];
    [super animateDismiss:completion];
    
    void (^completionBlock)(void) = ^
    {
        [_mainSheetView menuDidDisappearAnimated:true];
        [_actionsSheetView menuDidDisappearAnimated:true];
    };
    
    [self performDisappearBackgroundTransition:completionBlock];
}

- (void)performAppearBackgroundTransition:(void (^)(BOOL))completionBlock
{
    TGItemMenuTransitionType type = [self _transitionType];
    if (type == TGItemMenuTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            _blurView.alpha = 1.0f;
        } completion:completionBlock];
    }
    else
    {
        if (completionBlock != nil)
            completionBlock(true);
    }
}

- (void)performDisappearBackgroundTransition:(void (^)(void))completionBlock
{
    TGItemMenuTransitionType type = [self _transitionType];
    if (type == TGItemMenuTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            [TGHacks setApplicationStatusBarAlpha:1.0f];
            
            _blurView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            completionBlock();
        }];
    }
    else
    {
        [TGHacks setApplicationStatusBarAlpha:1.0f];
        completionBlock();
    }
}

- (void)_didAppear
{
    [self addSubview:_containerView];
    
    if (self.presentActionsImmediately || self.isLocked)
        return;
    
    [UIView animateWithDuration:0.25 animations:^
    {
        _arrowView.alpha = 1.0f;
    }];
}

- (void)_willDisappear
{
    [UIView animateWithDuration:0.16 animations:^
    {
        _arrowView.alpha = 0.0f;
    }];
    
    [_mainSheetView menuWillDisappearAnimated:true];
    [_actionsSheetView menuWillDisappearAnimated:true];
}

- (void)setArrowHidden:(bool)hidden animated:(bool)animated
{
    if (animated)
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _arrowView.alpha = hidden ? 0.0f : 1.0f;
        }];
    }
    else
    {
        _arrowView.alpha = hidden ? 0.0f : 1.0f;
    }
}

- (void)_handlePanOffset:(CGFloat)offset
{
    CGFloat centerDelta = [self _mainViewFrameExpanded:false].origin.y - [self _mainViewFrameExpanded:true].origin.y;
    
    CGFloat appliedOffset = [self swipeOffsetForOffset:offset];
    
    CGRect frame = [self _mainViewFrameExpanded:_actionsWerePresentedOnGestureStart];
    frame.origin.y += appliedOffset;
    _mainSheetView.frame = frame;
    _shadowView.frame = [self _shadowFrame];
    
    [self setArrowHidden:(appliedOffset < TGItemMenuSheetPreviewArrowVisibleThreshold || _actionsPresented) animated:true];
    
    if (!_actionsPresented)
    {
        if ((centerDelta > TGItemMenuSheetPreviewLockThreshold && (appliedOffset * -1) > centerDelta) || (centerDelta < TGItemMenuSheetPreviewLockThreshold && (appliedOffset * -1) > TGItemMenuSheetPreviewLockThreshold))
        {
            [self _presentActions:nil];
        }
    }
    else if (!_actionsAnimatingDismiss)
    {
        CGRect expandedActionsFrame = [self _actionsViewFrameExpanded:true];
        CGFloat diff = CGRectGetMaxY(_mainSheetView.frame) - 10.0f - CGRectGetMinY(expandedActionsFrame);
        
        if (diff > 0)
        {
            expandedActionsFrame.origin.y += diff;
            _actionsSheetView.frame = expandedActionsFrame;
        }
        
        if (appliedOffset >= 50.0f)
            [self dismissActions];
    }
}

- (void)_handlePressEnded
{
    [self _initializeInternalGestureRecognizer];
    
    if (!self.presentActionsImmediately)
    {
        [_mainSheetView menuDidAppearAnimated:true];
        [_actionsSheetView menuDidAppearAnimated:true];
    }
    
    [self _centerMainSheetView];
}

- (bool)_maybeLockWithVelocity:(CGFloat)velocity
{
    if (velocity < -TGItemMenuSheetPreviewLockVelocityThreshold)
    {
        [self _initializeInternalGestureRecognizer];
        [self _presentActions:nil];
        [self _centerMainSheetView];
        
        return true;
    }
    
    return false;
}

- (void)_initializeInternalGestureRecognizer
{
    if (_panGestureRecognizer != nil)
        return;
    
    _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    _panGestureRecognizer.delegate = self;
    [self addGestureRecognizer:_panGestureRecognizer];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _panGestureRecognizer)
    {
        NSString *viewClassName = NSStringFromClass(otherGestureRecognizer.view.class);
        if ([viewClassName rangeOfString:@"WKScroll"].location != NSNotFound || [viewClassName rangeOfString:@"UIWebViewScroll"].location != NSNotFound)
        {
            return true;
        }
        
        return false;
    }
    
    return false;
}


- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGPoint location = [gestureRecognizer locationInView:self];
    CGPoint velocity = [gestureRecognizer velocityInView:self];
 
    CGFloat offset = location.y - _gestureStartLocation.y;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _actionsWerePresented = _actionsPresented;
            _actionsWerePresentedOnGestureStart = _actionsPresented;
            _gestureStartLocation = location;
            
            _panHandlingItemView = nil;
            for (TGMenuSheetItemView *itemView in _mainSheetView.itemViews)
            {
                if (itemView.handlesPan)
                {
                    _shouldPassPanOffset = true;
                    _panHandlingItemView = itemView;
                    break;
                }
            }
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            bool shouldPan = _shouldPassPanOffset && [_panHandlingItemView passPanOffset:0];
            if (!shouldPan)
            {
                _wasPanning = false;
                [self _handlePanOffset:0];
            }
            else
            {
                if (!_wasPanning)
                {
                    _gestureStartLocation = location;
                    _wasPanning = true;
                    offset = 0;
                }
            }
            
            if (!_shouldPassPanOffset || shouldPan)
                [self _handlePanOffset:offset];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            bool allowDismissal = !_shouldPassPanOffset || _wasPanning;
            if (_actionsPresented && velocity.y < TGItemMenuSheetPreviewLockVelocityThreshold)
            {
                [self _centerMainSheetView];
            }
            else if (allowDismissal)
            {
                _dismissByVelocity = _actionsPresented;
                [self performDismissal];
            }
        }
            break;
            
        default:
            break;
    }
}

#pragma mark -

- (void)_centerMainSheetView
{
    [self setArrowHidden:_actionsPresented animated:true];
    
    [UIView animateWithDuration:0.44 delay:0.0 usingSpringWithDamping:0.72f initialSpringVelocity:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:^
    {
        _mainSheetView.frame = [self _mainViewFrameExpanded:true];
        _shadowView.frame = [self _shadowFrame];
        if (_actionsPresented && !_actionsAnimatingDismiss)
            _actionsSheetView.frame = [self _actionsViewFrameExpanded:true];
    } completion:nil];
}

- (CGRect)_mainViewFrameExpanded:(bool)expanded
{
    CGSize menuSize = _mainSheetView.menuSize;
    CGRect rect = CGRectMake((_containerView.frame.size.width - menuSize.width) / 2.0f, (_containerView.frame.size.height - menuSize.height) / 2.0f, menuSize.width, menuSize.height);
    
    if (expanded)
    {
        CGRect actionsViewRect = [self _actionsViewFrameExpanded:true];
        rect.origin.y = MIN(rect.origin.y, actionsViewRect.origin.y - rect.size.height + 10.0f);
    }
    
    return rect;
}

- (CGRect)_actionsViewFrameExpanded:(bool)expanded
{
    CGSize menuSize = _actionsSheetView.menuSize;
    CGRect rect = CGRectMake((_containerView.frame.size.width - menuSize.width) / 2.0f, _containerView.frame.size.height, menuSize.width, menuSize.height);
    
    if (expanded)
        rect.origin.y = _containerView.frame.size.height - rect.size.height;
    
    return rect;
}

- (CGFloat)swipeOffsetForOffset:(CGFloat)offset
{
    if (offset < 0)
        return [self rubberBandedOffsetForOffset:offset bandingStart:0.0f coefficient:0.4f range:600.0f];
    else if ((_actionsPresented || _actionsWerePresented) && offset > 0.0f)
        return [self rubberBandedOffsetForOffset:offset bandingStart:0.0f coefficient:0.3f range:480.0f];
    else if (!_actionsPresented && offset > 0.0f)
        return [self rubberBandedOffsetForOffset:offset bandingStart:0.0f coefficient:0.12f range:320.0f];
    else
        return offset;
}

- (CGFloat)rubberBandedOffsetForOffset:(CGFloat)offset bandingStart:(CGFloat)bandingStart coefficient:(CGFloat)coefficient range:(CGFloat)range
{
    CGFloat bandedOffset = offset - bandingStart;
    return bandingStart + (1.0f - (1.0f / ((bandedOffset * coefficient / range) + 1.0f))) * range;
}

- (void)presentActions:(void (^)(void))animationBlock
{
    [self _initializeInternalGestureRecognizer];
    
    [self performAppearBackgroundTransition:nil];
    
    [self addSubview:_actionsSheetView];
    [self _presentActions:animationBlock];
}

- (void)_presentActions:(void (^)(void))animationBlock
{
    if (_actionsPresented || _actionsAnimatingDismiss)
        return;
    
    _actionsPresented = true;
    _actionsWerePresented = true;
    _actionsSheetView.hidden = false;
    
    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.0f options:0 animations:^
    {
        _actionsSheetView.frame = [self _actionsViewFrameExpanded:true];
        if (animationBlock != nil)
            animationBlock();
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            if (_actionsSheetView.superview != _containerView)
                [_containerView addSubview:_actionsSheetView];
        }
    }];
}

- (void)dismissActions
{
    _actionsAnimatingDismiss = true;
    
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowAnimatedContent animations:^
    {
         _actionsSheetView.frame = [self _actionsViewFrameExpanded:false];
    } completion:^(__unused BOOL finished)
    {
        _actionsAnimatingDismiss = false;
        _actionsPresented = false;
        _actionsSheetView.hidden = true;
        
        if (_panGestureRecognizer != nil && _panGestureRecognizer.state != UIGestureRecognizerStateChanged)
            [self performDismissal];
    }];
}

- (void)performCommit
{
    [UIView animateWithDuration:0.3 delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowAnimatedContent animations:^
    {
        _mainSheetView.frame = CGRectMake(_mainSheetView.frame.origin.x, -_mainSheetView.frame.size.height, _mainSheetView.frame.size.width, _mainSheetView.frame.size.height);
        _shadowView.frame = [self _shadowFrame];
        _actionsSheetView.frame = [self _actionsViewFrameExpanded:false];
    } completion:^(__unused BOOL finished)
    {
        _mainSheetView.hidden = true;
        _actionsSheetView.hidden = true;
        [self animateDismiss:^
        {
            if (self.onDismiss != nil)
                self.onDismiss();
        }];
    }];
}

- (void)performDismissal
{
    if (_actionsPresented)
    {
        [self addSubview:_actionsSheetView];
    
        [UIView animateWithDuration:0.24 delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowAnimatedContent animations:^
        {
            if (!_actionsAnimatingDismiss)
                _actionsSheetView.frame = [self _actionsViewFrameExpanded:false];
            
            if (_actionsAnimatingDismiss || _dismissByVelocity)
            {
                _mainSheetView.frame = [self _mainViewFrameExpanded:false];
                _shadowView.frame = [self _shadowFrame];
            }
        } completion:nil];
        
        TGDispatchAfter(0.15, dispatch_get_main_queue(), ^
        {
            [self animateDismiss:^
            {
                if (self.onDismiss != nil)
                    self.onDismiss();
            }];
        });
    }
    else
    {
        [self animateDismiss:^
        {
            if (self.onDismiss != nil)
                self.onDismiss();
        }];
    }
}

- (bool)isLocked
{
    return _actionsPresented;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _blurView.frame = self.bounds;
    _blurDimView.frame = self.bounds;
}

@end
