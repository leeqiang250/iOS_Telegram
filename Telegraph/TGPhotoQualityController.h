#import "TGPhotoEditorTabController.h"

#import "TGVideoEditAdjustments.h"

@class PGPhotoEditor;
@class TGPhotoEditorPreviewView;
@class TGPhotoEditorController;

@interface TGPhotoQualityController : TGPhotoEditorTabController

@property (nonatomic, readonly) TGMediaVideoConversionPreset preset;

- (instancetype)initWithPhotoEditor:(PGPhotoEditor *)photoEditor previewView:(TGPhotoEditorPreviewView *)previewView;

@end
