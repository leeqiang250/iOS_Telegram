#import "TGMediaAvatarEditorTransition.h"
#import "TGPhotoEditorController.h"
#import "TGModernGalleryTransitionView.h"

#import "TGImageView.h"

#import "TGPhotoEditorUtils.h"
#import "TGImageUtils.h"
#import "JNWSpringAnimation.h"
#import "TGAnimationBlockDelegate.h"

#import "TGPhotoEditorTabController.h"
#import "TGPhotoAvatarCropView.h"

@interface TGMediaAvatarEditorTransition ()
{
    __weak TGPhotoEditorController *_controller;
    UIView *_curtainView;
    
    UIImageView *_fromTransitionView;
    TGImageView *_toTransitionView;
}
@end

@implementation TGMediaAvatarEditorTransition

- (instancetype)initWithController:(TGPhotoEditorController *)controller fromView:(UIView *)fromView
{
    self = [super init];
    if (self != nil)
    {
        _controller = controller;
        
        _fromTransitionView = [[UIImageView alloc] init];
        
        if ([fromView conformsToProtocol:@protocol(TGModernGalleryTransitionView)])
        {
            id<TGModernGalleryTransitionView> transitionView = (id<TGModernGalleryTransitionView>)fromView;
            _fromTransitionView.image = [transitionView transitionImage];
        }
    }
    return self;
}

- (void)presentAnimated:(bool)__unused animated
{
    _controller.view.backgroundColor = [UIColor clearColor];
    
    UIView *transitionWrapperView = [_controller transitionWrapperView];
    
    _curtainView = [[UIView alloc] initWithFrame:transitionWrapperView.frame];
    _curtainView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _curtainView.alpha = 0.0f;
    _curtainView.backgroundColor = [UIColor blackColor];
    [transitionWrapperView addSubview:_curtainView];
    
    CGRect referenceFrame = self.referenceFrame();
    _fromTransitionView.frame = [transitionWrapperView convertRect:referenceFrame fromView:nil];
    [transitionWrapperView addSubview:_fromTransitionView];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if ([_controller inFormSheet] || [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        orientation = UIInterfaceOrientationPortrait;
    
    CGSize referenceViewSize = [_controller referenceViewSizeForOrientation:orientation];
    CGRect containerFrame = [TGPhotoEditorTabController photoContainerFrameForParentViewFrame:CGRectMake(0, 0, referenceViewSize.width, referenceViewSize.height) toolbarLandscapeSize:_controller.toolbarLandscapeSize orientation:orientation panelSize:0.0f];
    
    CGFloat shortSide = MIN(referenceViewSize.width, referenceViewSize.height);
    CGFloat diameter = shortSide - [TGPhotoAvatarCropView areaInsetSize].width * 2;
    
    CGSize referenceImageSize = self.referenceImageSize();
    CGSize fittedSize = TGScaleToFill(referenceImageSize, CGSizeMake(diameter, diameter));
    
    CGRect fromTransitionFrame = CGRectMake(containerFrame.origin.x + (containerFrame.size.width - fittedSize.width) / 2, containerFrame.origin.y + (containerFrame.size.height - fittedSize.height) / 2, fittedSize.width, fittedSize.height);
    
    [self animateView:_fromTransitionView frameFrom:_fromTransitionView.frame to:[_controller.view convertRect:fromTransitionFrame toView:transitionWrapperView] velocity:CGPointZero rotationFrom:0.0f to:0.0f animatingIn:true completion:^(__unused bool finished)
    {
    }];

    _toTransitionView = [[TGImageView alloc] initWithFrame:fromTransitionFrame];
    [_toTransitionView setSignal:[[[self.referenceScreenImageSignal() deliverOn:[SQueue mainQueue]] filter:^bool(id result)
    {
        return [result isKindOfClass:[UIImage class]];
    }] onNext:^(UIImage *next)
    {
        [_controller _setScreenImage:next];
    }]];
    [transitionWrapperView addSubview:_toTransitionView];
    
    CGSize toSize = TGScaleToFill(referenceImageSize, referenceFrame.size);
    CGRect fromFrame = CGRectMake(referenceFrame.origin.x + (referenceFrame.size.width - toSize.width) / 2.0f, referenceFrame.origin.y + (referenceFrame.size.height - toSize.height) / 2, toSize.width, toSize.height);
    fromFrame = [_controller.view convertRect:fromFrame fromView:nil];

    [self animateView:_toTransitionView frameFrom:fromFrame to:_toTransitionView.frame velocity:CGPointZero rotationFrom:0.0f to:0.0f animatingIn:true completion:^(bool __unused finished)
    {
        _controller.view.backgroundColor = [UIColor blackColor];
        _curtainView.hidden = true;
        
        _fromTransitionView.hidden = true;
        
        [_toTransitionView removeFromSuperview];
        _toTransitionView = nil;
        
        [_controller _finishedTransitionIn];
    }];
    
    _toTransitionView.alpha = 0.0f;
    
    [UIView animateWithDuration:0.07 animations:^
    {
        _toTransitionView.alpha = 1.0f;
    }];
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _curtainView.alpha = 1.0f;
    }];
}

