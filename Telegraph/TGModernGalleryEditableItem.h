#import "TGModernGalleryItem.h"
#import "TGPhotoToolbarView.h"

@protocol TGMediaEditableItem;
@class TGMediaEditingContext;

@protocol TGModernGalleryEditableItem <TGModernGalleryItem>

@property (nonatomic, strong) TGMediaEditingContext *editingContext;

- (id<TGMediaEditableItem>)editableMediaItem;
- (TGPhotoEditorTab)toolbarTabs;
- (NSString *)uniqueId;

@end
