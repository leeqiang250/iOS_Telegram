#import "TGPhotoToolbarView.h"

#import "TGModernButtonView.h"
#import "TGPhotoEditorButton.h"

@interface TGPhotoToolbarView ()
{
    UIView *_backgroundView;
    
    UIView *_buttonsWrapperView;
    TGModernButton *_cancelButton;
    TGModernButton *_doneButton;
    
    UILabel *_infoLabel;
    
    UILongPressGestureRecognizer *_longPressGestureRecognizer;
    
    bool _transitionedOut;
}
@end

@implementation TGPhotoToolbarView

- (instancetype)initWithBackButton:(TGPhotoEditorBackButton)backButton doneButton:(TGPhotoEditorDoneButton)doneButton solidBackground:(bool)solidBackground
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        _backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
        _backgroundView.backgroundColor = (solidBackground ? [TGPhotoEditorInterfaceAssets toolbarBackgroundColor] : [TGPhotoEditorInterfaceAssets toolbarTransparentBackgroundColor]);
        [self addSubview:_backgroundView];
        
        _buttonsWrapperView = [[UIView alloc] initWithFrame:_backgroundView.bounds];
        [_backgroundView addSubview:_buttonsWrapperView];
        
        _cancelButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, 49, 49)];
        _cancelButton.exclusiveTouch = true;
        _cancelButton.adjustsImageWhenHighlighted = false;
        
        UIImage *cancelImage = nil;
        switch (backButton)
        {
            case TGPhotoEditorBackButtonCancel:
                cancelImage = [UIImage imageNamed:@"PhotoPickerCancelIcon"];
                break;
                
            default:
                cancelImage = [UIImage imageNamed:@"PhotoPickerBackIcon"];
                break;
        }
        [_cancelButton setImage:cancelImage forState:UIControlStateNormal];
        [_cancelButton addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_backgroundView addSubview:_cancelButton];
        
        UIImage *doneImage = nil;
        CGSize buttonSize = CGSizeMake(49.0f, 49.0f);
        switch (doneButton)
        {
            case TGPhotoEditorDoneButtonCheck:
                doneImage = [UIImage imageNamed:@"PhotoPickerDoneIcon"];
                break;
                
            default:
                doneImage = [UIImage imageNamed:@"PhotoPickerSendIcon"];
                //buttonSize = CGSizeMake(52.0f, 52.0f);
                break;
        }
        
        _doneButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0, 0, buttonSize.width, buttonSize.height)];
        _doneButton.exclusiveTouch = true;
        _doneButton.adjustsImageWhenHighlighted = false;
        
        [_doneButton setImage:doneImage forState:UIControlStateNormal];
        [_doneButton addTarget:self action:@selector(doneButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [_backgroundView addSubview:_doneButton];
        
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonLongPressed:)];
        _longPressGestureRecognizer.minimumPressDuration = 0.65;
        [_doneButton addGestureRecognizer:_longPressGestureRecognizer];
    }
    return self;
}

- (UIButton *)doneButton
{
    return _doneButton;
}

- (TGPhotoEditorButton *)createButtonForTab:(TGPhotoEditorTab)editorTab
{
    TGPhotoEditorButton *button = [[TGPhotoEditorButton alloc] initWithFrame:CGRectMake(0, 0, 33, 33)];
    button.tag = editorTab;
    [button addTarget:self action:@selector(tabButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    switch (editorTab)
    {
        case TGPhotoEditorCropTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets cropIcon];
            break;

        case TGPhotoEditorToolsTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets toolsIcon];
            break;

        case TGPhotoEditorRotateTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets rotateIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorPaintTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets paintIcon];
            break;
            
        case TGPhotoEditorStickerTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets stickerIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorTextTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets textIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorQualityTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets qualityIconForPreset:TGMediaVideoConversionPresetCompressedMedium];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorTimerTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets timerIconForValue:0.0];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorEraserTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets eraserIcon];
            break;
            
        case TGPhotoEditorMirrorTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets mirrorIcon];
            button.dontHighlightOnSelection = true;
            break;
            
        case TGPhotoEditorAspectRatioTab:
            [button setIconImage:[TGPhotoEditorInterfaceAssets aspectRatioIcon] activeIconImage:[TGPhotoEditorInterfaceAssets aspectRatioActiveIcon]];
            button.dontHighlightOnSelection = true;
            break;
        
        case TGPhotoEditorTintTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets tintIcon];
            break;
            
        case TGPhotoEditorBlurTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets blurIcon];
            break;
            
        case TGPhotoEditorCurvesTab:
            button.iconImage = [TGPhotoEditorInterfaceAssets curvesIcon];
            break;
            
        default:
            button = nil;
            break;
    }
    
    return button;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool inside = [super pointInside:point withEvent:event];
    if ([_doneButton pointInside:[self convertPoint:point toView:_doneButton] withEvent:nil])
        return true;
    
    return inside;
}

