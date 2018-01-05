#import "TGPhotoPaintSettingsView.h"

@class TGViewController;
@class TGDocumentMediaAttachment;

@interface TGPhotoStickersView : UIView <TGPhotoPaintPanelView>

@property (nonatomic, weak) TGViewController *parentViewController;
@property (nonatomic, weak) UIView *outerView;
@property (nonatomic, weak) UIView *targetView;

@property (nonatomic, copy) void (^stickerSelected)(TGDocumentMediaAttachment *, CGPoint, TGPhotoStickersView *, UIView *);
@property (nonatomic, copy) void (^dismissed)(void);

- (void)dismissWithSnapshotView:(UIView *)view startPoint:(CGPoint)startPoint targetFrame:(CGRect)targetFrame targetRotation:(CGFloat)targetRotation completion:(void (^)(void))completion;

@end
