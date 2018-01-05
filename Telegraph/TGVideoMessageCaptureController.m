#import "TGVideoMessageCaptureController.h"

#import <MTProtoKit/MTTime.h>

#import "TGCameraController.h"
#import "TGTelegraph.h"
#import "TGAppDelegate.h"

#import "TGHacks.h"
#import "TGImageBlur.h"
#import "TGImageUtils.h"
#import "TGPhotoEditorUtils.h"
#import "TGTimerTarget.h"
#import "TGObserverProxy.h"

#import "TGAudioSessionManager.h"
#import "TGMediaAssetImageSignals.h"

#import "TGTelegraphConversationMessageAssetsSource.h"

#import "TGModernButton.h"
#import "TGVideoCameraGLView.h"
#import "TGVideoCameraPipeline.h"
#import "PGCameraVolumeButtonHandler.h"

#import "TGVideoMessageControls.h"
#import "TGVideoMessageRingView.h"
#import "TGVideoMessageScrubber.h"
#import "TGModernGalleryVideoView.h"

const NSTimeInterval TGVideoMessageMaximumDuration = 60.0;

typedef enum
{
    TGVideoMessageTransitionTypeUsual,
    TGVideoMessageTransitionTypeSimplified,
    TGVideoMessageTransitionTypeLegacy
} TGVideoMessageTransitionType;

@interface TGVideoMessageCaptureControllerWindow  : TGOverlayControllerWindow

@property (nonatomic, assign) CGRect controlsFrame;
@property (nonatomic, assign) bool locked;

@end

@interface TGVideoMessageCaptureController () <TGVideoCameraPipelineDelegate, TGVideoMessageScrubberDataSource, TGVideoMessageScrubberDelegate>
{
    SQueue *_queue;
    
    AVCaptureDevicePosition _preferredPosition;
    TGVideoCameraPipeline *_capturePipeline;
    NSURL *_url;
    
    PGCameraVolumeButtonHandler *_buttonHandler;
    bool _autorotationWasEnabled;
    bool _dismissed;
    bool _changing;
    bool _gpuAvailable;
    bool _locked;
    bool _positionChangeLocked;
    bool _alreadyStarted;
    
    CGRect _controlsFrame;
    TGVideoMessageControls *_controlsView;
    TGModernButton *_switchButton;
    
    UIView *_wrapperView;
    
    UIView *_blurView;
    
    UIView *_fadeView;
    UIView *_circleWrapperView;
    UIImageView *_shadowView;
    UIView *_circleView;
    TGVideoCameraGLView *_previewView;
    TGVideoMessageRingView *_ringView;
    
    UIView *_separatorView;
    
    UIImageView *_placeholderView;
    
    bool _automaticDismiss;
    NSTimeInterval _startTimestamp;
    NSTimer *_recordingTimer;
    
    NSTimeInterval _previousDuration;
    NSUInteger _audioRecordingDurationSeconds;
    NSUInteger _audioRecordingDurationMilliseconds;
    
    id _activityHolder;
    SMetaDisposable *_activityDisposable;
    
    SMetaDisposable *_currentAudioSession;
    bool _otherAudioPlaying;
    
    id _didEnterBackgroundObserver;
    
    bool _stopped;
    id _liveUploadData;
    UIImage *_thumbnailImage;
    NSDictionary *_thumbnails;
    NSTimeInterval _duration;
    AVPlayer *_player;
    id _didPlayToEndObserver;
    
    TGModernGalleryVideoView *_videoView;
    UIImageView *_muteView;
    bool _muted;
    
    SMetaDisposable *_thumbnailsDisposable;
}

@property (nonatomic, copy) bool(^isAlreadyLocked)(void);

@end

@implementation TGVideoMessageCaptureController

- (instancetype)initWithParentController:(TGViewController *)parentController controlsFrame:(CGRect)controlsFrame isAlreadyLocked:(bool (^)(void))isAlreadyLocked
{
    self = [super init];
    if (self != nil)
    {
        self.isAlreadyLocked = isAlreadyLocked;
        
        _url = [TGVideoMessageCaptureController tempOutputPath];
        _queue = [[SQueue alloc] init];
        
        _previousDuration = 0.0;
        _preferredPosition = AVCaptureDevicePositionFront;
        
        self.isImportant = true;
        _controlsFrame = controlsFrame;
        
        TGVideoMessageCaptureControllerWindow *window = [[TGVideoMessageCaptureControllerWindow alloc] initWithParentController:parentController contentController:self keepKeyboard:true];
        window.windowLevel = 1000000000.0f - 0.001f;
        window.hidden = false;
        window.controlsFrame = controlsFrame;
        
        _gpuAvailable = true;
        
        _activityDisposable = [[SMetaDisposable alloc] init];
        _currentAudioSession = [[SMetaDisposable alloc] init];
        
        __weak TGVideoMessageCaptureController *weakSelf = self;
        _didEnterBackgroundObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *notification)
        {
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf != nil && !strongSelf->_stopped)
            {
                strongSelf->_automaticDismiss = true;
                strongSelf->_gpuAvailable = false;
                [strongSelf dismiss:true];
            }
        }];
        
        _thumbnailsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_thumbnailsDisposable dispose];
    [[NSNotificationCenter defaultCenter] removeObserver:_didEnterBackgroundObserver];
    [_activityDisposable dispose];
}

