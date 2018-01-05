#import "MTExportedAuthorizationData.h"

@implementation MTExportedAuthorizationData

- (instancetype)initWithAuthorizationBytes:(NSData *)authorizationBytes authorizationId:(int32_t)authorizationId
{
    self = [super init];
    if (self != nil)
    {
        _authorizationBytes = authorizationBytes;
        _authorizationId = authorizationId;
    }
    return self;
}

@end
