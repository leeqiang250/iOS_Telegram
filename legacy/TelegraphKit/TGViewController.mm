#import "TGViewController.h"

#import "TGToolbarButton.h"
#import "TGLabel.h"
#import "TGStringUtils.h"
#import "Freedom.h"

#import "TGNavigationController.h"
#import "TGOverlayControllerWindow.h"

#import <QuartzCore/QuartzCore.h>

#import "TGHacks.h"
#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGPopoverController.h"

#import <set>

#import "TGAppDelegate.h"

static __strong NSTimer *autorotationEnableTimer = nil;
static bool autorotationDisabled = false;

static __strong NSTimer *userInteractionEnableTimer = nil;

static std::set<int> autorotationLockIds;

@interface TGViewControllerSizeView : UIView {
    CGSize _validSize;
}

@property (nonatomic, copy) void (^sizeChanged)(CGSize size);

@end

@implementation TGViewControllerSizeView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _validSize = frame.size;
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    if (!CGSizeEqualToSize(_validSize, frame.size)) {
        _validSize = frame.size;
        if (_sizeChanged) {
            _sizeChanged(frame.size);
        }
    }
}

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    
    if (!CGSizeEqualToSize(_validSize, bounds.size)) {
        _validSize = bounds.size;
        if (_sizeChanged) {
            _sizeChanged(bounds.size);
        }
    }
}

@end

@interface UIViewController ()

- (void)setAutomaticallyAdjustsScrollViewInsets:(BOOL)value;

@end

@implementation TGAutorotationLock

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        static int nextId = 1;
        _lockId = nextId++;
        
        int lockId = _lockId;
        
        if ([NSThread isMainThread])
        {
            autorotationLockIds.insert(lockId);
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^
            {
                autorotationLockIds.insert(lockId);
            });
        }
    }
    return self;
}

- (void)dealloc
{
    int lockId = _lockId;
    
    if ([NSThread isMainThread])
    {
        autorotationLockIds.erase(lockId);
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            autorotationLockIds.erase(lockId);
        });
    }
}

@end

@interface TGViewController () <UIPopoverControllerDelegate, UIPopoverPresentationControllerDelegate>
{
    bool _hatTargetNavigationItem;
    
    id<SDisposable> _sizeClassDisposable;
    NSTimeInterval _currentSizeChangeDuration;
}

@property (nonatomic, strong) UIView *viewControllerStatusBarBackgroundView;
@property (nonatomic) UIInterfaceOrientation viewControllerRotatingFromOrientation;

@property (nonatomic, weak) UINavigationItem *targetNavigationItem;
@property (nonatomic, weak) UIViewController *targetNavigationTitleController;

@property (nonatomic, strong) UIBarButtonItem *leftBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *rightBarButtonItem;
@property (nonatomic, strong) NSString *titleText;
@property (nonatomic, strong) UIView *titleView;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

@end

@implementation TGViewController

+ (UIFont *)titleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGBoldSystemFontOfSize(20);
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGBoldSystemFontOfSize(17);
        return font;
    }
}

+ (UIFont *)titleTitleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGBoldSystemFontOfSize(16);
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGBoldSystemFontOfSize(15);
        return font;
    }
}

+ (UIFont *)titleSubtitleFontForStyle:(TGViewControllerStyle)__unused style landscape:(bool)landscape
{
    if (!landscape)
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGSystemFontOfSize(13);
        return font;
    }
    else
    {
        static UIFont *font = nil;
        if (font == nil)
            font = TGSystemFontOfSize(13);
        return font;
    }
}

+ (UIColor *)titleTextColorForStyle:(TGViewControllerStyle)style
{
    if (style == TGViewControllerStyleDefault)
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0xffffff);
        return color;
    }
    else
    {
        static UIColor *color = nil;
        if (color == nil)
            color = UIColorRGB(0xffffff);
        return color;
    }
}

+ (CGSize)screenSize:(UIDeviceOrientation)orientation
{
    CGSize mainScreenSize = TGScreenSize();
    
    CGSize size = CGSizeZero;
    if (UIDeviceOrientationIsPortrait(orientation))
        size = CGSizeMake(mainScreenSize.width, mainScreenSize.height);
    else
        size = CGSizeMake(mainScreenSize.height, mainScreenSize.width);
    return size;
}

+ (CGSize)screenSizeForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    CGSize mainScreenSize = TGScreenSize();
    
    CGSize size = CGSizeZero;
    if (UIInterfaceOrientationIsPortrait(orientation))
        size = CGSizeMake(mainScreenSize.width, mainScreenSize.height);
    else
        size = CGSizeMake(mainScreenSize.height, mainScreenSize.width);
    return size;
}

+ (bool)isWidescreen
{
    static bool isWidescreenInitialized = false;
    static bool isWidescreen = false;
    
    if (!isWidescreenInitialized)
    {
        isWidescreenInitialized = true;
        
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        if (screenSize.width > 321 || screenSize.height > 481)
            isWidescreen = true;
    }
    
    return isWidescreen;
}