+ (NSURL *)tempOutputPath
{
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"cam_%x.mp4", (int)arc4random()]]];
}

- (void)loadView
{
    [super loadView];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    CGRect wrapperFrame = TGIsPad() ? CGRectMake(0.0f, 0.0f, self.view.frame.size.width, CGRectGetMaxY(_controlsFrame)): CGRectMake(0.0f, 0.0f, self.view.frame.size.width, CGRectGetMinY(_controlsFrame));
    
    _wrapperView = [[UIView alloc] initWithFrame:wrapperFrame];
    _wrapperView.clipsToBounds = true;
    [self.view addSubview:_wrapperView];
    
    TGVideoMessageTransitionType type = [self _transitionType];
    CGRect fadeFrame = CGRectMake(0.0f, 0.0f, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    if (type != TGVideoMessageTransitionTypeLegacy)
    {
        UIBlurEffect *effect = nil;
        if (type == TGVideoMessageTransitionTypeSimplified)
            effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        [_wrapperView addSubview:_blurView];
        
        if (type == TGVideoMessageTransitionTypeSimplified)
        {
            _blurView.alpha = 0.0f;
        }
        else
        {
            _fadeView = [[UIView alloc] initWithFrame:fadeFrame];
            _fadeView.alpha = 0.0f;
            _fadeView.backgroundColor = UIColorRGBA(0xffffff, 0.4f);
            [_wrapperView addSubview:_fadeView];
        }
    }
    else
    {
        _fadeView = [[UIView alloc] initWithFrame:fadeFrame];
        _fadeView.alpha = 0.0f;
        _fadeView.backgroundColor = UIColorRGBA(0xffffff, 0.6f);
        [_wrapperView addSubview:_fadeView];
    }
    
    _circleWrapperView = [[UIView alloc] initWithFrame:CGRectMake((_wrapperView.frame.size.width - 216.0f - 38.0f) / 2.0f, _wrapperView.frame.size.height + 100.0f, 216.0f + 38.0f, 216.0f + 38.0f)];
    _circleWrapperView.alpha = 0.0f;
    _circleWrapperView.clipsToBounds = false;
    [_wrapperView addSubview:_circleWrapperView];
    
    _shadowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"VideoMessageShadow"]];
    _shadowView.frame = _circleWrapperView.bounds;
    [_circleWrapperView addSubview:_shadowView];
    
    _circleView = [[UIView alloc] initWithFrame:CGRectInset(_circleWrapperView.bounds, 19.0f, 19.0f)];
    _circleView.clipsToBounds = true;
    _circleView.layer.cornerRadius = _circleView.frame.size.width / 2.0f;
    [_circleWrapperView addSubview:_circleView];
    
    _placeholderView = [[UIImageView alloc] initWithFrame:_circleView.bounds];
    _placeholderView.backgroundColor = [UIColor blackColor];
    _placeholderView.image = [TGVideoMessageCaptureController startImage];
    [_circleView addSubview:_placeholderView];
    
    _ringView = [[TGVideoMessageRingView alloc] initWithFrame:CGRectMake((_circleWrapperView.frame.size.width - 234.0f) / 2.0f, (_circleWrapperView.frame.size.height - 234.0f) / 2.0f, 234.0f, 234.0f)];
    [_circleWrapperView addSubview:_ringView];
    
    CGRect controlsFrame = _controlsFrame;
    CGFloat height = TGIsPad() ? 56.0f : 45.0f;
    controlsFrame.origin.y = CGRectGetMaxY(controlsFrame) - height;
    controlsFrame.size.height = height;
    
    _controlsView = [[TGVideoMessageControls alloc] initWithFrame:controlsFrame];
    _controlsView.clipsToBounds = true;
    _controlsView.parent = self;
    _controlsView.isAlreadyLocked = self.isAlreadyLocked;
    _controlsView.controlsHeight = _controlsFrame.size.height;
    
    __weak TGVideoMessageCaptureController *weakSelf = self;
    _controlsView.cancel = ^
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_automaticDismiss = true;
            [strongSelf dismiss:true];
            
            if (strongSelf.onCancel != nil)
                strongSelf.onCancel();
        }
    };
    _controlsView.deletePressed = ^
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            strongSelf->_automaticDismiss = true;
            [strongSelf dismiss:true];
            
            if (strongSelf.onCancel != nil)
                strongSelf.onCancel();

        };
    };
    _controlsView.sendPressed = ^
    {
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [strongSelf sendPressed];
        };
    };
    [self.view addSubview:_controlsView];
    
    _separatorView = [[UIView alloc] initWithFrame:CGRectMake(_controlsView.frame.origin.x, _controlsFrame.origin.y - TGScreenPixel, _controlsView.frame.size.width, TGScreenPixel)];
    _separatorView.backgroundColor = UIColorRGB(0xb2b2b2);
    _separatorView.userInteractionEnabled = false;
    [self.view addSubview:_separatorView];
    
    if ([TGVideoCameraPipeline cameraPositionChangeAvailable])
    {
        _switchButton = [[TGModernButton alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
        _switchButton.alpha = 0.0f;
        _switchButton.adjustsImageWhenHighlighted = false;
        _switchButton.adjustsImageWhenDisabled = false;
        [_switchButton setImage:[UIImage imageNamed:@"VideoRecordPositionSwitch"] forState:UIControlStateNormal];
        [_switchButton addTarget:self action:@selector(changeCameraPosition) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:_switchButton];
    }
    
    void (^voidBlock)(void) = ^{};
    _buttonHandler = [[PGCameraVolumeButtonHandler alloc] initWithUpButtonPressedBlock:voidBlock upButtonReleasedBlock:voidBlock downButtonPressedBlock:voidBlock downButtonReleasedBlock:voidBlock];
    
    [self configureCamera];
}

- (TGVideoMessageTransitionType)_transitionType
{
    static dispatch_once_t onceToken;
    static TGVideoMessageTransitionType type;
    dispatch_once(&onceToken, ^
    {
        CGSize screenSize = TGScreenSize();
        if (iosMajorVersion() < 8 || (NSInteger)screenSize.height == 480)
            type = TGVideoMessageTransitionTypeLegacy;
        else if (iosMajorVersion() == 8)
            type = TGVideoMessageTransitionTypeSimplified;
        else
            type = TGVideoMessageTransitionTypeUsual;
    });
    
    return type;
}

- (void)setupPreviewView
{
    _previewView = [[TGVideoCameraGLView alloc] initWithFrame:_circleView.bounds];
    [_circleView insertSubview:_previewView belowSubview:_placeholderView];
    
    [self captureStarted];
}

- (void)_transitionIn
{
    TGVideoMessageTransitionType type = [self _transitionType];
    if (type == TGVideoMessageTransitionTypeUsual)
    {
        UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        
        UIView *rootView = TGAppDelegateInstance.rootController.view;
        rootView.superview.backgroundColor = [UIColor whiteColor];
        
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            ((UIVisualEffectView *)_blurView).effect = effect;
            _fadeView.alpha = 1.0f;
        } completion:nil];
    }
    else if (type == TGVideoMessageTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
             _blurView.alpha = 1.0f;
        } completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.25 animations:^
        {
            _fadeView.alpha = 1.0f;
        }];
    }
}

