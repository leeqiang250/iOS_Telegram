#import <Foundation/Foundation.h>

@class SSignal;
@class TGPhotoEditorController;

@interface TGMediaAvatarEditorTransition : NSObject

@property (nonatomic, copy) CGRect (^referenceFrame)(void);

@property (nonatomic, copy) CGSize (^referenceImageSize)(void);
@property (nonatomic, copy) SSignal *(^referenceScreenImageSignal)(void);

@property (nonatomic, assign) CGRect outReferenceFrame;
@property (nonatomic, strong) UIView *repView;

- (instancetype)initWithController:(TGPhotoEditorController *)controller fromView:(UIView *)fromView;

- (void)presentAnimated:(bool)animated;
- (void)dismissAnimated:(bool)animated completion:(void (^)(void))completion;

@end