- (void)dismissAnimated:(bool)__unused animated completion:(void (^)(void))completion
{
    _controller.view.backgroundColor = [UIColor clearColor];
    _curtainView.hidden = false;
    
    UIView *transitionWrapperView = [_controller transitionWrapperView];
    
    UIView *fromView = self.repView;
    CGRect outReferenceFrame = self.outReferenceFrame;
    fromView.frame = [transitionWrapperView convertRect:outReferenceFrame fromView:nil];
    [transitionWrapperView addSubview:fromView];
    
    CGRect toFrame = self.referenceFrame();
    [self animateView:fromView frameFrom:fromView.frame to:toFrame velocity:CGPointZero rotationFrom:0.0f to:0.0f animatingIn:false completion:^(__unused bool finished)
    {
        [fromView removeFromSuperview];
    }];
    
    UIView *toView = _fromTransitionView;
    toView.hidden = false;
    toView.frame = outReferenceFrame;
    
    [self animateView:toView frameFrom:toView.frame to:toFrame velocity:CGPointZero rotationFrom:0.0f to:0.0f animatingIn:false completion:^(__unused bool finished)
    {
        if (completion != nil)
            completion();
        
        [toView removeFromSuperview];
    }];
    
    [UIView animateWithDuration:0.1 animations:^
    {
        fromView.alpha = 0.0f;
    }];
    
    [UIView animateWithDuration:0.3f animations:^
    {
        _curtainView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {

    }];
}

- (void)animateView:(UIView *)view frameFrom:(CGRect)fromFrame to:(CGRect)toFrame velocity:(CGPoint)__unused velocity rotationFrom:(CGFloat)fromRotation to:(CGFloat)toRotation animatingIn:(bool)animatingIn completion:(void (^)(bool))completion
{
    if (fromFrame.size.width < FLT_EPSILON || fromFrame.size.height < FLT_EPSILON )
    {
        completion(true);
        return;
    }
    
    if (ABS(toRotation - fromRotation) > FLT_EPSILON)
    {
    }
    
    [CATransaction begin];
    
    CGFloat damping = animatingIn ? 25.0f : 30.0f;
    CGFloat mass = 0.8f;
    CGFloat durationFactor = animatingIn ? 1.8f : 2.0f;
    
    CGPoint fromPosition = CGPointMake(CGRectGetMidX(fromFrame), CGRectGetMidY(fromFrame));
    CGPoint toPosition = CGPointMake(CGRectGetMidX(toFrame), CGRectGetMidY(toFrame));
    JNWSpringAnimation *positionAnimation = [JNWSpringAnimation animationWithKeyPath:@"position"];
    positionAnimation.fromValue = [NSValue valueWithCGPoint:fromPosition];
    positionAnimation.toValue = [NSValue valueWithCGPoint:toPosition];
    positionAnimation.damping = damping;
    positionAnimation.mass = mass;
    positionAnimation.removedOnCompletion = true;
    positionAnimation.fillMode = kCAFillModeForwards;
    positionAnimation.durationFactor = durationFactor;
    TGAnimationBlockDelegate *delegate = [[TGAnimationBlockDelegate alloc] initWithLayer:view.layer];
    delegate.completion = ^(BOOL finished)
    {
        if (completion)
            completion(finished);
    };
    positionAnimation.delegate = delegate;
    view.layer.position = toPosition;
    [view.layer addAnimation:positionAnimation forKey:@"position"];
    
    CGPoint fromScale = CGPointMake(fromFrame.size.width / view.bounds.size.width, fromFrame.size.height/ view.bounds.size.height);
    CGPoint toScale = CGPointMake(toFrame.size.width / view.bounds.size.width, toFrame.size.height / view.bounds.size.height);
    view.layer.transform = CATransform3DMakeScale(toFrame.size.width / view.bounds.size.width, toFrame.size.height / view.bounds.size.height, 1.0f);
    {
        JNWSpringAnimation *scaleAnimation = [JNWSpringAnimation animationWithKeyPath:@"transform.scale.x"];
        scaleAnimation.fromValue = @(fromScale.x);
        scaleAnimation.toValue = @(toScale.x);
        scaleAnimation.damping = damping;
        scaleAnimation.mass = mass;
        scaleAnimation.removedOnCompletion = true;
        scaleAnimation.fillMode = kCAFillModeForwards;
        scaleAnimation.durationFactor = durationFactor;
        [view.layer addAnimation:scaleAnimation forKey:@"transform.scale.x"];
    }
    {
        JNWSpringAnimation *scaleAnimation = [JNWSpringAnimation animationWithKeyPath:@"transform.scale.y"];
        scaleAnimation.fromValue = @(fromScale.y);
        scaleAnimation.toValue = @(toScale.y);
        scaleAnimation.damping = damping;
        scaleAnimation.mass = mass;
        scaleAnimation.removedOnCompletion = true;
        scaleAnimation.fillMode = kCAFillModeForwards;
        scaleAnimation.durationFactor = durationFactor;
        [view.layer addAnimation:scaleAnimation forKey:@"transform.scale.y"];
    }
    
    [CATransaction commit];
}

@end