- (void)setToolbarTabs:(TGPhotoEditorTab)tabs animated:(bool)animated
{
    if (tabs == _currentTabs)
        return;
    
    UIView *transitionView = nil;
    if (animated && _currentTabs != TGPhotoEditorNoneTab)
    {
        transitionView = [_buttonsWrapperView snapshotViewAfterScreenUpdates:false];
        transitionView.frame = _buttonsWrapperView.frame;
        [_buttonsWrapperView.superview addSubview:transitionView];
    }
    
    _currentTabs = tabs;
    
    NSArray *buttons = [_buttonsWrapperView.subviews copy];
    for (UIView *view in buttons)
        [view removeFromSuperview];
    
    if (_currentTabs & TGPhotoEditorCropTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorCropTab]];
    if (_currentTabs & TGPhotoEditorStickerTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorStickerTab]];
    if (_currentTabs & TGPhotoEditorPaintTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorPaintTab]];
    if (_currentTabs & TGPhotoEditorEraserTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorEraserTab]];
    if (_currentTabs & TGPhotoEditorTextTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorTextTab]];
    if (_currentTabs & TGPhotoEditorToolsTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorToolsTab]];
    if (_currentTabs & TGPhotoEditorRotateTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorRotateTab]];
    if (_currentTabs & TGPhotoEditorQualityTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorQualityTab]];
    if (_currentTabs & TGPhotoEditorTimerTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorTimerTab]];
    if (_currentTabs & TGPhotoEditorMirrorTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorMirrorTab]];
    if (_currentTabs & TGPhotoEditorAspectRatioTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorAspectRatioTab]];
    if (_currentTabs & TGPhotoEditorTintTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorTintTab]];
    if (_currentTabs & TGPhotoEditorBlurTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorBlurTab]];
    if (_currentTabs & TGPhotoEditorCurvesTab)
        [_buttonsWrapperView addSubview:[self createButtonForTab:TGPhotoEditorCurvesTab]];
    
    [self setNeedsLayout];
    
    if (animated)
    {
        _buttonsWrapperView.alpha = 0.0f;
        [UIView animateWithDuration:0.15 animations:^
        {
            _buttonsWrapperView.alpha = 1.0f;
            transitionView.alpha = 0.0f;
        } completion:^(__unused BOOL finished)
        {
            [transitionView removeFromSuperview];
        }];
    }
}

- (CGRect)cancelButtonFrame
{
    return _cancelButton.frame;
}

- (void)cancelButtonPressed
{
    if (self.cancelPressed != nil)
        self.cancelPressed();
}

- (void)doneButtonPressed
{
    if (self.donePressed != nil)
        self.donePressed();
}

- (void)doneButtonLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
    {
        if (self.doneLongPressed != nil)
            self.doneLongPressed(_doneButton);
    }
}

- (void)tabButtonPressed:(TGPhotoEditorButton *)sender
{
    if (self.tabPressed != nil)
        self.tabPressed((int)sender.tag);
}

- (void)setActiveTab:(TGPhotoEditorTab)tab
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        [button setSelected:(button.tag == tab) animated:false];
}

- (void)setDoneButtonEnabled:(bool)enabled animated:(bool)animated
{
    _doneButton.userInteractionEnabled = enabled;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
         {
             _doneButton.alpha = enabled ? 1.0f : 0.2f;
         } completion:nil];
    }
    else
    {
        _doneButton.alpha = enabled ? 1.0f : 0.2f;
    }
}

