#import "TGVideoMessageControls.h"

#import "TGFont.h"
#import "TGImageUtils.h"

#import "TGModernButton.h"
#import "TGModernConversationInputMicButton.h"
#import "TGVideoMessageScrubber.h"

static void setViewFrame(UIView *view, CGRect frame)
{
    CGAffineTransform transform = view.transform;
    view.transform = CGAffineTransformIdentity;
    if (!CGRectEqualToRect(view.frame, frame))
        view.frame = frame;
    view.transform = transform;
}

static CGRect viewFrame(UIView *view)
{
    CGAffineTransform transform = view.transform;
    view.transform = CGAffineTransformIdentity;
    CGRect result = view.frame;
    view.transform = transform;
    
    return result;
}

@interface TGVideoMessageControls () <TGModernConversationInputMicButtonDelegate>
{
    UIImageView *_slideToCancelArrow;
    UILabel *_slideToCancelLabel;
    
    TGModernButton *_cancelButton;
    
    TGModernButton *_deleteButton;
    TGModernButton *_sendButton;
    
    UIImageView *_recordIndicatorView;
    UILabel *_recordDurationLabel;
    
    CFAbsoluteTime _recordingInterfaceShowTime;
}
@end

@implementation TGVideoMessageControls

- (void)captureStarted
{
    [UIView transitionWithView:_recordDurationLabel duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        _recordDurationLabel.textColor = [UIColor whiteColor];
    } completion:nil];
    
    [UIView transitionWithView:_slideToCancelLabel duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        _slideToCancelLabel.textColor = [UIColor whiteColor];
    } completion:nil];
    
    [UIView transitionWithView:_slideToCancelArrow duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
        _slideToCancelArrow.image = TGTintedImage(_slideToCancelArrow.image, [UIColor whiteColor]);
    } completion:nil];
}