+ (bool)hasLargeScreen
{
    static bool value = false;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        CGFloat side = MAX(screenSize.width, screenSize.height);
        value = side >= 667.0f - FLT_EPSILON;
    });
    
    return value;
}

+ (bool)hasVeryLargeScreen {
    static bool value = false;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
        CGFloat side = MAX(screenSize.width, screenSize.height);
        value = side >= 736 - FLT_EPSILON;
    });
    
    return value;
}

+ (bool)hasTallScreen {
    static bool value = false;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
      {
          CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:UIInterfaceOrientationPortrait];
          CGFloat side = MAX(screenSize.width, screenSize.height);
          value = side >= 812 - FLT_EPSILON;
      });
    
    return value;
}

+ (void)disableAutorotation
{
    autorotationDisabled = true;
}

+ (void)enableAutorotation
{
    autorotationDisabled = false;
}

+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval
{
    [self disableAutorotationFor:timeInterval reentrant:false];
}

+ (void)disableAutorotationFor:(NSTimeInterval)timeInterval reentrant:(bool)reentrant
{
    if (reentrant && autorotationDisabled)
        return;
    
    autorotationDisabled = true;
    
    if (autorotationEnableTimer != nil)
    {
        if ([autorotationEnableTimer isValid])
        {
            [autorotationEnableTimer invalidate];
        }
        autorotationEnableTimer = nil;
    }
    
    autorotationEnableTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval] interval:0 target:self selector:@selector(enableTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:autorotationEnableTimer forMode:NSRunLoopCommonModes];
}

+ (bool)autorotationAllowed
{
    return !autorotationDisabled && autorotationLockIds.empty();
}

+ (void)attemptAutorotation
{
    if ([TGViewController autorotationAllowed])
    {
        [UIViewController attemptRotationToDeviceOrientation];
    }
}

+ (void)enableTimerEvent
{
    autorotationDisabled = false;

    [self attemptAutorotation];
    
    autorotationEnableTimer = nil;
}

+ (void)disableUserInteractionFor:(NSTimeInterval)timeInterval
{
    if (userInteractionEnableTimer != nil)
    {
        if ([userInteractionEnableTimer isValid])
        {
            [userInteractionEnableTimer invalidate];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
        }
        userInteractionEnableTimer = nil;
    }
    
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    
    userInteractionEnableTimer = [[NSTimer alloc] initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:timeInterval] interval:0 target:self selector:@selector(userInteractionEnableTimerEvent) userInfo:nil repeats:false];
    [[NSRunLoop mainRunLoop] addTimer:userInteractionEnableTimer forMode:NSRunLoopCommonModes];
}

+ (void)setUseExperimentalRTL:(bool)useExperimentalRTL
{
    NSString *documentsDirectory = [TGAppDelegate documentsPath];
    uint8_t value = useExperimentalRTL ? 1 : 0;
    [[[NSData alloc] initWithBytes:&value length:1] writeToFile:[documentsDirectory stringByAppendingPathComponent:@"rtl.state"] atomically:false];
}

+ (bool)useExperimentalRTL
{

    return false;
}

+ (void)userInteractionEnableTimerEvent
{
    [[UIApplication sharedApplication] endIgnoringInteractionEvents];
    
    userInteractionEnableTimer = nil;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self)
    {
        [self _commonViewControllerInit];
    }
    return self;
}

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        [self _commonViewControllerInit];
    }
    return self;
}

- (void)_commonViewControllerInit
{
    self.wantsFullScreenLayout = true;
    self.automaticallyManageScrollViewInsets = true;
    self.autoManageStatusBarBackground = true;
    __block bool initializedSizeClass = false;
    _currentSizeClass = UIUserInterfaceSizeClassCompact;
    
    __weak TGViewController *weakSelf = self;
    _sizeClassDisposable = [[TGAppDelegateInstance.rootController sizeClass] startWithNext:^(NSNumber *next) {
        __strong TGViewController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            if (strongSelf->_currentSizeClass != [next integerValue]) {
                strongSelf->_currentSizeClass = (UIUserInterfaceSizeClass)[next integerValue];
                if (initializedSizeClass) {
                    [strongSelf updateSizeClass];
                }
            }
        }
    }];
    initializedSizeClass = true;
    
    if ([self respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)])
        [self setAutomaticallyAdjustsScrollViewInsets:false];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerStatusBarWillChangeFrame:) name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerKeyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewControllerKeyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc
{
    [_sizeClassDisposable dispose];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillChangeStatusBarFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    
    [_associatedPopoverController dismissPopoverAnimated:false];
}

- (NSMutableArray *)associatedWindowStack
{
    if (_associatedWindowStack == nil)
        _associatedWindowStack = [[NSMutableArray alloc] init];
    
    return _associatedWindowStack;
}

