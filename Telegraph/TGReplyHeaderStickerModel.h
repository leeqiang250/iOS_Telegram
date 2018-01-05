#import "TGReplyHeaderModel.h"

@class TGUser;
@class TGDocumentMediaAttachment;

@interface TGReplyHeaderStickerModel : TGReplyHeaderModel

- (instancetype)initWithPeer:(id)peer fileMedia:(TGDocumentMediaAttachment *)fileMedia incoming:(bool)incoming system:(bool)system;

@end
