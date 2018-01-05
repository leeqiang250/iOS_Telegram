#import "TGMediaAssetsModernLibrary.h"
#import "TGMediaAssetFetchResultChange.h"
#import "TGMediaAssetMomentList.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface TGMediaAssetsModernLibrary () <PHPhotoLibraryChangeObserver>
{
    PHPhotoLibrary *_photoLibrary;
    SPipe *_libraryChangePipe;
}
@end

@implementation TGMediaAssetsModernLibrary

- (instancetype)initForAssetType:(TGMediaAssetType)assetType
{
    self = [super initForAssetType:assetType];
    if (self != nil)
    {
        _libraryChangePipe = [[SPipe alloc] init];
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
    return self;
}

- (void)dealloc
{
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
}

- (SSignal *)assetGroups
{
    TGMediaAssetType assetType = self.assetType;
    SSignal *(^groupsSignal)(void) = ^
    {
        return [[self cameraRollGroup] map:^NSArray *(TGMediaAssetGroup *cameraRollGroup)
        {
            NSMutableArray *groups = [[NSMutableArray alloc] init];
            if (cameraRollGroup != nil)
                [groups addObject:cameraRollGroup];
            
            PHFetchResult *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
            for (PHAssetCollection *album in albums)
                [groups addObject:[[TGMediaAssetGroup alloc] initWithPHAssetCollection:album fetchResult:nil]];
            
            PHFetchResult *smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
            for (PHAssetCollection *album in smartAlbums)
            {
                if ([TGMediaAssetGroup _isSmartAlbumCollectionSubtype:album.assetCollectionSubtype requiredForAssetType:assetType])
                {
                    TGMediaAssetGroup *group = [[TGMediaAssetGroup alloc] initWithPHAssetCollection:album fetchResult:nil];
                    if (group.assetCount > 0)
                        [groups addObject:group];
                }
            }
            
            [groups sortUsingFunction:TGMediaAssetGroupComparator context:nil];
            
            PHFetchOptions *options = [[PHFetchOptions alloc] init];
            options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"startDate" ascending:true]];
            
            //PHFetchResult *moments = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeMoment subtype:PHAssetCollectionSubtypeAny options:options];
            //TGMediaAssetMomentList *momentList = [[TGMediaAssetMomentList alloc] initWithPHFetchResult:moments];
            //[groups insertObject:momentList atIndex:0];
            
            return groups;
        }];
    };
    
    SSignal *initialSignal = [[TGMediaAssetsModernLibrary _requestAuthorization] mapToSignal:^SSignal *(NSNumber *statusValue)
    {
        TGMediaLibraryAuthorizationStatus status = (TGMediaLibraryAuthorizationStatus)[statusValue integerValue];
        if (status != TGMediaLibraryAuthorizationStatusAuthorized)
            return [SSignal fail:nil];
        
        return groupsSignal();
    }];
    
    SSignal *updateSignal = [[self libraryChanged] mapToSignal:^SSignal *(__unused id change)
    {
        return groupsSignal();
    }];
    
    return [initialSignal then:updateSignal];
}

- (SSignal *)cameraRollGroup
{
    TGMediaAssetType assetType = self.assetType;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        PHFetchOptions *options = [PHFetchOptions new];
        
        if (iosMajorVersion() == 8 && iosMinorVersion() < 1)
        {
            PHFetchResult *fetchResult = nil;
            
            if (assetType == TGMediaAssetAnyType)
                fetchResult = [PHAsset fetchAssetsWithOptions:options];
            else
                fetchResult = [PHAsset fetchAssetsWithMediaType:[TGMediaAsset assetMediaTypeForAssetType:assetType] options:options];
            
            [subscriber putNext:[[TGMediaAssetGroup alloc] initWithPHFetchResult:fetchResult]];
            [subscriber putCompletion];
        }
        else
        {
            PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil];
            PHAssetCollection *assetCollection = fetchResult.firstObject;
            
            if (assetCollection != nil)
            {
                if (assetType != TGMediaAssetAnyType)
                    options.predicate = [NSPredicate predicateWithFormat:@"mediaType = %i", [TGMediaAsset assetMediaTypeForAssetType:assetType]];
                
                PHFetchResult *assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
                
                [subscriber putNext:[[TGMediaAssetGroup alloc] initWithPHAssetCollection:assetCollection fetchResult:assetsFetchResult]];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        }
        
        return nil;
    }];
}

