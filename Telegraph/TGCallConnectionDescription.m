#import "TGCallConnectionDescription.h"

@implementation TGCallConnectionDescription

- (instancetype)initWithIdentifier:(int64_t)identifier ipv4:(NSString *)ipv4 ipv6:(NSString *)ipv6 port:(int32_t)port peerTag:(NSData *)peerTag {
    self = [super init];
    if (self != nil) {
        _identifier = identifier;
        _ipv4 = ipv4 ?: @"";
        _ipv6 = ipv6 ?: @"";
        _port = port;
        _peerTag = peerTag;
    }
    return self;
}

@end


@implementation TGCallConnection

- (instancetype)initWithKey:(NSData *)key keyHash:(NSData *)keyHash defaultConnection:(TGCallConnectionDescription *)defaultConnection alternativeConnections:(NSArray<TGCallConnectionDescription *> *)alternativeConnections {
    self = [super init];
    if (self != nil) {
        _key = key;
        _keyHash = keyHash;
        _defaultConnection = defaultConnection;
        _alternativeConnections = alternativeConnections;
    }
    return self;
}

@end