- (void)_transitionOut
{
    TGVideoMessageTransitionType type = [self _transitionType];
    if (type == TGVideoMessageTransitionTypeUsual)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            ((UIVisualEffectView *)_blurView).effect = nil;
            _fadeView.alpha = 0.0f;
         } completion:nil];
    }
    else if (type == TGVideoMessageTransitionTypeSimplified)
    {
        [UIView animateWithDuration:0.22 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^
        {
            _blurView.alpha = 0.0f;
        } completion:nil];
    }
    else
    {
        [UIView animateWithDuration:0.15 animations:^
        {
            _fadeView.alpha = 0.0f;
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    _capturePipeline.renderingEnabled = true;
    
    _startTimestamp = CFAbsoluteTimeGetCurrent();
    
    [_controlsView setShowRecordingInterface:true velocity:0.0f];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:true];
    
    [self _transitionIn];
    
    [self _beginAudioSession:false];
    [_queue dispatch:^
    {
        [_capturePipeline startRunning];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _autorotationWasEnabled = [TGViewController autorotationAllowed];
    [TGViewController disableAutorotation];
    
    _circleWrapperView.transform = CGAffineTransformMakeScale(0.3f, 0.3f);
    
    CGPoint targetPosition = CGPointMake(_wrapperView.frame.size.width / 2.0f, _wrapperView.frame.size.height / 2.0f - _controlsView.frame.size.height);
    switch (self.interfaceOrientation)
    {
        case UIInterfaceOrientationLandscapeLeft:
            targetPosition.x = MIN(_wrapperView.frame.size.width - _circleWrapperView.bounds.size.width / 2.0f - 20.0f, _wrapperView.frame.size.width / 4.0f * 3.0f);
            targetPosition.y = self.view.frame.size.height / 2.0f;
            break;
            
        case UIInterfaceOrientationLandscapeRight:
            targetPosition.x = MAX(_circleWrapperView.bounds.size.width / 2.0f + 20.0f, _wrapperView.frame.size.width / 4.0f);
            targetPosition.y = self.view.frame.size.height / 2.0f;
            break;
            
        default:
            if (self.view.frame.size.height > self.view.frame.size.width && fabs(_wrapperView.frame.size.height - self.view.frame.size.height) < 50.0f)
                targetPosition.y = _wrapperView.frame.size.height / 3.0f - 20.0f;
            
            targetPosition.y = MAX(_circleWrapperView.bounds.size.height / 2.0f + 40.0f, targetPosition.y);
                
            break;
    }
    
    [UIView animateWithDuration:0.5 delay:0.0 usingSpringWithDamping:0.8f initialSpringVelocity:0.2f options:kNilOptions animations:^
    {
        _circleWrapperView.center = targetPosition;
        _circleWrapperView.transform = CGAffineTransformIdentity;
    } completion:nil];
    
    [UIView animateWithDuration:0.2 animations:^
    {
        _circleWrapperView.alpha = 1.0f;
    } completion:nil];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGRect fadeFrame = TGIsPad() ? self.view.bounds : CGRectMake(0.0f, 0.0f, _wrapperView.frame.size.width, _wrapperView.frame.size.height);
    _blurView.frame = fadeFrame;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)__unused toInterfaceOrientation duration:(NSTimeInterval)__unused duration
{
    if (TGIsPad())
    {
        _automaticDismiss = true;
        [self dismiss:true];
    }
}

- (void)dismissImmediately
{
    [super dismiss];
    
    [self _endAudioSession];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:false];
    [self stopCapture];
    
    if (_autorotationWasEnabled)
        [TGViewController enableAutorotation];
}

- (void)dismiss
{
    [self dismiss:true];
}

- (void)dismiss:(bool)cancelled
{
    _dismissed = cancelled;
    
    if (self.onDismiss != nil)
        self.onDismiss(_automaticDismiss);
    
    if (_player != nil)
        [_player pause];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.userInteractionEnabled = false;
    
    [UIView animateWithDuration:0.15 animations:^
    {
        _circleWrapperView.alpha = 0.0f;
        _switchButton.alpha = 0.0f;
    }];
    
    [self _transitionOut];
    
    [_controlsView setShowRecordingInterface:false velocity:0.0f];
    
    TGDispatchAfter(0.3, dispatch_get_main_queue(), ^
    {
        [self dismissImmediately];
    });
}

- (void)complete
{
    if (_stopped)
        return;
    
    [_activityDisposable dispose];
    [self stopRecording];
    
    [self dismiss:false];
}

- (void)buttonInteractionUpdate:(CGPoint)value
{
    [_controlsView buttonInteractionUpdate:value];
}

- (void)setLocked
{
    ((TGVideoMessageCaptureControllerWindow *)self.view.window).locked = true;
    [_controlsView setLocked];
}

- (void)stop
{
    if (!_capturePipeline.isRecording)
        return;
    
    ((TGVideoMessageCaptureControllerWindow *)self.view.window).locked = false;
    _stopped = true;
    _gpuAvailable = false;
    _switchButton.userInteractionEnabled = false;
    
    [_activityDisposable dispose];
    [self stopRecording];
}

- (void)sendPressed
{
    _automaticDismiss = true;
    [self dismiss:false];
    
    [self finishWithURL:_url dimensions:CGSizeMake(240.0f, 240.0f) duration:_duration liveUploadData:_liveUploadData thumbnailImage:_thumbnailImage];
}

- (void)unmutePressed
{
    [self _updateMuted:false];
    
    [[SQueue concurrentDefaultQueue] dispatch:^
    {
        _player.muted = false;
        
        [self _seekToPosition:_controlsView.scrubberView.trimStartValue];
    }];
}

- (void)_stop
{
    [_controlsView setStopped];
    [UIView animateWithDuration:0.2 animations:^
    {
        _switchButton.alpha = 0.0f;
        _ringView.alpha = 0.0f;
    } completion:^(__unused BOOL finished)
    {
        _ringView.hidden = true;
        _switchButton.hidden = true;
    }];
}

- (void)setupVideoView
{
    _controlsView.scrubberView.trimStartValue = 0.0;
    _controlsView.scrubberView.trimEndValue = _duration;
    [_controlsView.scrubberView setTrimApplied:false];
    [_controlsView.scrubberView reloadData];
    
    _player = [[AVPlayer alloc] initWithURL:_url];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _player.muted = true;
    
    _didPlayToEndObserver = [[TGObserverProxy alloc] initWithTarget:self targetSelector:@selector(playerItemDidPlayToEndTime:) name:AVPlayerItemDidPlayToEndTimeNotification object:_player.currentItem];
    
    _videoView = [[TGModernGalleryVideoView alloc] initWithFrame:_previewView.frame player:_player];
    [_previewView.superview insertSubview:_videoView belowSubview:_previewView];
    
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(unmutePressed)];
    [_videoView addGestureRecognizer:gestureRecognizer];
    
    _muted = true;
    _muteView = [[UIImageView alloc] initWithImage:[[TGTelegraphConversationMessageAssetsSource instance] systemUnmuteButton]];
    _muteView.frame = CGRectMake(floor(CGRectGetMidX(_circleView.bounds) - 12.0f), CGRectGetMaxY(_circleView.bounds) - 24.0f - 8.0f, 24.0f, 24.0f);
    [_previewView.superview addSubview:_muteView];
    
    [_player play];
    
    [UIView animateWithDuration:0.1 delay:0.1 options:kNilOptions animations:^
    {
        _previewView.alpha = 0.0f;
    } completion:nil];
}

- (void)_updateMuted:(bool)muted
{
    if (muted == _muted)
        return;
    
    _muted = muted;
    
    UIView *muteButtonView = _muteView;
    [muteButtonView.layer removeAllAnimations];
    
    if ((muteButtonView.transform.a < 0.3f || muteButtonView.transform.a > 1.0f) || muteButtonView.alpha < FLT_EPSILON)
    {
        muteButtonView.transform = CGAffineTransformMakeScale(0.001f, 0.001f);
        muteButtonView.alpha = 0.0f;
    }
    
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState | 7 << 16 animations:^
    {
        muteButtonView.transform = muted ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.001f, 0.001f);
    } completion:nil];
    
    [UIView animateWithDuration:0.2 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
    {
        muteButtonView.alpha = muted ? 1.0f : 0.0f;
    } completion:nil];
}

