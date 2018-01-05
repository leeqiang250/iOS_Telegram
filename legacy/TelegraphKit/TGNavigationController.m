#import "TGNavigationController.h"

#import "Freedom.h"

#import "TGNavigationBar.h"
#import "TGViewController.h"
#import "TGToolbarButton.h"

#import "TGHacks.h"

#import "TGRTLScreenEdgePanGestureRecognizer.h"

#import "TGImageUtils.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "TGViewController.h"
#import "TGMainTabsController.h"
#import "TGTelegraph.h"

@interface TGNavigationPercentTransition : UIPercentDrivenInteractiveTransition

@end

@interface UINavigationController () {
    
}

@end

@interface TGNavigationController () <UINavigationControllerDelegate, UIGestureRecognizerDelegate>
{
    UITapGestureRecognizer *_dimmingTapRecognizer;
    CGSize _preferredContentSize;
    
    id<SDisposable> _playerStatusDisposable;
    CGFloat _currentAdditionalStatusBarHeight;
    
    UIPanGestureRecognizer *_panGestureRecognizer;
}

@property (nonatomic) bool wasShowingNavigationBar;

@property (nonatomic, strong) TGAutorotationLock *autorotationLock;

@end

@implementation TGNavigationController

+ (TGNavigationController *)navigationControllerWithRootController:(UIViewController *)controller
{
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers
{
    return [self navigationControllerWithControllers:controllers navigationBarClass:[TGNavigationBar class]];
}

+ (TGNavigationController *)navigationControllerWithControllers:(NSArray *)controllers navigationBarClass:(Class)navigationBarClass
{
    TGNavigationController *navigationController = [[TGNavigationController alloc] initWithNavigationBarClass:navigationBarClass toolbarClass:[UIToolbar class]];
    
    bool first = true;
    for (id controller in controllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    [navigationController setViewControllers:controllers];
    
    ((TGNavigationBar *)navigationController.navigationBar).navigationController = navigationController;
    
    return navigationController;
}

+ (TGNavigationController *)makeWithRootController:(UIViewController *)controller {
    return [self navigationControllerWithControllers:[NSArray arrayWithObject:controller]];
}

- (instancetype)initWithNavigationBarClass:(Class)navigationBarClass toolbarClass:(Class)toolbarClass
{
    self = [super initWithNavigationBarClass:navigationBarClass toolbarClass:toolbarClass];
    if (self != nil)
    {
        
    }
    return self;
}

- (void)dealloc
{
    [_playerStatusDisposable dispose];
    self.delegate = nil;
    [_dimmingTapRecognizer.view removeGestureRecognizer:_dimmingTapRecognizer];
}

- (void)loadView
{
    [super loadView];
    if (iosMajorVersion() >= 11) {
        if (@available(iOS 11.0, *)) {
            self.navigationBar.prefersLargeTitles = false;
        } else {
            // Fallback on earlier versions
        }
    }
    
    /*if (false && iosMajorVersion() >= 8) {
        SEL selector = NSSelectorFromString(TGEncodeText(@"`tdsffoFehfQboHftuvsfSfdphoj{fs", -1));
        if ([self respondsToSelector:selector])
        {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            UIScreenEdgePanGestureRecognizer *screenPanRecognizer = [self performSelector:selector];
#pragma clang diagnostic pop
            
            screenPanRecognizer.enabled = false;
            
            Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
            id targetActionPairs = object_getIvar(screenPanRecognizer, targetsIvar);
            
            Class targetActionPairClass = NSClassFromString(@"UIGestureRecognizerTarget");
            Ivar targetIvar = class_getInstanceVariable(targetActionPairClass, "_target");
            Ivar actionIvar = class_getInstanceVariable(targetActionPairClass, "_action");
            
            for (id targetActionPair in targetActionPairs)
            {
                id target = object_getIvar(targetActionPair, targetIvar);
                SEL action = (__bridge void *)object_getIvar(targetActionPair, actionIvar);
                
                _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:target action:action];
                _panGestureRecognizer.delegate = self;
                _panGestureRecognizer.delaysTouchesBegan = true;
                [screenPanRecognizer.view addGestureRecognizer:_panGestureRecognizer];
                
                break;
            }
        }
    }*/
}

//- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)__unused gestureRecognizer
//{
//    SEL selector = NSSelectorFromString(TGEncodeText(@"`tdsffoFehfQboHftuvsfSfdphoj{fs", -1));
//    if ([self respondsToSelector:selector])
//    {
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//        UIScreenEdgePanGestureRecognizer *screenPanRecognizer = [self performSelector:selector];
//        
//        bool shouldBegin = [screenPanRecognizer.delegate gestureRecognizerShouldBegin:screenPanRecognizer];
//        if (self.viewControllers.count == 1)
//            shouldBegin = false;
//        
//        return shouldBegin;
//    }
//    return true;
//}

//- (UIGestureRecognizer *)interactivePopGestureRecognizer
//{
//    return _panGestureRecognizer;
//}

- (void)setDisplayPlayer:(bool)displayPlayer
{
    _displayPlayer = displayPlayer;
    
    if (_displayPlayer && [self.navigationBar isKindOfClass:[TGNavigationBar class]])
    {
        __weak TGNavigationController *weakSelf = self;
        [_playerStatusDisposable dispose];
        _playerStatusDisposable = [[[[TGTelegraphInstance musicPlayer] playingStatus] deliverOn:[SQueue mainQueue]] startWithNext:^(TGMusicPlayerStatus *status)
        {
            __strong TGNavigationController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (status != nil && strongSelf->_currentAdditionalNavigationBarHeight < FLT_EPSILON)
                {
                    strongSelf->_minimizePlayer = false;
                    [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
                }
                
                CGFloat currentAdditionalNavigationBarHeight = status == nil ? 0.0f : (strongSelf->_minimizePlayer ? 2.0f : 36.0f);
                if (ABS(strongSelf->_currentAdditionalNavigationBarHeight - currentAdditionalNavigationBarHeight) > FLT_EPSILON)
                {
                    strongSelf->_currentAdditionalNavigationBarHeight = currentAdditionalNavigationBarHeight;
                    [((TGNavigationBar *)strongSelf.navigationBar) showMusicPlayerView:status != nil animation:^
                    {
                        [strongSelf updatePlayerOnControllers];
                    }];
                }
            }
        }];
    }
    else
    {
        [_playerStatusDisposable dispose];
    }
}

- (void)setMinimizePlayer:(bool)minimizePlayer
{
    if (_minimizePlayer != minimizePlayer)
    {
        _minimizePlayer = minimizePlayer;
        
        if (_currentAdditionalNavigationBarHeight > FLT_EPSILON)
            _currentAdditionalNavigationBarHeight = _minimizePlayer ? 2.0f : 36.0f;
        [(TGNavigationBar *)self.navigationBar setMinimizedMusicPlayer:_minimizePlayer];
        
        [UIView animateWithDuration:0.25 animations:^
        {
            [self updatePlayerOnControllers];
        }];
    }
}

- (void)setShowCallStatusBar:(bool)showCallStatusBar
{
    if (_showCallStatusBar == showCallStatusBar)
        return;
    
    _showCallStatusBar = showCallStatusBar;
    
    _currentAdditionalStatusBarHeight = _showCallStatusBar ? 20.0f : 0.0f;
    [(TGNavigationBar *)self.navigationBar setVerticalOffset:_currentAdditionalStatusBarHeight];
    
    [UIView animateWithDuration:0.25 animations:^
    {
        static SEL selector = NULL;
        static void (*impl)(id, SEL) = NULL;
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            selector = NSSelectorFromString(TGEncodeText(@"`vqebufCbstGpsDvssfouJoufsgbdfPsjfoubujpo", -1));
            Method method = class_getInstanceMethod([UINavigationController class], selector);
            impl = (void (*)(id, SEL))method_getImplementation(method);
        });
        
        if (impl != NULL)
            impl(self, selector);

        [self updateStatusBarOnControllers];
    }];
}


