#import "TGMediaAssetModernImageSignals.h"

#import <Photos/Photos.h>
#import "UIImage+TG.h"

#import "TGPhotoEditorUtils.h"
#import "TGImageUtils.h"
#import "TGImageBlur.h"

#import "TGTimer.h"

#import "TGMediaAsset.h"

@implementation TGMediaAssetModernImageSignals

+ (SSignal *)imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)allowNetworkAccess
{
    return [self _imageForAsset:asset imageType:imageType size:size allowNetworkAccess:allowNetworkAccess suppressNetworkError:false];
}

+ (SSignal *)_imageForAsset:(TGMediaAsset *)asset imageType:(TGMediaAssetImageType)imageType size:(CGSize)size allowNetworkAccess:(bool)allowNetworkAccess suppressNetworkError:(bool)suppressNetworkError
{    
    CGSize imageSize = size;
    if (imageType == TGMediaAssetImageTypeFullSize)
        imageSize = PHImageManagerMaximumSize;
    
    bool isScreenImage = (imageType == TGMediaAssetImageTypeScreen || imageType == TGMediaAssetImageTypeFastScreen);
    
    PHImageRequestOptions *options = [TGMediaAssetModernImageSignals _optionsForAssetImageType:imageType];
    
    PHImageContentMode contentMode = PHImageContentModeAspectFill;
    if (isScreenImage)
        contentMode = PHImageContentModeAspectFit;
    
    if ([asset representsBurst] && (isScreenImage || imageType == TGMediaAssetImageTypeFullSize))
    {
        SSignal *signal = [[[self imageDataForAsset:asset] filter:^bool(id value)
        {
            return [value isKindOfClass:[TGMediaAssetImageData class]];
        }] map:^UIImage *(TGMediaAssetImageData *data)
        {
            UIImage *image = [UIImage imageWithData:data.imageData];
            
            if (imageType != TGMediaAssetImageTypeFullSize)
            {
                CGSize fittedSize = TGFitSize(image.size, size);
                image = TGScaleImageToPixelSize(image, fittedSize);
            }
            
            return image;
        }];
        
        if (imageType == TGMediaAssetImageTypeFastScreen)
            signal = [[[self imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeMake(128, 128) allowNetworkAccess:allowNetworkAccess] take:1] then:signal];
        
        return signal;
    }
    else if (asset.isVideo && asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate && isScreenImage)
    {
        SSignal *signal = [[[self avAssetForVideoAsset:asset allowNetworkAccess:allowNetworkAccess] filter:^bool(id value)
        {
            return [value isKindOfClass:[AVAsset class]];
        }] mapToSignal:^SSignal *(AVAsset *avAsset)
        {
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:avAsset];
                imageGenerator.appliesPreferredTrackTransform = true;
                imageGenerator.maximumSize = size;
                
                [imageGenerator generateCGImagesAsynchronouslyForTimes:@[ [NSValue valueWithCMTime:kCMTimeZero] ] completionHandler:^(__unused CMTime requestedTime, CGImageRef cgImage, __unused CMTime actualTime, __unused AVAssetImageGeneratorResult result, NSError *error)
                {
                    if (error == nil && cgImage != NULL)
                    {
                        UIImage *image = [UIImage imageWithCGImage:cgImage];
                        [subscriber putNext:image];
                        [subscriber putCompletion];
                    }
                    else
                    {
                        [subscriber putError:error];
                    }
                }];
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [imageGenerator cancelAllCGImageGeneration];
                }];
            }];
        }];
        
        if (imageType == TGMediaAssetImageTypeFastScreen)
            signal = [[[self imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:CGSizeMake(128, 128) allowNetworkAccess:allowNetworkAccess] take:1] then:signal];
        
        return signal;
    }
    else
    {
        SSignal *(^requestImageSignal)(bool) = ^SSignal *(bool networkAccessAllowed)
        {
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                PHImageRequestOptions *requestOptions = options;
                if (networkAccessAllowed)
                {
                    if (imageType == TGMediaAssetImageTypeFastScreen)
                        requestOptions = [TGMediaAssetModernImageSignals _optionsForAssetImageType:TGMediaAssetImageTypeScreen];
                    else
                        requestOptions = [options copy];

                    requestOptions.networkAccessAllowed = true;
                    
                    if (isScreenImage || imageType == TGMediaAssetImageTypeFullSize)
                    {
                        requestOptions.progressHandler = ^(double progress, __unused NSError *error, __unused BOOL *stop, __unused NSDictionary *info)
                        {
                            [subscriber putNext:@(progress)];
                        };
                    }
                }
                
                PHImageRequestID token = [[self imageManager] requestImageForAsset:asset.backingAsset targetSize:imageSize contentMode:contentMode options:requestOptions resultHandler:^(UIImage *result, NSDictionary *info)
                {
                    bool cancelled = [info[PHImageCancelledKey] boolValue];
                    if (cancelled)
                        return;
                    
                    bool degraded = [info[PHImageResultIsDegradedKey] boolValue];
                    if (result == nil && !networkAccessAllowed)
                    {
                        TGLog(@"requestImageForAsset: error -1");
                        
                        [subscriber putError:@true];
                        return;
                    }
                    
                    if (result != nil)
                    {
                        if (networkAccessAllowed)
                            [subscriber putNext:@(1.0f)];
                        
                        [subscriber putNext:result];
                        if (!degraded)
                            [subscriber putCompletion];
                    }
                    else
                    {
                        [subscriber putError:nil];
                    }
                }];
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [[self imageManager] cancelImageRequest:token];
                }];
            }];
        };
        
        if (allowNetworkAccess && !suppressNetworkError)
        {
            return [requestImageSignal(false) catch:^SSignal *(id error)
            {
                if ([error isKindOfClass:[NSNumber class]])
                {
                    return [[[[self _imageForAsset:asset imageType:TGMediaAssetImageTypeAspectRatioThumbnail size:TGPhotoThumbnailSizeForCurrentScreen() allowNetworkAccess:true suppressNetworkError:true] filter:^bool(id value)
                    {
                        return [value isKindOfClass:[UIImage class]];
                    }] map:^id(UIImage *image)
                    {
                        image.degraded = true;
                        return image;
                    }] then:requestImageSignal(true)];
                }
                
                return [SSignal fail:error];
            }];
        }
        else
        {
            return requestImageSignal(suppressNetworkError);
        }
    }
    
    return [SSignal fail:nil];
}