- (void)_seekToPosition:(NSTimeInterval)position
{
    CMTime targetTime = CMTimeMakeWithSeconds(MIN(position, _duration - 0.1), NSEC_PER_SEC);
    [_player.currentItem seekToTime:targetTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

- (void)playerItemDidPlayToEndTime:(NSNotification *)__unused notification
{
    [self _seekToPosition:_controlsView.scrubberView.trimStartValue];
    
    TGDispatchOnMainThread(^
    {
        [self _updateMuted:true];
        
        [[SQueue concurrentDefaultQueue] dispatch:^
        {
            _player.muted = true;
        }];
    });
}

#pragma mark -

- (void)changeCameraPosition
{
    if (_positionChangeLocked)
        return;
    
    _preferredPosition = (_preferredPosition == AVCaptureDevicePositionFront) ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    
    _gpuAvailable = false;
    [_previewView removeFromSuperview];
    _previewView = nil;

    _ringView.alpha = 0.0f;
    
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [UIView transitionWithView:_circleWrapperView duration:0.4f options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionCurveEaseOut animations:^
        {
            _placeholderView.hidden = false;
        } completion:^(__unused BOOL finished)
        {
            _ringView.alpha = 1.0f;
            _gpuAvailable = true;
        }];
        
        [_capturePipeline setCameraPosition:_preferredPosition];
        
        _positionChangeLocked = true;
        TGDispatchAfter(1.0, dispatch_get_main_queue(), ^
        {
            _positionChangeLocked = false;
        });
    });
}

