/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGActor.h"

#import "ASWatcher.h"

@interface TGRevokeSessionsActor : TGActor <ASWatcher>

@property (nonatomic, strong) ASHandle *actionHandle;

- (void)revokeSessionsSuccess;
- (void)revokeSessionsFailed;

@end
