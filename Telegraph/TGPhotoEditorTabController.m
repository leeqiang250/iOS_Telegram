#import "TGPhotoEditorTabController.h"
#import "TGPhotoEditorController.h"

#import "TGPhotoEditorAnimation.h"

#import "TGFont.h"

#import "TGPhotoEditorPreviewView.h"
#import "TGPhotoToolbarView.h"

#import "PGPhotoEditorValues.h"
#import "TGVideoEditAdjustments.h"

#import "TGPhotoEditorUtils.h"
#import "TGImageUtils.h"

#import "JNWSpringAnimation.h"
#import "TGAnimationBlockDelegate.h"

const CGFloat TGPhotoEditorPanelSize = 115.0f;
const CGFloat TGPhotoEditorToolbarSize = 49.0f;

@interface TGPhotoEditorTabController ()
{
    bool _noTransitionView;
    CGRect _transitionInReferenceFrame;
    UIView *_transitionInReferenceView;
    UIView *_transitionInParentView;
    CGRect _transitionTargetFrame;
}
@end

@implementation TGPhotoEditorTabController

- (void)handleTabAction:(TGPhotoEditorTab)__unused tab
{
}

- (BOOL)prefersStatusBarHidden
{
    if ([self inFormSheet])
        return false;
    
    return true;
}

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarShouldBeHidden
{
    return true;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (self.beginTransitionIn != nil)
    {
        bool noTransitionView = false;
        CGRect referenceFrame = CGRectZero;
        UIView *parentView = nil;
        UIView *referenceView = self.beginTransitionIn(&referenceFrame, &parentView, &noTransitionView);
        
        [self prepareTransitionInWithReferenceView:referenceView referenceFrame:referenceFrame parentView:parentView noTransitionView:noTransitionView];
        self.beginTransitionIn = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_transitionInPending)
    {
        _transitionInPending = false;
        [self animateTransitionIn];
    }
}

- (void)transitionInWithDuration:(CGFloat)__unused duration
{
    
}

- (void)prepareTransitionInWithReferenceView:(UIView *)referenceView referenceFrame:(CGRect)referenceFrame parentView:(UIView *)parentView noTransitionView:(bool)noTransitionView
{
    CGRect targetFrame = [self _targetFrameForTransitionInFromFrame:referenceFrame];
    
    if (_CGRectEqualToRectWithEpsilon(targetFrame, referenceFrame, FLT_EPSILON))
    {
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
        
        [self _finishedTransitionInWithView:nil];
        
        return;
    }
    
    _transitionInPending = true;
    
    _noTransitionView = noTransitionView;
    if (noTransitionView)
        return;
    
    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    UIView *transitionViewSuperview = nil;
    UIImage *transitionImage = nil;
    if ([referenceView isKindOfClass:[UIImageView class]])
        transitionImage = ((UIImageView *)referenceView).image;
    
    if (transitionImage != nil)
    {
        _transitionView = [[UIImageView alloc] initWithImage:transitionImage];
        _transitionView.clipsToBounds = true;
        _transitionView.contentMode = UIViewContentModeScaleAspectFill;
        transitionViewSuperview = parentView;
    }
    else
    {
        _transitionView = referenceView;
        transitionViewSuperview = self.view;
    }
    
    
    _transitionView.hidden = false;
    _transitionView.frame = referenceFrame;
    _transitionTargetFrame = [self _targetFrameForTransitionInFromFrame:referenceFrame];
    [transitionViewSuperview addSubview:_transitionView];
}

- (void)animateTransitionIn
{    
    if (_noTransitionView)
        return;
    
    _transitionInProgress = true;
    
    POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
    if (self.transitionSpeed > FLT_EPSILON)
        animation.springSpeed = self.transitionSpeed;
    animation.fromValue = [NSValue valueWithCGRect:_transitionView.frame];
    animation.toValue = [NSValue valueWithCGRect:_transitionTargetFrame];
    animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
    {
        _transitionInProgress = false;
        
        UIView *transitionView = _transitionView;
        _transitionView = nil;
        
        if (self.finishedTransitionIn != nil)
        {
            self.finishedTransitionIn();
            self.finishedTransitionIn = nil;
        }
        
        [self _finishedTransitionInWithView:transitionView];
    };
    [_transitionView pop_addAnimation:animation forKey:@"frame"];
}

