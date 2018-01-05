/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDatacenterTransferAuthAction.h"

#import "MTContext.h"
#import "MTSerialization.h"
#import "MTProto.h"
#import "MTRequestMessageService.h"
#import "MTRequest.h"
#import "MTBuffer.h"

@interface MTDatacenterTransferAuthAction () <MTContextChangeListener>
{
    id _authToken;
    
    MTProto *_sourceDatacenterMtProto;
    
    NSInteger _destinationDatacenterId;
    MTProto *_destinationDatacenterMtProto;
    
    __weak MTContext *_context;
}

@end

@implementation MTDatacenterTransferAuthAction

- (void)dealloc
{
    [self cleanup];
}

- (void)cleanup
{
    MTContext *context = _context;
    [context removeChangeListener:self];
    
    [_sourceDatacenterMtProto stop];
    _sourceDatacenterMtProto = nil;
    
    [_destinationDatacenterMtProto stop];
    _destinationDatacenterMtProto = nil;
}

- (void)execute:(MTContext *)context masterDatacenterId:(NSInteger)masterDatacenterId destinationDatacenterId:(NSInteger)destinationDatacenterId authToken:(id)authToken
{
    _destinationDatacenterId = destinationDatacenterId;
    _context = context;
    _authToken = authToken;
    
    if (_destinationDatacenterId != 0 && context != nil && _authToken != nil)
    {
        if ([_authToken isEqual:[context authTokenForDatacenterWithId:_destinationDatacenterId]])
            [self complete];
        else
            [self beginTransferFromDatacenterId:masterDatacenterId];
    }
    else
        [self fail];
}

- (void)contextDatacenterAuthTokenUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId authToken:(id)authToken
{
    MTContext *currentContext = _context;
    if (currentContext == nil || context != currentContext)
        return;
    
    if (authToken != nil && [_authToken isEqual:authToken])
    {
        if (datacenterId == _destinationDatacenterId)
            [self complete];
        else
            [self beginTransferFromDatacenterId:datacenterId];
    }
}

- (void)beginTransferFromDatacenterId:(NSInteger)sourceDatacenterId
{
    MTContext *context = _context;
    if (context == nil)
    {
        [self fail];
        
        return;
    }
    
    _sourceDatacenterMtProto = [[MTProto alloc] initWithContext:context datacenterId:sourceDatacenterId usageCalculationInfo:nil];
    
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    [_sourceDatacenterMtProto addMessageService:requestService];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    NSData *exportAuthRequestData = nil;
    MTExportAuthorizationResponseParser responseParser = [[context.serialization exportAuthorization:(int32_t)_destinationDatacenterId data:&exportAuthRequestData] copy];
    
    [request setPayload:exportAuthRequestData metadata:@"exportAuthorization" responseParser:responseParser];
    
    __weak MTDatacenterTransferAuthAction *weakSelf = self;
    [request setCompleted:^(MTExportedAuthorizationData *result, __unused NSTimeInterval timestamp, id error)
    {
        __strong MTDatacenterTransferAuthAction *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (error == nil)
        {
            [strongSelf beginTransferWithId:result.authorizationId data:result.authorizationBytes];
        }
        else
            [strongSelf fail];
    }];
    
    [requestService addRequest:request];
}

- (void)beginTransferWithId:(int32_t)dataId data:(NSData *)authData
{
    [_sourceDatacenterMtProto stop];
    _sourceDatacenterMtProto = nil;
    
    MTContext *context = _context;
    _destinationDatacenterMtProto = [[MTProto alloc] initWithContext:context datacenterId:_destinationDatacenterId usageCalculationInfo:nil];
    
    MTRequestMessageService *requestService = [[MTRequestMessageService alloc] initWithContext:context];
    [_destinationDatacenterMtProto addMessageService:requestService];
    
    MTRequest *request = [[MTRequest alloc] init];
    
    NSData *importAuthRequestData = [_context.serialization importAuthorization:dataId bytes:authData];
    
    [request setPayload:importAuthRequestData metadata:@"importAuthorization" responseParser:^id (NSData *data)
    {
        return @true;
    }];
    
    NSInteger destinationDatacenterId = _destinationDatacenterId;
    id authToken = _authToken;
    
    __weak MTDatacenterTransferAuthAction *weakSelf = self;
    [request setCompleted:^(__unused id result, __unused NSTimeInterval timestamp, id error)
    {
        __strong MTDatacenterTransferAuthAction *strongSelf = weakSelf;
        if (strongSelf == nil)
            return;
        
        if (error == nil)
        {
            [context updateAuthTokenForDatacenterWithId:destinationDatacenterId authToken:authToken];
            
            [strongSelf complete];
        }
        else
            [strongSelf fail];
    }];
    
    [requestService addRequest:request];
}

- (void)cancel
{
    [self cleanup];
    
    [self fail];
}

- (void)complete
{
    id<MTDatacenterTransferAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterTransferAuthActionCompleted:)])
        [delegate datacenterTransferAuthActionCompleted:self];
}

- (void)fail
{
    id<MTDatacenterTransferAuthActionDelegate> delegate = _delegate;
    if ([delegate respondsToSelector:@selector(datacenterTransferAuthActionCompleted:)])
        [delegate datacenterTransferAuthActionCompleted:self];
}

@end
