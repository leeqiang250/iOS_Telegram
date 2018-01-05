#import "TGMediaAssetFetchResultChange.h"
#import "TGMediaAssetImageSignals.h"

@class TGMediaAsset;
@class TGMediaSelectionContext;

@interface TGMediaAssetsPreheatMixin : NSObject

@property (nonatomic, copy) NSInteger (^assetCount)(void);
@property (nonatomic, copy) TGMediaAsset *(^assetAtIndexPath)(NSIndexPath *);

@property (nonatomic, assign) TGMediaAssetImageType imageType;
@property (nonatomic, assign) CGSize imageSize;
@property (nonatomic, assign) bool reversed;

- (instancetype)initWithCollectionView:(UICollectionView *)collectionView scrollDirection:(UICollectionViewScrollDirection)scrollDirection;
- (void)update;
- (void)stop;

@end


@interface TGMediaAssetsCollectionViewIncrementalUpdater : NSObject

+ (void)updateCollectionView:(UICollectionView *)collectionView withChange:(TGMediaAssetFetchResultChange *)change completion:(void (^)(bool incremental))completion;

@end


@interface TGMediaAssetsSaveToCameraRoll : NSObject

+ (void)saveImageAtURL:(NSURL *)url;
+ (void)saveImageWithData:(NSData *)imageData;
+ (void)saveVideoAtURL:(NSURL *)url;

@end


@interface TGMediaAssetsDateUtils : NSObject

+ (NSString *)formattedDateRangeWithStartDate:(NSDate *)startDate endDate:(NSDate *)endDate currentDate:(NSDate *)currentDate shortDate:(bool)shortDate;

@end