+ (SSignal *)imageDataForAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    SSignal *(^requestDataSignal)(bool) = ^SSignal *(bool networkAccessAllowed)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            PHImageRequestOptions *options = [TGMediaAssetModernImageSignals _optionsForAssetImageType:TGMediaAssetImageTypeFullSize];
            if (networkAccessAllowed)
            {
                options.networkAccessAllowed = true;
                options.progressHandler = ^(double progress, __unused NSError *error, __unused BOOL *stop, __unused NSDictionary *info)
                {
                    [subscriber putNext:@(progress)];
                };
            }
            
            PHImageRequestID token = [[self imageManager] requestImageDataForAsset:asset.backingAsset options:options resultHandler:^(NSData *imageData, NSString *dataUTI, __unused UIImageOrientation orientation, NSDictionary *info)
            {
                bool inCloud = [info[PHImageResultIsInCloudKey] boolValue];
                if (inCloud && imageData.length == 0)
                {
                    [subscriber putError:@true];
                    return;
                }
                
                NSURL *fileUrl = info[@"PHImageFileURLKey"];
                NSString *fileName = fileUrl.absoluteString.lastPathComponent;
                NSString *fileExtension = fileName.pathExtension;
                if ([fileName isEqualToString:[NSString stringWithFormat:@"FullSizeRender.%@", fileExtension]])
                {
                    NSArray *components = [fileUrl.absoluteString componentsSeparatedByString:@"/"];
                    bool found = false;
                    for (NSString *component in components)
                    {
                        if ([component hasPrefix:@"IMG_"])
                        {
                            fileName = [NSString stringWithFormat:@"%@.%@", component, fileExtension];
                            found = true;
                            break;
                        }
                    }
                    if (!found)
                        fileName = asset.fileName;
                }
                
                TGMediaAssetImageData *data = [[TGMediaAssetImageData alloc] init];
                data.fileURL = fileUrl;
                data.fileName = fileName;
                data.fileUTI = dataUTI;
                data.imageData = imageData;
                
                if (networkAccessAllowed)
                    [subscriber putNext:@(1.0f)];
                
                [subscriber putNext:data];
                [subscriber putCompletion];
            }];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [[self imageManager] cancelImageRequest:token];
            }];
        }];
    };
    
    if (allowNetworkAccess)
    {
        return [requestDataSignal(false) catch:^SSignal *(id error)
        {
            if ([error isKindOfClass:[NSNumber class]])
                return requestDataSignal(true);
            
            return [SSignal fail:error];
        }];
    }
    else
    {
        return requestDataSignal(false);
    }
}

