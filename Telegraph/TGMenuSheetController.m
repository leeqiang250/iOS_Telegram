#import "TGMenuSheetController.h"

#import <SSignalKit/SSignalKit.h>

#import "TGMenuSheetView.h"
#import "TGMenuSheetDimView.h"
#import "TGMenuSheetItemView.h"
#import "TGMenuSheetCollectionView.h"

#import "TGAppDelegate.h"

#import "TGObserverProxy.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

#import "TGOverlayController.h"
#import "TGOverlayControllerWindow.h"

const CGFloat TGMenuSheetPadMenuWidth = 375.0f;
const CGFloat TGMenuSheetDefaultStatusBarHeight = 20.0f;

typedef enum
{
    TGMenuSheetAnimationChange,
    TGMenuSheetAnimationDismiss,
    TGMenuSheetAnimationPresent,
    TGMenuSheetAnimationFastDismiss
} TGMenuSheetAnimation;

typedef enum
{
    TGMenuPanDirectionHorizontal,
    TGMenuPanDirectionVertical,
} TGMenuPanDirection;

@interface TGMenuPanGestureRecognizer : UIPanGestureRecognizer

@property (nonatomic, assign) TGMenuPanDirection direction;

@end

@interface TGMenuSheetController () <UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, UIPopoverControllerDelegate, UIViewControllerPreviewingDelegate>
{
    bool _dark;
    
    UIView *_containerView;
    TGMenuSheetDimView *_dimView;
    TGMenuSheetView *_sheetView;
    bool _presented;
    
    SMetaDisposable *_sizeClassDisposable;
    UIUserInterfaceSizeClass _sizeClass;
    
    bool _hasSwipeGesture;
    TGMenuPanGestureRecognizer *_gestureRecognizer;
    CGFloat _gestureStartPosition;
    CGFloat _gestureActualStartPosition;
    bool _shouldPassPanOffset;
    bool _wasPanning;
    
    bool _hasDistractableItems;
    
    __weak UIView *_sourceView;
    __weak UIViewController *_parentController;
    
    CGFloat _keyboardOffset;
    id _keyboardWillChangeFrameProxy;
    
    bool _checked3dTouch;
    NSDictionary *_3dTouchHandlers;
    
    UIPopoverController *_popoverController;
}
@end

@implementation TGMenuSheetController

- (instancetype)init
{
    return [self init:false];
}

- (instancetype)init:(bool)__unused dark
{
    self = [super init];
    if (self != nil)
    {
        _dark = dark;
        _disposables = [[SDisposableSet alloc] init];
        _permittedArrowDirections = UIPopoverArrowDirectionDown;
    }
    return self;
}

- (instancetype)initWithItemViews:(NSArray *)itemViews
{
    self = [self init];
    if (self != nil)
    {
        [self setItemViews:itemViews];
    }
    return self;
}

- (void)dealloc
{
    [_sizeClassDisposable dispose];
}

- (void)loadView
{
    [super loadView];
    
    if (TGAppDelegateInstance.rootController.currentSizeClass == UIUserInterfaceSizeClassCompact)
    {
        self.view.frame = TGAppDelegateInstance.rootController.applicationBounds;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    
    __weak TGMenuSheetController *weakSelf = self;
    _sizeClassDisposable = [[SMetaDisposable alloc] init];
    [_sizeClassDisposable setDisposable:[[TGAppDelegateInstance rootController].sizeClass startWithNext:^(NSNumber *next)
    {
        __strong TGMenuSheetController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        UIUserInterfaceSizeClass sizeClass = next.integerValue;
        [strongSelf updateTraitsWithSizeClass:sizeClass];
    }]];
    
    _containerView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:_containerView];
    
    _dimView = [[TGMenuSheetDimView alloc] initWithActionMenuView:_sheetView];
    _dimView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_dimView addTarget:self action:@selector(dimViewPressed) forControlEvents:UIControlEventTouchUpInside];
    [_dimView setTheaterMode:_hasDistractableItems animated:false];
    [_containerView addSubview:_dimView];
    
    [_containerView addSubview:_sheetView];
    
    _keyboardWillChangeFrameProxy = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification];
}

- (void)setItemViews:(NSArray *)itemViews
{
    [self setItemViews:itemViews animated:false];
}