#pragma mark -

- (void)startRecording
{
    [_buttonHandler ignoreEventsFor:1.0f andDisable:false];
    [_capturePipeline startRecording:_url preset:TGMediaVideoConversionPresetVideoMessage liveUpload:true];
    
    [self startRecordingTimer];
}

- (void)stopRecording
{
    [_capturePipeline stopRecording];
    [_buttonHandler ignoreEventsFor:1.0f andDisable:true];
}

- (void)finishWithURL:(NSURL *)url dimensions:(CGSize)dimensions duration:(NSTimeInterval)duration liveUploadData:(TGLiveUploadActorData *)liveUploadData thumbnailImage:(UIImage *)thumbnailImage
{
    if (duration < 1.0)
        _dismissed = true;
    
    CGFloat minSize = MIN(thumbnailImage.size.width, thumbnailImage.size.height);
    CGFloat maxSize = MAX(thumbnailImage.size.width, thumbnailImage.size.height);
    
    bool mirrored = true;
    UIImageOrientation orientation = [self orientationForThumbnailWithTransform:_capturePipeline.videoTransform mirrored:mirrored];
    
    UIImage *image = TGPhotoEditorCrop(thumbnailImage, nil, orientation, 0.0f, CGRectMake((maxSize - minSize) / 2.0f, 0.0f, minSize, minSize), mirrored, CGSizeMake(240.0f, 240.0f), thumbnailImage.size, true);
    
    NSDictionary *fileDictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:NULL];
    NSUInteger fileSize = (NSUInteger)[fileDictionary fileSize];
    
    UIImage *startImage = TGSecretBlurredAttachmentImage(image, image.size, NULL, false);
    [TGVideoMessageCaptureController saveStartImage:startImage];
    
    TGVideoEditAdjustments *adjustments = nil;
    if (_stopped)
    {
        NSTimeInterval trimStartValue = _controlsView.scrubberView.trimStartValue;
        NSTimeInterval trimEndValue = _controlsView.scrubberView.trimEndValue;
        
        if (trimStartValue > DBL_EPSILON || trimEndValue < _duration - DBL_EPSILON)
        {
            adjustments = [TGVideoEditAdjustments editAdjustmentsWithOriginalSize:dimensions cropRect:CGRectMake(0.0f, 0.0f, dimensions.width, dimensions.height) cropOrientation:UIImageOrientationUp cropLockedAspectRatio:1.0 cropMirrored:false trimStartValue:trimStartValue trimEndValue:trimEndValue paintingData:nil sendAsGif:false preset:TGMediaVideoConversionPresetVideoMessage];
            
            duration = trimEndValue - trimStartValue;
        }
        
        if (trimStartValue > DBL_EPSILON)
        {
            NSArray *thumbnail = [self thumbnailsForTimestamps:@[@(trimStartValue)]];
            image = thumbnail.firstObject;
        }
    }
    
    if (!_dismissed && !_changing && self.finishedWithVideo != nil)
        self.finishedWithVideo(url, image, fileSize, duration, dimensions, liveUploadData, adjustments);
    else
        [[NSFileManager defaultManager] removeItemAtURL:url error:NULL];
    
    _changing = false;
}