- (void)setupStatusBarOnControllers:(NSArray *)controllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
            }
            else if ([maybeController isKindOfClass:[TGMainTabsController class]])
            {
                [self setupPlayerOnControllers:((TGMainTabsController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updateStatusBarOnControllers
{
    if ([[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *viewController = (TGViewController *)maybeController;
                [viewController setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                [viewController setNeedsStatusBarAppearanceUpdate];
                
                if ([viewController.presentedViewController isKindOfClass:[TGNavigationController class]] && viewController.presentedViewController.modalPresentationStyle != UIModalPresentationPopover)
                {
                    [(TGNavigationController *)viewController.presentedViewController setShowCallStatusBar:_showCallStatusBar];
                }
            }
            else if ([maybeController isKindOfClass:[TGMainTabsController class]])
            {
                for (id controller in ((TGMainTabsController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalStatusBarHeight:_currentAdditionalStatusBarHeight];
                    }
                }
                [((TGMainTabsController *)maybeController) setNeedsStatusBarAppearanceUpdate];
            }
        }
    }
}

static UIView *findDimmingView(UIView *view)
{
    static NSString *encodedString = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        encodedString = TGEncodeText(@"VJEjnnjohWjfx", -1);
    });
    
    if ([NSStringFromClass(view.class) isEqualToString:encodedString])
        return view;
    
    for (UIView *subview in view.subviews)
    {
        UIView *result = findDimmingView(subview);
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.modalPresentationStyle == UIModalPresentationFormSheet)
    {
        UIView *dimmingView = findDimmingView(self.view.window);
        bool tapSetup = false;
        if (_dimmingTapRecognizer != nil)
        {
            for (UIGestureRecognizer *recognizer in dimmingView.gestureRecognizers)
            {
                if (recognizer == _dimmingTapRecognizer)
                {
                    tapSetup = true;
                    break;
                }
            }
        }
        
        if (!tapSetup)
        {
            _dimmingTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dimmingViewTapped:)];
            [dimmingView addGestureRecognizer:_dimmingTapRecognizer];
        }
    }
}

- (void)dimmingViewTapped:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        [self.presentingViewController dismissViewControllerAnimated:true completion:nil];
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGSize screenSize = TGScreenSize();
    static Class containerClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        containerClass = freedomClass(0xf045e5dfU);
    });
    
    for (UIView *view in self.view.subviews)
    {
        if ([view isKindOfClass:containerClass])
        {
            CGRect frame = view.frame;
            
            if (ABS(frame.size.width - screenSize.width) < FLT_EPSILON)
            {
                if (ABS(frame.size.height - screenSize.height + 20) < FLT_EPSILON)
                {
                    frame.origin.y = frame.size.height - screenSize.height;
                    frame.size.height = screenSize.height;
                }
                else if (frame.size.height > screenSize.height + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.height;
                }
            }
            else if (ABS(frame.size.width - screenSize.height) < FLT_EPSILON)
            {
                if (frame.size.height > screenSize.width + FLT_EPSILON)
                {
                    frame.origin.y = 0;
                    frame.size.height = screenSize.width;
                }
            }
            
            if (ABS(frame.size.height) < FLT_EPSILON)
            {
                frame.size.height = screenSize.height;
            }
            
            if (!CGRectEqualToRect(view.frame, frame))
                view.frame = frame;
            
            break;
        }
    }
}