- (void)setEditButtonsEnabled:(bool)enabled animated:(bool)animated
{
    _buttonsWrapperView.userInteractionEnabled = enabled;
    
    if (animated)
    {
        [UIView animateWithDuration:0.2f delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^
        {
            _buttonsWrapperView.alpha = enabled ? 1.0f : 0.2f;
        } completion:nil];
    }
    else
    {
        _buttonsWrapperView.alpha = enabled ? 1.0f : 0.2f;
    }
}

- (void)setEditButtonsHidden:(bool)hidden animated:(bool)animated
{
    CGFloat targetAlpha = hidden ? 0.0f : 1.0f;
    
    if (animated)
    {
        for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
            button.hidden = false;
        
        [UIView animateWithDuration:0.2f
                         animations:^
        {
            for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
                button.alpha = targetAlpha;
        } completion:^(__unused BOOL finished)
        {
            for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
                button.hidden = hidden;
        }];
    }
    else
    {
        for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        {
            button.alpha = (float)targetAlpha;
            button.hidden = hidden;
        }
    }
}

- (void)setEditButtonsHighlighted:(TGPhotoEditorTab)buttons
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        button.active = (buttons & button.tag);
}

- (void)setEditButtonsDisabled:(TGPhotoEditorTab)buttons
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
        button.disabled = (buttons & button.tag);
}

- (TGPhotoEditorButton *)buttonForTab:(TGPhotoEditorTab)tab
{
    for (TGPhotoEditorButton *button in _buttonsWrapperView.subviews)
    {
        if (button.tag == tab)
            return button;
    }
    return nil;
}

