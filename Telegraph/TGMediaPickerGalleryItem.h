#import "TGModernGalleryImageItem.h"
#import "TGMediaAsset.h"

@interface TGMediaPickerGalleryItem : NSObject <TGModernGalleryItem>

@property (nonatomic, strong) TGMediaAsset *asset;
@property (nonatomic, strong) UIImage *immediateThumbnailImage;
@property (nonatomic, assign) bool asFile;

- (instancetype)initWithAsset:(TGMediaAsset *)asset;

@end