- (void)prepareForCustomTransitionOut
{
    
}

- (void)transitionOutSwitching:(bool)__unused switching completion:(void (^)(void))__unused completion
{

}

- (void)transitionOutSaving:(bool)saving completion:(void (^)(void))completion
{
    [self transitionOutSwitching:false completion:nil];
    
    CGRect referenceFrame = [self transitionOutReferenceFrame];
    UIView *referenceView = nil;
    UIView *parentView = nil;
    
    CGSize referenceSize = [self referenceViewSize];
    
    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & TGPhotoEditorControllerAvatarIntent)
    {
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            referenceFrame = CGRectMake(referenceSize.height - referenceFrame.size.height - referenceFrame.origin.y,
                                        referenceSize.width - referenceFrame.size.width - referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            referenceFrame = CGRectMake(referenceFrame.origin.y,
                                        referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
    }
    
    if (self.beginTransitionOut != nil)
        referenceView = self.beginTransitionOut(&referenceFrame, &parentView);
    
    if (parentView == nil)
        parentView = referenceView.superview.superview;
    
    if (self.intent & TGPhotoEditorControllerFromCameraIntent && self.intent & TGPhotoEditorControllerAvatarIntent)
    {
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            referenceFrame = CGRectMake(referenceSize.width - referenceFrame.size.height - referenceFrame.origin.y,
                                        referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            referenceFrame = CGRectMake(referenceFrame.origin.y,
                                        referenceSize.height - referenceFrame.size.width - referenceFrame.origin.x,
                                        referenceFrame.size.height, referenceFrame.size.width);
        }
    }
    
    if (saving)
    {
        [self _animatePreviewViewTransitionOutToFrame:CGRectNull saving:saving parentView:parentView completion:^
        {
            if (completion != nil)
                completion();
        }];
    }
    else
    {
        UIView *toTransitionView = nil;
        
        UIImage *transitionImage = nil;
        if ([referenceView isKindOfClass:[UIImageView class]])
            transitionImage = ((UIImageView *)referenceView).image;
        
        if (transitionImage != nil)
        {
            toTransitionView = [[UIImageView alloc] initWithImage:transitionImage];
            toTransitionView.clipsToBounds = true;
            toTransitionView.contentMode = UIViewContentModeScaleAspectFill;
        }
        else
        {
            toTransitionView = [referenceView snapshotViewAfterScreenUpdates:false];
        }
        
        [parentView addSubview:toTransitionView];
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
            orientation = UIInterfaceOrientationPortrait;

        CGRect sourceFrame = [self transitionOutSourceFrameForReferenceFrame:referenceView.frame orientation:orientation];
        CGRect targetFrame = referenceFrame;
        toTransitionView.frame = sourceFrame;
        
        NSMutableSet *animations = [NSMutableSet set];
        void (^onAnimationCompletion)(id) = ^(id object)
        {
            [animations removeObject:object];
            
            if (animations.count == 0)
            {
                [toTransitionView removeFromSuperview];
                
                if (completion != nil)
                    completion();
            }
        };
        
        [animations addObject:@1];
        [self _animatePreviewViewTransitionOutToFrame:targetFrame saving:saving parentView:nil completion:^
        {
            onAnimationCompletion(@1);
        }];
        
        [animations addObject:@2];
        POPSpringAnimation *animation = [TGPhotoEditorAnimation prepareTransitionAnimationForPropertyNamed:kPOPViewFrame];
        if (self.transitionSpeed > FLT_EPSILON)
            animation.springSpeed = self.transitionSpeed;
        animation.fromValue = [NSValue valueWithCGRect:toTransitionView.frame];
        animation.toValue = [NSValue valueWithCGRect:targetFrame];
        animation.completionBlock = ^(__unused POPAnimation *animation, __unused BOOL finished)
        {
            onAnimationCompletion(@2);
        };
        [toTransitionView pop_addAnimation:animation forKey:@"frame"];
    }
}

- (CGRect)transitionOutSourceFrameForReferenceFrame:(CGRect)referenceFrame orientation:(UIInterfaceOrientation)orientation
{
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:self.view.frame toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize];
    CGSize fittedSize = TGScaleToSize(referenceFrame.size, containerFrame.size);
    CGRect sourceFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                    containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                    fittedSize.width,
                                    fittedSize.height);
    
    return sourceFrame;
}

