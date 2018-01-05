#import "TGViewController.h"
#import "TGOverlayController.h"

#import "PGPhotoEditorItem.h"

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;

@interface TGPhotoEditorItemController : TGViewController

@property (nonatomic, copy) void(^editorItemUpdated)(void);
@property (nonatomic, copy) void(^beginTransitionIn)(void);
@property (nonatomic, copy) void(^beginTransitionOut)(void);
@property (nonatomic, copy) void(^finishedCombinedTransition)(void);

@property (nonatomic, assign) CGFloat toolbarLandscapeSize;
@property (nonatomic, assign) bool initialAppearance;
@property (nonatomic, assign) bool skipProcessingOnCompletion;

- (instancetype)initWithEditorItem:(id<PGPhotoEditorItem>)editorItem photoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

- (void)attachPreviewView:(TGPhotoEditorPreviewView *)previewView;

- (void)prepareForCombinedAppearance;
- (void)finishedCombinedAppearance;

@end
