/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@interface MTTimeFixContext : NSObject

@property (nonatomic, readonly) int64_t messageId;
@property (nonatomic, readonly) int32_t messageSeqNo;
@property (nonatomic, strong, readonly) id transactionId;
@property (nonatomic, readonly) CFAbsoluteTime timeFixAbsoluteStartTime;

- (instancetype)initWithMessageId:(int64_t)messageId messageSeqNo:(int32_t)messageSeqNo transactionId:(id)transactionId timeFixAbsoluteStartTime:(CFAbsoluteTime)timeFixAbsoluteStartTime;

@end