- (void)setItemViews:(NSArray *)itemViews animated:(bool)animated
{
    UIUserInterfaceSizeClass sizeClass = [self sizeClass];
    bool compact = (sizeClass == UIUserInterfaceSizeClassCompact);

    bool hasDistractableItems = false;
    for (TGMenuSheetItemView *itemView in itemViews)
    {
        itemView.menuController = self;
        
        if (itemView.distractable)
            hasDistractableItems = true;
    }
    _hasDistractableItems = hasDistractableItems;
    
    if (_dimView != nil)
        [_dimView setTheaterMode:_hasDistractableItems animated:animated];
    
    __weak TGMenuSheetController *weakSelf = self;
    void (^menuRelayout)(void) = ^
    {
        __strong TGMenuSheetController *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        [strongSelf repositionMenuWithReferenceSize:TGAppDelegateInstance.rootController.applicationBounds.size];
    };
    
    if (animated && compact)
    {
        TGMenuSheetView *sheetView = _sheetView;
        
        UIView *snapshotView = [sheetView snapshotViewAfterScreenUpdates:false];
        snapshotView.frame = [_containerView convertRect:sheetView.frame toView:_containerView.superview];
        [_containerView.superview addSubview:snapshotView];
        
        [sheetView menuWillDisappearAnimated:false];
        [sheetView removeFromSuperview];
        [sheetView menuDidDisappearAnimated:false];
        
        void (^changeBlock)(void) = ^
        {
            snapshotView.frame = CGRectMake(snapshotView.frame.origin.x, snapshotView.frame.origin.y + snapshotView.frame.size.height, snapshotView.frame.size.width, snapshotView.frame.size.height);
        };
        void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
        {
            [snapshotView removeFromSuperview];
        };
        
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:0.25 delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:0.0 options:UIViewAnimationOptionCurveLinear animations:changeBlock completion:completionBlock];
        }
        else
        {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:changeBlock completion:completionBlock];
        }
        
        _sheetView = [[TGMenuSheetView alloc] initWithItemViews:itemViews sizeClass:sizeClass dark:_dark];
        _sheetView.menuRelayout = menuRelayout;
        _sheetView.menuWidth = sheetView.menuWidth;
        _sheetView.maxHeight = _maxHeight;
        [_containerView addSubview:_sheetView];
        
        [self updateGestureRecognizer];
        [self.view setNeedsLayout];
        
        [self applySheetOffset:_sheetView.menuHeight];
        [_sheetView menuWillAppearAnimated:animated];
        [self animateSheetViewToPosition:0 velocity:0 type:TGMenuSheetAnimationPresent completion:^
        {
            [_sheetView menuDidAppearAnimated:animated];
        }];
    }
    else
    {
        void (^configureBlock)(void) = ^
        {
            _sheetView = [[TGMenuSheetView alloc] initWithItemViews:itemViews sizeClass:sizeClass dark:_dark];
            _sheetView.menuRelayout = menuRelayout;
            _sheetView.maxHeight = _maxHeight;
            if (self.isViewLoaded)
                [_containerView addSubview:_sheetView];
            
            [self updateGestureRecognizer];
            [self.view setNeedsLayout];
        };
        
        if (_sheetView != nil)
        {
            [_parentController dismissViewControllerAnimated:false completion:^
            {
                [_sheetView menuWillDisappearAnimated:animated];
                [_sheetView removeFromSuperview];
                [_sheetView menuDidDisappearAnimated:animated];
                configureBlock();
                
                [_sheetView menuWillAppearAnimated:animated];
                
                [self _presentPopoverInController:_parentController];
                
                [_sheetView menuDidAppearAnimated:animated];
            }];
        }
        else
        {
            configureBlock();
        }
    }
    
    _itemViews = itemViews;
}

- (void)dimViewPressed
{
    if (!self.dismissesByOutsideTap)
        return;
    
    bool dismissalAllowed = true;
    if (_sheetView.tapDismissalAllowed != nil)
        dismissalAllowed = _sheetView.tapDismissalAllowed();
    
    if (!dismissalAllowed)
        return;

    [self dismissAnimated:true manual:true];
}

#pragma mark -

- (UIView *)sourceView
{
    return _sourceView;
}

- (UIUserInterfaceSizeClass)sizeClass
{
    UIUserInterfaceSizeClass sizeClass = _sizeClass;
    if (self.inhibitPopoverPresentation)
        sizeClass = UIUserInterfaceSizeClassCompact;
    return sizeClass;
}

