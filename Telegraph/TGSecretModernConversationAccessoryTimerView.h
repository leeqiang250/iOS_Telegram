/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import <UIKit/UIKit.h>

@class TGSecretModernConversationAccessoryTimerView;

@protocol TGSecretModernConversationAccessoryTimerViewDelegate <NSObject>

@optional

- (void)accessoryTimerViewPressed:(TGSecretModernConversationAccessoryTimerView *)accessoryTimerView;

@end

@interface TGSecretModernConversationAccessoryTimerView : UIView

@property (nonatomic, weak) id<TGSecretModernConversationAccessoryTimerViewDelegate> delegate;

@property (nonatomic) NSInteger timerValue;

@end

