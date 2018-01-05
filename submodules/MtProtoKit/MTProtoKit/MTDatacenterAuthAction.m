/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDatacenterAuthAction.h"

#import "MTContext.h"
#import "MTProto.h"
#import "MTRequest.h"
#import "MTDatacenterSaltInfo.h"

#import "MTDatacenterAuthMessageService.h"

@interface MTDatacenterAuthAction () <MTDatacenterAuthMessageServiceDelegate>
{
    NSInteger _datacenterId;
    __weak MTContext *_context;
    
    bool _awaitingAddresSetUpdate;
    MTProto *_authMtProto;
}

@end

@implementation MTDatacenterAuthAction

- (void)dealloc
{
    [self cleanup];
}

- (void)execute:(MTContext *)context datacenterId:(NSInteger)datacenterId isCdn:(bool)isCdn
{
    _datacenterId = datacenterId;
    _context = context;
    
    if (_datacenterId != 0 && context != nil)
    {
        if ([context authInfoForDatacenterWithId:_datacenterId] != nil)
            [self complete];
        else
        {
            _authMtProto = [[MTProto alloc] initWithContext:context datacenterId:_datacenterId usageCalculationInfo:nil];
            _authMtProto.cdn = isCdn;
            _authMtProto.useUnauthorizedMode = true;
            
            MTDatacenterAuthMessageService *authService = [[MTDatacenterAuthMessageService alloc] initWithContext:context];
            authService.delegate = self;
            [_authMtProto addMessageService:authService];
        }
    }
    else
        [self fail];
}

- (void)authMessageServiceCompletedWithAuthInfo:(MTDatacenterAuthInfo *)authInfo
{
    MTContext *context = _context;
    [context updateAuthInfoForDatacenterWithId:_datacenterId authInfo:authInfo];
    [self complete];
}

- (void)cleanup
{
    MTProto *authMtProto = _authMtProto;
    _authMtProto = nil;
    
    [authMtProto stop];
}

- (void)cancel
{
    [self cleanup];
    [self fail];
}

- (void)complete
{
    id<MTDatacenterAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterAuthActionCompleted:)])
        [delegate datacenterAuthActionCompleted:self];
}

- (void)fail
{
    id<MTDatacenterAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterAuthActionCompleted:)])
        [delegate datacenterAuthActionCompleted:self];
}

@end
