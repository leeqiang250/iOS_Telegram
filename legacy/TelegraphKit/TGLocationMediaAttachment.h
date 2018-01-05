/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMediaAttachment.h"

#define TGLocationMediaAttachmentType 0x0C9ED06E

@interface TGVenueAttachment : NSObject <NSCoding>

@property (nonatomic, strong, readonly) NSString *title;
@property (nonatomic, strong, readonly) NSString *address;
@property (nonatomic, strong, readonly) NSString *provider;
@property (nonatomic, strong, readonly) NSString *venueId;

- (instancetype)initWithTitle:(NSString *)title address:(NSString *)address provider:(NSString *)provider venueId:(NSString *)venueId;

@end

@interface TGLocationMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding>

@property (nonatomic) double latitude;
@property (nonatomic) double longitude;

@property (nonatomic, strong) TGVenueAttachment *venue;

@end