- (void)setShowRecordingInterface:(bool)show velocity:(CGFloat)velocity
{
    CGFloat hideLeftOffset = 400.0f;
    
    bool isAlreadyLocked = self.isAlreadyLocked();
    
    if (show)
    {
        _recordingInterfaceShowTime = CFAbsoluteTimeGetCurrent();
        
        if (_recordIndicatorView == nil)
        {
            static UIImage *indicatorImage = nil;
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^
            {
                indicatorImage = TGCircleImage(9.0f, UIColorRGB(0xF33D2B));
            });
            _recordIndicatorView = [[UIImageView alloc] initWithImage:indicatorImage];
        }
        
        setViewFrame(_recordIndicatorView, CGRectMake(11.0f, CGFloor((self.frame.size.height - 9.0f) / 2.0f), 9.0f, 9.0f));
        _recordIndicatorView.transform = CGAffineTransformMakeTranslation(-80.0f, 0.0f);
        
        if (_recordDurationLabel == nil)
        {
            _recordDurationLabel = [[UILabel alloc] init];
            _recordDurationLabel.backgroundColor = [UIColor clearColor];
            _recordDurationLabel.textColor = [UIColor blackColor];
            _recordDurationLabel.font = TGSystemFontOfSize(15.0f);
            _recordDurationLabel.text = @"0:00,00 ";
            [_recordDurationLabel sizeToFit];
            _recordDurationLabel.alpha = 0.0f;
            _recordDurationLabel.layer.anchorPoint = CGPointMake((26.0f - _recordDurationLabel.frame.size.width) / (2 * 26.0f), 0.5f);
            _recordDurationLabel.textAlignment = NSTextAlignmentLeft;
            _recordDurationLabel.userInteractionEnabled = false;
        }
        
        setViewFrame(_recordDurationLabel, CGRectMake(26.0f, CGFloor((self.frame.size.height - _recordDurationLabel.frame.size.height) / 2.0f), _recordDurationLabel.frame.size.width, _recordDurationLabel.frame.size.height));
        
        _recordDurationLabel.transform = CGAffineTransformMakeTranslation(-80.0f, 0.0f);
        
        if (_slideToCancelLabel == nil)
        {
            _slideToCancelLabel = [[UILabel alloc] init];
            _slideToCancelLabel.backgroundColor = [UIColor clearColor];
            _slideToCancelLabel.textColor = UIColorRGB(0x9597a0);
            _slideToCancelLabel.font = TGSystemFontOfSize(15.0f);
            _slideToCancelLabel.text = TGLocalized(@"Conversation.SlideToCancel");
            _slideToCancelLabel.clipsToBounds = false;
            _slideToCancelLabel.userInteractionEnabled = false;
            [_slideToCancelLabel sizeToFit];
            setViewFrame(_slideToCancelLabel, CGRectMake(CGFloor((self.frame.size.width - _slideToCancelLabel.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _slideToCancelLabel.frame.size.height) / 2.0f), _slideToCancelLabel.frame.size.width, _slideToCancelLabel.frame.size.height));
            _slideToCancelLabel.alpha = 0.0f;
            
            _slideToCancelArrow = [[UIImageView alloc] initWithImage:TGTintedImage([UIImage imageNamed:@"ModernConversationAudioSlideToCancel.png"], UIColorRGB(0x9597a0))];
            CGRect slideToCancelArrowFrame = viewFrame(_slideToCancelArrow);
            setViewFrame(_slideToCancelArrow, CGRectMake(CGFloor((self.frame.size.width - _slideToCancelLabel.frame.size.width) / 2.0f) - slideToCancelArrowFrame.size.width - 7.0f, CGFloor((self.frame.size.height - _slideToCancelLabel.frame.size.height) / 2.0f), slideToCancelArrowFrame.size.width, slideToCancelArrowFrame.size.height));
            _slideToCancelArrow.alpha = 0.0f;
            [self addSubview:_slideToCancelArrow];
            
            _slideToCancelArrow.transform = CGAffineTransformMakeTranslation(hideLeftOffset, 0.0f);
            _slideToCancelLabel.transform = CGAffineTransformMakeTranslation(hideLeftOffset, 0.0f);
            
            _cancelButton = [[TGModernButton alloc] init];
            _cancelButton.titleLabel.font = TGSystemFontOfSize(17.0f);
            [_cancelButton setTitle:TGLocalized(@"Common.Cancel") forState:UIControlStateNormal];
            [_cancelButton setTitleColor:TGAccentColor()];
            [_cancelButton addTarget:self action:@selector(cancelPressed) forControlEvents:UIControlEventTouchUpInside];
            [_cancelButton sizeToFit];
            [self addSubview:_cancelButton];
            
            setViewFrame(_cancelButton, CGRectMake(CGFloor((self.frame.size.width - _cancelButton.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _cancelButton.frame.size.height) / 2.0f) - 1.0f, _cancelButton.frame.size.width, _cancelButton.frame.size.height));
        }
        
        if (!isAlreadyLocked)
        {
            _cancelButton.alpha = 0.0f;
            _cancelButton.userInteractionEnabled = false;
        }
        
        _recordDurationLabel.text = @"0:00,00";
        
        if (_recordIndicatorView.superview == nil)
            [self addSubview:_recordIndicatorView];
        [_recordIndicatorView.layer removeAllAnimations];
        
        if (_recordDurationLabel.superview == nil)
            [self addSubview:_recordDurationLabel];
        [_recordDurationLabel.layer removeAllAnimations];
        
        _slideToCancelArrow.transform = CGAffineTransformMakeTranslation(300.0f, 0.0f);
        _slideToCancelLabel.transform = CGAffineTransformMakeTranslation(300.0f, 0.0f);
        
        int animationCurveOption = iosMajorVersion() >= 7 ? (7 << 16) : 0;
        
        [UIView animateWithDuration:0.25 delay:0.06 options:animationCurveOption animations:^
        {
            _recordIndicatorView.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        [UIView animateWithDuration:0.25 delay:0.0 options:animationCurveOption animations:^
        {
            _recordDurationLabel.alpha = 1.0f;
            _recordDurationLabel.transform = CGAffineTransformIdentity;
        } completion:nil];
        
        if (!isAlreadyLocked)
        {
            if (_slideToCancelLabel.superview == nil)
                [self addSubview:_slideToCancelLabel];
            
            [UIView animateWithDuration:0.18 delay:0.0 options:animationCurveOption animations:^
            {
                _slideToCancelArrow.alpha = 1.0f;
                _slideToCancelArrow.transform = CGAffineTransformIdentity;
                 
                _slideToCancelLabel.alpha = 1.0f;
                _slideToCancelLabel.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
    else
    {
        [self removeDotAnimation];
        NSTimeInterval durationFactor = MIN(0.4, MAX(1.0, velocity / 1000.0));
        
        int options = 0;
        
        if (ABS(CFAbsoluteTimeGetCurrent() - _recordingInterfaceShowTime) < 0.2)
        {
            options = UIViewAnimationOptionBeginFromCurrentState;
        }
        
        int animationCurveOption = iosMajorVersion() >= 7 ? (7 << 16) : 0;
        [UIView animateWithDuration:0.25 * durationFactor delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
        {
            _recordIndicatorView.transform = CGAffineTransformMakeTranslation(-90.0f, 0.0f);
        } completion:^(BOOL finished)
        {
            if (finished)
                [_recordIndicatorView removeFromSuperview];
        }];
        
        [UIView animateWithDuration:0.25 * durationFactor delay:0.05 * durationFactor options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
        {
            _recordDurationLabel.alpha = 0.0f;
            _recordDurationLabel.transform = CGAffineTransformMakeTranslation(-90.0f, 0.0f);
        } completion:^(BOOL finished)
        {
            if (finished)
                [_recordDurationLabel removeFromSuperview];
        }];
        
        [UIView animateWithDuration:0.2 * durationFactor delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
        {
            _slideToCancelArrow.alpha = 0.0f;
            _slideToCancelArrow.transform = CGAffineTransformMakeTranslation(-300, 0.0f);
            _slideToCancelLabel.alpha = 0.0f;
            _slideToCancelLabel.transform = CGAffineTransformMakeTranslation(-200, 0.0f);
            
            CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -22.0f);
            transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
            _cancelButton.transform = transform;
            _cancelButton.alpha = 0.0f;
            
            _sendButton.transform = CGAffineTransformMakeScale(0.01, 0.01);
            _sendButton.alpha = 0.0f;
            
            transform = CGAffineTransformMakeTranslation(0.0f, -44.0f);
            transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
            
            _deleteButton.transform = transform;
            _deleteButton.alpha = 0.0f;
            
            _scrubberView.transform = transform;
            _scrubberView.alpha = 0.0f;
        } completion:nil];
    }
}

- (void)buttonInteractionUpdate:(CGPoint)value
{
    CGFloat valueX = value.x;
    CGFloat offset = valueX * 300.0f;
    
    offset = MAX(0.0f, offset - 5.0f);
    
    _slideToCancelArrow.transform = CGAffineTransformMakeTranslation(-offset, 0.0f);
    
    CGAffineTransform labelTransform = CGAffineTransformIdentity;
    labelTransform = CGAffineTransformTranslate(labelTransform, -offset, 0.0f);
    _slideToCancelLabel.transform = labelTransform;
    
    CGAffineTransform indicatorTransform = CGAffineTransformIdentity;
    CGAffineTransform durationTransform = CGAffineTransformIdentity;
    
    static CGFloat freeOffsetLimit = 35.0f;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        CGFloat labelWidth = [TGLocalized(@"Conversation.SlideToCancel") sizeWithFont:TGSystemFontOfSize(14.0f)].width;
        CGFloat arrowOrigin = CGFloor((TGScreenSize().width - labelWidth) / 2.0f) - 9.0f - 6.0f;
        CGFloat timerWidth = 90.0f;
        
        freeOffsetLimit = MAX(0.0f, arrowOrigin - timerWidth);
    });
    
    if (offset > freeOffsetLimit)
    {
        indicatorTransform = CGAffineTransformMakeTranslation(freeOffsetLimit - offset, 0.0f);
        durationTransform = CGAffineTransformMakeTranslation(freeOffsetLimit - offset, 0.0f);
    }
    
    if (!CGAffineTransformEqualToTransform(indicatorTransform, _recordIndicatorView.transform))
        _recordIndicatorView.transform = indicatorTransform;
    
    if (!CGAffineTransformEqualToTransform(durationTransform, _recordDurationLabel.transform))
        _recordDurationLabel.transform = durationTransform;
}

- (void)setLocked
{
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 22.0f);
    transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
    _cancelButton.alpha = 0.0f;
    _cancelButton.transform = transform;
    _cancelButton.userInteractionEnabled = true;
    
    [UIView animateWithDuration:0.3 delay:0.0 options:7 << 16 animations:^
    {
        _cancelButton.transform = CGAffineTransformIdentity;
        
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -22.0f);
        transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
        _slideToCancelLabel.transform = transform;
    } completion:^(__unused BOOL finished)
    {
        _slideToCancelLabel.transform = CGAffineTransformIdentity;
    }];
    
    [UIView animateWithDuration:0.25 animations:^
    {
        _slideToCancelArrow.alpha = 0.0f;
        _slideToCancelLabel.alpha = 0.0f;
        _cancelButton.alpha = 1.0f;
    }];
}

