#import "TGNeoAudioMessageViewModel.h"
#import "TGBridgeMessage.h"

@interface TGNeoAudioMessageViewModel ()
{
    TGNeoLabelViewModel *_nameModel;
    TGNeoLabelViewModel *_durationModel;
    
    bool _isVoiceMessage;
    int32_t _duration;
    
    UIColor *_iconTint;
    NSString *_spinnerName;
}
@end

@implementation TGNeoAudioMessageViewModel

- (instancetype)initWithMessage:(TGBridgeMessage *)message type:(TGNeoMessageType)type users:(NSDictionary *)users context:(TGBridgeContext *)context
{
    self = [super initWithMessage:message type:type users:users context:context];
    if (self != nil)
    {
        TGBridgeAudioMediaAttachment *audioAttachment = nil;
        TGBridgeDocumentMediaAttachment *documentAttachment = nil;
        
        for (TGBridgeMediaAttachment *attachment in message.media)
        {
            if ([attachment isKindOfClass:[TGBridgeAudioMediaAttachment class]])
            {
                audioAttachment = (TGBridgeAudioMediaAttachment *)attachment;
                _isVoiceMessage = true;
                _duration = audioAttachment.duration;
                break;
            }
            else if ([attachment isKindOfClass:[TGBridgeDocumentMediaAttachment class]])
            {
                documentAttachment = (TGBridgeDocumentMediaAttachment *)attachment;
                _isVoiceMessage = documentAttachment.isVoice;
                _duration = documentAttachment.duration;
                break;
            }
        }

        NSString *title = TGLocalized(@"Message.Audio");
        NSString *subtitle = @"";
        
        if (!_isVoiceMessage)
        {
            [self removeSubmodel:self.forwardHeaderModel];
            self.forwardHeaderModel = nil;

            if (documentAttachment.title.length > 0)
                title = documentAttachment.title;
            else
                title = documentAttachment.fileName;
            
            subtitle = documentAttachment.performer.length > 0 ? documentAttachment.performer : @"";
        }
        else
        {
            NSInteger durationMinutes = floor(_duration / 60.0);
            NSInteger durationSeconds = _duration % 60;
            subtitle = [NSString stringWithFormat:@"%ld:%02ld", (long)durationMinutes, (long)durationSeconds];
        }
        
        _nameModel = [[TGNeoLabelViewModel alloc] initWithText:title font:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[self normalColorForMessage:message] attributes:nil];
        _nameModel.multiline = false;
        [self addSubmodel:_nameModel];
        
        _durationModel = [[TGNeoLabelViewModel alloc] initWithText:subtitle font:[UIFont systemFontOfSize:12] color:[self subtitleColorForMessage:message] attributes:nil];
        _durationModel.multiline = false;
        [self addSubmodel:_durationModel];
        
        _iconTint = [self accentColorForMessage:message];
        if (message.outgoing)
            _spinnerName = @"BubbleSpinner";
        else
            _spinnerName = @"BubbleSpinnerIncoming";
    }
    return self;
}

- (CGSize)layoutWithContainerSize:(CGSize)containerSize
{
    CGSize contentContainerSize = [self contentContainerSizeWithContainerSize:containerSize];
    
    CGSize headerSize = [self layoutHeaderModelsWithContainerSize:contentContainerSize];
    CGFloat maxContentWidth = headerSize.width;
    CGFloat textTopOffset = headerSize.height;
    
    CGFloat leftOffset = 26 + TGNeoBubbleMessageMetaSpacing;
    
    UIEdgeInsets inset = UIEdgeInsetsMake(textTopOffset + 1.5f, TGNeoBubbleMessageViewModelInsets.left, 0, 0);
    NSDictionary *audioButtonDictionary = @{};
    if (_isVoiceMessage)
    {
        audioButtonDictionary = @{ TGNeoMessageAudioIcon: @"MediaAudioPlay",
                                   TGNeoMessageAudioIconTint: _iconTint,
                                   TGNeoMessageAudioAnimatedIcon: _spinnerName,
                                   TGNeoMessageAudioButtonHasBackground: @false };
        inset.left -= 4;
        leftOffset -= 5;
    }

    contentContainerSize = CGSizeMake(containerSize.width - TGNeoBubbleMessageViewModelInsets.left - TGNeoBubbleMessageViewModelInsets.right - leftOffset, FLT_MAX);
    
    CGSize nameSize = [_nameModel contentSizeWithContainerSize:contentContainerSize];
    CGSize durationSize = [_durationModel contentSizeWithContainerSize:contentContainerSize];
    maxContentWidth = MAX(maxContentWidth, MAX(nameSize.width, durationSize.width) + leftOffset);
    
    _nameModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, textTopOffset, nameSize.width, 14);
    _durationModel.frame = CGRectMake(TGNeoBubbleMessageViewModelInsets.left + leftOffset, CGRectGetMaxY(_nameModel.frame), durationSize.width, 14);
    
    [self addAdditionalLayout:@{ TGNeoContentInset: [NSValue valueWithUIEdgeInsets:inset], TGNeoMessageAudioButton: audioButtonDictionary } withKey:TGNeoMessageMetaGroup];
    
    CGSize contentSize = CGSizeMake(inset.left + TGNeoBubbleMessageViewModelInsets.right + maxContentWidth, CGRectGetMaxY(_durationModel.frame) + TGNeoBubbleMessageViewModelInsets.bottom);
    
    [super layoutWithContainerSize:contentSize];
    
    return contentSize;
}

@end