- (void)layoutSubviews
{
    CGRect backgroundFrame = self.bounds;
    if (!_transitionedOut)
    {
        _backgroundView.frame = backgroundFrame;
    }
    else
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(backgroundFrame.origin.x, backgroundFrame.size.height, backgroundFrame.size.width, backgroundFrame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-backgroundFrame.size.width, backgroundFrame.origin.y, backgroundFrame.size.width, backgroundFrame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(backgroundFrame.size.width, backgroundFrame.origin.y, backgroundFrame.size.width, backgroundFrame.size.height);
            }
        }
    }
    _buttonsWrapperView.frame = _backgroundView.bounds;
    
    NSArray *buttons = _buttonsWrapperView.subviews;
    
    if (self.frame.size.width > self.frame.size.height)
    {
        if (buttons.count == 1)
        {
            UIView *button = buttons.firstObject;
            button.frame = CGRectMake(CGFloor(self.frame.size.width / 2 - button.frame.size.width / 2), (self.frame.size.height - button.frame.size.height) / 2, button.frame.size.width, button.frame.size.height);
        }
        else if (buttons.count == 2)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *rightButton = buttons.lastObject;
            
            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 5 * 2 - 5 - leftButton.frame.size.width / 2), (self.frame.size.height - leftButton.frame.size.height) / 2, leftButton.frame.size.width, leftButton.frame.size.height);
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), (self.frame.size.height - rightButton.frame.size.height) / 2, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        else if (buttons.count == 3)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *centerButton = [buttons objectAtIndex:1];
            UIView *rightButton = buttons.lastObject;
            
            centerButton.frame = CGRectMake(CGFloor(self.frame.size.width / 2 - centerButton.frame.size.width / 2), (self.frame.size.height - centerButton.frame.size.height) / 2, centerButton.frame.size.width, centerButton.frame.size.height);

            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 6 * 2 - 10 - leftButton.frame.size.width / 2), (self.frame.size.height - leftButton.frame.size.height) / 2, leftButton.frame.size.width, leftButton.frame.size.height);
            
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), (self.frame.size.height - rightButton.frame.size.height) / 2, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        else if (buttons.count == 4)
        {
            UIView *leftButton = buttons.firstObject;
            UIView *centerLeftButton = [buttons objectAtIndex:1];
            UIView *centerRightButton = [buttons objectAtIndex:2];
            UIView *rightButton = buttons.lastObject;
            
            leftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 8 * 2 - 3 - leftButton.frame.size.width / 2), (self.frame.size.height - leftButton.frame.size.height) / 2, leftButton.frame.size.width, leftButton.frame.size.height);
            
            centerLeftButton.frame = CGRectMake(CGFloor(self.frame.size.width / 10 * 4 + 5 - centerLeftButton.frame.size.width / 2), (self.frame.size.height - centerLeftButton.frame.size.height) / 2, centerLeftButton.frame.size.width, centerLeftButton.frame.size.height);
            
            centerRightButton.frame = CGRectMake(CGCeil(self.frame.size.width - centerLeftButton.frame.origin.x - centerRightButton.frame.size.width), (self.frame.size.height - centerRightButton.frame.size.height) / 2, centerRightButton.frame.size.width, centerRightButton.frame.size.height);
            
            rightButton.frame = CGRectMake(CGCeil(self.frame.size.width - leftButton.frame.origin.x - rightButton.frame.size.width), (self.frame.size.height - rightButton.frame.size.height) / 2, rightButton.frame.size.width, rightButton.frame.size.height);
        }
        
        _cancelButton.frame = CGRectMake(0, 0, 49, 49);
        CGFloat offset = 49.0f;
        if (_doneButton.frame.size.width > 49.0f)
            offset = 60.0f;
        
        _doneButton.frame = CGRectMake(self.frame.size.width - offset, 49.0f - offset, _doneButton.frame.size.width, _doneButton.frame.size.height);
        
        _infoLabel.frame = CGRectMake(49.0f + 10.0f, 0.0f, self.frame.size.width - (49.0f + 10.0f) * 2.0f, self.frame.size.height);
    }
    else
    {
        if (buttons.count == 1)
        {
            UIView *button = buttons.firstObject;
            button.frame = CGRectMake((self.frame.size.width - button.frame.size.width) / 2, CGFloor((self.frame.size.height - button.frame.size.height) / 2), button.frame.size.width, button.frame.size.height);
        }
        else if (buttons.count == 2)
        {
            UIView *topButton = buttons.firstObject;
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake((self.frame.size.width - topButton.frame.size.width) / 2, CGFloor(self.frame.size.height / 5 * 2 - 10 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            bottomButton.frame = CGRectMake((self.frame.size.width - bottomButton.frame.size.width) / 2, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
        else if (buttons.count == 3)
        {
            UIView *topButton = buttons.firstObject;
            UIView *centerButton = [buttons objectAtIndex:1];
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake((self.frame.size.width - topButton.frame.size.width) / 2, CGFloor(self.frame.size.height / 6 * 2 - 10 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            centerButton.frame = CGRectMake((self.frame.size.width - centerButton.frame.size.width) / 2, CGFloor((self.frame.size.height - centerButton.frame.size.height) / 2), centerButton.frame.size.width, centerButton.frame.size.height);
            bottomButton.frame = CGRectMake((self.frame.size.width - bottomButton.frame.size.width) / 2, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
        else if (buttons.count == 4)
        {
            UIView *topButton = buttons.firstObject;
            UIView *centerTopButton = [buttons objectAtIndex:1];
            UIView *centerBottonButton = [buttons objectAtIndex:2];
            UIView *bottomButton = buttons.lastObject;
            
            topButton.frame = CGRectMake((self.frame.size.width - topButton.frame.size.width) / 2, CGFloor(self.frame.size.height / 8 * 2 - 3 - topButton.frame.size.height / 2), topButton.frame.size.width, topButton.frame.size.height);
            
            centerTopButton.frame = CGRectMake((self.frame.size.width - centerTopButton.frame.size.width) / 2, CGFloor(self.frame.size.height / 10 * 4 + 5 - centerTopButton.frame.size.height / 2), centerTopButton.frame.size.width, centerTopButton.frame.size.height);
            
            centerBottonButton.frame = CGRectMake((self.frame.size.width - centerBottonButton.frame.size.width) / 2, CGCeil(self.frame.size.height - centerTopButton.frame.origin.y - centerBottonButton.frame.size.height), centerBottonButton.frame.size.width, centerBottonButton.frame.size.height);
            
            bottomButton.frame = CGRectMake((self.frame.size.width - bottomButton.frame.size.width) / 2, CGCeil(self.frame.size.height - topButton.frame.origin.y - bottomButton.frame.size.height), bottomButton.frame.size.width, bottomButton.frame.size.height);
        }
    
        _cancelButton.frame = CGRectMake(0, self.frame.size.height - 49, 49, 49);
        _cancelButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        
        _doneButton.frame = CGRectMake(0, 0, 49, 49);
        _doneButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        
        _infoLabel.transform = CGAffineTransformIdentity;
        _infoLabel.frame = CGRectMake(49.0f + 10.0f, 0.0f, self.frame.size.width - (49.0f + 10.0f) * 2.0f, self.frame.size.height);
        
        if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
        {
            _infoLabel.transform = CGAffineTransformMakeRotation(M_PI_2);
        }
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
        {
            _infoLabel.transform = CGAffineTransformMakeRotation(-M_PI_2);
        }
    }
}

- (void)transitionInAnimated:(bool)animated
{
    [self transitionInAnimated:animated transparent:false];
}

- (void)transitionInAnimated:(bool)animated transparent:(bool)transparent
{
    _transitionedOut = false;
    self.backgroundColor = transparent ? [UIColor clearColor] : [UIColor blackColor];
    
    void (^animationBlock)(void) = ^
    {
        if (self.frame.size.width > self.frame.size.height)
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, 0, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        else
            _backgroundView.frame = CGRectMake(0, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
    };
    
    void (^completionBlock)(BOOL) = ^(BOOL finished)
    {
        if (finished)
            self.backgroundColor = [UIColor clearColor];
    };
    
    if (animated)
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, _backgroundView.frame.size.height, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
        }
        
        if (iosMajorVersion() >= 7)
            [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:completionBlock];
        else
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:completionBlock];
    }
    else
    {
        animationBlock();
        completionBlock(true);
    }
}

- (void)transitionOutAnimated:(bool)animated
{
    [self transitionOutAnimated:animated transparent:false hideOnCompletion:false];
}

- (void)transitionOutAnimated:(bool)animated transparent:(bool)transparent hideOnCompletion:(bool)hideOnCompletion
{
    _transitionedOut = true;
    
    void (^animationBlock)(void) = ^
    {
        if (self.frame.size.width > self.frame.size.height)
        {
            _backgroundView.frame = CGRectMake(_backgroundView.frame.origin.x, _backgroundView.frame.size.height, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
        }
        else
        {
            if (_interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            {
                _backgroundView.frame = CGRectMake(-_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
            else
            {
                _backgroundView.frame = CGRectMake(_backgroundView.frame.size.width, _backgroundView.frame.origin.y, _backgroundView.frame.size.width, _backgroundView.frame.size.height);
            }
        }
    };
    
    void (^completionBlock)(BOOL) = ^(__unused BOOL finished)
    {
        if (hideOnCompletion)
            self.hidden = true;
    };
    
    self.backgroundColor = transparent ? [UIColor clearColor] : [UIColor blackColor];
    
    if (animated)
    {
        if (iosMajorVersion() >= 7)
            [UIView animateWithDuration:0.4f delay:0.0f usingSpringWithDamping:1.0f initialSpringVelocity:0.0f options:UIViewAnimationOptionCurveLinear animations:animationBlock completion:completionBlock];
        else
            [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionAllowUserInteraction animations:animationBlock completion:completionBlock];
    }
    else
    {
        animationBlock();
        completionBlock(true);
    }
}

- (void)setInfoString:(NSString *)string
{
    if (_infoLabel == nil)
    {
        _infoLabel = [[UILabel alloc] init];
        _infoLabel.backgroundColor = [UIColor clearColor];
        _infoLabel.font = TGSystemFontOfSize(13.0f);
        _infoLabel.textAlignment = NSTextAlignmentCenter;
        _infoLabel.textColor = [UIColor whiteColor];
        [_backgroundView addSubview:_infoLabel];
        
        [self setNeedsLayout];
    }
    
    _infoLabel.text = string;
}

@end