- (UIImageOrientation)orientationForThumbnailWithTransform:(CGAffineTransform)transform mirrored:(bool)mirrored
{
    CGFloat angle = atan2(transform.b, transform.a);
    NSInteger degrees =  (360 + (NSInteger)TGRadiansToDegrees(angle)) % 360;
    
    switch (degrees)
    {
        case 90:
            return mirrored ? UIImageOrientationLeft : UIImageOrientationRight;
            break;
            
        case 180:
            return UIImageOrientationDown;
            break;
            
        case 270:
            return mirrored ? UIImageOrientationLeft : UIImageOrientationRight;
            
        default:
            break;
    }
    
    return UIImageOrientationUp;
}

#pragma mark -

- (void)startRecordingTimer
{
    [_controlsView recordingStarted];
    [_controlsView setDurationString:@"0:00,00"];
    
    _audioRecordingDurationSeconds = 0;
    _audioRecordingDurationMilliseconds = 0.0;
    _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:2.0 / 60.0 repeat:false];
}

- (void)timerEvent
{
    if (_recordingTimer != nil)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
    }
    
    NSTimeInterval recordingDuration = _capturePipeline.videoDuration;
    if (isnan(recordingDuration))
        recordingDuration = 0.0;
    
    if (recordingDuration < _previousDuration)
        recordingDuration = _previousDuration;
    
    _previousDuration = recordingDuration;
    [_ringView setValue:recordingDuration / TGVideoMessageMaximumDuration];
    
    CFAbsoluteTime currentTime = MTAbsoluteSystemTime();
    NSUInteger currentDurationSeconds = (NSUInteger)recordingDuration;
    NSUInteger currentDurationMilliseconds = (int)(recordingDuration * 100.0f) % 100;
    if (currentDurationSeconds == _audioRecordingDurationSeconds && currentDurationMilliseconds == _audioRecordingDurationMilliseconds)
    {
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:MAX(0.01, _audioRecordingDurationSeconds + 2.0 / 60.0 - currentTime) repeat:false];
    }
    else
    {
        _audioRecordingDurationSeconds = currentDurationSeconds;
        _audioRecordingDurationMilliseconds = currentDurationMilliseconds;
        [_controlsView setDurationString:[[NSString alloc] initWithFormat:@"%d:%02d,%02d", (int)_audioRecordingDurationSeconds / 60, (int)_audioRecordingDurationSeconds % 60, (int)_audioRecordingDurationMilliseconds]];
        _recordingTimer = [TGTimerTarget scheduledMainThreadTimerWithTarget:self action:@selector(timerEvent) interval:2.0 / 60.0 repeat:false];
    }
    
    if (recordingDuration >= TGVideoMessageMaximumDuration)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
        
        _automaticDismiss = true;
        [self stop];
        
        if (self.onStop != nil)
            self.onStop();
    }
}

- (void)stopRecordingTimer
{
    if (_recordingTimer != nil)
    {
        [_recordingTimer invalidate];
        _recordingTimer = nil;
    }
}

#pragma mark -

- (void)captureStarted
{
    bool firstTime = !_alreadyStarted;
    _alreadyStarted = true;
    
    _switchButton.frame = CGRectMake(11.0f, _controlsFrame.origin.y - _switchButton.frame.size.height - 7.0f, _switchButton.frame.size.width, _switchButton.frame.size.height);
    
    NSTimeInterval delay = firstTime ? 0.1 : 0.2;
    [UIView animateWithDuration:0.3 delay:delay options:kNilOptions animations:^
    {
        _placeholderView.alpha = 0.0f;
        _switchButton.alpha = 1.0f;
    } completion:^(__unused BOOL finished)
    {
        _placeholderView.hidden = true;
        _placeholderView.alpha = 1.0f;
    }];
    
    if (firstTime)
    {
        TGDispatchAfter(0.2, dispatch_get_main_queue(), ^
        {
            [self startRecording];
        });
    }
}

- (void)stopCapture
{
    [_capturePipeline stopRunning];
}

- (void)configureCamera
{
    _capturePipeline = [[TGVideoCameraPipeline alloc] initWithDelegate:self position:_preferredPosition callbackQueue:dispatch_get_main_queue()];
    _capturePipeline.orientation = (AVCaptureVideoOrientation)self.interfaceOrientation;
    
    __weak TGVideoMessageCaptureController *weakSelf = self;
    _capturePipeline.micLevel = ^(CGFloat level)
    {
        TGDispatchOnMainThread(^
        {
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.micLevel != nil)
                strongSelf.micLevel(level);
        });
    };
}

#pragma mark -

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline didStopRunningWithError:(NSError *)__unused error
{
}

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer
{
    if (!_gpuAvailable)
        return;
    
    if (!_previewView)
        [self setupPreviewView];
    
    [_previewView displayPixelBuffer:previewPixelBuffer];
}

- (void)capturePipelineDidRunOutOfPreviewBuffers:(TGVideoCameraPipeline *)__unused capturePipeline
{
    if (_gpuAvailable)
        [_previewView flushPixelBufferCache];
}

