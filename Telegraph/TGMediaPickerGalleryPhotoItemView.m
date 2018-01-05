#import "TGMediaPickerGalleryPhotoItemView.h"

#import "TGFont.h"
#import "TGStringUtils.h"
#import "TGMediaAssetImageSignals.h"

#import "TGPhotoEditorUtils.h"

#import "TGModernGalleryZoomableScrollView.h"
#import "TGMessageImageViewOverlayView.h"
#import "TGImageView.h"

#import "TGMediaSelectionContext.h"

#import "TGMediaPickerGalleryPhotoItem.h"

@interface TGMediaPickerGalleryPhotoItemView ()
{
    UILabel *_fileInfoLabel;
    
    TGMessageImageViewOverlayView *_progressView;
    bool _progressVisible;
    void (^_currentAvailabilityObserver)(bool);
    
    UIView *_temporaryRepView;
    
    SMetaDisposable *_attributesDisposable;
}
@end

@implementation TGMediaPickerGalleryPhotoItemView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
        _imageView = [[TGModernGalleryImageItemImageView alloc] init];
        _imageView.progressChanged = ^(CGFloat value)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            [strongSelf setProgressVisible:value < 1.0f - FLT_EPSILON value:value animated:true];
        };
        _imageView.availabilityStateChanged = ^(bool available)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                if (strongSelf->_currentAvailabilityObserver)
                    strongSelf->_currentAvailabilityObserver(available);
            }
        };
        [self.scrollView addSubview:_imageView];
        
        _fileInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
        _fileInfoLabel.backgroundColor = [UIColor clearColor];
        _fileInfoLabel.font = TGSystemFontOfSize(13);
        _fileInfoLabel.textAlignment = NSTextAlignmentCenter;
        _fileInfoLabel.textColor = [UIColor whiteColor];
    }
    return self;
}

- (void)dealloc
{
    [_attributesDisposable dispose];
}

- (void)setHiddenAsBeingEdited:(bool)hidden
{
    self.imageView.hidden = hidden;
    _temporaryRepView.hidden = hidden;
}

- (void)prepareForRecycle
{
    _imageView.hidden = false;
    [_imageView reset];
    [self setProgressVisible:false value:0.0f animated:false];
}

- (void)setItem:(TGMediaPickerGalleryPhotoItem *)item synchronously:(bool)synchronously
{
    [super setItem:item synchronously:synchronously];
    
    _imageSize = item.asset.dimensions;
    [self reset];
    
    if (item.asset == nil)
    {
        [self.imageView reset];
    }
    else
    {
        __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
        void (^fadeOutRepView)(void) = ^
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (strongSelf->_temporaryRepView == nil)
                return;
            
            UIView *repView = strongSelf->_temporaryRepView;
            strongSelf->_temporaryRepView = nil;
            [UIView animateWithDuration:0.2f animations:^
            {
                repView.alpha = 0.0f;
            } completion:^(__unused BOOL finished)
            {
                [repView removeFromSuperview];
            }];
        };

        SSignal *assetSignal = [TGMediaAssetImageSignals imageForAsset:item.asset imageType:(item.immediateThumbnailImage != nil) ? TGMediaAssetImageTypeScreen : TGMediaAssetImageTypeFastScreen size:CGSizeMake(1280, 1280)];
        
        SSignal *imageSignal = assetSignal;
        if (item.editingContext != nil)
        {
            imageSignal = [[[item.editingContext imageSignalForItem:item.editableMediaItem] deliverOn:[SQueue mainQueue]] mapToSignal:^SSignal *(id result)
            {
                __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
                if (strongSelf == nil)
                    return [SSignal complete];
                
                if (result == nil)
                {
                    return [[assetSignal deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                    {
                        fadeOutRepView();
                    }];
                }
                else if ([result isKindOfClass:[UIView class]])
                {
                    [strongSelf _setTemporaryRepView:result];
                    return [[SSignal single:nil] deliverOn:[SQueue mainQueue]];
                }
                else
                {
                    return [[[SSignal single:result] deliverOn:[SQueue mainQueue]] afterNext:^(__unused id next)
                    {
                        fadeOutRepView();
                    }];
                }
            }];
        }
        
        if (item.immediateThumbnailImage != nil)
        {
            imageSignal = [[SSignal single:item.immediateThumbnailImage] then:imageSignal];
            item.immediateThumbnailImage = nil;
        }
        
        [self.imageView setSignal:[[imageSignal deliverOn:[SQueue mainQueue]] afterNext:^(id next)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if ([next isKindOfClass:[UIImage class]])
                strongSelf->_imageSize = ((UIImage *)next).size;
            
            [strongSelf reset];
        }]];
        
        if (!item.asFile)
            return;
        
        _fileInfoLabel.text = nil;
        
        if (_attributesDisposable == nil)
            _attributesDisposable = [[SMetaDisposable alloc] init];
        
        [_attributesDisposable setDisposable:[[[TGMediaAssetImageSignals fileAttributesForAsset:item.asset] deliverOn:[SQueue mainQueue]] startWithNext:^(TGMediaAssetImageFileAttributes *next)
        {
            __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            NSString *extension = next.fileName.pathExtension.uppercaseString;
            NSString *fileSize = [TGStringUtils stringForFileSize:next.fileSize precision:2];
            NSString *dimensions = [NSString stringWithFormat:@"%dx%d", (int)next.dimensions.width, (int)next.dimensions.height];
            
            strongSelf->_fileInfoLabel.text = [NSString stringWithFormat:@"%@ • %@ • %@", extension, fileSize, dimensions];
        }]];
    }
}

