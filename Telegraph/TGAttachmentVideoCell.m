#import "TGAttachmentVideoCell.h"
#import "TGModernGalleryTransitionView.h"

#import "TGFont.h"
#import "TGPhotoEditorUtils.h"
#import "TGPaintUtils.h"

#import "TGMediaAsset+TGMediaEditableItem.h"
#import "TGVideoEditAdjustments.h"
#import "TGPaintingData.h"

NSString *const TGAttachmentVideoCellIdentifier = @"AttachmentVideoCell";

@interface TGAttachmentVideoCell () <TGModernGalleryTransitionView>
{
    SMetaDisposable *_adjustmentsDisposable;
}
@end

@implementation TGAttachmentVideoCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
        
        _durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _durationLabel.backgroundColor = [UIColor clearColor];
        _durationLabel.font = TGSystemFontOfSize(12);
        _durationLabel.textColor = [UIColor whiteColor];
        [self addSubview:_durationLabel];
        
        _gradientView.hidden = false;
        
        [self bringSubviewToFront:_cornersView];
        
        _adjustmentsDisposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_adjustmentsDisposable dispose];
}

- (void)setAsset:(TGMediaAsset *)asset signal:(SSignal *)signal
{
    [super setAsset:asset signal:signal];
    
    _durationLabel.text = [NSString stringWithFormat:@"%d:%02d", (int)ceil(asset.videoDuration) / 60, (int)ceil(asset.videoDuration) % 60];
    [_durationLabel sizeToFit];
    CGRect durationFrame = _durationLabel.frame;
    durationFrame.size = CGSizeMake(ceil(_durationLabel.frame.size.width), ceil(_durationLabel.frame.size.height));
    _durationLabel.frame = durationFrame;
    
    if (asset.subtypes & TGMediaAssetSubtypeVideoTimelapse)
        _iconView.image = [UIImage imageNamed:@"ModernMediaItemTimelapseIcon"];
    else if (asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate)
        _iconView.image = [UIImage imageNamed:@"ModernMediaItemSloMoIcon"];
    else
        _iconView.image = [UIImage imageNamed:@"ModernMediaItemVideoIcon"];
    
    SSignal *adjustmentsSignal = [self.editingContext adjustmentsSignalForItem:self.asset];
    
    __weak TGAttachmentVideoCell *weakSelf = self;
    [_adjustmentsDisposable setDisposable:[adjustmentsSignal startWithNext:^(TGVideoEditAdjustments *next)
    {
        __strong TGAttachmentVideoCell *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if ([next isKindOfClass:[TGVideoEditAdjustments class]])
            [strongSelf _layoutImageForOriginalSize:next.originalSize cropRect:next.cropRect cropOrientation:next.cropOrientation];
        else
            [strongSelf _layoutImageWithoutAdjustments];
    }]];
}

- (void)_transformLayoutForOrientation:(UIImageOrientation)orientation originalSize:(CGSize *)inOriginalSize cropRect:(CGRect *)inCropRect
{
    if (inOriginalSize == NULL || inCropRect == NULL)
        return;
    
    CGSize originalSize = *inOriginalSize;
    CGRect cropRect = *inCropRect;
    
    if (orientation == UIImageOrientationLeft)
    {
        cropRect = CGRectMake(cropRect.origin.y, originalSize.width - cropRect.size.width - cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (orientation == UIImageOrientationRight)
    {
        cropRect = CGRectMake(originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.origin.x, cropRect.size.height, cropRect.size.width);
        originalSize = CGSizeMake(originalSize.height, originalSize.width);
    }
    else if (orientation == UIImageOrientationDown)
    {
        cropRect = CGRectMake(originalSize.width - cropRect.size.width - cropRect.origin.x, originalSize.height - cropRect.size.height - cropRect.origin.y, cropRect.size.width, cropRect.size.height);
    }
    
    *inOriginalSize = originalSize;
    *inCropRect = cropRect;
}

- (CGPoint)fittedCropCenterRect:(CGRect)cropRect scale:(CGFloat)scale
{
    CGSize size = CGSizeMake(cropRect.size.width * scale, cropRect.size.height * scale);
    CGRect rect = CGRectMake(cropRect.origin.x * scale, cropRect.origin.y * scale, size.width, size.height);
    
    return CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
}

- (void)_layoutImageForOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation
{
    self.imageView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    
    [self _transformLayoutForOrientation:cropOrientation originalSize:&originalSize cropRect:&cropRect];
    
    CGSize scaledSize = TGScaleToFillSize(cropRect.size, self.frame.size);
    CGFloat ratio = cropRect.size.width > cropRect.size.height ? scaledSize.width / cropRect.size.width : scaledSize.height / cropRect.size.height;
    
    CGSize fittedOriginalSize = CGSizeMake(originalSize.width * ratio, originalSize.height * ratio);
    CGPoint centerPoint = CGPointMake(fittedOriginalSize.width / 2.0f, fittedOriginalSize.height / 2.0f);
    
    CGFloat scale = fittedOriginalSize.width / originalSize.width;
    CGPoint centerOffset = TGPaintSubtractPoints(centerPoint, [self fittedCropCenterRect:cropRect scale:scale]);

    self.imageView.bounds = CGRectMake(0, 0, fittedOriginalSize.width, fittedOriginalSize.height);
    self.imageView.center = TGPaintAddPoints(TGPaintCenterOfRect(self.bounds), centerOffset);
    
    //self.imageView.frame = CGRectMake(-cropRect.origin.x * ratio + (self.frame.size.width - fillSize.width) / 2, -cropRect.origin.y * ratio + (self.frame.size.height - fillSize.height) / 2, );
}

- (void)_layoutImageWithoutAdjustments
{
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.frame = self.bounds;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    _iconView.frame = CGRectMake(0, self.frame.size.height - 19, 19, 19);
    
    CGSize durationSize = _durationLabel.frame.size;
    _durationLabel.frame = CGRectMake(self.frame.size.width - durationSize.width - 4, self.frame.size.height - durationSize.height - 2, durationSize.width, durationSize.height);
}

- (UIImage *)transitionImageSquared
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0f);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) cornerRadius:TGAttachmentMenuCellCornerRadius] addClip];
    
    UIImage *image = self.imageView.image;
    
    CGSize originalSize = CGSizeZero;
    CGRect cropRect = CGRectZero;
    UIImageOrientation cropOrientation = UIImageOrientationUp;
    
    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[self.editingContext adjustmentsForItem:self.asset];
    if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
    {
        originalSize = adjustments.originalSize;
        cropRect = adjustments.cropRect;
        cropOrientation = adjustments.cropOrientation;
        
        __block UIImage *editedImage = nil;
        [[self.editingContext thumbnailImageSignalForItem:self.asset withUpdates:false synchronous:true] startWithNext:^(UIImage *next)
         {
             editedImage = next;
         }];
        
        if (editedImage != nil)
            image = editedImage;
    }
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    CGSize fillSize = TGScaleToFillSize(image.size, self.bounds.size);
    if (CGRectEqualToRect(cropRect, CGRectZero))
    {
        [image drawInRect:CGRectMake((self.bounds.size.width - fillSize.width) / 2, (self.bounds.size.height - fillSize.height) / 2, fillSize.width, fillSize.height)];
    }
    else
    {
        CGContextConcatCTM(context, TGVideoCropTransformForOrientation(cropOrientation, self.frame.size, false));
        
        CGFloat ratio = (cropRect.size.width > cropRect.size.height) ? self.frame.size.height / cropRect.size.height : self.frame.size.width / cropRect.size.width;
        CGSize fillSize = CGSizeMake(cropRect.size.width * ratio, cropRect.size.height * ratio);
        
        [image drawInRect:CGRectMake(-cropRect.origin.x * ratio + (self.frame.size.width - fillSize.width) / 2, -cropRect.origin.y * ratio + (self.frame.size.height - fillSize.height) / 2, originalSize.width * ratio, originalSize.height * ratio)];
    }
    
    CGContextRestoreGState(context);
    
    UIImage *transitionImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return transitionImage;
}