- (void)setAssociatedPopoverController:(TGPopoverController *)associatedPopoverController
{
    if (_associatedPopoverController != nil)
        [_associatedPopoverController dismissPopoverAnimated:false];
    
    _associatedPopoverController = associatedPopoverController;
    _associatedPopoverController.delegate = self;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (popoverController == _associatedPopoverController)
    {
        _associatedPopoverController = nil;
    }
}

- (UINavigationController *)navigationController
{
    UIViewController *customParentViewController = _customParentViewController;
    if (customParentViewController.navigationController != nil)
        return customParentViewController.navigationController;
    return [super navigationController];
}

- (bool)shouldIgnoreStatusBar
{
    if (_currentSizeClass != UIUserInterfaceSizeClassCompact) {
        if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        {
            switch (((TGNavigationController *)self.navigationController).presentationStyle)
            {
                case TGNavigationControllerPresentationStyleRootInPopover:
                case TGNavigationControllerPresentationStyleChildInPopover:
                case TGNavigationControllerPresentationStyleInFormSheet:
                    return true;
                default:
                    break;
            }
        }
    }
    
    return false;
}

- (bool)shouldIgnoreNavigationBar
{
    if ([self.navigationController isKindOfClass:[TGNavigationController class]])
    {
        switch (((TGNavigationController *)self.navigationController).presentationStyle)
        {
            case TGNavigationControllerPresentationStyleRootInPopover:
                return iosMajorVersion() < 8;
            default:
                break;
        }
    }
    
    return false;
}

- (bool)inPopover
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        return false;
    else
    {
        if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        {
            switch (((TGNavigationController *)self.navigationController).presentationStyle)
            {
                case TGNavigationControllerPresentationStyleRootInPopover:
                case TGNavigationControllerPresentationStyleChildInPopover:
                    return true;
                default:
                    break;
            }
        }
        
        return false;
    }
}

- (bool)inFormSheet
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        return false;
    else
    {
        if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        {
            switch (((TGNavigationController *)self.navigationController).presentationStyle)
            {
                case TGNavigationControllerPresentationStyleInFormSheet:
                    return true;
                default:
                    break;
            }
        }
        
        return self.modalPresentationStyle == UIModalPresentationFormSheet;
    }
}

- (bool)willCaptureInputShortly
{
    return false;
}

- (UIPopoverController *)popoverController
{
    if ([self.navigationController isKindOfClass:[TGNavigationController class]])
    {
        return ((TGNavigationController *)self.navigationController).parentPopoverController;
    }
    
    return nil;
}

- (void)acquireRotationLock
{
    if (_autorotationLock == nil)
        _autorotationLock = [[TGAutorotationLock alloc] init];
}

- (void)releaseRotationLock
{
    _autorotationLock = nil;
}

- (void)localizationUpdated
{
}

+ (int)preferredAnimationCurve
{
    return iosMajorVersion() >= 7 ? 7 : 0;
}

- (CGSize)referenceViewSizeForOrientation:(UIInterfaceOrientation)orientation
{
    if ([self inFormSheet])
        return CGSizeMake(540.0f, 620.0f);
    else if ([self inPopover])
        return CGSizeMake(320.0f, 528.0f);
    else
        return [TGViewController screenSizeForInterfaceOrientation:orientation];
}

- (UIInterfaceOrientation)currentInterfaceOrientation
{
    if ([self inFormSheet])
        return UIInterfaceOrientationPortrait;
    return (self.view.bounds.size.width >= TGScreenSize().height - FLT_EPSILON) ? UIInterfaceOrientationLandscapeLeft : UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate
{
    if (self.presentedViewController != nil && ![self.presentedViewController shouldAutorotate])
        return false;
    
    return [TGViewController autorotationAllowed];
}

- (void)loadView
{
    [super loadView];
    
    TGViewControllerSizeView *sizeView = [[TGViewControllerSizeView alloc] initWithFrame:self.view.bounds];
    sizeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    __weak TGViewController *weakSelf = self;
    sizeView.sizeChanged = ^(CGSize size) {
        __strong TGViewController *strongSelf = weakSelf;
        if (strongSelf != nil) {
            [strongSelf layoutControllerForSize:size duration:strongSelf->_currentSizeChangeDuration];
        }
    };
    sizeView.userInteractionEnabled = false;
    sizeView.hidden = true;
    [self.view addSubview:sizeView];
 
    if ([TGViewController useExperimentalRTL] && _customParentViewController == nil && !_doNotFlipIfRTL)
        ((UIView *)self.view).transform = CGAffineTransformMakeScale(-1.0f, 1.0f);
}

- (void)viewDidLoad
{
    if (_autoManageStatusBarBackground && [self preferredStatusBarStyle] == UIStatusBarStyleDefault && ![self shouldIgnoreStatusBar])
    {
        _viewControllerStatusBarBackgroundView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 20)];
        _viewControllerStatusBarBackgroundView.userInteractionEnabled = false;
        _viewControllerStatusBarBackgroundView.layer.zPosition = 1000;
        _viewControllerStatusBarBackgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _viewControllerStatusBarBackgroundView.backgroundColor = [UIColor blackColor];
        if (iosMajorVersion() < 7)
            [self.view addSubview:_viewControllerStatusBarBackgroundView];
    }
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    _viewControllerIsAnimatingAppearanceTransition = true;
    _viewControllerIsAppearing = true;
    //_viewControllerHasEverAppeared = true;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad && iosMajorVersion() < 7)
    {
        CGSize size = CGSizeMake(320, 491);
        self.contentSizeForViewInPopover = size;
    }
    
    if ([self.navigationController isKindOfClass:[TGNavigationController class]])
        [(TGNavigationController *)self.navigationController setupNavigationBarForController:self animated:animated];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation force:false notify:true];
    
    [self adjustToInterfaceOrientation:self.interfaceOrientation];
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    _viewControllerIsAppearing = false;
    _viewControllerIsAnimatingAppearanceTransition = false;
    _viewControllerHasEverAppeared = true;
    
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    _viewControllerIsDisappearing = true;
    _viewControllerIsAnimatingAppearanceTransition = true;
    
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    _viewControllerIsDisappearing = false;
    _viewControllerIsAnimatingAppearanceTransition = false;
    
    [super viewDidDisappear:animated];
}