- (void)_setTemporaryRepView:(UIView *)view
{
    [_temporaryRepView removeFromSuperview];
    _temporaryRepView = view;
    
    _imageSize = TGScaleToSize(view.frame.size, self.containerView.frame.size);
    
    view.hidden = self.imageView.hidden;
    view.frame = CGRectMake((self.containerView.frame.size.width - _imageSize.width) / 2.0f, (self.containerView.frame.size.height - _imageSize.height) / 2.0f, _imageSize.width, _imageSize.height);
    
    [self.containerView addSubview:view];
}

- (void)setProgressVisible:(bool)progressVisible value:(CGFloat)value animated:(bool)animated
{
    _progressVisible = progressVisible;
    
    if (progressVisible && _progressView == nil)
    {
        _progressView = [[TGMessageImageViewOverlayView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 50.0f, 50.0f)];
        _progressView.userInteractionEnabled = false;
        
        _progressView.frame = (CGRect){{CGFloor((self.frame.size.width - _progressView.frame.size.width) / 2.0f), CGFloor((self.frame.size.height - _progressView.frame.size.height) / 2.0f)}, _progressView.frame.size};
    }
    
    if (progressVisible)
    {
        if (_progressView.superview == nil)
            [self.containerView addSubview:_progressView];
        
        _progressView.alpha = 1.0f;
    }
    else if (_progressView.superview != nil)
    {
        if (animated)
        {
            [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^
            {
                _progressView.alpha = 0.0f;
            } completion:^(BOOL finished)
            {
                if (finished)
                    [_progressView removeFromSuperview];
            }];
        }
        else
            [_progressView removeFromSuperview];
    }
    
    [_progressView setProgress:value cancelEnabled:false animated:animated];
}

- (void)singleTap
{
    if ([self.item conformsToProtocol:@protocol(TGModernGallerySelectableItem)])
    {
        TGMediaSelectionContext *selectionContext = ((id<TGModernGallerySelectableItem>)self.item).selectionContext;
        id<TGMediaSelectableItem> item = ((id<TGModernGallerySelectableItem>)self.item).selectableMediaItem;
        
        [selectionContext toggleItemSelection:item animated:true sender:nil];
    }
    else
    {
        id<TGModernGalleryItemViewDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(itemViewDidRequestInterfaceShowHide:)])
            [delegate itemViewDidRequestInterfaceShowHide:self];
    }
}

- (UIView *)footerView
{
    if (((TGMediaPickerGalleryItem *)self.item).asFile)
        return _fileInfoLabel;
    
    return nil;
}

- (SSignal *)contentAvailabilityStateSignal
{
    __weak TGMediaPickerGalleryPhotoItemView *weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        __strong TGMediaPickerGalleryPhotoItemView *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            [subscriber putNext:@([strongSelf->_imageView isAvailableNow])];
            strongSelf->_currentAvailabilityObserver = ^(bool available)
            {
                [subscriber putNext:@(available)];
            };
        }

        return nil;
    }];
}

- (CGSize)contentSize
{
    return _imageSize;
}

- (UIView *)contentView
{
    return _imageView;
}

- (UIView *)transitionContentView
{
    if (_temporaryRepView != nil)
        return _temporaryRepView;
    
    return [self contentView];
}

- (UIView *)transitionView
{
    return self.containerView;
}

- (CGRect)transitionViewContentRect
{
    UIView *contentView = [self transitionContentView];
    return [contentView convertRect:contentView.bounds toView:[self transitionView]];
}

@end
