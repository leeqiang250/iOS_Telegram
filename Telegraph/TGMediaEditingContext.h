#import <SSignalKit/SSignalKit.h>

@protocol TGMediaEditableItem <NSObject>

@property (nonatomic, readonly) bool isVideo;
@property (nonatomic, readonly) NSString *uniqueIdentifier;

@optional
@property (nonatomic, readonly) CGSize originalSize;

- (SSignal *)thumbnailImageSignal;
- (SSignal *)screenImageSignal:(NSTimeInterval)position;
- (SSignal *)originalImageSignal:(NSTimeInterval)position;

@end


@class TGPaintingData;

@protocol TGMediaEditAdjustments <NSObject>

@property (nonatomic, readonly) CGSize originalSize;
@property (nonatomic, readonly) CGRect cropRect;
@property (nonatomic, readonly) UIImageOrientation cropOrientation;
@property (nonatomic, readonly) CGFloat cropLockedAspectRatio;
@property (nonatomic, readonly) bool cropMirrored;
@property (nonatomic, readonly) TGPaintingData *paintingData;

- (bool)hasPainting;

- (bool)cropAppliedForAvatar:(bool)forAvatar;
- (bool)isDefaultValuesForAvatar:(bool)forAvatar;

- (bool)isCropEqualWith:(id<TGMediaEditAdjustments>)adjusments;

@end


@interface TGMediaEditingContext : NSObject

@property (nonatomic, readonly) bool inhibitEditing;

+ (instancetype)contextForCaptionsOnly;

- (SSignal *)imageSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)imageSignalForItem:(NSObject<TGMediaEditableItem> *)item withUpdates:(bool)withUpdates;
- (SSignal *)thumbnailImageSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)thumbnailImageSignalForItem:(id<TGMediaEditableItem>)item withUpdates:(bool)withUpdates synchronous:(bool)synchronous;
- (SSignal *)fastImageSignalForItem:(NSObject<TGMediaEditableItem> *)item withUpdates:(bool)withUpdates;

- (void)setImage:(UIImage *)image thumbnailImage:(UIImage *)thumbnailImage forItem:(id<TGMediaEditableItem>)item synchronous:(bool)synchronous;
- (void)setFullSizeImage:(UIImage *)image forItem:(id<TGMediaEditableItem>)item;

- (void)setTemporaryRep:(id)rep forItem:(id<TGMediaEditableItem>)item;

- (SSignal *)fullSizeImageUrlForItem:(id<TGMediaEditableItem>)item;

- (NSString *)captionForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)captionSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setCaption:(NSString *)caption forItem:(NSObject<TGMediaEditableItem> *)item;

- (NSObject<TGMediaEditAdjustments> *)adjustmentsForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)adjustmentsSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setAdjustments:(NSObject<TGMediaEditAdjustments> *)adjustments forItem:(NSObject<TGMediaEditableItem> *)item;

- (NSNumber *)timerForItem:(NSObject<TGMediaEditableItem> *)item;
- (SSignal *)timerSignalForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setTimer:(NSNumber *)timer forItem:(NSObject<TGMediaEditableItem> *)item;

- (NSNumber *)timer;
- (SSignal *)timerSignal;
- (void)setTimer:(NSNumber *)seconds;

- (UIImage *)paintingImageForItem:(NSObject<TGMediaEditableItem> *)item;
- (bool)setPaintingData:(NSData *)data image:(UIImage *)image forItem:(NSObject<TGMediaEditableItem> *)item dataUrl:(NSURL **)dataOutUrl imageUrl:(NSURL **)imageOutUrl forVideo:(bool)video;
- (void)clearPaintingData;

- (SSignal *)facesForItem:(NSObject<TGMediaEditableItem> *)item;
- (void)setFaces:(NSArray *)faces forItem:(NSObject<TGMediaEditableItem> *)item;

- (SSignal *)cropAdjustmentsUpdatedSignal;

- (void)requestOriginalThumbnailImageForItem:(id<TGMediaEditableItem>)item completion:(void (^)(UIImage *))completion;
- (void)requestOriginalImageForItem:(id<TGMediaEditableItem>)itemId completion:(void (^)(UIImage *image))completion;
- (void)setOriginalImage:(UIImage *)image forItem:(id<TGMediaEditableItem>)item synchronous:(bool)synchronous;

@end