+ (NSDictionary *)metadataWithImageData:(NSData *)imageData
{
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)(imageData), NULL);
    if (imageSource != NULL)
    {
        NSDictionary *options = @{ (NSString *)kCGImageSourceShouldCache : @false };
        CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (__bridge CFDictionaryRef)options);
        if (imageProperties != NULL)
        {
            NSDictionary *metadata = (__bridge NSDictionary *)imageProperties;
            CFRelease(imageProperties);
            CFRelease(imageSource);
            return metadata;
        }
        CFRelease(imageSource);
    }
    
    return nil;
}

+ (SSignal *)imageMetadataForAsset:(TGMediaAsset *)asset
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
        options.networkAccessAllowed = false;
        
        PHContentEditingInputRequestID token = [[self imageManager] requestImageDataForAsset:asset.backingAsset options:options resultHandler:^(NSData *imageData, __unused NSString * dataUTI, __unused UIImageOrientation orientation, __unused NSDictionary *info)
        {
            if (imageData != nil)
            {
                NSDictionary *metadata = [self metadataWithImageData:imageData];
                [subscriber putNext:metadata];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [asset.backingAsset cancelContentEditingInputRequest:token];
        }];
    }];
}

+ (SSignal *)fileAttributesForAsset:(TGMediaAsset *)asset
{
    SSignal *attributesSignal = [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        PHImageRequestID token = [[PHImageManager defaultManager] requestImageDataForAsset:asset.backingAsset options:nil resultHandler:^(NSData *data, NSString *dataUTI, __unused UIImageOrientation orientation, NSDictionary *info)
        {
            NSURL *fileUrl = info[@"PHImageFileURLKey"];
            
            TGMediaAssetImageFileAttributes *attributes = [[TGMediaAssetImageFileAttributes alloc] init];
            attributes.fileName = fileUrl.absoluteString.lastPathComponent;
            attributes.fileUTI = dataUTI;
            attributes.dimensions = asset.dimensions;
            attributes.fileSize = data.length;
            
            [subscriber putNext:attributes];
            [subscriber putCompletion];
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [[PHImageManager defaultManager] cancelImageRequest:token];
        }];
    }];
    
    if (asset.isVideo)
    {
        return [[self avAssetForVideoAsset:asset] mapToSignal:^SSignal *(AVAsset *avAsset)
        {
            if ([avAsset isKindOfClass:[AVURLAsset class]])
            {
                return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
                {
                    NSURL *assetUrl = ((AVURLAsset *)avAsset).URL;
                    
                    NSString *uti;
                    [assetUrl getResourceValue:&uti forKey:NSURLTypeIdentifierKey error:nil];
                    
                    NSNumber *size;
                    [assetUrl getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
                    
                    TGMediaAssetImageFileAttributes *attributes = [[TGMediaAssetImageFileAttributes alloc] init];
                    attributes.fileName = assetUrl.absoluteString.lastPathComponent;
                    attributes.fileUTI = uti;
                    attributes.dimensions = asset.dimensions;
                    attributes.fileSize = size.unsignedIntegerValue;
                    
                    [subscriber putNext:attributes];
                    [subscriber putCompletion];
                    
                    return nil;
                }];
            }
            else if ([avAsset isKindOfClass:[AVComposition class]])
            {
                return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
                {
                    AVAssetTrack *track = avAsset.tracks.firstObject;
                    if (track == nil)
                    {
                        [subscriber putError:nil];
                        return nil;
                    }
                    
                    AVCompositionTrackSegment *segment = (AVCompositionTrackSegment *)track.segments.firstObject;
                    if (![segment isKindOfClass:[AVCompositionTrackSegment class]])
                    {
                        [subscriber putError:nil];
                        return nil;
                    }
                    
                    NSURL *assetUrl = segment.sourceURL;
                    if (assetUrl == nil)
                    {
                        [subscriber putError:nil];
                        return nil;
                    }

                    NSString *uti;
                    [assetUrl getResourceValue:&uti forKey:NSURLTypeIdentifierKey error:nil];
                    
                    int32_t estimatedSize = 0;
                    NSArray *tracks = avAsset.tracks;
                    for (AVAssetTrack * track in tracks)
                    {
                        CGFloat rate = [track estimatedDataRate] / 8.0f;
                        CGFloat seconds = CMTimeGetSeconds(track.timeRange.duration);
                        estimatedSize += (int32_t)(seconds * rate);
                    }
                    
                    TGMediaAssetImageFileAttributes *attributes = [[TGMediaAssetImageFileAttributes alloc] init];
                    attributes.fileName = assetUrl.absoluteString.lastPathComponent;
                    attributes.fileUTI = uti;
                    attributes.dimensions = asset.dimensions;
                    attributes.fileSize = estimatedSize;
                    
                    [subscriber putNext:attributes];
                    [subscriber putCompletion];
                    
                    return nil;
                }];
            }
            
            return [SSignal fail:nil];
        }];
    }
    else
    {
        return attributesSignal;
    }
}