- (void)capturePipelineRecordingDidStart:(TGVideoCameraPipeline *)__unused capturePipeline
{
    __weak TGVideoMessageCaptureController *weakSelf = self;
    [_activityDisposable setDisposable:[[[SSignal complete] delay:0.3 onQueue:[SQueue mainQueue]] startWithNext:nil error:nil completed:^{
        __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
        if (strongSelf != nil && strongSelf->_requestActivityHolder) {
            strongSelf->_activityHolder = strongSelf->_requestActivityHolder();
        }
    }]];
}

- (void)capturePipelineRecordingWillStop:(TGVideoCameraPipeline *)__unused capturePipeline
{
}

- (void)capturePipelineRecordingDidStop:(TGVideoCameraPipeline *)__unused capturePipeline duration:(NSTimeInterval)duration liveUploadData:(id)liveUploadData thumbnailImage:(UIImage *)thumbnailImage thumbnails:(NSDictionary *)thumbnails
{
    if (_stopped && duration > 0.33)
    {
        _duration = duration;
        _liveUploadData = liveUploadData;
        _thumbnailImage = thumbnailImage;
        _thumbnails = thumbnails;
        TGDispatchOnMainThread(^
        {
            [self _stop];
            [self setupVideoView];
        });
    }
    else
    {
        [self finishWithURL:_url dimensions:CGSizeMake(240.0f, 240.0f) duration:duration liveUploadData:liveUploadData thumbnailImage:thumbnailImage];
    }
}

- (void)capturePipeline:(TGVideoCameraPipeline *)__unused capturePipeline recordingDidFailWithError:(NSError *)__unused error
{
}

#pragma mark - 

- (void)_beginAudioSession:(bool)speaker
{
    [_queue dispatch:^
    {
        _otherAudioPlaying = [[AVAudioSession sharedInstance] isOtherAudioPlaying];
        
        __weak TGVideoMessageCaptureController *weakSelf = self;
        [_currentAudioSession setDisposable:[[TGAudioSessionManager instance] requestSessionWithType:speaker ? TGAudioSessionTypePlayAndRecordHeadphones : TGAudioSessionTypePlayAndRecord interrupted:^
        {
            __strong TGVideoMessageCaptureController *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                strongSelf->_automaticDismiss = true;
                [strongSelf complete];
            }
        }]];
    }];
}

- (void)_endAudioSession
{
    id<SDisposable> currentAudioSession = _currentAudioSession;
    [_queue dispatch:^
    {
        [currentAudioSession dispose];
    }];
}

#pragma mark -

static UIImage *startImage = nil;

+ (NSString *)_startImagePath
{
    return [[TGAppDelegate cachePath] stringByAppendingPathComponent:@"startImage.jpg"];
}

+ (UIImage *)startImage
{
    if (startImage == nil)
        startImage = [UIImage imageWithContentsOfFile:[self _startImagePath]] ? : [UIImage imageNamed:@"VideoMessagePlaceholder.jpg"];
    
    return startImage;
}

+ (void)saveStartImage:(UIImage *)image
{
    if (image == nil)
        return;
    
    [self clearStartImage];
    
    startImage = image;
    
    NSData *data = UIImageJPEGRepresentation(image, 0.8f);
    [data writeToFile:[self _startImagePath] atomically:true];
}

+ (void)clearStartImage
{
    startImage = nil;
    [[NSFileManager defaultManager] removeItemAtPath:[self _startImagePath] error:NULL];
}

+ (void)requestCameraAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock
{
    if (iosMajorVersion() < 7)
    {
        if (resultBlock != nil)
            resultBlock(true, false);
        return;
    }
    
    bool wasNotDetermined = ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusNotDetermined);
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted)
    {
        TGDispatchOnMainThread(^
        {
            if (resultBlock != nil)
                resultBlock(granted, wasNotDetermined);
        });
    }];
}

+ (void)requestMicrophoneAccess:(void (^)(bool granted, bool wasNotDetermined))resultBlock
{
    if (iosMajorVersion() < 7)
    {
        if (resultBlock != nil)
            resultBlock(true, false);
        return;
    }
    
    bool wasNotDetermined = ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio] == AVAuthorizationStatusNotDetermined);
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted)
    {
        TGDispatchOnMainThread(^
        {
            if (resultBlock != nil)
                resultBlock(granted, wasNotDetermined);
        });
    }];
}

#pragma mark - Scrubbing

- (NSTimeInterval)videoScrubberDuration:(TGVideoMessageScrubber *)__unused videoScrubber
{
    return _duration;
}

- (void)videoScrubberDidBeginScrubbing:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (void)videoScrubberDidEndScrubbing:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber valueDidChange:(NSTimeInterval)__unused position
{
}

#pragma mark - Trimming

- (void)videoScrubberDidBeginEditing:(TGVideoMessageScrubber *)__unused videoScrubber
{
    [_player pause];
}