- (void)_adjustControllerInsetForRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    float additionalKeyboardHeight = [self _keyboardAdditionalDeltaHeightWhenRotatingFrom:_viewControllerRotatingFromOrientation toOrientation:toInterfaceOrientation];
    
    [self _updateControllerInsetForOrientation:toInterfaceOrientation statusBarHeight:[TGHacks statusBarHeightForOrientation:toInterfaceOrientation] keyboardHeight:[self _currentKeyboardHeight:toInterfaceOrientation] + additionalKeyboardHeight force:false notify:true];
}

- (UIEdgeInsets)controllerInsetForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    CGFloat statusBarHeight = [TGHacks statusBarHeightForOrientation:orientation];
    CGFloat keyboardHeight = [self _currentKeyboardHeight:orientation];
    
    CGFloat navigationBarHeight = ([self navigationBarShouldBeHidden] || [self shouldIgnoreNavigationBar]) ? 0 : [self navigationBarHeightForInterfaceOrientation:orientation];
    UIEdgeInsets edgeInset = UIEdgeInsetsMake(([self shouldIgnoreStatusBar] ? 0.0f : statusBarHeight) + navigationBarHeight, 0, 0, 0);
    
    edgeInset.left += _parentInsets.left;
    edgeInset.top += _parentInsets.top;
    edgeInset.right += _parentInsets.right;
    edgeInset.bottom += _parentInsets.bottom;
    
    if ([self.parentViewController isKindOfClass:[UITabBarController class]])
        edgeInset.bottom += [self tabBarHeight];
    
    if (!_ignoreKeyboardWhenAdjustingScrollViewInsets)
        edgeInset.bottom = MAX(edgeInset.bottom, keyboardHeight);
    
    edgeInset.left += _explicitTableInset.left;
    edgeInset.right += _explicitTableInset.right;
    edgeInset.top += _explicitTableInset.top;
    edgeInset.bottom += _explicitTableInset.bottom;
    
    return edgeInset;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{   
    _viewControllerIsChangingInterfaceOrientation = true;
    _viewControllerRotatingFromOrientation = self.interfaceOrientation;
    _currentSizeChangeDuration = duration;
    
    if (_adjustControllerInsetWhenStartingRotation)
        [self _adjustControllerInsetForRotationToInterfaceOrientation:toInterfaceOrientation];
    
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self adjustToInterfaceOrientation:toInterfaceOrientation];
    
    if (!_adjustControllerInsetWhenStartingRotation)
        [self _adjustControllerInsetForRotationToInterfaceOrientation:toInterfaceOrientation];
    
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    //TGLog(@"Did rotate");
    _viewControllerIsChangingInterfaceOrientation = false;
    _currentSizeChangeDuration = 0.0;
    
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
}

- (CGFloat)_currentKeyboardHeight:(UIInterfaceOrientation)orientation
{
    if ([self inPopover])
        return 0.0f;
    
    if ([self isViewLoaded] && !_viewControllerHasEverAppeared && ([self findFirstResponder:self.view] == nil && ![self willCaptureInputShortly]))
        return 0.0f;
    
    if ([TGHacks isKeyboardVisible])
        return [TGHacks keyboardHeightForOrientation:orientation];
    
    return 0.0f;
}

- (float)_keyboardAdditionalDeltaHeightWhenRotatingFrom:(UIInterfaceOrientation)fromOrientation toOrientation:(UIInterfaceOrientation)toOrientation
{
    if ([TGHacks isKeyboardVisible])
    {
        if (UIInterfaceOrientationIsPortrait(fromOrientation) != UIInterfaceOrientationIsPortrait(toOrientation))
        {
        }
    }
    
    return 0.0f;
}