- (UIImage *)transitionImage
{
    if (fabs(self.frame.size.width - self.frame.size.height) < FLT_EPSILON)
        return [self transitionImageSquared];
    
    UIImage *sourceImage = self.imageView.image;
    
    CGSize originalSize = self.asset.dimensions;
    CGRect cropRect = CGRectMake(0, 0, originalSize.width, originalSize.height);
    UIImageOrientation cropOrientation = UIImageOrientationUp;
    
    TGVideoEditAdjustments *adjustments = (TGVideoEditAdjustments *)[self.editingContext adjustmentsForItem:self.asset];
    if ([adjustments isKindOfClass:[TGVideoEditAdjustments class]])
    {
        originalSize = adjustments.originalSize;
        cropRect = adjustments.cropRect;
        cropOrientation = adjustments.cropOrientation;
        
        __block UIImage *editedImage = nil;
        [[self.editingContext thumbnailImageSignalForItem:self.asset withUpdates:false synchronous:true] startWithNext:^(UIImage *next)
        {
            editedImage = next;
        }];
        
        if (editedImage != nil)
            sourceImage = editedImage;
    }
    
    CGSize fillSize = TGScaleToFillSize(cropRect.size, self.bounds.size);
    UIImage *croppedImage = TGPhotoEditorVideoCrop(sourceImage, nil, cropOrientation, 0, cropRect, false, fillSize, originalSize, true, true);

    UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0.0f);
    
    CGFloat scale = 1.0f;
    CGSize scaledBoundsSize = CGSizeZero;
    CGSize scaledImageSize = CGSizeZero;
    
    if (croppedImage.size.width > croppedImage.size.height)
    {
        scale = self.frame.size.height / croppedImage.size.height;
        scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, croppedImage.size.height);
        
        scaledImageSize = CGSizeMake(croppedImage.size.width * scale, croppedImage.size.height * scale);
        
        if (scaledImageSize.width < self.frame.size.width)
        {
            scale = self.frame.size.width / croppedImage.size.width;
            scaledBoundsSize = CGSizeMake(croppedImage.size.width, self.frame.size.height / scale);
        }
    }
    else
    {
        scale = self.frame.size.width / croppedImage.size.width;
        scaledBoundsSize = CGSizeMake(croppedImage.size.width, self.frame.size.height / scale);
        
        scaledImageSize = CGSizeMake(croppedImage.size.width * scale, croppedImage.size.height * scale);
        
        if (scaledImageSize.width < self.frame.size.width)
        {
            scale = self.frame.size.height / croppedImage.size.height;
            scaledBoundsSize = CGSizeMake(self.frame.size.width / scale, croppedImage.size.height);
        }
    }

    CGRect rect = self.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0f);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height) cornerRadius:TGAttachmentMenuCellCornerRadius] addClip];
    
    CGContextScaleCTM(context, scale, scale);
    [croppedImage drawInRect:CGRectMake((scaledBoundsSize.width - croppedImage.size.width) / 2,
                                        (scaledBoundsSize.height - croppedImage.size.height) / 2,
                                        croppedImage.size.width,
                                        croppedImage.size.height)];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

@end
