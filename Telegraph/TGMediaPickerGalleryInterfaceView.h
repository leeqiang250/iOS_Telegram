#import "TGModernGalleryInterfaceView.h"
#import "TGModernGalleryItem.h"

#import "TGPhotoToolbarView.h"

@class TGMediaSelectionContext;
@class TGMediaEditingContext;
@class TGSuggestionContext;
@class TGMediaPickerGallerySelectedItemsModel;

@interface TGMediaPickerGalleryInterfaceView : UIView <TGModernGalleryInterfaceView>

@property (nonatomic, copy) void (^captionSet)(id<TGModernGalleryItem>, NSString *);
@property (nonatomic, copy) void (^donePressed)(id<TGModernGalleryItem>);

@property (nonatomic, copy) void (^photoStripItemSelected)(NSInteger index);

@property (nonatomic, copy) void (^timerRequested)(void);

@property (nonatomic, assign) bool hasCaptions;
@property (nonatomic, assign) bool hasTimer;
@property (nonatomic, assign) bool inhibitDocumentCaptions;
@property (nonatomic, assign) bool usesSimpleLayout;
@property (nonatomic, assign) bool hasSwipeGesture;
@property (nonatomic, assign) bool usesFadeOutForDismissal;

@property (nonatomic, readonly) TGPhotoEditorTab currentTabs;

@property (nonatomic, readonly) UIView *timerButton;

- (instancetype)initWithFocusItem:(id<TGModernGalleryItem>)focusItem selectionContext:(TGMediaSelectionContext *)selectionContext editingContext:(TGMediaEditingContext *)editingContext hasSelectionPanel:(bool)hasSelectionPanel recipientName:(NSString *)recipientName;

- (void)setSelectedItemsModel:(TGMediaPickerGallerySelectedItemsModel *)selectedItemsModel;
- (void)setEditorTabPressed:(void (^)(TGPhotoEditorTab tab))editorTabPressed;
- (void)setSuggestionContext:(TGSuggestionContext *)suggestionContext;

- (void)setThumbnailSignalForItem:(SSignal *(^)(id))thumbnailSignalForItem;

- (void)updateSelectionInterface:(NSUInteger)selectedCount counterVisible:(bool)counterVisible animated:(bool)animated;
- (void)updateSelectedPhotosView:(bool)reload incremental:(bool)incremental add:(bool)add index:(NSInteger)index;
- (void)setSelectionInterfaceHidden:(bool)hidden animated:(bool)animated;
- (void)setAllInterfaceHidden:(bool)hidden delay:(NSTimeInterval)__unused delay animated:(bool)animated;
- (void)setToolbarsHidden:(bool)hidden animated:(bool)animated;

- (void)editorTransitionIn;
- (void)editorTransitionOut;

- (void)setTabBarUserInteractionEnabled:(bool)enabled;

@end