- (void)_animatePreviewViewTransitionOutToFrame:(CGRect)__unused toFrame saving:(bool)__unused saving parentView:(UIView *)__unused parentView completion:(void (^)(void))__unused completion
{
    
}

- (CGRect)_targetFrameForTransitionInFromFrame:(CGRect)fromFrame
{
    CGSize referenceSize = [self referenceViewSize];
    UIInterfaceOrientation orientation = self.interfaceOrientation;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceSize.width, referenceSize.height) toolbarLandscapeSize:self.toolbarLandscapeSize orientation:orientation panelSize:TGPhotoEditorPanelSize];
    CGSize fittedSize = TGScaleToSize(fromFrame.size, containerFrame.size);
    CGRect toFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2,
                                containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2,
                                fittedSize.width,
                                fittedSize.height);
    
    return toFrame;
}

- (void)_finishedTransitionInWithView:(UIView *)transitionView
{
    [transitionView removeFromSuperview];
}

- (bool)inFormSheet
{
    return [(TGViewController *)[self parentViewController] inFormSheet];
}

- (CGSize)referenceViewSize
{
    if (self.parentViewController != nil)
    {
        TGPhotoEditorController *controller = (TGPhotoEditorController *)self.parentViewController;
        return [controller referenceViewSize];
    }

    return CGSizeZero;
}

- (void)animateTransitionOutToRect:(CGRect)__unused fromRect saving:(bool)__unused saving duration:(CGFloat)__unused duration
{
    
}

- (void)prepareTransitionOutSaving:(bool)__unused saving
{
    
}

- (CGRect)transitionOutReferenceFrame
{
    return CGRectZero;
}

- (UIView *)transitionOutReferenceView
{
    return nil;
}

- (UIView *)snapshotView
{
    return nil;
}

- (bool)dismissing
{
    return _dismissing;
}

- (bool)isDismissAllowed
{
    return true;
}

- (id)currentResultRepresentation
{
    return nil;
}

- (void)_updateTabs
{
    if (self.tabsChanged != nil)
        self.tabsChanged();
}

- (TGPhotoEditorTab)activeTab
{
    return TGPhotoEditorNoneTab;
}

- (TGPhotoEditorTab)highlightedTabs
{
    return TGPhotoEditorNoneTab;
}

+ (CGRect)photoContainerFrameForParentViewFrame:(CGRect)parentViewFrame toolbarLandscapeSize:(CGFloat)toolbarLandscapeSize orientation:(UIInterfaceOrientation)orientation panelSize:(CGFloat)panelSize
{
    CGFloat panelToolbarPortraitSize = TGPhotoEditorToolbarSize + panelSize;
    CGFloat panelToolbarLandscapeSize = toolbarLandscapeSize + panelSize;
    
    switch (orientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            return CGRectMake(panelToolbarLandscapeSize, 0, parentViewFrame.size.width - panelToolbarLandscapeSize, parentViewFrame.size.height);
            
        case UIInterfaceOrientationLandscapeRight:
            return CGRectMake(0, 0, parentViewFrame.size.width - panelToolbarLandscapeSize, parentViewFrame.size.height);
            
        default:
            return CGRectMake(0, 0, parentViewFrame.size.width, parentViewFrame.size.height - panelToolbarPortraitSize);
    }
}

+ (TGPhotoEditorTab)highlightedButtonsForEditorValues:(id<TGMediaEditAdjustments>)editorValues forAvatar:(bool)forAvatar
{
    TGPhotoEditorTab highlightedButtons = TGPhotoEditorNoneTab;
    
    if ([editorValues cropAppliedForAvatar:forAvatar])
        highlightedButtons |= TGPhotoEditorCropTab;
    
    if ([editorValues hasPainting])
        highlightedButtons |= TGPhotoEditorPaintTab;
    
    if ([editorValues isKindOfClass:[PGPhotoEditorValues class]])
    {
        if ([(PGPhotoEditorValues *)editorValues toolsApplied])
            highlightedButtons |= TGPhotoEditorToolsTab;
    }
    
    return highlightedButtons;
}

@end
