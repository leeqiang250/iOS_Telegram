#import <Foundation/Foundation.h>

#import <SSignalKit/SSignalKit.h>

@interface TGChannelStateSignals : NSObject

+ (void)addChannelUpdates:(int64_t)peerId updates:(NSArray *)updates;
+ (SSignal *)updatedChannel:(int64_t)peerId;
+ (void)clearChannelStates;
+ (SSignal *)pollOnce:(int64_t)peerId;
+ (SSignal *)addInviterMessage:(int64_t)peerId accessHash:(int64_t)accessHash;
+ (SSignal *)validateMessageRanges:(int64_t)peerId pts:(int32_t)pts validPts:(int32_t)validPts messageRanges:(NSArray *)messageRanges;

@end