- (SSignal *)assetsOfAssetGroup:(TGMediaAssetGroup *)assetGroup reversed:(bool)reversed
{
    if (assetGroup == nil)
        return [SSignal fail:nil];
    
    SAtomic *fetchResult = [[SAtomic alloc] initWithValue:assetGroup.backingFetchResult];
    SSignal *initialSignal = [[TGMediaAssetsModernLibrary _requestAuthorization] mapToSignal:^SSignal *(NSNumber *statusValue)
    {
        TGMediaLibraryAuthorizationStatus status = (TGMediaLibraryAuthorizationStatus)[statusValue integerValue];
        if (status == TGMediaLibraryAuthorizationStatusNotDetermined)
            return [SSignal fail:nil];
        
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [subscriber putNext:[[TGMediaAssetFetchResult alloc] initWithPHFetchResult:fetchResult.value reversed:reversed]];
            [subscriber putCompletion];
            
            return nil;
        }];
    }];
    
    SSignal *updateSignal = [[[[self libraryChanged] map:^PHFetchResultChangeDetails *(PHChange *change)
    {
        return [change changeDetailsForFetchResult:fetchResult.value];
    }] filter:^bool(PHFetchResultChangeDetails *details)
    {
        return (details != nil);
    }] map:^id(PHFetchResultChangeDetails *details)
    {
        [fetchResult modify:^id(__unused id value)
        {
            return details.fetchResultAfterChanges;
        }];
        return [TGMediaAssetFetchResultChange changeWithPHFetchResultChangeDetails:details reversed:reversed];
    }];
    
    return [initialSignal then:updateSignal];
}

+ (NSLock *)sharedRequestLock
{
    static dispatch_once_t onceToken;
    static NSLock *lock;
    dispatch_once(&onceToken, ^
    {
        lock = [[NSLock alloc] init];
    });
    return lock;
}

- (SSignal *)updatedAssetsForAssets:(NSArray *)assets
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        NSMutableArray *identifiers = [[NSMutableArray alloc] init];
        for (TGMediaAsset *asset in assets)
            [identifiers addObject:asset.identifier];
        
        NSMutableArray *updatedAssets = [[NSMutableArray alloc] init];
        
        [[TGMediaAssetsModernLibrary sharedRequestLock] lock];
        @autoreleasepool
        {
            PHFetchResult *fetchResult =  [PHAsset fetchAssetsWithLocalIdentifiers:identifiers options:nil];
            for (PHAsset *asset in fetchResult)
            {
                TGMediaAsset *updatedAsset = [[TGMediaAsset alloc] initWithPHAsset:asset];
                if (updatedAsset != nil)
                    [updatedAssets addObject:updatedAsset];
            }
        }
        [[TGMediaAssetsModernLibrary sharedRequestLock] unlock];
        
        [subscriber putNext:updatedAssets];
        [subscriber putCompletion];
        
        return nil;
    }];
}

- (SSignal *)assetWithIdentifier:(NSString *)identifier
{
    if (identifier.length == 0)
        return [SSignal fail:nil];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        PHAsset *asset = nil;
        
        [[TGMediaAssetsModernLibrary sharedRequestLock] lock];
        @autoreleasepool
        {
            asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[ identifier ] options:nil].firstObject;
        }
        [[TGMediaAssetsModernLibrary sharedRequestLock] unlock];
        
        if (asset != nil)
        {
            [subscriber putNext:[[TGMediaAsset alloc] initWithPHAsset:asset]];
            [subscriber putCompletion];
        }
        else
        {
            [subscriber putError:nil];
        }
        
        return nil;
    }];
}

#pragma mark - 

- (void)photoLibraryDidChange:(PHChange *)change
{
    __strong TGMediaAssetsModernLibrary *strongSelf = self;
    if (strongSelf != nil)
        strongSelf->_libraryChangePipe.sink(change);
}

- (SSignal *)libraryChanged
{
    return [_libraryChangePipe.signalProducer() filter:^bool(PHChange *change)
    {
        return (change != nil);
    }];
}

#pragma mark -