- (CGFloat)_currentStatusBarHeight
{
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    CGFloat minStatusBarHeight = [self prefersStatusBarHidden] ? 0.0f : 20.0f;
    CGFloat statusBarHeight = MAX(minStatusBarHeight, MIN(statusBarFrame.size.width, statusBarFrame.size.height));
    return MIN(40.0f, statusBarHeight + _additionalStatusBarHeight);
}

- (void)viewControllerStatusBarWillChangeFrame:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation)
    {
        CGRect statusBarFrame = [[[notification userInfo] objectForKey:UIApplicationStatusBarFrameUserInfoKey] CGRectValue];
        CGFloat minStatusBarHeight = [self prefersStatusBarHidden] ? 0.0f : 20.0f;
        CGFloat statusBarHeight = MAX(minStatusBarHeight, MIN(statusBarFrame.size.width, statusBarFrame.size.height));
        statusBarHeight = MIN(40.0f, statusBarHeight + _additionalStatusBarHeight);
        
        CGFloat keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
        
        [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
        } completion:nil];
    }
}

- (UIView *)findFirstResponder:(UIView *)view
{
    if ([view isFirstResponder])
        return view;
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = [self findFirstResponder:subview];
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (void)viewControllerKeyboardWillChangeFrame:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation && ![self inPopover])
    {
        CGFloat statusBarHeight = [self _currentStatusBarHeight];
        
        CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
        CGFloat keyboardHeight = MIN(keyboardFrame.size.height, keyboardFrame.size.width);
        double duration = ([[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]);
        
        if ([self isViewLoaded] && !_viewControllerHasEverAppeared && ([self findFirstResponder:self.view] == nil && ![self willCaptureInputShortly]))
        {
            
        }
        else if (_viewControllerIsAnimatingAppearanceTransition || !_viewControllerHasEverAppeared)
        {
            [UIView performWithoutAnimation:^
            {
                [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
            }];
        }
        else
        {
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
            } completion:nil];
        }
    }
}

- (void)viewControllerKeyboardWillHide:(NSNotification *)notification
{
    if (!_viewControllerIsChangingInterfaceOrientation && ![self inPopover])
    {
        CGFloat statusBarHeight = [self _currentStatusBarHeight];
        
        float keyboardHeight = 0.0f;
        double duration = ([[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]);
        
        if ([self isViewLoaded] && !_viewControllerHasEverAppeared && [self findFirstResponder:self.view] == nil && ![self willCaptureInputShortly])
        {
            
        }
        else if (_viewControllerIsAnimatingAppearanceTransition || !_viewControllerHasEverAppeared)
        {
            [UIView performWithoutAnimation:^
            {
                [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
            }];
        }
        else
        {
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
            } completion:nil];
        }
    }
}

#pragma mark -

- (void)adjustNavigationItem:(UIInterfaceOrientation)__unused orientation
{
}

#pragma mark -

- (UIBarStyle)requiredNavigationBarStyle
{
    return UIBarStyleDefault;
}

- (bool)navigationBarHasAction
{
    return false;
}

- (void)navigationBarAction
{
}

- (void)navigationBarSwipeDownAction
{
}

- (bool)statusBarShouldBeHidden
{
    return false;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (!TGAppDelegateInstance.rootController.callStatusBarHidden)
        return UIStatusBarStyleLightContent;
    else
        return UIStatusBarStyleDefault;
}

- (void)setNeedsStatusBarAppearanceUpdate
{
    if (iosMajorVersion() < 7)
        return;
    
    [super setNeedsStatusBarAppearanceUpdate];
    
    if (iosMajorVersion() < 8)
        return;
    
    UIWindow *lastWindow = [UIApplication sharedApplication].windows.lastObject;
    if (lastWindow != self.view.window && [lastWindow isKindOfClass:[TGOverlayControllerWindow class]])
    {
        static void (*methodImpl)(id, SEL) = NULL;
        static dispatch_once_t onceToken;
        static SEL methodSelector = NULL;
        dispatch_once(&onceToken, ^
        {
            methodImpl = (void (*)(id, SEL))freedomImpl([UIApplication sharedApplication], 0xa7a8dd8a, NULL);
        });
        
        if (methodImpl != NULL)
            methodImpl([UIApplication sharedApplication], methodSelector);
    }
}

- (void)adjustToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    [self adjustNavigationItem:orientation];
}

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset
{
    [self setExplicitTableInset:explicitTableInset scrollIndicatorInset:_explicitScrollIndicatorInset];
}

- (void)setExplicitScrollIndicatorInset:(UIEdgeInsets)explicitScrollIndicatorInset
{
    [self setExplicitTableInset:_explicitTableInset scrollIndicatorInset:explicitScrollIndicatorInset];
}

- (void)setAdditionalNavigationBarHeight:(CGFloat)additionalNavigationBarHeight
{
    _additionalNavigationBarHeight = additionalNavigationBarHeight;
    
    CGFloat statusBarHeight = [self _currentStatusBarHeight];
    CGFloat keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
}