- (void)videoScrubberDidEndEditing:(TGVideoMessageScrubber *)videoScrubber endValueChanged:(bool)endValueChanged
{
    [self updatePlayerRange:videoScrubber.trimEndValue];
    
    if (endValueChanged)
        [self _seekToPosition:videoScrubber.trimStartValue];
    
    [_player play];
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber editingStartValueDidChange:(NSTimeInterval)startValue
{
    [self _seekToPosition:startValue];
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber editingEndValueDidChange:(NSTimeInterval)endValue
{
   [self _seekToPosition:endValue];
}

- (void)updatePlayerRange:(NSTimeInterval)trimEndValue
{
    _player.currentItem.forwardPlaybackEndTime = CMTimeMakeWithSeconds(trimEndValue, NSEC_PER_SEC);
}

#pragma mark - Thumbnails

- (CGFloat)videoScrubberThumbnailAspectRatio:(TGVideoMessageScrubber *)__unused videoScrubber
{
    return 1.0f;
}

- (NSArray *)videoScrubber:(TGVideoMessageScrubber *)videoScrubber evenlySpacedTimestamps:(NSInteger)count startingAt:(NSTimeInterval)startTimestamp endingAt:(NSTimeInterval)endTimestamp
{
    if (endTimestamp < startTimestamp)
        return nil;
    
    if (count == 0)
        return nil;
    
    NSTimeInterval duration = [self videoScrubberDuration:videoScrubber];
    if (endTimestamp > duration)
        endTimestamp = duration;
    
    NSTimeInterval interval = (endTimestamp - startTimestamp) / count;
    
    NSMutableArray *timestamps = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < count; i++)
        [timestamps addObject:@(startTimestamp + i * interval)];
    
    return timestamps;
}

- (NSArray *)thumbnailsForTimestamps:(NSArray *)timestamps
{
    NSArray *thumbnailTimestamps = [_thumbnails.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *thumbnails = [[NSMutableArray alloc] init];
    
    __block NSUInteger i = 1;
    [timestamps enumerateObjectsUsingBlock:^(NSNumber *timestampVal, __unused NSUInteger index, __unused BOOL *stop)
    {
        NSTimeInterval timestamp = timestampVal.doubleValue;
        NSNumber *closestTimestamp = [self closestTimestampForTimestamp:timestamp timestamps:thumbnailTimestamps start:i finalIndex:&i];
        
        [thumbnails addObject:_thumbnails[closestTimestamp]];
    }];
    
    return thumbnails;
}

- (NSNumber *)closestTimestampForTimestamp:(NSTimeInterval)timestamp timestamps:(NSArray *)timestamps start:(NSUInteger)start finalIndex:(NSUInteger *)finalIndex
{
    NSTimeInterval leftTimestamp = [timestamps[start - 1] doubleValue];
    NSTimeInterval rightTimestamp = [timestamps[start] doubleValue];
    
    if (fabs(leftTimestamp - timestamp) < fabs(rightTimestamp - timestamp))
    {
        *finalIndex = start;
        return timestamps[start - 1];
    }
    else
    {
        if (start == timestamps.count - 1)
        {
            *finalIndex = start;
            return timestamps[start];
        }
        
        return [self closestTimestampForTimestamp:timestamp timestamps:timestamps start:start + 1 finalIndex:finalIndex];
    }
}

- (void)videoScrubber:(TGVideoMessageScrubber *)__unused videoScrubber requestThumbnailImagesForTimestamps:(NSArray *)timestamps size:(CGSize)__unused size isSummaryThumbnails:(bool)isSummaryThumbnails
{
    if (timestamps.count == 0)
        return;
    
    NSArray *thumbnails = [self thumbnailsForTimestamps:timestamps];
    [thumbnails enumerateObjectsUsingBlock:^(UIImage *image, NSUInteger index, __unused BOOL *stop)
    {
        if (index < timestamps.count)
            [_controlsView.scrubberView setThumbnailImage:image forTimestamp:[timestamps[index] doubleValue] isSummaryThubmnail:isSummaryThumbnails];
    }];
}

- (void)videoScrubberDidFinishRequestingThumbnails:(TGVideoMessageScrubber *)__unused videoScrubber
{
    [_controlsView showScrubberView];
}

- (void)videoScrubberDidCancelRequestingThumbnails:(TGVideoMessageScrubber *)__unused videoScrubber
{
}

- (CGSize)videoScrubberOriginalSize:(TGVideoMessageScrubber *)__unused videoScrubber cropRect:(CGRect *)cropRect cropOrientation:(UIImageOrientation *)cropOrientation cropMirrored:(bool *)cropMirrored
{
    if (cropRect != NULL)
        *cropRect = CGRectMake(0.0f, 0.0f, 240.0f, 240.0f);
    
    if (cropOrientation != NULL)
    {
        if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
            *cropOrientation = UIImageOrientationUp;
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeLeft)
            *cropOrientation = UIImageOrientationRight;
        else if (self.interfaceOrientation == UIInterfaceOrientationLandscapeRight)
            *cropOrientation = UIImageOrientationLeft;
    }
    
    if (cropMirrored != NULL)
        *cropMirrored = false;
    
    return CGSizeMake(240.0f, 240.0f);
}

@end


@implementation TGVideoMessageCaptureControllerWindow

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    bool flag = [super pointInside:point withEvent:event];
    if (_locked)
    {
        if (point.x >= self.frame.size.width - 60.0f && point.y >= self.controlsFrame.origin.y && point.y < CGRectGetMaxY(self.controlsFrame))
            return false;
    }
    return flag;
}

@end