- (void)viewDidLoad
{   
    self.delegate = self;
    
    /*if(iosMajorVersion() >=11)
    {
        // 会导致 IOS 11 以上的版本 Navigation 遮挡后面看不到
        [self.navigationBar setTranslucent:NO];
    }*/
    
    
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)updateControllerLayout:(bool)__unused animated
{
}

- (void)setupNavigationBarForController:(UIViewController *)viewController animated:(bool)animated
{
    UIBarStyle barStyle = UIBarStyleDefault;
    bool navigationBarShouldBeHidden = false;
    UIStatusBarStyle statusBarStyle = UIStatusBarStyleBlackOpaque;
    bool statusBarShouldBeHidden = false;
    
    if ([viewController conformsToProtocol:@protocol(TGViewControllerNavigationBarAppearance)])
    {
        id<TGViewControllerNavigationBarAppearance> appearance = (id<TGViewControllerNavigationBarAppearance>)viewController;
        
        barStyle = [appearance requiredNavigationBarStyle];
        navigationBarShouldBeHidden = [appearance navigationBarShouldBeHidden];
        if ([appearance respondsToSelector:@selector(preferredStatusBarStyle)])
            statusBarStyle = [appearance preferredStatusBarStyle];
        if ([appearance respondsToSelector:@selector(statusBarShouldBeHidden)])
            statusBarShouldBeHidden = [appearance statusBarShouldBeHidden];
    }
    
    if (navigationBarShouldBeHidden != self.navigationBarHidden)
    {
        [self setNavigationBarHidden:navigationBarShouldBeHidden animated:animated];
    }
    
    if ([[UIApplication sharedApplication] isStatusBarHidden] != statusBarShouldBeHidden)
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarShouldBeHidden withAnimation:animated ? UIStatusBarAnimationFade : UIStatusBarAnimationNone];
    if ([[UIApplication sharedApplication] statusBarStyle] != statusBarStyle)
        [[UIApplication sharedApplication] setStatusBarStyle:statusBarStyle animated:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (_restrictLandscape)
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    
    if (self.topViewController != nil)
        return [self.topViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (BOOL)shouldAutorotate
{
    if (_restrictLandscape)
        return false;
    
    if (self.topViewController != nil)
    {
        if ([self.topViewController respondsToSelector:@selector(shouldAutorotate)])
        {
            if (![self.topViewController shouldAutorotate])
                return false;
        }
    }
    
    bool result = [super shouldAutorotate];
    if (!result)
        return false;
    
    if ([self respondsToSelector:@selector(interactivePopGestureRecognizer)])
    {
        UIGestureRecognizerState state = self.interactivePopGestureRecognizer.state;
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged)
            return false;
    }
    
    return true;
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

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    if (_restrictLandscape)
        return UIInterfaceOrientationMaskPortrait;
    
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)setNavigationBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (!hidden)
        self.navigationBar.alpha = 1.0f;
    
    [(TGNavigationBar *)self.navigationBar setHiddenState:hidden animated:animated];
    
    [super setNavigationBarHidden:hidden animated:animated];
}

