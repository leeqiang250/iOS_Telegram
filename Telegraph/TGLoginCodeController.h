/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGViewController.h"

#import "ActionStage.h"

#import "TGNavigationController.h"

@interface TGLoginCodeController : TGViewController <ASWatcher, TGNavigationControllerItem>

@property (nonatomic, strong) ASHandle *actionHandle;

@property (nonatomic, strong) NSString *phoneNumber;
@property (nonatomic, strong) NSString *registePhoneNumber;
@property (nonatomic, strong) NSString *phoneCodeHash;
@property (nonatomic, strong) NSString *phoneCode;
@property (nonatomic, assign) bool needInvitationCode;

- (id)initWithShowKeyboard:(bool)showKeyboard phoneNumber:(NSString *)phoneNumber phoneCodeHash:(NSString *)phoneCodeHash phoneTimeout:(NSTimeInterval)phoneTimeout messageSentToTelegram:(bool)messageSentToTelegram messageSentViaPhone:(bool)messageSentViaPhone needInvitationCode:(bool)needInvitationCode registePhoneNumber:(NSString*)registePhoneNumber;

- (void)applyCode:(NSString *)code;

@end