+ (void)startCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    NSArray *backingAssets = [assets valueForKey:@"backingAsset"];
    PHImageRequestOptions *options = [TGMediaAssetModernImageSignals _optionsForAssetImageType:imageType];
    
    [[self imageManager] startCachingImagesForAssets:backingAssets targetSize:size contentMode:PHImageContentModeAspectFill options:options];
}

+ (void)stopCachingImagesForAssets:(NSArray *)assets imageType:(TGMediaAssetImageType)imageType size:(CGSize)size
{
    NSArray *backingAssets = [assets valueForKey:@"backingAsset"];
    PHImageRequestOptions *options = [TGMediaAssetModernImageSignals _optionsForAssetImageType:imageType];
    
    [[self imageManager] stopCachingImagesForAssets:backingAssets targetSize:size contentMode:PHImageContentModeAspectFill options:options];
}

+ (void)stopCachingImagesForAllAssets
{
    [[self imageManager] stopCachingImagesForAllAssets];
}

+ (PHImageRequestOptions *)_optionsForAssetImageType:(TGMediaAssetImageType)imageType
{
    PHImageRequestOptions *options = [PHImageRequestOptions new];
    
    switch (imageType)
    {
        case TGMediaAssetImageTypeFastLargeThumbnail:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            options.resizeMode = PHImageRequestOptionsResizeModeFast;
            break;
            
        case TGMediaAssetImageTypeLargeThumbnail:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            options.resizeMode = PHImageRequestOptionsResizeModeFast;
            break;
            
        case TGMediaAssetImageTypeAspectRatioThumbnail:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            break;
            
        case TGMediaAssetImageTypeScreen:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            options.resizeMode = PHImageRequestOptionsResizeModeExact;
            break;
            
        case TGMediaAssetImageTypeFastScreen:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
            options.resizeMode = PHImageRequestOptionsResizeModeExact;
            break;
            
        case TGMediaAssetImageTypeFullSize:
            options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            options.resizeMode = PHImageRequestOptionsResizeModeNone;
            break;
            
        default:
            break;
    }
    
    return options;
}