- (void)setAdditionalStatusBarHeight:(CGFloat)additionalStatusBarHeight
{
    _additionalStatusBarHeight = additionalStatusBarHeight;
    
    CGFloat statusBarHeight = [self _currentStatusBarHeight];
    CGFloat keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
}

- (void)setExplicitTableInset:(UIEdgeInsets)explicitTableInset scrollIndicatorInset:(UIEdgeInsets)scrollIndicatorInset
{
    _explicitTableInset = explicitTableInset;
    _explicitScrollIndicatorInset = scrollIndicatorInset;
    
    CGFloat statusBarHeight = [self _currentStatusBarHeight];
    CGFloat keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    [self _updateControllerInsetForOrientation:self.interfaceOrientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:false notify:true];
}

- (bool)_updateControllerInset:(bool)force
{
    return [self _updateControllerInsetForOrientation:self.interfaceOrientation force:force notify:true];
}

- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation force:(bool)force notify:(bool)notify
{
    CGFloat statusBarHeight = [self _currentStatusBarHeight];
    CGFloat keyboardHeight = [self _currentKeyboardHeight:self.interfaceOrientation];
    
    return [self _updateControllerInsetForOrientation:orientation statusBarHeight:statusBarHeight keyboardHeight:keyboardHeight force:(bool)force notify:notify];
}

- (CGFloat)navigationBarHeightForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    static CGFloat portraitHeight = 44.0f;
    static CGFloat landscapeHeight = 32.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        CGFloat widescreenWidth = MAX(screenSize.width, screenSize.height);
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && ABS(widescreenWidth - 736) > FLT_EPSILON)
        {
            portraitHeight = 44.0f;
            landscapeHeight = 32.0f;
        }
        else
        {
            portraitHeight = 44.0f;
            landscapeHeight = 44.0f;
        }
    });
    
    return (UIInterfaceOrientationIsPortrait(orientation) ? portraitHeight : landscapeHeight) + _additionalNavigationBarHeight;
}

- (CGFloat)tabBarHeight
{
    static CGFloat height = 0.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            height = 49.0f;
        else
            height = 56.0f;
    });
    
    return height;
}

- (bool)_updateControllerInsetForOrientation:(UIInterfaceOrientation)orientation statusBarHeight:(CGFloat)statusBarHeight keyboardHeight:(CGFloat)keyboardHeight force:(bool)force notify:(bool)notify
{
    CGFloat navigationBarHeight = ([self navigationBarShouldBeHidden] || [self shouldIgnoreNavigationBar]) ? 0 : [self navigationBarHeightForInterfaceOrientation:orientation];
    
    UIEdgeInsets edgeInset = UIEdgeInsetsMake(([self shouldIgnoreStatusBar] ? 0.0f : statusBarHeight) + navigationBarHeight, 0, 0, 0);
    
    edgeInset.left += _parentInsets.left;
    edgeInset.top += _parentInsets.top;
    edgeInset.right += _parentInsets.right;
    edgeInset.bottom += _parentInsets.bottom;
    
    if ([self.parentViewController isKindOfClass:[UITabBarController class]])
        edgeInset.bottom += [self tabBarHeight];
    
    if (!_ignoreKeyboardWhenAdjustingScrollViewInsets)
        edgeInset.bottom = MAX(edgeInset.bottom, keyboardHeight);
    
    UIEdgeInsets previousInset = _controllerInset;
    UIEdgeInsets previousCleanInset = _controllerCleanInset;
    UIEdgeInsets previousIndicatorInset = _controllerScrollInset;
    
    UIEdgeInsets scrollEdgeInset = edgeInset;
    scrollEdgeInset.left += _explicitScrollIndicatorInset.left;
    scrollEdgeInset.right += _explicitScrollIndicatorInset.right;
    scrollEdgeInset.top += _explicitScrollIndicatorInset.top;
    scrollEdgeInset.bottom += _explicitScrollIndicatorInset.bottom;
    
    UIEdgeInsets cleanInset = edgeInset;
    
    edgeInset.left += _explicitTableInset.left;
    edgeInset.right += _explicitTableInset.right;
    edgeInset.top += _explicitTableInset.top;
    edgeInset.bottom += _explicitTableInset.bottom;
    
    if (force || !UIEdgeInsetsEqualToEdgeInsets(previousInset, edgeInset) || !UIEdgeInsetsEqualToEdgeInsets(previousIndicatorInset, scrollEdgeInset) || !UIEdgeInsetsEqualToEdgeInsets(previousCleanInset, cleanInset))
    {
        _controllerInset = edgeInset;
        _controllerCleanInset = cleanInset;
        _controllerScrollInset = scrollEdgeInset;
        _controllerStatusBarHeight = statusBarHeight;
        
        if (notify)
            [self controllerInsetUpdated:previousInset];
        
        return true;
    }
    
    return false;
}

