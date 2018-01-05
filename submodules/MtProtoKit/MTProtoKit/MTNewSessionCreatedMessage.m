#import "MTNewSessionCreatedMessage.h"

@implementation MTNewSessionCreatedMessage

- (instancetype)initWithFirstMessageId:(int64_t)firstMessageId uniqueId:(int64_t)uniqueId serverSalt:(int64_t)serverSalt
{
    self = [super init];
    if (self != nil)
    {
        _firstMessageId = firstMessageId;
        _uniqueId = uniqueId;
        _serverSalt = serverSalt;
    }
    return self;
}

@end
