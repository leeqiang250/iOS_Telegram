/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "TGMediaAttachment.h"

#import "TGImageInfo.h"

#import "TGDocumentAttributeFilename.h"
#import "TGDocumentAttributeAnimated.h"
#import "TGDocumentAttributeSticker.h"
#import "TGDocumentAttributeImageSize.h"
#import "TGDocumentAttributeAudio.h"
#import "TGDocumentAttributeVideo.h"

#define TGDocumentMediaAttachmentType ((int)0xE6C64318)

@interface TGDocumentMediaAttachment : TGMediaAttachment <TGMediaAttachmentParser, NSCoding, NSCopying>

@property (nonatomic) int64_t localDocumentId;

@property (nonatomic) int64_t documentId;
@property (nonatomic) int64_t accessHash;
@property (nonatomic) int datacenterId;
@property (nonatomic) int32_t userId;
@property (nonatomic) int date;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic) int size;
@property (nonatomic) int32_t version;
@property (nonatomic, strong) TGImageInfo *thumbnailInfo;

@property (nonatomic, strong) NSString *documentUri;

@property (nonatomic, strong) NSArray *attributes;
@property (nonatomic, strong) NSString *caption;

@property (nonatomic, readonly) NSArray *textCheckingResults;

- (NSString *)safeFileName;
+ (NSString *)safeFileNameForFileName:(NSString *)fileName;
- (NSString *)fileName;

- (bool)isAnimated;
- (bool)isSticker;
- (bool)isStickerWithPack;
- (id<TGStickerPackReference>)stickerPackReference;
- (bool)isVoice;
- (CGSize)pictureSize;
- (bool)isRoundVideo;

@end