- (bool)isInPopover
{
    if ([_parentController isKindOfClass:[TGNavigationController class]])
    {
        TGNavigationController *navController = (TGNavigationController *)_parentController;
        if (navController.presentationStyle == TGNavigationControllerPresentationStyleRootInPopover)
            return true;
    }
    
    return false;
}

#pragma mark -

- (void)popoverPresentationController:(UIPopoverPresentationController *)__unused popoverPresentationController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)__unused view
{
    if (self.sourceRect != nil)
        *rect = self.sourceRect();
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)__unused popoverController
{
    _popoverController = nil;
}

- (void)popoverController:(UIPopoverController *)__unused popoverController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)__unused view
{
    if (self.sourceRect != nil)
        *rect = self.sourceRect();
}

#pragma mark -

- (void)_presentPopoverInController:(UIViewController *)controller
{
    if (_sourceView == nil && self.barButtonItem == nil)
        return;
    
    if (iosMajorVersion() >= 8)
    {
        [controller presentViewController:self animated:false completion:nil];
        if (self.popoverPresentationController == nil)
            return;
        
        self.popoverPresentationController.backgroundColor = _dark ? UIColorRGB(0x161616) : [UIColor whiteColor];
        self.popoverPresentationController.delegate = self;
        self.popoverPresentationController.permittedArrowDirections = self.permittedArrowDirections;
        
        if (self.barButtonItem != nil)
        {
            self.popoverPresentationController.barButtonItem = self.barButtonItem;
        }
        else
        {
            self.popoverPresentationController.sourceView = _sourceView;
            CGRect sourceRect = _sourceView.bounds;
            if (self.sourceRect != nil)
                sourceRect = self.sourceRect();
            self.popoverPresentationController.sourceRect = sourceRect;
        }
    }
    else
    {
        _popoverController = [[UIPopoverController alloc] initWithContentViewController:self];
        
        if (self.barButtonItem != nil)
        {
            [_popoverController presentPopoverFromBarButtonItem:self.barButtonItem permittedArrowDirections:self.permittedArrowDirections animated:false];
        }
        else
        {
            CGRect sourceRect = _sourceView.bounds;
            if (self.sourceRect != nil)
                sourceRect = self.sourceRect();
            
            [_popoverController presentPopoverFromRect:sourceRect inView:self.sourceView permittedArrowDirections:self.permittedArrowDirections animated:false];
        }
    }
}

- (void)presentInViewController:(UIViewController *)viewController sourceView:(UIView *)sourceView animated:(bool)animated
{
    _sourceView = sourceView;
    
    UIUserInterfaceSizeClass sizeClass = [self sizeClass];
    
    bool compact = (sizeClass == UIUserInterfaceSizeClassCompact);
    if (compact)
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    else
        self.modalPresentationStyle = UIModalPresentationPopover;
    
    if (viewController.navigationController != nil)
        viewController = viewController.navigationController.parentViewController ?: viewController.navigationController;
    
    _parentController = viewController;
    
    if ([_parentController.presentedViewController isKindOfClass:[TGMenuSheetController class]])
        return;
    
    for (UIViewController *controller in _parentController.childViewControllers)
    {
        if ([controller isKindOfClass:[TGMenuSheetController class]])
            return;
    }
    
    if (sizeClass == UIUserInterfaceSizeClassRegular || [self isInPopover])
    {
        _sheetView.menuWidth = TGMenuSheetPadMenuWidth;
    }
    else
    {
        CGSize referenceSize = TGAppDelegateInstance.rootController.applicationBounds.size;
        CGFloat minSide = MIN(referenceSize.width, referenceSize.height);
        if (self.narrowInLandscape)
            _sheetView.menuWidth = minSide;
        else
            _sheetView.menuWidth = referenceSize.width;
    }
    
    if (compact)
    {
        [viewController addChildViewController:self];
        [viewController.view addSubview:self.view];
        
        _dimView.alpha = 0.0f;
        [self setDimViewHidden:false animated:animated];
        
        if (iosMajorVersion() >= 7 && [viewController isKindOfClass:[TGNavigationController class]])
            ((TGNavigationController *)viewController).interactivePopGestureRecognizer.enabled = false;
        
        if (animated)
        {
            CGFloat menuHeight = _sheetView.menuHeight;
            [self applySheetOffset:menuHeight];
            
            if (self.willPresent != nil)
            {
                [self viewWillLayoutSubviews];
                self.willPresent(menuHeight);
            }
            
            [self viewWillLayoutSubviews];
            [_sheetView menuWillAppearAnimated:animated];
            [self animateSheetViewToPosition:0 velocity:0 type:TGMenuSheetAnimationPresent completion:^
            {
                [_sheetView menuDidAppearAnimated:animated];
                _presented = true;
            }];
        }
        else
        {
            if (self.willPresent != nil)
                self.willPresent(0);
            
            [_sheetView menuWillAppearAnimated:animated];
            [_sheetView menuDidAppearAnimated:animated];
            _presented = true;
        }
    }
    else
    {
        [_sheetView menuSize];
        
        if (self.willPresent != nil)
            self.willPresent(0);
        
        [_sheetView menuWillAppearAnimated:false];

        [self _presentPopoverInController:viewController];

        [_sheetView menuDidAppearAnimated:false];
        _presented = true;
    }
    
    [self setup3DTouch];
}

