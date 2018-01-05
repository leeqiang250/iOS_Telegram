#import "TGMediaPickerPhotoStripCell.h"
#import "TGCheckButtonView.h"
#import "TGImageView.h"

#import "TGFont.h"
#import "TGPhotoEditorUtils.h"

#import "TGMediaPickerGallerySelectedItemsModel.h"
#import "TGMediaSelectionContext.h"
#import "TGMediaEditingContext.h"

#import "TGVideoEditAdjustments.h"

#import "TGMediaAsset+TGMediaEditableItem.h"

NSString *const TGMediaPickerPhotoStripCellKind = @"PhotoStripCell";

@interface TGMediaPickerPhotoStripCell ()
{
    TGCheckButtonView *_checkButton;
    UIImageView *_iconView;
    UIImageView *_gradientView;
    UILabel *_label;
    
    NSObject *_item;
    SMetaDisposable *_itemSelectedDisposable;
    bool _isGif;
    
    SMetaDisposable *_adjustmentsDisposable;
}

@property (nonatomic, readonly) TGImageView *imageView;

@end

@implementation TGMediaPickerPhotoStripCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil)
    {
        self.clipsToBounds = true;
        
        if (iosMajorVersion() >= 8)
            self.layer.cornerRadius = 4.0f;
        
        _imageView = [[TGImageView alloc] initWithFrame:self.bounds];
        _imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:_imageView];
        
        static dispatch_once_t onceToken;
        static UIImage *gradientImage;
        dispatch_once(&onceToken, ^
        {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(1.0f, 20.0f), false, 0.0f);
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGColorRef colors[2] = {
                CGColorRetain(UIColorRGBA(0x000000, 0.0f).CGColor),
                CGColorRetain(UIColorRGBA(0x000000, 0.8f).CGColor)
            };
            
            CFArrayRef colorsArray = CFArrayCreate(kCFAllocatorDefault, (const void **)&colors, 2, NULL);
            CGFloat locations[2] = {0.0f, 1.0f};
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, colorsArray, (CGFloat const *)&locations);
            
            CFRelease(colorsArray);
            CFRelease(colors[0]);
            CFRelease(colors[1]);
            
            CGColorSpaceRelease(colorSpace);
            
            CGContextDrawLinearGradient(context, gradient, CGPointMake(0.0f, 0.0f), CGPointMake(0.0f, 20.0f), 0);
            
            CFRelease(gradient);
            
            gradientImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        });
        
        _gradientView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _gradientView.image = gradientImage;
        _gradientView.hidden = true;
        [self addSubview:_gradientView];
        
        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];
        
        _label = [[UILabel alloc] init];
        _label.textColor = [UIColor whiteColor];
        _label.backgroundColor = [UIColor clearColor];
        _label.textAlignment = NSTextAlignmentRight;
        _label.font = TGSystemFontOfSize(12.0f);
        [_label sizeToFit];
        [self addSubview:_label];
    }
    return self;
}

- (void)dealloc
{
    [_itemSelectedDisposable dispose];
    [_adjustmentsDisposable dispose];
}

