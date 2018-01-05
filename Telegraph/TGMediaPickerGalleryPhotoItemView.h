#import "TGModernGalleryZoomableItemView.h"
#import "TGModernGalleryEditableItemView.h"
#import "TGModernGalleryImageItemImageView.h"

@interface TGMediaPickerGalleryPhotoItemView : TGModernGalleryZoomableItemView <TGModernGalleryEditableItemView>

@property (nonatomic) CGSize imageSize;

@property (nonatomic, strong) TGModernGalleryImageItemImageView *imageView;

@end
