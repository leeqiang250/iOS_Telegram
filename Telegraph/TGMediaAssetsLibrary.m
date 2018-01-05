#import "TGMediaAssetsLibrary.h"

#import "TGMediaAssetsModernLibrary.h"
#import "TGMediaAssetsLegacyLibrary.h"

@implementation TGMediaAssetsLibrary

static Class TGMediaAssetsLibraryClass = nil;

+ (void)load
{
    if ([self usesPhotoFramework])
        TGMediaAssetsLibraryClass = [TGMediaAssetsModernLibrary class];
    else
        TGMediaAssetsLibraryClass = [TGMediaAssetsLegacyLibrary class];

    [TGMediaAssetsLibraryClass authorizationStatus];
}

- (instancetype)initForAssetType:(TGMediaAssetType)assetType
{
    self = [super init];
    if (self != nil)
    {
        _assetType = assetType;
        _queue = [[SQueue alloc] init];
    }
    return self;
}

+ (instancetype)libraryForAssetType:(TGMediaAssetType)assetType
{
    return [[TGMediaAssetsLibraryClass alloc] initForAssetType:assetType];
}

- (SSignal *)assetWithIdentifier:(NSString *)__unused identifier
{
    return nil;
}

- (SSignal *)assetGroups
{
    return nil;
}

- (SSignal *)cameraRollGroup
{
    return nil;
}

- (SSignal *)updatedAssetsForAssets:(NSArray *)__unused assets
{
    return nil;
}

- (SSignal *)libraryChanged
{
    return nil;
}

NSInteger TGMediaAssetGroupComparator(TGMediaAssetGroup *group1, TGMediaAssetGroup *group2, __unused void *context)
{
    if (group1.subtype < group2.subtype)
        return NSOrderedAscending;
    else if (group1.subtype > group2.subtype)
        return NSOrderedDescending;
    
    return [group1.title compare:group2.title];
}

#pragma mark - Assets

- (SSignal *)assetsOfAssetGroup:(TGMediaAssetGroup *)__unused assetGroup reversed:(bool)__unused reversed
{
    return nil;
}

- (SSignal *)_legacyAssetsOfAssetGroup:(TGMediaAssetGroup *)assetGroup reversed:(bool)reversed
{
    NSParameterAssert(assetGroup);
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        TGMediaAssetFetchResult *mediaFetchResult = [[TGMediaAssetFetchResult alloc] init];
        
        NSEnumerationOptions options = kNilOptions;
        if (reversed)
            options = NSEnumerationReverse;
        
        [assetGroup.backingAssetsGroup enumerateAssetsWithOptions:options usingBlock:^(ALAsset *asset, __unused NSUInteger index, __unused BOOL *stop)
        {
            if (asset != nil)
                [mediaFetchResult _appendALAsset:asset];
        }];
        
        [subscriber putNext:mediaFetchResult];
        [subscriber putCompletion];
        
        return nil;
    }] startOn:_queue];
}

#pragma mark - 

- (SSignal *)saveAssetWithImage:(UIImage *)__unused image
{
    return nil;
}

- (SSignal *)saveAssetWithImageData:(NSData *)__unused imageData
{
    return nil;
}

- (SSignal *)saveAssetWithImageAtUrl:(NSURL *)url
{
    return [self _saveAssetWithUrl:url isVideo:false];
}

- (SSignal *)saveAssetWithVideoAtUrl:(NSURL *)url
{
    return [self _saveAssetWithUrl:url isVideo:true];
}

- (SSignal *)_saveAssetWithUrl:(NSURL *)__unused url isVideo:(bool)__unused isVideo
{
    return nil;
}

#pragma mark -

+ (TGMediaAssetsLibrary *)sharedLibrary
{
    static dispatch_once_t onceToken;
    static TGMediaAssetsLibrary *library;
    dispatch_once(&onceToken, ^
    {
        library = [self libraryForAssetType:TGMediaAssetAnyType];
    });
    return library;
}

#pragma mark - Authorization Status

+ (SSignal *)authorizationStatusSignal
{
    return [TGMediaAssetsLibraryClass authorizationStatusSignal];
}

+ (void)requestAuthorizationForAssetType:(TGMediaAssetType)assetType completion:(void (^)(TGMediaLibraryAuthorizationStatus, TGMediaAssetGroup *))completion
{
    [TGMediaAssetsLibraryClass requestAuthorizationForAssetType:assetType completion:completion];
}

+ (TGMediaLibraryAuthorizationStatus)authorizationStatus
{
    if (TGMediaLibraryCachedAuthorizationStatus != TGMediaLibraryAuthorizationStatusNotDetermined)
        return TGMediaLibraryCachedAuthorizationStatus;
    
    TGMediaLibraryCachedAuthorizationStatus = [TGMediaAssetsLibraryClass authorizationStatus];
    
    return TGMediaLibraryCachedAuthorizationStatus;
}

#pragma mark - 

+ (bool)usesPhotoFramework
{
    static dispatch_once_t onceToken;
    static bool usesPhotosFramework = false;
    dispatch_once(&onceToken, ^
    {
        usesPhotosFramework = (iosMajorVersion() >= 8.0);
    });
    return usesPhotosFramework;
}

@end
