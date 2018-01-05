/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMenuItem.h"

#define TGSwitchItemType ((int)0x13F663CB)

@interface TGSwitchItem : TGMenuItem

@property (nonatomic, strong) NSString *title;
@property (nonatomic) bool isOn;

@property (nonatomic) SEL action;

- (id)initWithTitle:(NSString *)title;

@end