- (void)_autoAdjustInsetsForScrollView:(UIScrollView *)scrollView previousInset:(UIEdgeInsets)previousInset
{
    CGPoint contentOffset = scrollView.contentOffset;
    
    UIEdgeInsets finalInset = self.controllerInset;
    
    scrollView.contentInset = finalInset;
    scrollView.scrollIndicatorInsets = self.controllerScrollInset;

    if (!UIEdgeInsetsEqualToEdgeInsets(previousInset, UIEdgeInsetsZero))
    {
        CGFloat maxOffset = scrollView.contentSize.height - (scrollView.frame.size.height - finalInset.bottom);
        
        if (![self shouldAdjustScrollViewInsetsForInversedLayout])
            contentOffset.y += previousInset.top - finalInset.top;
        
        contentOffset.y = MAX(-finalInset.top, MIN(contentOffset.y, maxOffset));
        [scrollView setContentOffset:contentOffset animated:false];
    }
    else if (contentOffset.y < finalInset.top)
    {
        contentOffset.y = -finalInset.top;
        [scrollView setContentOffset:contentOffset animated:false];
    }
    
    
}

- (bool)shouldAdjustScrollViewInsetsForInversedLayout
{
    return false;
}

- (void)controllerInsetUpdated:(UIEdgeInsets)previousInset
{
    if (self.isViewLoaded)
    {
        if (_automaticallyManageScrollViewInsets)
        {
            if (_scrollViewsForAutomaticInsetsAdjustment != nil)
            {
                for (UIScrollView *scrollView in _scrollViewsForAutomaticInsetsAdjustment)
                {
                    [self _autoAdjustInsetsForScrollView:scrollView previousInset:previousInset];
                }
            }
            else
            {
                for (UIView *view in self.view.subviews)
                {
                    if ([view isKindOfClass:[UIScrollView class]])
                    {
                        [self _autoAdjustInsetsForScrollView:(UIScrollView *)view previousInset:previousInset];
                        
                        break;
                    }
                }
            }
        }
    }
}

- (BOOL)prefersStatusBarHidden
{
    return false;
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden animated:(BOOL)animated
{
    [self setNavigationBarHidden:navigationBarHidden withAnimation:animated ? TGViewControllerNavigationBarAnimationSlide : TGViewControllerNavigationBarAnimationNone];
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation
{
    [self setNavigationBarHidden:navigationBarHidden withAnimation:animation duration:0.3f];
}

- (void)setNavigationBarHidden:(bool)navigationBarHidden withAnimation:(TGViewControllerNavigationBarAnimation)animation duration:(NSTimeInterval)duration
{
    if (navigationBarHidden != self.navigationController.navigationBarHidden || navigationBarHidden != self.navigationBarShouldBeHidden)
    {
        self.navigationBarShouldBeHidden = navigationBarHidden;
        
        if (animation == TGViewControllerNavigationBarAnimationFade)
        {
            if (navigationBarHidden != self.navigationController.navigationBarHidden)
            {
                if (!navigationBarHidden)
                {
                    [self.navigationController setNavigationBarHidden:false animated:false];
                    self.navigationController.navigationBar.alpha = 0.0f;
                }
                [UIView animateWithDuration:duration animations:^
                {
                    self.navigationController.navigationBar.alpha = navigationBarHidden ? 0.0f : 1.0f;
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        if (navigationBarHidden)
                        {
                            self.navigationController.navigationBar.alpha = 1.0f;
                            [self.navigationController setNavigationBarHidden:true animated:false];
                        }
                    }
                }];
            }
        }
        else if (animation == TGViewControllerNavigationBarAnimationSlideFar)
        {
            if (navigationBarHidden != self.navigationController.navigationBarHidden)
            {
                CGFloat barHeight = [self navigationBarHeightForInterfaceOrientation:self.interfaceOrientation];
                CGFloat statusBarHeight = [TGHacks statusBarHeightForOrientation:self.interfaceOrientation];
                
                CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:self.interfaceOrientation];
                
                if (!navigationBarHidden)
                {
                    [self.navigationController setNavigationBarHidden:false animated:false];
                    self.navigationController.navigationBar.frame = CGRectMake(0, -barHeight, screenSize.width, barHeight);
                }
                
                [UIView animateWithDuration:duration delay:0 options:0 animations:^
                {
                    if (navigationBarHidden)
                        self.navigationController.navigationBar.frame = CGRectMake(0, -barHeight, screenSize.width, barHeight);
                    else
                        self.navigationController.navigationBar.frame = CGRectMake(0, statusBarHeight, screenSize.width, barHeight);
                } completion:^(BOOL finished)
                {
                    if (finished)
                    {
                        if (navigationBarHidden)
                            [self.navigationController setNavigationBarHidden:true animated:false];
                    }
                }];
            }
        }
        else
        {
            [self.navigationController setNavigationBarHidden:navigationBarHidden animated:animation == TGViewControllerNavigationBarAnimationSlide];
        }
        
        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration delay:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            [self _updateControllerInset:false];
        } completion:nil];
    }
}

- (CGFloat)statusBarBackgroundAlpha
{
    return _viewControllerStatusBarBackgroundView.alpha;
}

