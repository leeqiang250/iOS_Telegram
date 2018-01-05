#import "TGAttachmentCameraView.h"
#import "TGMenuSheetView.h"
#import "TGAttachmentMenuCell.h"

#import "PGCamera.h"
#import "TGCameraPreviewView.h"
#import "TGPhotoEditorUtils.h"

#import <AVFoundation/AVFoundation.h>

@interface TGAttachmentCameraView ()
{
    UIView *_wrapperView;
    UIView *_fadeView;
    UIImageView *_iconView;
    UIImageView *_cornersView;
    UIView *_zoomedView;
    
    TGCameraPreviewView *_previewView;
    __weak PGCamera *_camera;
}
@end

@implementation TGAttachmentCameraView

- (instancetype)initForSelfPortrait:(bool)selfPortrait
{
    self = [super initWithFrame:CGRectZero];
    if (self != nil)
    {
        self.backgroundColor = [UIColor clearColor];
        
        _wrapperView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 84.0f, 84.0f)];
        [self addSubview:_wrapperView];
        
        PGCamera *camera = nil;
        if ([PGCamera cameraAvailable])
        {
            camera = [[PGCamera alloc] initWithMode:PGCameraModePhoto position:selfPortrait ? PGCameraPositionFront : PGCameraPositionUndefined];
        }
        _camera = camera;
        
        _previewView = [[TGCameraPreviewView alloc] initWithFrame:CGRectMake(0, 0, 84.0f, 84.0f)];
        [_wrapperView addSubview:_previewView];
        [camera attachPreviewView:_previewView];
        
        _iconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"AttachmentMenuInteractiveCameraIcon"]];
        [self addSubview:_iconView];
        
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture:)]];
        
        [self setInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation] animated:false];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleOrientationChange:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
        
        _fadeView = [[UIView alloc] initWithFrame:self.bounds];
        _fadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _fadeView.backgroundColor = [UIColor blackColor];
        _fadeView.hidden = true;
        [self addSubview:_fadeView];
        
        if (!TGMenuSheetUseEffectView)
        {
            static dispatch_once_t onceToken;
            static UIImage *cornersImage;
            dispatch_once(&onceToken, ^
            {
                CGRect rect = CGRectMake(0, 0, TGAttachmentMenuCellCornerRadius * 2 + 1.0f, TGAttachmentMenuCellCornerRadius * 2 + 1.0f);
                
                UIGraphicsBeginImageContextWithOptions(rect.size, false, 0);
                CGContextRef context = UIGraphicsGetCurrentContext();
                
                CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                CGContextFillRect(context, rect);
                
                CGContextSetBlendMode(context, kCGBlendModeClear);
                
                CGContextSetFillColorWithColor(context, [UIColor clearColor].CGColor);
                CGContextFillEllipseInRect(context, rect);
                
                cornersImage = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius, TGAttachmentMenuCellCornerRadius)];
                
                UIGraphicsEndImageContext();
            });
            
            _cornersView = [[UIImageView alloc] initWithImage:cornersImage];
            _cornersView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _cornersView.frame = _previewView.bounds;
            [_previewView addSubview:_cornersView];
        }
        
        _zoomedView = [[UIView alloc] initWithFrame:self.bounds];
        _zoomedView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _zoomedView.backgroundColor = [UIColor whiteColor];
        _zoomedView.alpha = 0.0f;
        _zoomedView.userInteractionEnabled = false;
        [self addSubview:_zoomedView];
    }
    return self;
}

- (void)dealloc
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview == _wrapperView && _camera != nil)
        [self stopPreview];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)setZoomedProgress:(CGFloat)progress
{
    _zoomedView.alpha = progress;
}

- (TGCameraPreviewView *)previewView
{
    return _previewView;
}

- (bool)previewViewAttached
{
    return _previewView.superview == _wrapperView;
}

- (void)detachPreviewView
{
    [UIView animateWithDuration:0.1f animations:^
    {
        _cornersView.alpha = 0.0f;
    }];
    _iconView.alpha = 0.0f;
}

- (void)attachPreviewViewAnimated:(bool)animated
{
    [_wrapperView addSubview:_previewView];
    [self setNeedsLayout];
    
    if (animated)
    {
        _iconView.alpha = 0.0f;
        [UIView animateWithDuration:0.2 animations:^
        {
            _iconView.alpha = 1.0f;
        }];
    }
}

- (void)willAttachPreviewView
{
    [UIView animateWithDuration:0.1f delay:0.1f options:kNilOptions animations:^
    {
        _cornersView.alpha = 1.0f;
    } completion:nil];
}

- (void)tapGesture:(UITapGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateRecognized)
    {
        if (_pressed)
            _pressed();
    }
}

- (void)startPreview
{
    PGCamera *camera = _camera;
    [camera startCaptureForResume:false completion:nil];
}

- (void)stopPreview
{
    PGCamera *camera = _camera;
    [camera stopCaptureForPause:false completion:nil];
    _camera = nil;
}

- (void)pausePreview
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview != _wrapperView)
        return;
    
    PGCamera *camera = _camera;
    [camera stopCaptureForPause:true completion:nil];
}

- (void)resumePreview
{
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview != _wrapperView)
        return;
    
    PGCamera *camera = _camera;
    [camera startCaptureForResume:true completion:nil];
}

- (void)handleOrientationChange:(NSNotification *)__unused notification
{
    [self setInterfaceOrientation:[[UIApplication sharedApplication] statusBarOrientation] animated:true];
}

- (void)setInterfaceOrientation:(UIInterfaceOrientation)orientation animated:(bool)animated
{
    void(^block)(void) = ^
    {
        _wrapperView.transform = CGAffineTransformMakeRotation(-1 * TGRotationForInterfaceOrientation(orientation));
    };
    
    if (animated)
        [UIView animateWithDuration:0.3f animations:block];
    else
        block();
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    TGCameraPreviewView *previewView = _previewView;
    if (previewView.superview == _wrapperView)
        previewView.frame = self.bounds;
    
    _iconView.frame = CGRectMake((self.frame.size.width - _iconView.frame.size.width) / 2, (self.frame.size.height - _iconView.frame.size.height) / 2, _iconView.frame.size.width, _iconView.frame.size.height);
}

@end