+ (SSignal *)saveUncompressedVideoForAsset:(TGMediaAsset *)asset toPath:(NSString *)path allowNetworkAccess:(bool)allowNetworkAccess
{
    if (asset.subtypes & TGMediaAssetSubtypeVideoHighFrameRate)
    {
        SSignal *(^sessionSignal)(bool) = ^(bool networkAccessAllowed)
        {
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                PHVideoRequestOptions *requestOptions = [[PHVideoRequestOptions alloc] init];
                requestOptions.networkAccessAllowed = networkAccessAllowed;
                if (networkAccessAllowed)
                {
                    requestOptions.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
                    requestOptions.progressHandler = ^(double progress, __unused NSError *error, __unused BOOL *stop, __unused NSDictionary *info)
                    {
                        [subscriber putNext:@(progress)];
                    };
                }
                
                PHImageRequestID token = [[self imageManager] requestExportSessionForVideo:asset.backingAsset options:requestOptions exportPreset:AVAssetExportPresetPassthrough resultHandler:^(AVAssetExportSession *exportSession, __unused NSDictionary *info)
                {
                    if (asset == nil && !networkAccessAllowed)
                    {
                        [subscriber putError:@true];
                        return;
                    }
                    
                    if (exportSession != nil)
                    {
                        [subscriber putNext:exportSession];
                        [subscriber putCompletion];
                    }
                    else
                    {
                        [subscriber putError:nil];
                    }
                }];
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [[self imageManager] cancelImageRequest:token];
                }];
            }];
        };
        
        SSignal *(^exportSignal)(AVAssetExportSession *) = ^SSignal *(AVAssetExportSession *exportSession)
        {
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                NSString *fileName = @"VIDEO.MOV";
                if (exportSession.asset != nil)
                {
                    AVAssetTrack *track = [exportSession.asset.tracks firstObject];
                    if (track != nil)
                    {
                        AVCompositionTrackSegment *segment = (AVCompositionTrackSegment *)[track.segments firstObject];
                        if ([segment isKindOfClass:[AVCompositionTrackSegment class]])
                        {
                            NSString *lastPathComponent = [segment.sourceURL lastPathComponent];
                            fileName = lastPathComponent;
                        }
                    }
                }
                
                TGTimer *progressTimer = [[TGTimer alloc] initWithTimeout:0.5 repeat:true completion:^
                {
                    [subscriber putNext:@(exportSession.progress)];
                } queue:[SQueue concurrentDefaultQueue]._dispatch_queue];
                [progressTimer start];
                
                exportSession.outputURL = [NSURL fileURLWithPath:path];
                exportSession.outputFileType = AVFileTypeMPEG4;
                [exportSession exportAsynchronouslyWithCompletionHandler:^
                {
                    if (exportSession.status == AVAssetExportSessionStatusCompleted)
                    {
                        [subscriber putNext:fileName];
                        [subscriber putCompletion];
                    }
                    else
                    {
                        [subscriber putError:nil];
                    }
                }];
                
                return [[SBlockDisposable alloc] initWithBlock:^
                {
                    [progressTimer invalidate];
                    if (exportSession.status != AVAssetExportSessionStatusCompleted)
                        [exportSession cancelExport];
                }];
            }];
        };
        
        SSignal *finalSessionSignal = nil;
        if (allowNetworkAccess)
        {
            finalSessionSignal = [sessionSignal(false) catch:^SSignal *(id error)
            {
                if ([error isKindOfClass:[NSNumber class]])
                    return sessionSignal(true);
                        
                return [SSignal fail:error];
            }];
        }
        else
        {
            finalSessionSignal = sessionSignal(false);
        }
        
        return [finalSessionSignal mapToSignal:^SSignal *(id value)
        {
            if ([value isKindOfClass:[AVAssetExportSession class]])
                return exportSignal(value);
            else
                return [SSignal single:value];
        }];
    }
    else
    {
        return [[self avAssetForVideoAsset:asset allowNetworkAccess:allowNetworkAccess] mapToSignal:^SSignal *(id value)
        {
            if (![value isKindOfClass:[AVURLAsset class]])
                return [SSignal single:value];
            
            AVAsset *avAsset = (AVAsset *)value;
            return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
            {
                NSURL *assetUrl = ((AVURLAsset *)avAsset).URL;
                NSError *error;
            
                [[NSFileManager defaultManager] copyItemAtPath:assetUrl.path toPath:path error:&error];
                
                if (error == nil)
                {
                    NSString *fileName = assetUrl.lastPathComponent;
                    
                    [subscriber putNext:fileName];
                    [subscriber putCompletion];
                }
                else
                {
                    [subscriber putError:error];
                }
                
                return nil;
            }];
        }];
    }
}

