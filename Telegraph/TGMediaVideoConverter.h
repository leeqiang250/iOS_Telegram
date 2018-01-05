#import <SSignalKit/SSignalKit.h>

#import "TGVideoEditAdjustments.h"

@interface TGMediaVideoFileWatcher : NSObject
{
    NSURL *_fileURL;
}

- (void)setupWithFileURL:(NSURL *)fileURL;
- (id)fileUpdated:(bool)completed;

@end


@interface TGMediaVideoConverter : NSObject

+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher;
+ (SSignal *)convertAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments watcher:(TGMediaVideoFileWatcher *)watcher inhibitAudio:(bool)inhibitAudio;
+ (SSignal *)hashForAVAsset:(AVAsset *)avAsset adjustments:(TGMediaVideoEditAdjustments *)adjustments;

+ (NSUInteger)estimatedSizeForPreset:(TGMediaVideoConversionPreset)preset duration:(NSTimeInterval)duration hasAudio:(bool)hasAudio;
+ (TGMediaVideoConversionPreset)bestAvailablePresetForDimensions:(CGSize)dimensions;
+ (CGSize)_renderSizeWithCropSize:(CGSize)cropSize;

@end


@interface TGMediaVideoConversionResult : NSObject

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSUInteger fileSize;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) CGSize dimensions;
@property (nonatomic, readonly) UIImage *coverImage;
@property (nonatomic, readonly) id liveUploadData;

- (NSDictionary *)dictionary;

@end


@interface TGMediaVideoConversionPresetSettings : NSObject

+ (CGSize)maximumSizeForPreset:(TGMediaVideoConversionPreset)preset;
+ (NSDictionary *)videoSettingsForPreset:(TGMediaVideoConversionPreset)preset dimensions:(CGSize)dimensions;
+ (NSDictionary *)audioSettingsForPreset:(TGMediaVideoConversionPreset)preset;


//REMOVE

+ (bool)showVMSize;
+ (void)setShowVMSize:(bool)on;

+ (NSInteger)vmSide;
+ (NSInteger)vmBitrate;

+ (void)setVMSide:(NSInteger)side;
+ (void)setVMBitrate:(NSInteger)bitrate;

@end
