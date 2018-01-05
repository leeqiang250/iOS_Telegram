#import "TGChannelBannedRights.h"

#import "PSKeyValueCoder.h"

#import "TLChannelBannedRights.h"

@implementation TGChannelBannedRights

- (instancetype)initWithBanReadMessages:(bool)banReadMessages banSendMessages:(bool)banSendMessages banSendMedia:(bool)banSendMedia banSendStickers:(bool)banSendStickers banSendGifs:(bool)banSendGifs banSendGames:(bool)banSendGames banSendInline:(bool)banSendInline banEmbedLinks:(bool)banEmbedLinks timeout:(int32_t)timeout {
    self = [super init];
    if (self != nil) {
        _banReadMessages = banReadMessages;
        _banSendMessages = banSendMessages;
        _banSendMedia = banSendMedia;
        _banSendStickers = banSendStickers;
        _banSendGifs = banSendGifs;
        _banSendGames = banSendGames;
        _banSendInline = banSendInline;
        _banEmbedLinks = banEmbedLinks;
        _timeout = timeout;
    }
    return self;
}

- (int32_t)tlFlags {
    int32_t flags = 0;
    if (_banReadMessages) {
        flags |= (1 << 0);
    }
    if (_banSendMessages) {
        flags |= (1 << 1);
    }
    if (_banSendMedia) {
        flags |= (1 << 2);
    }
    if (_banSendStickers) {
        flags |= (1 << 3);
    }
    if (_banSendGifs) {
        flags |= (1 << 4);
    }
    if (_banSendGames) {
        flags |= (1 << 5);
    }
    if (_banSendInline) {
        flags |= (1 << 6);
    }
    if (_banEmbedLinks) {
        flags |= (1 << 7);
    }
    return flags;
}

- (instancetype)initWithKeyValueCoder:(PSKeyValueCoder *)coder {
    TLChannelBannedRights *rights = [[TLChannelBannedRights$channelBannedRights alloc] init];
    rights.flags = [coder decodeInt32ForCKey:"f"];
    rights.until_date = [coder decodeInt32ForCKey:"t"];
    return [self initWithTL:(TLChannelBannedRights *)rights];
}

- (instancetype)initWithTL:(TLChannelBannedRights *)tlRights {
    return [self initWithBanReadMessages:tlRights.flags & (1 << 0) banSendMessages:tlRights.flags & (1 << 1) banSendMedia:tlRights.flags & (1 << 2) banSendStickers:tlRights.flags & (1 << 3) banSendGifs:tlRights.flags & (1 << 4) banSendGames:tlRights.flags & (1 << 5) banSendInline:tlRights.flags & (1 << 6) banEmbedLinks:tlRights.flags & (1 << 7) timeout:tlRights.until_date];
}

- (TLChannelBannedRights *)tlRights {
    TLChannelBannedRights$channelBannedRights *rights = [[TLChannelBannedRights$channelBannedRights alloc] init];
    rights.flags = [self tlFlags];
    rights.until_date = _timeout;
    return rights;
}

- (void)encodeWithKeyValueCoder:(PSKeyValueCoder *)coder {
    [coder encodeInt32:[self tlFlags] forCKey:"f"];
    [coder encodeInt32:_timeout forCKey:"t"];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[TGChannelBannedRights class]] && [((TGChannelBannedRights *)object) tlFlags] == [self tlFlags] && ((TGChannelBannedRights *)object)->_timeout == _timeout) {
        return true;
    } else {
        return false;
    }
}

- (int32_t)numberOfRestrictions {
    int32_t flags = [self tlFlags];
    int32_t count = 0;
    for (int i = 0; i < 31; i++) {
        if (flags == 0) {
            break;
        }
        if ((flags & 1) != 0) {
            count++;
        }
        flags = flags >> 1;
    }
    return count;
}

@end