+ (SSignal *)playerItemForVideoAsset:(TGMediaAsset *)asset
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        PHVideoRequestOptions *options = [[PHVideoRequestOptions alloc] init];
        options.networkAccessAllowed = true;
        options.progressHandler = ^(double progress, __unused NSError *error, __unused BOOL *stop, __unused NSDictionary *info)
        {
            [subscriber putNext:@(progress)];
        };
        
        PHImageRequestID token = [[self imageManager] requestPlayerItemForVideo:asset.backingAsset options:options resultHandler:^(AVPlayerItem *playerItem, __unused NSDictionary *info)
        {
            bool cancelled = [info[PHImageCancelledKey] boolValue];
            if (cancelled)
                return;
            
            if (playerItem != nil)
            {
                [subscriber putNext:playerItem];
                [subscriber putCompletion];
            }
            else
            {
                [subscriber putError:nil];
            }
        }];
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            [[self imageManager] cancelImageRequest:token];
        }];
    }];
}

+ (SSignal *)avAssetForVideoAsset:(TGMediaAsset *)asset allowNetworkAccess:(bool)allowNetworkAccess
{
    SSignal *(^requestSignal)(bool) = ^(bool networkAccessAllowed)
    {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
        {
            PHVideoRequestOptions *requestOptions = [[PHVideoRequestOptions alloc] init];
            requestOptions.networkAccessAllowed = networkAccessAllowed;
            if (networkAccessAllowed)
            {
                requestOptions.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
                requestOptions.progressHandler = ^(double progress, __unused NSError *error, __unused BOOL *stop, __unused NSDictionary *info)
                {
                    [subscriber putNext:@(progress)];
                };
            }
            
            PHImageRequestID token = [[self imageManager] requestAVAssetForVideo:asset.backingAsset options:requestOptions resultHandler:^(AVAsset *asset, __unused AVAudioMix *audioMix, __unused NSDictionary *info)
            {
                bool cancelled = [info[PHImageCancelledKey] boolValue];
                if (cancelled)
                    return;
                
                if (asset == nil && !networkAccessAllowed)
                {
                    [subscriber putError:@true];
                    return;
                }
                
                if (asset != nil)
                {
                    [subscriber putNext:asset];
                    [subscriber putCompletion];
                }
                else
                {
                    [subscriber putError:nil];
                }
            }];
            
            return [[SBlockDisposable alloc] initWithBlock:^
            {
                [[self imageManager] cancelImageRequest:token];
            }];
        }];
    };
    
    if (allowNetworkAccess)
    {
        return [requestSignal(false) catch:^SSignal *(id error)
        {
            if ([error isKindOfClass:[NSNumber class]])
                return requestSignal(true);
            
            return [SSignal fail:error];
        }];
    }
    else
    {
        return requestSignal(false);
    }
}

+ (PHCachingImageManager *)imageManager
{
    static dispatch_once_t onceToken;
    static PHCachingImageManager *imageManager;
    dispatch_once(&onceToken, ^
    {
        imageManager = [[PHCachingImageManager alloc] init];
    });
    return imageManager;
}

+ (bool)usesPhotoFramework
{
    return true;
}

@end