- (void)setStopped
{
    UIImage *deleteImage = [UIImage imageNamed:@"ModernConversationActionDelete.png"];
    
    _deleteButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
    [_deleteButton setImage:deleteImage forState:UIControlStateNormal];
    _deleteButton.adjustsImageWhenDisabled = false;
    _deleteButton.adjustsImageWhenHighlighted = false;
    [_deleteButton addTarget:self action:@selector(deleteButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_deleteButton];
    
    CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, 45.0f);
    transform = CGAffineTransformScale(transform, 0.88f, 0.88f);
    _deleteButton.transform = transform;
    
    TGModernButton *sendButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 45.0f, 45.0f)];
    sendButton.modernHighlight = true;
    _sendButton = sendButton;
    _sendButton.alpha = 0.0f;
    _sendButton.exclusiveTouch = true;
    [_sendButton setImage:[UIImage imageNamed:@"ModernConversationSend"] forState:UIControlStateNormal];
    _sendButton.adjustsImageWhenHighlighted = false;
    [_sendButton addTarget:self action:@selector(sendButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_sendButton];
    
    _scrubberView = [[TGVideoMessageScrubber alloc] init];
    _scrubberView.dataSource = self.parent;
    _scrubberView.delegate = self.parent;
    [self addSubview:_scrubberView];
    
    [self layoutSubviews];
    
    transform = CGAffineTransformMakeTranslation(0.0f, 44.0f);
    _scrubberView.transform = transform;
    
    int animationCurveOption = iosMajorVersion() >= 7 ? (7 << 16) : 0;
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
    {
        _recordIndicatorView.transform = CGAffineTransformMakeTranslation(-90.0f, 0.0f);
        _recordIndicatorView.alpha = 0.0f;
    } completion:^(BOOL finished)
    {
        if (finished)
        {
            [self removeDotAnimation];
            [_recordIndicatorView removeFromSuperview];
        }
    }];
    
    [UIView animateWithDuration:0.25 delay:0.05 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
    {
        _recordDurationLabel.alpha = 0.0f;
        _recordDurationLabel.transform = CGAffineTransformMakeTranslation(-90.0f, 0.0f);
    } completion:^(BOOL finished)
    {
        if (finished)
            [_recordDurationLabel removeFromSuperview];
    }];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
    {
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -22.0f);
        transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
        _cancelButton.transform = transform;
        _cancelButton.alpha = 0.0f;
    } completion:nil];
    
    [UIView animateWithDuration:0.2 delay:0.07 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
    {
        _deleteButton.transform = CGAffineTransformMakeScale(0.88f, 0.88f);
    } completion:nil];
    
    [UIView animateWithDuration:0.3 animations:^
    {
        _sendButton.alpha = 1.0f;
    }];
}

