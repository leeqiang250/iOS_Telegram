#import <AVFoundation/AVFoundation.h>
#import "TGVideoEditAdjustments.h"

@protocol TGVideoCameraPipelineDelegate;


@interface TGVideoCameraPipeline : NSObject

@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign) bool renderingEnabled;
@property (nonatomic, readonly) NSTimeInterval videoDuration;
@property (nonatomic, readonly) CGAffineTransform videoTransform;
@property (nonatomic, readonly) bool isRecording;

@property (nonatomic, copy) void (^micLevel)(CGFloat);

- (instancetype)initWithDelegate:(id<TGVideoCameraPipelineDelegate>)delegate position:(AVCaptureDevicePosition)position callbackQueue:(dispatch_queue_t)queue;

- (void)startRunning;
- (void)stopRunning;

- (void)startRecording:(NSURL *)url preset:(TGMediaVideoConversionPreset)preset liveUpload:(bool)liveUpload;
- (void)stopRecording;

- (CGAffineTransform)transformForOrientation:(AVCaptureVideoOrientation)orientation;

- (void)setCameraPosition:(AVCaptureDevicePosition)position;
+ (bool)cameraPositionChangeAvailable;

@end


@protocol TGVideoCameraPipelineDelegate <NSObject>
@required

- (void)capturePipeline:(TGVideoCameraPipeline *)capturePipeline didStopRunningWithError:(NSError *)error;

- (void)capturePipeline:(TGVideoCameraPipeline *)capturePipeline previewPixelBufferReadyForDisplay:(CVPixelBufferRef)previewPixelBuffer;
- (void)capturePipelineDidRunOutOfPreviewBuffers:(TGVideoCameraPipeline *)capturePipeline;

- (void)capturePipelineRecordingDidStart:(TGVideoCameraPipeline *)capturePipeline;
- (void)capturePipeline:(TGVideoCameraPipeline *)capturePipeline recordingDidFailWithError:(NSError *)error;
- (void)capturePipelineRecordingWillStop:(TGVideoCameraPipeline *)capturePipeline;
- (void)capturePipelineRecordingDidStop:(TGVideoCameraPipeline *)capturePipeline duration:(NSTimeInterval)duration liveUploadData:(id)liveUploadData thumbnailImage:(UIImage *)thumbnailImage thumbnails:(NSDictionary *)thumbnails;

@end
