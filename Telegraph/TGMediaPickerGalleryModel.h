#import "TGModernGalleryModel.h"

#import "TGMediaPickerGalleryInterfaceView.h"
#import "TGModernGalleryController.h"

#import "TGPhotoEditorController.h"

@class TGModernGalleryController;
@class TGMediaPickerGallerySelectedItemsModel;
@protocol TGMediaEditAdjustments;

@class TGMediaSelectionContext;
@protocol TGMediaSelectableItem;

@class TGSuggestionContext;

@interface TGMediaPickerGalleryModel : TGModernGalleryModel

@property (nonatomic, copy) void (^willFinishEditingItem)(id<TGMediaEditableItem> item, id<TGMediaEditAdjustments> adjustments, id temporaryRep, bool hasChanges);
@property (nonatomic, copy) void (^didFinishEditingItem)(id<TGMediaEditableItem>item, id<TGMediaEditAdjustments> adjustments, UIImage *resultImage, UIImage *thumbnailImage);
@property (nonatomic, copy) void (^didFinishRenderingFullSizeImage)(id<TGMediaEditableItem> item, UIImage *fullSizeImage);

@property (nonatomic, copy) void (^saveItemCaption)(id<TGMediaEditableItem> item, NSString *caption);

@property (nonatomic, copy) void (^storeOriginalImageForItem)(id<TGMediaEditableItem> item, UIImage *originalImage);

@property (nonatomic, copy) id<TGMediaEditAdjustments> (^requestAdjustments)(id<TGMediaEditableItem> item);

@property (nonatomic, copy) void (^editorOpened)(void);
@property (nonatomic, copy) void (^editorClosed)(void);

@property (nonatomic, assign) bool useGalleryImageAsEditableItemImage;
@property (nonatomic, weak) TGModernGalleryController *controller;

@property (nonatomic, readonly, strong) TGMediaPickerGalleryInterfaceView *interfaceView;
@property (nonatomic, readonly, strong) TGMediaPickerGallerySelectedItemsModel *selectedItemsModel;

@property (nonatomic, copy) NSInteger (^externalSelectionCount)(void);

@property (nonatomic, readonly) TGMediaSelectionContext *selectionContext;
@property (nonatomic, strong) TGSuggestionContext *suggestionContext;

- (instancetype)initWithItems:(NSArray *)items focusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasCaptions:(bool)hasCaptions hasTimer:(bool)hasTimer inhibitDocumentCaptions:(bool)inhibitDocumentCaptions hasSelectionPanel:(bool)hasSelectionPanel recipientName:(NSString *)recipientName;

- (void)setCurrentItem:(id<TGMediaSelectableItem>)item direction:(TGModernGalleryScrollAnimationDirection)direction;

@end