- (void)setupPlayerOnControllers:(NSArray *)controllers
{
    if (_displayPlayer && [[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in controllers)
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                TGViewController *controller = maybeController;
                [controller setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if ([maybeController isKindOfClass:[TGMainTabsController class]])
            {
                [self setupPlayerOnControllers:((TGMainTabsController *)maybeController).viewControllers];
            }
        }
    }
}

- (void)updatePlayerOnControllers
{
    if (_displayPlayer && [[self navigationBar] isKindOfClass:[TGNavigationBar class]])
    {
        for (id maybeController in [self viewControllers])
        {
            if ([maybeController isKindOfClass:[TGViewController class]])
            {
                [((TGViewController *)maybeController) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
            }
            else if ([maybeController isKindOfClass:[TGMainTabsController class]])
            {
                for (id controller in ((TGMainTabsController *)maybeController).viewControllers)
                {
                    if ([controller isKindOfClass:[TGViewController class]])
                    {
                        [((TGViewController *)controller) setAdditionalNavigationBarHeight:_currentAdditionalNavigationBarHeight];
                    }
                }
            }
        }
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (self.viewControllers.count == 0) {
        if ([viewController isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)viewController setIsFirstInStack:true];
        } else {
            [(TGViewController *)viewController setIsFirstInStack:false];
        }
    }
    _isInControllerTransition = true;
    if (viewController != nil) {
        [self setupPlayerOnControllers:@[viewController]];
        [self setupStatusBarOnControllers:@[viewController]];
    }
    [super pushViewController:viewController animated:animated];
    _isInControllerTransition = false;
    
    //
    
    if(iosMajorVersion() >=11)
    {
        /*[self.navigationController.navigationBar.subviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger idx, BOOL *stop)
         {
             //iOS10,改变了导航栏的私有接口为_UIBarBackground
             if ([view isKindOfClass:NSClassFromString(@"_UIBarBackground")])
             {
                 [view.subviews firstObject].hidden = YES;
             }
             
             //iOS10之前使用的是_UINavigationBarBackground
             if ([view isKindOfClass:NSClassFromString(@"_UINavigationBarBackground")])
             {
                 [view.subviews firstObject].hidden = YES;
             }
         }];*/
    }
}

- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    bool first = true;
    for (id controller in viewControllers) {
        if ([controller isKindOfClass:[TGViewController class]]) {
            [(TGViewController *)controller setIsFirstInStack:first];
        }
        first = false;
    }
    
    _isInControllerTransition = true;
    [self setupPlayerOnControllers:viewControllers];
    [self setupStatusBarOnControllers:viewControllers];
    [super setViewControllers:viewControllers animated:animated];
    _isInControllerTransition = false;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    if (animated)
    {
        static ptrdiff_t controllerOffset = -1;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            controllerOffset = freedomIvarOffset([UINavigationController class], 0xb281e8fU);
        });
        
        if (controllerOffset != -1)
        {
            __unsafe_unretained NSObject **controller = (__unsafe_unretained NSObject **)(void *)(((uint8_t *)(__bridge void *)self) + controllerOffset);
            if (*controller != nil)
            {
                static Class decoratedClass = Nil;
                static dispatch_once_t onceToken;
                dispatch_once(&onceToken, ^
                {
                   decoratedClass = freedomMakeClass([*controller class], [TGNavigationPercentTransition class]);
                });
                
                if (decoratedClass != Nil && ![*controller isKindOfClass:decoratedClass])
                    object_setClass(*controller, decoratedClass);
            }
        }
    }
    
    _isInPopTransition = true;
    UIViewController *result = [super popViewControllerAnimated:animated];
    _isInPopTransition = false;
    
    return result;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    for (NSUInteger i = self.viewControllers.count - 1; i >= 1; i--)
    {
        UIViewController *viewController = self.viewControllers[i];
        if (viewController.presentedViewController != nil)
            [viewController dismissViewControllerAnimated:false completion:nil];
    }
    
    return [super popToRootViewControllerAnimated:animated];
}