- (void)dismissAnimated:(bool)animated
{
    [self dismissAnimated:animated manual:false];
}

- (void)dismissAnimated:(bool)animated manual:(bool)manual
{
    [self dismissAnimated:animated manual:manual completion:nil];
}

- (void)dismissAnimated:(bool)animated manual:(bool)manual completion:(void (^)(void))completion
{
    bool compact = ([self sizeClass] == UIUserInterfaceSizeClassCompact);
    
    if (self.willDismiss != nil)
        self.willDismiss(manual);
    
    if (compact)
    {
        if (iosMajorVersion() >= 7 && [self.parentViewController isKindOfClass:[TGNavigationController class]])
            ((TGNavigationController *)self.parentViewController).interactivePopGestureRecognizer.enabled = true;
        
        [_sheetView menuWillDisappearAnimated:animated];
        [self setDimViewHidden:true animated:animated];
        if (animated)
        {
            self.view.userInteractionEnabled = false;
            [self animateSheetViewToPosition:_sheetView.menuHeight velocity:0 type:TGMenuSheetAnimationDismiss completion:^
            {
                [self.view removeFromSuperview];
                [self removeFromParentViewController];
                [_sheetView menuDidDisappearAnimated:animated];
                
                if (self.didDismiss != nil)
                    self.didDismiss(manual);
                
                if (completion != nil)
                    completion();
            }];
        }
        else
        {
            [self.view removeFromSuperview];
            [self removeFromParentViewController];
            [_sheetView menuDidDisappearAnimated:animated];
            
            if (self.didDismiss != nil)
                self.didDismiss(manual);
            
            if (completion != nil)
                completion();
        }
    }
    else
    {
        [_sheetView menuWillDisappearAnimated:animated];
        
        void (^dismissedBlock)(void) = ^
        {
            [_sheetView menuDidDisappearAnimated:animated];
            if (self.didDismiss != nil)
                self.didDismiss(manual);
            
            if (completion != nil)
                completion();
            
            if ([self.parentViewController isKindOfClass:[TGOverlayController class]]) {
                TGOverlayControllerWindow *window = ((TGOverlayController *)self.parentViewController).overlayWindow;
                if (window.dismissByMenuSheet) {
                    [window dismiss];
                }
            }
        };
        
        if (_popoverController == nil)
        {
            [self.presentingViewController dismissViewControllerAnimated:false completion:dismissedBlock];
        }
        else
        {
            [_popoverController dismissPopoverAnimated:false];
            dismissedBlock();
        }
    }
}

- (void)animateSheetViewToPosition:(CGFloat)position velocity:(CGFloat)velocity type:(TGMenuSheetAnimation)type completion:(void (^)(void))completion
{
    CGFloat animationVelocity = position > 0 ? fabs(velocity) / fabs(position - self.view.frame.origin.y) : 0;
    
    void (^changeBlock)(void) = ^
    {
        _containerView.frame = CGRectMake(_containerView.frame.origin.x, position, _containerView.frame.size.width, _containerView.frame.size.height);
        [_sheetView didChangeAbsoluteFrame];
    };
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (completion != nil)
            completion();
    };
    
    if (type == TGMenuSheetAnimationPresent)
    {
        UIViewAnimationOptions options = UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionAllowAnimatedContent;
        if (iosMajorVersion() >= 7)
            options |= 7 << 16;
        [UIView animateWithDuration:0.3 delay:0.0 options:options animations:changeBlock completion:completionBlock];
    }
    else
    {
        CGFloat duration = 0.25;
        if (type == TGMenuSheetAnimationFastDismiss)
            duration = 0.2;
        
        if (iosMajorVersion() >= 7)
        {
            [UIView animateWithDuration:duration delay:0.0 usingSpringWithDamping:1.5 initialSpringVelocity:animationVelocity options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowAnimatedContent animations:changeBlock completion:completionBlock];
        }
        else
        {
            [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionAllowAnimatedContent animations:changeBlock completion:completionBlock];
        }
    }
}

