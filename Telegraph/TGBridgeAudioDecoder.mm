#import "TGBridgeAudioDecoder.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#import "TGAudioBuffer.h"

#import "ATQueue.h"

#import "opusfile.h"
#import "opusenc.h"

const NSInteger TGBridgeAudioDecoderInputSampleRate = 48000;
const NSInteger TGBridgeAudioDecoderResultSampleRate = 24000;
const NSUInteger TGBridgeAudioDecoderBufferSize = 32768;

#define checkResult(result,operation) (_checkResultLite((result),(operation),__FILE__,__LINE__))

static inline bool _checkResultLite(OSStatus result, const char *operation, const char* file, int line)
{
    if ( result != noErr )
    {
        NSLog(@"%s:%d: %s result %d %08X %4.4s\n", file, line, operation, (int)result, (int)result, (char*)&result);
        return NO;
    }
    return YES;
}

@interface TGBridgeAudioDecoder ()
{
    NSURL *_url;
    NSURL *_resultURL;
    
    OggOpusFile *_opusFile;
    
    bool _finished;
    bool _cancelled;
}
@end

@implementation TGBridgeAudioDecoder

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil)
    {
        _url = url;
        
        int64_t randomId = 0;
        arc4random_buf(&randomId, 8);
        _resultURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString alloc] initWithFormat:@"%" PRIx64 "", randomId]]];
    }
    return self;
}

- (void)startWithCompletion:(void (^)(NSURL *))completion
{
    [[TGBridgeAudioDecoder processingQueue] dispatch:^
    {
        int error = OPUS_OK;
        _opusFile = op_open_file(_url.path.UTF8String, &error);
        if (_opusFile == NULL || error != OPUS_OK)
        {
            return;
        }
        
        AudioStreamBasicDescription sourceFormat;
        sourceFormat.mSampleRate = TGBridgeAudioDecoderInputSampleRate;
        sourceFormat.mFormatID = kAudioFormatLinearPCM;
        sourceFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        sourceFormat.mFramesPerPacket = 1;
        sourceFormat.mChannelsPerFrame = 1;
        sourceFormat.mBitsPerChannel = 16;
        sourceFormat.mBytesPerPacket = 2;
        sourceFormat.mBytesPerFrame = 2;
        
        AudioStreamBasicDescription destFormat;
        memset(&destFormat, 0, sizeof(destFormat));
        destFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame;
        destFormat.mFormatID = kAudioFormatMPEG4AAC;
        destFormat.mSampleRate = TGBridgeAudioDecoderResultSampleRate;
        UInt32 size = sizeof(destFormat);
        if (!checkResult(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &destFormat),
                          "AudioFormatGetProperty(kAudioFormatProperty_FormatInfo)"))
        {
            return;
        }
        
        ExtAudioFileRef destinationFile;
        if (!checkResult(ExtAudioFileCreateWithURL((__bridge CFURLRef)_resultURL, kAudioFileM4AType, &destFormat, NULL, kAudioFileFlags_EraseFile, &destinationFile), "ExtAudioFileCreateWithURL"))
        {
            return;
        }
        
        if (!checkResult(ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat, size, &sourceFormat),
                         "ExtAudioFileSetProperty(destinationFile, kExtAudioFileProperty_ClientDataFormat"))
        {
            return;
        }
        
        bool canResumeAfterInterruption = false;
        AudioConverterRef converter;
        size = sizeof(converter);
        if (checkResult(ExtAudioFileGetProperty(destinationFile, kExtAudioFileProperty_AudioConverter, &size, &converter),
                         "ExtAudioFileGetProperty(kExtAudioFileProperty_AudioConverter;)"))
        {
            UInt32 canResume = 0;
            size = sizeof(canResume);
            if (AudioConverterGetProperty(converter, kAudioConverterPropertyCanResumeFromInterruption, &size, &canResume) == noErr)
                canResumeAfterInterruption = canResume;
        }
        
        uint8_t srcBuffer[TGBridgeAudioDecoderBufferSize];
        while (!_cancelled)
        {
            AudioBufferList bufferList;
            bufferList.mNumberBuffers = 1;
            bufferList.mBuffers[0].mNumberChannels = sourceFormat.mChannelsPerFrame;
            bufferList.mBuffers[0].mDataByteSize = TGBridgeAudioDecoderBufferSize;
            bufferList.mBuffers[0].mData = srcBuffer;
            
            uint32_t writtenOutputBytes = 0;
            while (writtenOutputBytes < TGBridgeAudioDecoderBufferSize)
            {
                int32_t readSamples = op_read(_opusFile, (opus_int16 *)(srcBuffer + writtenOutputBytes), (TGBridgeAudioDecoderBufferSize - writtenOutputBytes) / sourceFormat.mBytesPerFrame, NULL);
                
                if (readSamples > 0)
                    writtenOutputBytes += readSamples * sourceFormat.mBytesPerFrame;
                else
                    break;
            }
            bufferList.mBuffers[0].mDataByteSize = writtenOutputBytes;
            int32_t nFrames = writtenOutputBytes / sourceFormat.mBytesPerFrame;
            
            if (nFrames == 0)
                break;
            
            OSStatus status = ExtAudioFileWrite(destinationFile, nFrames, &bufferList);
            if (status == kExtAudioFileError_CodecUnavailableInputConsumed)
            {
                TGLog(@"1");
            }
            else if (status == kExtAudioFileError_CodecUnavailableInputNotConsumed)
            {
                TGLog(@"2");
            }
            else if (!checkResult(status, "ExtAudioFileWrite"))
            {
                TGLog(@"3");
            }
        }
        
        ExtAudioFileDispose(destinationFile);
        
        if (completion != nil)
            completion(_resultURL);
    }];
}

- (void)stop
{
    
}

+ (ATQueue *)processingQueue
{
    static ATQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[ATQueue alloc] initWithName:@"org.telegram.opusAudioDecoderQueue"];
    });
    
    return queue;
}

@end
