/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#if defined(MtProtoKitDynamicFramework)
#   import <MTProtoKitDynamic/MTMessageService.h>
#elif defined(MtProtoKitMacFramework)
#   import <MTProtoKitMac/MTMessageService.h>
#else
#   import <MTProtoKit/MTMessageService.h>
#endif

@class MTResendMessageService;

@protocol MTResendMessageServiceDelegate <NSObject>

@optional

- (void)resendMessageServiceCompleted:(MTResendMessageService *)resendService;

@end

@interface MTResendMessageService : NSObject <MTMessageService>

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, weak) id<MTResendMessageServiceDelegate> delegate;

- (instancetype)initWithMessageId:(int64_t)messageId;

@end