#pragma mark -

- (bool)hasSwipeGesture
{
    return _hasSwipeGesture;
}

- (void)setHasSwipeGesture:(bool)hasSwipeGesture
{
    if (_hasSwipeGesture == hasSwipeGesture)
        return;

    _hasSwipeGesture = hasSwipeGesture;
    [self updateGestureRecognizer];
}

- (void)updateGestureRecognizer
{
    if (_sheetView == nil)
        return;
    
    if (_hasSwipeGesture && [self sizeClass] != UIUserInterfaceSizeClassRegular)
    {
        if (_gestureRecognizer != nil)
        {
            [_sheetView removeGestureRecognizer:_gestureRecognizer];
            _gestureRecognizer = nil;
        }
        
        _gestureRecognizer = [[TGMenuPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        _gestureRecognizer.direction = TGMenuPanDirectionVertical;
        _gestureRecognizer.delegate = self;
        [_sheetView addGestureRecognizer:_gestureRecognizer];
        
        __weak TGMenuSheetController *weakSelf = self;
        _sheetView.handleInternalPan = ^(UIPanGestureRecognizer *gestureRecognizer)
        {
            __strong TGMenuSheetController *strongSelf = weakSelf;
            if (strongSelf != nil)
                [strongSelf handlePan:gestureRecognizer];
        };
    }
    else
    {
        [_sheetView removeGestureRecognizer:_gestureRecognizer];
        _gestureRecognizer = nil;
        
        _sheetView.handleInternalPan = nil;
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
{
    for (TGMenuSheetItemView *itemView in _sheetView.itemViews)
    {
        if ([itemView inhibitPan])
            return false;
    }
    return true;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if (gestureRecognizer == _gestureRecognizer)
    {
        if ([otherGestureRecognizer.view isKindOfClass:[TGMenuSheetCollectionView class]])
        {
            TGMenuSheetCollectionView *collectionView = (TGMenuSheetCollectionView *)otherGestureRecognizer.view;
            return collectionView.allowSimultaneousPan;
        }
        else if ([otherGestureRecognizer.view isKindOfClass:[TGMenuSheetScrollView class]])
        {
            return true;
        }
        
        return false;
    }
    
    return false;
}

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    CGFloat location = [gestureRecognizer locationInView:self.view].y;
    CGFloat offset = location - _gestureStartPosition;
    
    switch (gestureRecognizer.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            _gestureStartPosition = location;
            _gestureActualStartPosition = location;
            CGRect activeRect = [_sheetView activePanRect];
            _shouldPassPanOffset = !CGRectIsNull(activeRect) && (CGRectContainsPoint(activeRect, CGPointMake(self.view.frame.size.width / 2.0f, _gestureStartPosition)));
        }
            break;
            
        case UIGestureRecognizerStateChanged:
        {
            bool shouldPan = _shouldPassPanOffset && [_sheetView passPanOffset:offset];
            if (!shouldPan)
            {
                _wasPanning = false;
                [self applySheetOffset:0];
            }
            else
            {
                if (!_wasPanning)
                {
                    _gestureStartPosition = location;
                    _wasPanning = true;
                    offset = 0;
                }
            }
            
            if (!_shouldPassPanOffset || shouldPan)
                [self applySheetOffset:[self swipeOffsetForOffset:offset]];
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        {
            CGFloat velocity = [gestureRecognizer velocityInView:self.view].y;
            bool allowDismissal = !_shouldPassPanOffset || _wasPanning;
            
            if (velocity > 200.0f && allowDismissal)
            {
                [self setDimViewHidden:true animated:true];
                [self animateSheetViewToPosition:_sheetView.menuHeight velocity:velocity type:TGMenuSheetAnimationDismiss completion:^
                {
                    [self dismissAnimated:false];
                }];
            }
            else
            {
                [self animateSheetViewToPosition:0 velocity:0 type:TGMenuSheetAnimationChange completion:nil];
            }
        }
            break;
            
        case UIGestureRecognizerStateCancelled:
        {
            [self animateSheetViewToPosition:0 velocity:0 type:TGMenuSheetAnimationChange completion:nil];
        }
            break;
            
        default:
            break;
    }
}

- (void)applySheetOffset:(CGFloat)offset
{
    _containerView.frame = CGRectMake(_containerView.frame.origin.x, self.view.frame.origin.y + offset, self.view.frame.size.width, self.view.frame.size.height);
    [_sheetView didChangeAbsoluteFrame];
}

- (CGFloat)swipeOffsetForOffset:(CGFloat)offset
{
    if (offset >= 0)
        return offset;
    
    static CGFloat c = 0.1f;
    static CGFloat d = 300.0f;
    
    return (1.0f - (1.0f / ((offset * c / d) + 1.0f))) * d;
}

- (CGFloat)clampVelocity:(CGFloat)velocity
{
    CGFloat value = velocity < 0.0f ? -velocity : velocity;
    value = MIN(30.0f, 0.0f);
    return velocity < 0.0f ? -value : value;
}

#pragma mark - Traits

- (void)updateTraitsWithSizeClass:(UIUserInterfaceSizeClass)sizeClass
{
    UIUserInterfaceSizeClass previousClass = [self sizeClass];
    _sizeClass = sizeClass;
    
    [_sheetView updateTraitsWithSizeClass:[self sizeClass]];
    
    if (_presented && previousClass != [self sizeClass])
    {
        switch (sizeClass)
        {
            case UIUserInterfaceSizeClassRegular:
            {
                _dimView.hidden = true;
                
                self.modalPresentationStyle = UIModalPresentationPopover;
                
                [self.view removeFromSuperview];
                [self removeFromParentViewController];
                
                [self _presentPopoverInController:_parentController];
                
                if (iosMajorVersion() >= 7 && [_parentController isKindOfClass:[TGNavigationController class]])
                    ((TGNavigationController *)_parentController).interactivePopGestureRecognizer.enabled = true;
            }
                break;
                
            default:
            {
                _dimView.hidden = false;
                
                [self.presentingViewController dismissViewControllerAnimated:false completion:^
                {
                    self.modalPresentationStyle = UIModalPresentationFullScreen;
                    
                    [_parentController addChildViewController:self];
                    [_parentController.view addSubview:self.view];
                    [self.view setNeedsLayout];
                    
                    if (iosMajorVersion() >= 7 && [_parentController isKindOfClass:[TGNavigationController class]])
                        ((TGNavigationController *)_parentController).interactivePopGestureRecognizer.enabled = false;
                }];
            }
                break;
        }
    }
    
    [self updateGestureRecognizer];
}

#pragma mark -

- (void)viewWillLayoutSubviews
{
    if ([self sizeClass] == UIUserInterfaceSizeClassRegular || [self isInPopover])
    {
        _sheetView.menuWidth = TGMenuSheetPadMenuWidth;
        
        CGSize menuSize = _sheetView.menuSize;
        if (iosMajorVersion() >= 7)
            self.preferredContentSize = menuSize;
        _sheetView.frame = CGRectMake(0, 0, menuSize.width, self.view.frame.size.height);
        _containerView.frame = _sheetView.bounds;
        _dimView.frame = CGRectZero;
    }
    else
    {
        CGSize referenceSize = TGAppDelegateInstance.rootController.applicationBounds.size;
    
        _containerView.frame = CGRectMake(_containerView.frame.origin.x, _containerView.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
        _dimView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);

        CGFloat minSide = MIN(referenceSize.width, referenceSize.height);
        if (self.narrowInLandscape)
            _sheetView.menuWidth = minSide;
        else
            _sheetView.menuWidth = referenceSize.width;
        
        [self repositionMenuWithReferenceSize:referenceSize];
        
        [_sheetView layoutSubviews];
    }
    
    [_sheetView didChangeAbsoluteFrame];
}

- (void)repositionMenuWithReferenceSize:(CGSize)referenceSize
{
    if ([self sizeClass] == UIUserInterfaceSizeClassRegular)
        return;
    
    referenceSize.height = referenceSize.height + TGMenuSheetDefaultStatusBarHeight - [self statusBarHeight];
    
    CGSize menuSize = _sheetView.menuSize;
    _sheetView.frame = CGRectMake((_containerView.frame.size.width - menuSize.width) / 2.0f, referenceSize.height - menuSize.height, menuSize.width, menuSize.height);
}

- (CGFloat)statusBarHeight
{
    CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat statusBarHeight = MIN(statusBarSize.width, statusBarSize.height);
    statusBarHeight = MAX(TGMenuSheetDefaultStatusBarHeight, statusBarHeight);
    
    return statusBarHeight;
}

- (void)setDimViewHidden:(bool)hidden animated:(bool)animated
{
    void (^changeBlock)(void) = ^
    {
        _dimView.alpha = hidden ? 0.0f : 1.0f;
    };
    
    if (animated)
        [UIView animateWithDuration:0.25f animations:changeBlock];
    else
        changeBlock();
}

- (UIViewController *)parentController
{
    return _parentController;
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    NSTimeInterval duration = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] == nil ? 0.3 : [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    int curve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] intValue];
    CGRect screenKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrame = [self.view convertRect:screenKeyboardFrame fromView:nil];

    CGFloat keyboardHeight = (keyboardFrame.size.height <= FLT_EPSILON || keyboardFrame.size.width <= FLT_EPSILON) ? 0.0f : (self.view.frame.size.height - keyboardFrame.origin.y);
    keyboardHeight = MAX(keyboardHeight, 0.0f);
    
    if (self.followsKeyboard)
    {
        if (duration >= FLT_EPSILON)
        {
            [UIView animateWithDuration:duration delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | curve animations:^{
                [self updateKeyboardOffset:keyboardHeight];
            } completion:nil];
        }
        else
        {
            [self updateKeyboardOffset:keyboardHeight];
        }
    }
}

- (void)updateKeyboardOffset:(CGFloat)keyboardOffset
{
    _keyboardOffset = keyboardOffset;
    _sheetView.keyboardOffset = keyboardOffset;
    
    [self repositionMenuWithReferenceSize:TGAppDelegateInstance.rootController.applicationBounds.size];
    [_sheetView layoutSubviews];
}

- (void)setMaxHeight:(CGFloat)maxHeight
{
    _maxHeight = maxHeight;
    _sheetView.maxHeight = maxHeight;
}

- (void)removeFromParentViewController {
    if ([self.parentViewController isKindOfClass:[TGOverlayController class]]) {
        TGOverlayControllerWindow *window = ((TGOverlayController *)self.parentViewController).overlayWindow;
        if (window.dismissByMenuSheet) {
            [window dismiss];
        }
    }
    [super removeFromParentViewController];
}

#pragma mark - 

- (void)setup3DTouch
{
    if (iosMajorVersion() >= 9 && self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)
    {
        for (TGMenuSheetItemView *itemView in _sheetView.itemViews)
        {
            if (itemView.previewSourceView != nil)
                [self registerForPreviewingWithDelegate:itemView sourceView:itemView.previewSourceView];
        }
    }
}

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)__unused popoverPresentationController {
    if ([self.parentViewController isKindOfClass:[TGOverlayController class]]) {
        TGOverlayControllerWindow *window = ((TGOverlayController *)self.parentViewController).overlayWindow;
        if (window.dismissByMenuSheet) {
            [window dismiss];
        }
    } else if ([self.parentController isKindOfClass:[TGOverlayController class]]) {
        TGOverlayControllerWindow *window = ((TGOverlayController *)self.parentController).overlayWindow;
        if (window.dismissByMenuSheet) {
            [window dismiss];
        }
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    for (TGMenuSheetItemView *itemView in _sheetView.itemViews)
    {
        [itemView _willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)__unused fromInterfaceOrientation
{
    for (TGMenuSheetItemView *itemView in _sheetView.itemViews)
    {
        [itemView _didRotateToInterfaceOrientation:[UIApplication sharedApplication].statusBarOrientation];
    }
}

@end


@implementation TGMenuPanGestureRecognizer

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    
    if (self.state != UIGestureRecognizerStateBegan)
        return;
    
    CGPoint velocity = [self velocityInView:self.view];
    switch (self.direction)
    {
        case TGMenuPanDirectionHorizontal:
            if (fabs(velocity.y) > fabs(velocity.x))
                self.state = UIGestureRecognizerStateCancelled;
            break;
            
        case TGMenuPanDirectionVertical:
            if (fabs(velocity.x) > fabs(velocity.y))
                self.state = UIGestureRecognizerStateCancelled;
            break;
            
        default:
            break;
    }
}

@end