- (SSignal *)saveAssetWithImage:(UIImage *)image
{
    return [[TGMediaAssetsModernLibrary _requestAuthorization] mapToSignal:^SSignal *(NSNumber *statusValue)
    {
        TGMediaLibraryAuthorizationStatus status = (TGMediaLibraryAuthorizationStatus)[statusValue integerValue];
        if (status != TGMediaLibraryAuthorizationStatusAuthorized)
            return [SSignal fail:nil];
       
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
            {
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError *error)
            {
                if (error == nil && success)
                    [subscriber putCompletion];
                else
                    [subscriber putError:error];
            }];
            
            return nil;
        }];
    }];
}

- (SSignal *)saveAssetWithImageData:(NSData *)imageData
{
    if (imageData == nil || imageData.length == 0)
        return [SSignal fail:nil];
    
    return [self saveAssetWithImage:[UIImage imageWithData:imageData]];
}

- (SSignal *)_saveAssetWithUrl:(NSURL *)url isVideo:(bool)isVideo
{
    return [[TGMediaAssetsModernLibrary _requestAuthorization] mapToSignal:^SSignal *(NSNumber *statusValue)
    {
        TGMediaLibraryAuthorizationStatus status = (TGMediaLibraryAuthorizationStatus)[statusValue integerValue];
        if (status != TGMediaLibraryAuthorizationStatusAuthorized)
            return [SSignal fail:nil];
       
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^
            {
                if (!isVideo)
                    [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
                else
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
            } completionHandler:^(BOOL success, NSError *error)
            {
                if (error == nil && success)
                    [subscriber putCompletion];
                else
                    [subscriber putError:error];
            }];
            
            return nil;
        }];
    }];
}

#pragma mark -

+ (SSignal *)_requestAuthorization
{
    if (TGMediaLibraryCachedAuthorizationStatus != TGMediaLibraryAuthorizationStatusNotDetermined)
        return [SSignal single:@(TGMediaLibraryCachedAuthorizationStatus)];
    
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status)
        {
            TGMediaLibraryAuthorizationStatus authorizationStatus = [self _authorizationStatusForPHAuthorizationStatus:status];
            TGMediaLibraryCachedAuthorizationStatus = authorizationStatus;
            [subscriber putNext:@(authorizationStatus)];
            [subscriber putCompletion];
        }];
        
        return nil;
    }];
}

+ (SSignal *)authorizationStatusSignal
{
    return [self _requestAuthorization];
}

+ (void)requestAuthorizationForAssetType:(TGMediaAssetType)assetType completion:(void (^)(TGMediaLibraryAuthorizationStatus, TGMediaAssetGroup *))completion
{
    TGMediaLibraryAuthorizationStatus currentStatus = [self authorizationStatus];
    if (currentStatus == TGMediaLibraryAuthorizationStatusDenied || currentStatus == TGMediaLibraryAuthorizationStatusRestricted)
    {
        completion(currentStatus, nil);
    }
    else
    {
        [[[self _requestAuthorization] mapToSignal:^SSignal *(NSNumber *statusValue)
        {
            TGMediaLibraryAuthorizationStatus status = (TGMediaLibraryAuthorizationStatus)statusValue.integerValue;
            if (status == TGMediaLibraryAuthorizationStatusAuthorized)
            {
                TGMediaAssetsLibrary *library = [self libraryForAssetType:assetType];
                return [library cameraRollGroup];
            }
            else
            {
                completion(status, nil);
                return [SSignal complete];
            }
        }] startWithNext:^(TGMediaAssetGroup *group)
        {
            completion(TGMediaLibraryAuthorizationStatusAuthorized, group);
        } error:^(__unused id error)
        {
            completion([self authorizationStatus], nil);
        } completed:nil];
    }
}

+ (TGMediaLibraryAuthorizationStatus)authorizationStatus
{
    return [self _authorizationStatusForPHAuthorizationStatus:[PHPhotoLibrary authorizationStatus]];
}

+ (TGMediaLibraryAuthorizationStatus)_authorizationStatusForPHAuthorizationStatus:(PHAuthorizationStatus)status
{
    switch (status)
    {
        case PHAuthorizationStatusRestricted:
            return TGMediaLibraryAuthorizationStatusRestricted;
            
        case PHAuthorizationStatusDenied:
            return TGMediaLibraryAuthorizationStatusDenied;
            
        case PHAuthorizationStatusAuthorized:
            return TGMediaLibraryAuthorizationStatusAuthorized;
            
        default:
            return TGMediaLibraryAuthorizationStatusNotDetermined;
    }
}

@end