TGNavigationController *findNavigationControllerInWindow(UIWindow *window)
{
    if ([window.rootViewController isKindOfClass:[TGNavigationController class]])
        return (TGNavigationController *)window.rootViewController;
    
    return nil;
}

TGNavigationController *findNavigationController()
{
    NSArray *windows = [UIApplication sharedApplication].windows;
    for (int i = (int)windows.count - 1; i >= 0; i--)
    {
        TGNavigationController *result = findNavigationControllerInWindow(windows[i]);
        if (result != nil)
            return result;
    }
    
    return nil;
}

- (CGFloat)myNominalTransitionAnimationDuration
{
    return 0.2f;
}

- (int)replacedKeyboardDirection:(int)arg1 arg2:(BOOL)arg2
{
    static SEL selector = NULL;
    static int (*impl)(id, SEL, int, BOOL) = NULL;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        selector = NSSelectorFromString(TGEncodeText(@"`lfzcpbseEjsfdujpoGpsUsbotjujpo;psefsjohJo;", -1));
        Method method = class_getInstanceMethod([UINavigationController class], selector);
        impl = (int (*)(id, SEL, int, BOOL))method_getImplementation(method);
    });
    
    int result = 1;
    if (impl != NULL)
        result = impl(self, selector, arg1, arg2);
    
    if ([TGViewController useExperimentalRTL])
    {
        if (result == 1)
            result = 2;
        else if (result == 2)
            result = 1;
    }
    
    return result;
}

- (void)setPreferredContentSize:(CGSize)preferredContentSize
{
    _preferredContentSize = preferredContentSize;
}

- (CGSize)preferredContentSize
{
    return _preferredContentSize;
}

@end

@implementation TGNavigationPercentTransition

- (void)updateInteractiveTransition:(CGFloat)percentComplete
{
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition && [TGHacks applicationKeyboardWindow] != nil && ![TGHacks applicationKeyboardWindow].hidden)
        {
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:navigationController.interfaceOrientation];
            CGFloat keyboardOffset = MAX(0.0f, percentComplete * screenSize.width);
            
            if ([TGViewController useExperimentalRTL])
                keyboardOffset = -keyboardOffset;
            
            UIView *keyboardView = [TGHacks applicationKeyboardView];
            CGRect keyboardViewFrame = keyboardView.frame;
            keyboardViewFrame.origin.x = keyboardOffset;
            
            keyboardView.frame = keyboardViewFrame;
        }
    }
    
    [super updateInteractiveTransition:percentComplete];
}

- (void)finishInteractiveTransition
{
    CGFloat value = self.percentComplete;
    UIView *keyboardView = [TGHacks applicationKeyboardView];
    CGRect keyboardViewFrame = keyboardView.frame;
    
    [super finishInteractiveTransition];
    
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition)
        {
            keyboardView.frame = keyboardViewFrame;
            
            CGSize screenSize = [TGViewController screenSizeForInterfaceOrientation:navigationController.interfaceOrientation];
            CGFloat keyboardOffset = 1.0f * screenSize.width;
            if ([TGViewController useExperimentalRTL])
                keyboardOffset = -keyboardOffset;
            
            keyboardViewFrame.origin.x = keyboardOffset;
            NSTimeInterval duration = (1.0 - value) * [navigationController myNominalTransitionAnimationDuration];
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^
             {
                 keyboardView.frame = keyboardViewFrame;
             } completion:nil];
        }
    }
}

- (void)cancelInteractiveTransition
{
    CGFloat value = self.percentComplete;
    
    TGNavigationController *navigationController = findNavigationController();
    if (navigationController != nil)
    {
        if (!navigationController.disableInteractiveKeyboardTransition && [TGHacks applicationKeyboardWindow] != nil && ![TGHacks applicationKeyboardWindow].hidden)
        {
            UIView *keyboardView = [TGHacks applicationKeyboardView];
            CGRect keyboardViewFrame = keyboardView.frame;
            keyboardViewFrame.origin.x = 0.0f;
            
            NSTimeInterval duration = value * [navigationController myNominalTransitionAnimationDuration];
            [UIView animateWithDuration:duration delay:0 options:UIViewAnimationOptionCurveLinear animations:^
             {
                 keyboardView.frame = keyboardViewFrame;
             } completion:nil];
        }
    }
    
    [super cancelInteractiveTransition];
}

@end
