/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@interface TGListsTableView : UITableView

@property (nonatomic, assign) bool blockContentOffset;
@property (nonatomic, assign) CGFloat indexOffset;
@property (nonatomic, assign) bool mayHaveIndex;
@property (nonatomic, copy) void (^onHitTest)(CGPoint);

- (void)adjustBehaviour;

@end
