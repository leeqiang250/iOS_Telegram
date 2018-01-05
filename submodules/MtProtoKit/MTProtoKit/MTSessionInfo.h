/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <Foundation/Foundation.h>

@class MTContext;

@interface MTSessionInfo : NSObject

@property (nonatomic) bool scheduledForCleanup;
@property (nonatomic) bool canBeDeleted;

- (instancetype)initWithRandomSessionIdAndContext:(MTContext *)context;
- (instancetype)initWithSessionId:(int64_t)sessionId context:(MTContext *)context;

- (int64_t)sessionId;
- (int64_t)generateClientMessageId:(bool *)monotonityViolated;
- (int64_t)generateServerMessageId;
- (int64_t)actualClientMessagId;

- (bool)messageProcessed:(int64_t)messageId;
- (void)setMessageProcessed:(int64_t)messageId;
- (void)scheduleMessageConfirmation:(int64_t)messageId size:(NSInteger)size;
- (NSArray *)scheduledMessageConfirmations;
- (bool)scheduledMessageConfirmationsExceedSize:(NSInteger)sizeLimit orCount:(NSUInteger)countLimit;
- (void)removeScheduledMessageConfirmationsWithIds:(NSArray *)messageIds;
- (void)assignTransactionId:(id)transactionId toScheduledMessageConfirmationsWithIds:(NSArray *)messageIds;
- (void)removeScheduledMessageConfirmationsWithTransactionIds:(NSArray *)transactionIds;

- (void)addContainerMessageIdMapping:(int64_t)containerMessageId childMessageIds:(NSArray *)childMessageIds;
- (NSArray *)messageIdsInContainer:(int64_t)containerMessageId;
- (NSArray *)messageIdsInContainersAfterMessageId:(int64_t)firstMessageId;

- (int32_t)takeSeqNo:(bool)messageIsMeaningful;

@end
