#import <Foundation/Foundation.h>

#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "TGMediaSelectionContext.h"
#import "TGMediaEditingContext.h"

typedef enum
{
    TGMediaAssetAnyType,
    TGMediaAssetPhotoType,
    TGMediaAssetVideoType,
    TGMediaAssetGifType
} TGMediaAssetType;

typedef enum
{
    TGMediaAssetSubtypeNone = 0,
    TGMediaAssetSubtypePhotoPanorama = (1UL << 0),
    TGMediaAssetSubtypePhotoHDR = (1UL << 1),
    TGMediaAssetSubtypePhotoScreenshot = (1UL << 2),
    TGMediaAssetSubtypeVideoStreamed = (1UL << 16),
    TGMediaAssetSubtypeVideoHighFrameRate = (1UL << 17),
    TGMediaAssetSubtypeVideoTimelapse = (1UL << 18)
} TGMediaAssetSubtype;

@interface TGMediaAsset : NSObject <TGMediaSelectableItem>

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) NSDate *date;
@property (nonatomic, readonly) bool isVideo;
@property (nonatomic, readonly) NSTimeInterval videoDuration;
@property (nonatomic, readonly) SSignal *actualVideoDuration;
@property (nonatomic, readonly) bool representsBurst;
@property (nonatomic, readonly) NSString *uniformTypeIdentifier;
@property (nonatomic, readonly) NSString *fileName;

@property (nonatomic, readonly) TGMediaAssetType type;
@property (nonatomic, readonly) TGMediaAssetSubtype subtypes;

- (instancetype)initWithPHAsset:(PHAsset *)asset;
- (instancetype)initWithALAsset:(ALAsset *)asset;

@property (nonatomic, readonly) PHAsset *backingAsset;
@property (nonatomic, readonly) ALAsset *backingLegacyAsset;

+ (PHAssetMediaType)assetMediaTypeForAssetType:(TGMediaAssetType)assetType;

@end
