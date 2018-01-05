/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGCollectionMenuController.h"

#import "ASWatcher.h"

@interface TGCreateGroupController : TGCollectionMenuController

- (void)setUserIds:(NSArray *)userIds;

- (instancetype)initWithCreateChannel:(bool)createChannel createChannelGroup:(bool)createChannelGroup;

@end