- (void)showScrubberView
{
    int animationCurveOption = iosMajorVersion() >= 7 ? (7 << 16) : 0;
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | animationCurveOption animations:^
    {
        CGAffineTransform transform = CGAffineTransformMakeTranslation(0.0f, -22.0f);
        transform = CGAffineTransformScale(transform, 0.25f, 0.25f);
    
        _scrubberView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)deleteButtonPressed
{
    _deleteButton.userInteractionEnabled = false;
    
    if (self.deletePressed != nil)
        self.deletePressed();
}

- (void)sendButtonPressed
{
    _sendButton.userInteractionEnabled = false;
    
    if (self.sendPressed != nil)
        self.sendPressed();
}

- (void)cancelPressed
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        if (self.cancel != nil)
            self.cancel();
    });
}

- (void)setDurationString:(NSString *)string
{
    _recordDurationLabel.text = string;
}

- (void)recordingStarted
{
    [self addRecordingDotAnimation];
}

- (void)addRecordingDotAnimation {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
    animation.values = @[@1.0f, @1.0f, @0.0f];
    animation.keyTimes = @[@.0, @0.4546, @0.9091, @1];
    animation.duration = 0.5;
    animation.duration = 0.5;
    animation.autoreverses = true;
    animation.repeatCount = INFINITY;
    
    [_recordIndicatorView.layer addAnimation:animation forKey:@"opacity-dot"];
}

- (void)removeDotAnimation {
    [_recordIndicatorView.layer removeAnimationForKey:@"opacity-dot"];
}

- (void)layoutSubviews
{
    if (_slideToCancelLabel != nil)
    {
        CGRect slideToCancelLabelFrame = viewFrame(_slideToCancelLabel);
        setViewFrame(_slideToCancelLabel, CGRectMake(CGFloor((self.frame.size.width - slideToCancelLabelFrame.size.width) / 2.0f), CGFloor((self.frame.size.height - slideToCancelLabelFrame.size.height) / 2.0f), slideToCancelLabelFrame.size.width, slideToCancelLabelFrame.size.height));
        
        CGRect slideToCancelArrowFrame = viewFrame(_slideToCancelArrow);
        setViewFrame(_slideToCancelArrow, CGRectMake(CGFloor((self.frame.size.width - slideToCancelLabelFrame.size.width) / 2.0f) - slideToCancelArrowFrame.size.width - 7.0f, CGFloor((self.frame.size.height - slideToCancelLabelFrame.size.height) / 2.0f), slideToCancelArrowFrame.size.width, slideToCancelArrowFrame.size.height));
    }
    
    setViewFrame(_sendButton, CGRectMake(self.frame.size.width - _sendButton.frame.size.width, 0.0f, _sendButton.frame.size.width, self.frame.size.height));
    _deleteButton.center = CGPointMake(24.0f, 22.0f);
    setViewFrame(_scrubberView, CGRectMake(46.0f, (self.frame.size.height - 33.0f) / 2.0f, self.frame.size.width - 46.0f * 2.0f, 33.0f));
}

@end