- (void)setItem:(NSObject *)item signal:(SSignal *)signal
{
    _item = item;
    
    if (self.selectionContext != nil)
    {
        if (_checkButton == nil)
        {
            _checkButton = [[TGCheckButtonView alloc] initWithStyle:TGCheckButtonStyleMedia];
            [_checkButton addTarget:self action:@selector(checkButtonPressed) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:_checkButton];
        }
        
        if (_itemSelectedDisposable == nil)
            _itemSelectedDisposable = [[SMetaDisposable alloc] init];
        
        [self setChecked:[self.selectionContext isItemSelected:(id<TGMediaSelectableItem>)item] animated:false];
        __weak TGMediaPickerPhotoStripCell *weakSelf = self;
        [_itemSelectedDisposable setDisposable:[[self.selectionContext itemInformativeSelectedSignal:(id<TGMediaSelectableItem>)item] startWithNext:^(TGMediaSelectionChange *next)
        {
            __strong TGMediaPickerPhotoStripCell *strongSelf = weakSelf;
            if (strongSelf == nil)
                return;
            
            if (![next.sender isKindOfClass:[TGMediaPickerGallerySelectedItemsModel class]])
                [strongSelf setChecked:next.selected animated:next.animated];
        }]];
    }
    
    if (_item == nil)
    {
        [_imageView reset];
        return;
    }
    
    [_imageView setSignal:signal];
    
    TGMediaAsset *asset = (TGMediaAsset *)item;
    if (![asset isKindOfClass:[TGMediaAsset class]])
        return;
    
    _isGif = false;
    
    switch (asset.type)
    {
        case TGMediaAssetVideoType:
        {
            _gradientView.hidden = false;
            _label.text = [NSString stringWithFormat:@"%d:%02d", (int)ceil(asset.videoDuration) / 60, (int)ceil(asset.videoDuration) % 60];
            
            if (asset.subtypes & TGMediaAssetSubtypeVideoTimelapse)
                _iconView.image = [UIImage imageNamed:@"ModernMediaItemTimelapseIcon"];
            else if (asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate)
                _iconView.image = [UIImage imageNamed:@"ModernMediaItemSloMoIcon"];
            else
                _iconView.image = [UIImage imageNamed:@"ModernMediaItemVideoIcon"];
            
            if (self.editingContext != nil)
            {
                SSignal *adjustmentsSignal = [self.editingContext adjustmentsSignalForItem:asset];
                
                __weak TGMediaPickerPhotoStripCell *weakSelf = self;
                [_adjustmentsDisposable setDisposable:[adjustmentsSignal startWithNext:^(TGVideoEditAdjustments *next)
                {
                    __strong TGMediaPickerPhotoStripCell *strongSelf = weakSelf;
                    if (strongSelf == nil)
                        return;
                    
                    if ([next isKindOfClass:[TGVideoEditAdjustments class]])
                        [strongSelf _layoutImageForOriginalSize:next.originalSize cropRect:next.cropRect cropOrientation:next.cropOrientation];
                    else
                        [strongSelf _layoutImageWithoutAdjustments];
                }]];
            }
        }
            break;
            
        case TGMediaAssetGifType:
        {
            _gradientView.hidden = false;
            _label.text = @"GIF";
            _iconView.image = nil;
            _isGif = true;
        }
            break;
            
        default:
        {
            _gradientView.hidden = true;
            _label.text = nil;
            _iconView.image = nil;
        }
            break;
    }
}

- (void)checkButtonPressed
{
    [_checkButton setSelected:!_checkButton.selected animated:true];
    
    if (self.itemSelected != nil)
        self.itemSelected((id<TGMediaSelectableItem>)_item, _checkButton.selected, _checkButton);
}

- (void)setChecked:(bool)checked animated:(bool)animated
{
    [_checkButton setSelected:checked animated:animated];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [_imageView reset];
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

- (void)_layoutImageForOriginalSize:(CGSize)originalSize cropRect:(CGRect)cropRect cropOrientation:(UIImageOrientation)cropOrientation
{
    self.imageView.transform = CGAffineTransformMakeRotation(TGRotationForOrientation(cropOrientation));
    
    [self _transformLayoutForOrientation:cropOrientation originalSize:&originalSize cropRect:&cropRect];
    
    CGFloat ratio = (cropRect.size.width > cropRect.size.height) ? self.frame.size.height / cropRect.size.height : self.frame.size.width / cropRect.size.width;
    CGSize fillSize = CGSizeMake(cropRect.size.width * ratio, cropRect.size.height * ratio);
    
    self.imageView.frame = CGRectMake(-cropRect.origin.x * ratio + (self.frame.size.width - fillSize.width) / 2, -cropRect.origin.y * ratio + (self.frame.size.height - fillSize.height) / 2, originalSize.width * ratio, originalSize.height * ratio);
}

- (void)_layoutImageWithoutAdjustments
{
    self.imageView.transform = CGAffineTransformIdentity;
    self.imageView.frame = self.bounds;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_checkButton != nil)
    {
        _checkButton.frame = CGRectMake(self.bounds.size.width - _checkButton.frame.size.width, 0, _checkButton.frame.size.width, _checkButton.frame.size.height);
    }
    
    if (!_gradientView.hidden)
        _gradientView.frame = CGRectMake(0, self.frame.size.height - 20.0f, self.frame.size.width, 20.0f);
    
    _iconView.frame = CGRectMake(0, self.frame.size.height - 19, 19, 19);
    
    [_label sizeToFit];
    CGSize durationSize = CGSizeMake(ceil(_label.frame.size.width), ceil(_label.frame.size.height));
    CGFloat x = _isGif ? 4 : self.frame.size.width - durationSize.width - 4;
    _label.frame = CGRectMake(x, self.frame.size.height - durationSize.height - 2, durationSize.width, durationSize.height);
}

@end