- (UIView *)statusBarBackgroundView
{
    return _viewControllerStatusBarBackgroundView;
}

- (void)setStatusBarBackgroundAlpha:(float)alpha
{
    _viewControllerStatusBarBackgroundView.alpha = alpha;
}

- (void)setTargetNavigationItem:(UINavigationItem *)targetNavigationItem titleController:(UIViewController *)titleController
{
    bool updated = _targetNavigationItem != targetNavigationItem || _targetNavigationTitleController != titleController;
    _targetNavigationItem = targetNavigationItem;
    _targetNavigationTitleController = titleController;
    _hatTargetNavigationItem = true;
    
    if (targetNavigationItem != nil && updated)
    {
        [[self _currentNavigationItem] setLeftBarButtonItem:_leftBarButtonItem animated:false];
        [[self _currentNavigationItem] setRightBarButtonItem:_rightBarButtonItem animated:false];
        [[self _currentNavigationItem] setTitle:_titleText];
        [[self _currentTitleController] setTitle:_titleText];
        [[self _currentNavigationItem] setTitleView:_titleView];
    }
}

- (UINavigationItem *)_currentNavigationItem
{
    return _hatTargetNavigationItem ? _targetNavigationItem : self.navigationItem;
}

- (UIViewController *)_currentTitleController
{
    return _hatTargetNavigationItem ? _targetNavigationTitleController : self;
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem
{
    [self setLeftBarButtonItem:leftBarButtonItem animated:false];
}

- (void)setLeftBarButtonItem:(UIBarButtonItem *)leftBarButtonItem animated:(BOOL)animated
{
    _leftBarButtonItem = leftBarButtonItem;
    [[self _currentNavigationItem] setLeftBarButtonItem:leftBarButtonItem animated:animated];
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem
{
    [self setRightBarButtonItem:rightBarButtonItem animated:false];
}

- (void)setRightBarButtonItem:(UIBarButtonItem *)rightBarButtonItem animated:(BOOL)animated
{
    _rightBarButtonItem = rightBarButtonItem;
    [[self _currentNavigationItem] setRightBarButtonItem:rightBarButtonItem animated:animated];
}

- (void)setTitleText:(NSString *)titleText
{
    _titleText = titleText;
    [[self _currentNavigationItem] setTitle:titleText];
    [[self _currentTitleController] setTitle:titleText];
}

- (void)setTitleView:(UIView *)titleView
{
    _titleView = titleView;
    if ([TGViewController useExperimentalRTL])
        _titleView.layer.sublayerTransform = CATransform3DMakeScale(-1.0f, 1.0f, 1.0f);
    [[self _currentNavigationItem] setTitleView:titleView];
}

- (BOOL)disablesAutomaticKeyboardDismissal
{
    return false;
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)())completion
{
    if (TGIsPad() && iosMajorVersion() >= 7)
        viewControllerToPresent.preferredContentSize = [self.navigationController preferredContentSize];
    
    if ([viewControllerToPresent isKindOfClass:[TGNavigationController class]])
    {
        TGNavigationController *navController = (TGNavigationController *)self.navigationController;
        if (navController.showCallStatusBar)
            [(TGNavigationController *)viewControllerToPresent setShowCallStatusBar:true];
    }
    
    if (iosMajorVersion() >= 8 && self.presentedViewController != nil && [self.presentedViewController isKindOfClass:[UIAlertController class]])
    {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self presentViewController:viewControllerToPresent animated:flag completion:completion];
        });
    }
    else
        [super presentViewController:viewControllerToPresent animated:flag completion:completion];
}

- (void)updateSizeClass {
    [self _updateControllerInset:true];
    
    if (_associatedPopoverController != nil) {
        [_associatedPopoverController dismissPopoverAnimated:false];
        
        if ([_associatedPopoverController.contentViewController isKindOfClass:[TGNavigationController class]]) {
            TGNavigationController *contentViewController = (TGNavigationController *)_associatedPopoverController.contentViewController;
            if (contentViewController.detachFromPresentingControllerInCompactMode) {
                NSMutableArray *viewControllers = [[NSMutableArray alloc] initWithArray:self.navigationController.viewControllers];
                [viewControllers addObjectsFromArray:contentViewController.viewControllers];
                [self.navigationController setViewControllers:viewControllers animated:false];
            }
        }
        
        _associatedPopoverController = nil;
    }
}

- (void)layoutControllerForSize:(CGSize)__unused size duration:(NSTimeInterval)__unused duration {
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems {
    if (self.externalPreviewActionItems != nil)
        return self.externalPreviewActionItems();
    
    return [super previewActionItems];
}

@end

@interface UINavigationController (DelegateAutomaticDismissKeyboard)

@end

@implementation UINavigationController (DelegateAutomaticDismissKeyboard)

- (BOOL)disablesAutomaticKeyboardDismissal
{
    return [self.topViewController disablesAutomaticKeyboardDismissal];
}

@end
