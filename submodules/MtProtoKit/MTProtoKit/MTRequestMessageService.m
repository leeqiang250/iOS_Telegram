/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTRequestMessageService.h"

#import "MTLogging.h"
#import "MTTime.h"
#import "MTTimer.h"
#import "MTContext.h"
#import "MTSerialization.h"
#import "MTProto.h"
#import "MTQueue.h"
#import "MTMessageTransaction.h"
#import "MTIncomingMessage.h"
#import "MTOutgoingMessage.h"
#import "MTPreparedMessage.h"
#import "MTRequest.h"
#import "MTRequestContext.h"
#import "MTRequestErrorContext.h"
#import "MTDropResponseContext.h"
#import "MTApiEnvironment.h"
#import "MTDatacenterAuthInfo.h"
#import "MTBuffer.h"

#import "MTInternalMessageParser.h"
#import "MTRpcResultMessage.h"
#import "MTRpcError.h"
#import "MTDropRpcResultMessage.h"

@interface MTRequestMessageService ()
{
    MTContext *_context;
    
    __weak MTProto *_mtProto;
    MTQueue *_queue;
    id<MTSerialization> _serialization;
    
    NSMutableArray *_requests;
    NSMutableArray *_dropReponseContexts;
    
    MTTimer *_requestsServiceTimer;
}

@end

@implementation MTRequestMessageService

- (instancetype)initWithContext:(MTContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _context = context;
        
        __weak MTRequestMessageService *weakSelf = self;
        MTContextBlockChangeListener *changeListener = [[MTContextBlockChangeListener alloc] init];
        changeListener.contextIsPasswordRequiredUpdated = ^(MTContext *context, NSInteger datacenterId)
        {
            __strong MTRequestMessageService *strongSelf = weakSelf;
            [strongSelf _contextIsPasswordRequiredUpdated:context datacenterId:datacenterId];
        };
        
        [_context addChangeListener:changeListener];
        
        _requests = [[NSMutableArray alloc] init];
        _dropReponseContexts = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc
{
    if (_requestsServiceTimer != nil)
    {
        [_requestsServiceTimer invalidate];
        _requestsServiceTimer = nil;
    }
}

- (void)addRequest:(MTRequest *)request
{
    [_queue dispatchOnQueue:^
    {
        MTProto *mtProto = _mtProto;
        if (mtProto == nil)
            return;
        
        if (![_requests containsObject:request])
        {
            [_requests addObject:request];
            [mtProto requestTransportTransaction];
        }
    }];
}

- (void)removeRequestByInternalId:(id)internalId
{
    [self removeRequestByInternalId:internalId askForReconnectionOnDrop:false];
}

- (void)removeRequestByInternalId:(id)internalId askForReconnectionOnDrop:(bool)askForReconnectionOnDrop
{
    [_queue dispatchOnQueue:^
    {
        bool anyNewDropRequests = false;
        bool removedAnyRequest = false;
        
        int index = -1;
        for (MTRequest *request in _requests)
        {
            index++;
            
            if ([request.internalId isEqual:internalId])
            {
                if (request.requestContext != nil)
                {
                    [_dropReponseContexts addObject:[[MTDropResponseContext alloc] initWithDropMessageId:request.requestContext.messageId]];
                    anyNewDropRequests = true;
                }
                
                if (request.requestContext.messageId != 0) {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTRequestMessageService#%x drop %" PRId64 "]", (int)self, request.requestContext.messageId);
                    }
                }
                
                request.requestContext = nil;
                [_requests removeObjectAtIndex:(NSUInteger)index];
                removedAnyRequest = true;
                
                break;
            }
        }
        
        if (anyNewDropRequests)
        {
            MTProto *mtProto = _mtProto;
            
            if (askForReconnectionOnDrop)
                [mtProto requestSecureTransportReset];

            [mtProto requestTransportTransaction];
        }
        
        if (removedAnyRequest && _requests.count == 0)
        {
            id<MTRequestMessageServiceDelegate> delegate = _delegate;
            if ([delegate respondsToSelector:@selector(requestMessageServiceDidCompleteAllRequests:)])
                [delegate requestMessageServiceDidCompleteAllRequests:self];
        }
        
        [self updateRequestsTimer];
    }];
}

- (void)requestCount:(void (^)(NSUInteger requestCount))completion
{
    if (completion == nil)
        return;
    
    if (_queue == nil)
        completion(0);
    else
    {
        [_queue dispatchOnQueue:^
        {
            completion(_requests.count);
        }];
    }
}

- (void)_contextIsPasswordRequiredUpdated:(MTContext *)context datacenterId:(NSInteger)datacenterId
{
    [_queue dispatchOnQueue:^
    {
        if ([context isPasswordInputRequiredForDatacenterWithId:datacenterId])
            return;
        
        if (context != _context)
            return;
        
        MTProto *mtProto = _mtProto;
        if (datacenterId == mtProto.datacenterId)
            [mtProto requestTransportTransaction];
    }];
}

- (void)updateRequestsTimer
{
    [_queue dispatchOnQueue:^
    {
        CFAbsoluteTime currentTime = MTAbsoluteSystemTime();
        
        CFAbsoluteTime minWaitTime = DBL_MAX;
        bool needTimer = false;
        bool needTransaction = false;
        
        for (MTRequest *request in _requests)
        {
            if (request.errorContext != nil)
            {
                if (request.requestContext == nil)
                {
                    if (request.errorContext.minimalExecuteTime > currentTime + DBL_EPSILON)
                    {
                        needTimer = true;
                        minWaitTime = MIN(minWaitTime, request.errorContext.minimalExecuteTime - currentTime);
                    }
                    else
                    {
                        request.errorContext.minimalExecuteTime = 0.0;
                        needTransaction = true;
                    }
                }
            }
        }
        
        if (needTimer)
        {
            if (_requestsServiceTimer == nil)
            {
                __weak MTRequestMessageService *weakSelf = self;
                _requestsServiceTimer = [[MTTimer alloc] initWithTimeout:minWaitTime repeat:false completion:^
                {
                    __strong MTRequestMessageService *strongSelf = weakSelf;
                    [strongSelf requestTimerEvent];
                } queue:_queue.nativeQueue];
                [_requestsServiceTimer start];
            }
            else
                [_requestsServiceTimer resetTimeout:minWaitTime];
        }
        else if (!needTimer && _requestsServiceTimer != nil)
        {
            [_requestsServiceTimer invalidate];
            _requestsServiceTimer = nil;
        }
        
        if (needTransaction)
        {
            MTProto *mtProto = _mtProto;
            [mtProto requestTransportTransaction];
        }
    }];
}

- (void)requestTimerEvent
{
    if (_requestsServiceTimer != nil)
    {
        [_requestsServiceTimer invalidate];
        _requestsServiceTimer = nil;
    }
    
    MTProto *mtProto = _mtProto;
    [mtProto requestTransportTransaction];
}

- (void)mtProtoWillAddService:(MTProto *)mtProto
{
    _queue = [mtProto messageServiceQueue];
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    _mtProto = mtProto;
    _serialization = mtProto.context.serialization;
    _apiEnvironment = mtProto.apiEnvironment;
}
    
- (void)mtProtoApiEnvironmentUpdated:(MTProto *)mtProto apiEnvironment:(MTApiEnvironment *)apiEnvironment {
    _apiEnvironment = apiEnvironment;
}

- (NSData *)decorateRequestData:(MTRequest *)request initializeApi:(bool)initializeApi unresolvedDependencyOnRequestInternalId:(__autoreleasing id *)unresolvedDependencyOnRequestInternalId
{    
    NSData *currentData = request.payload;
    
    if (initializeApi && _apiEnvironment != nil)
    {
        MTBuffer *buffer = [[MTBuffer alloc] init];
        
        // invokeWithLayer
        [buffer appendInt32:(int32_t)0xda9b0d0d];
        [buffer appendInt32:(int32_t)[_serialization currentLayer]];
        
        //initConnection#c7481da6 {X:Type} api_id:int device_model:string system_version:string app_version:string system_lang_code:string lang_pack:string lang_code:string query:!X = X;

        bool layerSupportsLangpacks = [_serialization currentLayer] >= 67;
        
        [buffer appendInt32:(int32_t)(layerSupportsLangpacks ? 0xc7481da6 : 0x69796de9)];
        [buffer appendInt32:(int32_t)_apiEnvironment.apiId];
        [buffer appendTLString:_apiEnvironment.deviceModel];
        [buffer appendTLString:_apiEnvironment.systemVersion];
        [buffer appendTLString:_apiEnvironment.appVersion];
        [buffer appendTLString:_apiEnvironment.systemLangCode];
        
        if (layerSupportsLangpacks) {
            [buffer appendTLString:_apiEnvironment.langPack];
            [buffer appendTLString:_apiEnvironment.langPackCode];
        }
        
        [buffer appendBytes:currentData.bytes length:currentData.length];
        currentData = buffer.data;
    }
    
    if (_apiEnvironment != nil && _apiEnvironment.disableUpdates)
    {
        MTBuffer *buffer = [[MTBuffer alloc] init];
        
        [buffer appendInt32:(int32_t)0xbf9459b7];

        [buffer appendBytes:currentData.bytes length:currentData.length];
        currentData = buffer.data;
    }
    
    if (request.shouldDependOnRequest != nil)
    {
        NSUInteger index = [_requests indexOfObject:request];
        if (index != NSNotFound)
        {
            for (NSInteger i = ((NSInteger)index) - 1; i >= 0; i--)
            {
                MTRequest *anotherRequest = _requests[(NSUInteger)i];
                if (request.shouldDependOnRequest(anotherRequest))
                {
                    if (anotherRequest.requestContext != nil)
                    {
                        MTBuffer *buffer = [[MTBuffer alloc] init];
                        
                        // invokeAfterMsg
                        [buffer appendInt32:(int32_t)0xcb9f372d];
                        [buffer appendInt64:anotherRequest.requestContext.messageId];
                        [buffer appendBytes:currentData.bytes length:currentData.length];
                        
                        currentData = buffer.data;
                    }
                    else if (unresolvedDependencyOnRequestInternalId != nil)
                        *unresolvedDependencyOnRequestInternalId = anotherRequest.internalId;
                    
                    break;
                }
            }
        }
    }
    
    return currentData;
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto
{
    NSMutableArray *messages = nil;
    NSMutableDictionary *requestInternalIdToMessageInternalId = nil;
    
    bool requestsWillInitializeApi = _apiEnvironment != nil && ![_apiEnvironment.apiInitializationHash isEqualToString:[_context authInfoForDatacenterWithId:mtProto.datacenterId].authKeyAttributes[@"apiInitializationHash"]];
    
    CFAbsoluteTime currentTime = MTAbsoluteSystemTime();
    
    for (MTRequest *request in _requests)
    {
        if (request.dependsOnPasswordEntry && [_context isPasswordInputRequiredForDatacenterWithId:mtProto.datacenterId])
            continue;
        
        if (request.errorContext != nil)
        {
            if (request.errorContext.minimalExecuteTime > currentTime)
                continue;
            if (request.errorContext.waitingForTokenExport)
                continue;
        }
        
        if (request.requestContext == nil || (!request.requestContext.waitingForMessageId && !request.requestContext.delivered && request.requestContext.transactionId == nil))
        {   
            if (messages == nil)
                messages = [[NSMutableArray alloc] init];
            if (requestInternalIdToMessageInternalId == nil)
                requestInternalIdToMessageInternalId = [[NSMutableDictionary alloc] init];
            
            __autoreleasing id autoreleasingUnresolvedDependencyOnRequestInternalId = nil;
            
            int64_t messageId = 0;
            int32_t messageSeqNo = 0;
            if (request.requestContext != nil)
            {
                messageId = request.requestContext.messageId;
                messageSeqNo = request.requestContext.messageSeqNo;
            }
            
            MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:[self decorateRequestData:request initializeApi:requestsWillInitializeApi unresolvedDependencyOnRequestInternalId:&autoreleasingUnresolvedDependencyOnRequestInternalId] metadata:request.metadata messageId:messageId messageSeqNo:messageSeqNo];
            outgoingMessage.needsQuickAck = request.acknowledgementReceived != nil;
            outgoingMessage.hasHighPriority = request.hasHighPriority;
            
            id unresolvedDependencyOnRequestInternalId = autoreleasingUnresolvedDependencyOnRequestInternalId;
            if (unresolvedDependencyOnRequestInternalId != nil)
            {
                outgoingMessage.dynamicDecorator = ^id (NSData *currentData, NSDictionary *messageInternalIdToPreparedMessage)
                {
                    id messageInternalId = requestInternalIdToMessageInternalId[unresolvedDependencyOnRequestInternalId];
                    if (messageInternalId != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                        if (preparedMessage != nil)
                        {
                            MTBuffer *invokeAfterBuffer = [[MTBuffer alloc] init];
                            [invokeAfterBuffer appendInt32:(int32_t)0xcb9f372d];
                            [invokeAfterBuffer appendInt64:preparedMessage.messageId];
                            [invokeAfterBuffer appendBytes:currentData.bytes length:currentData.length];
                            return invokeAfterBuffer.data;
                        }
                    }
                    
                    return currentData;
                };
            }
            
            requestInternalIdToMessageInternalId[request.internalId] = outgoingMessage.internalId;
            [messages addObject:outgoingMessage];
        }
    }
    
    NSMutableDictionary *dropMessageIdToMessageInternalId = nil;
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (messages == nil)
            messages = [[NSMutableArray alloc] init];
        if (dropMessageIdToMessageInternalId == nil)
            dropMessageIdToMessageInternalId = [[NSMutableDictionary alloc] init];
        
        MTBuffer *dropAnswerBuffer = [[MTBuffer alloc] init];
        [dropAnswerBuffer appendInt32:(int32_t)0x58e4a740];
        [dropAnswerBuffer appendInt64:dropContext.dropMessageId];
        
        MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:dropAnswerBuffer.data metadata:@"dropAnswer" messageId:dropContext.messageId messageSeqNo:dropContext.messageSeqNo];
        outgoingMessage.requiresConfirmation = false;
        dropMessageIdToMessageInternalId[@(dropContext.dropMessageId)] = outgoingMessage.internalId;
        [messages addObject:outgoingMessage];
    }
    
    if (messages.count != 0)
    {
        return [[MTMessageTransaction alloc] initWithMessagePayload:messages prepared:^(NSDictionary *messageInternalIdToPreparedMessage) {
            for (MTRequest *request in _requests) {
                id messageInternalId = requestInternalIdToMessageInternalId[request.internalId];
                if (messageInternalId != nil) {
                    MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                    if (preparedMessage != nil) {
                        MTRequestContext *requestContext = [[MTRequestContext alloc] initWithMessageId:preparedMessage.messageId messageSeqNo:preparedMessage.seqNo transactionId:nil quickAckId:0];
                        requestContext.willInitializeApi = requestsWillInitializeApi;
                        requestContext.waitingForMessageId = true;
                        request.requestContext = requestContext;
                    }
                }
            }
        } failed:^{
            for (MTRequest *request in _requests) {
                id messageInternalId = requestInternalIdToMessageInternalId[request.internalId];
                if (messageInternalId != nil) {
                    request.requestContext.waitingForMessageId = false;
                }
            }
        } completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, NSDictionary *messageInternalIdToQuickAckId)
        {
            for (MTRequest *request in _requests)
            {
                id messageInternalId = requestInternalIdToMessageInternalId[request.internalId];
                if (messageInternalId != nil)
                {
                    request.requestContext.waitingForMessageId = false;
                    MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[messageInternalId];
                    if (preparedMessage != nil && messageInternalIdToTransactionId[messageInternalId] != nil)
                    {
                        MTRequestContext *requestContext = [[MTRequestContext alloc] initWithMessageId:preparedMessage.messageId messageSeqNo:preparedMessage.seqNo transactionId:messageInternalIdToTransactionId[messageInternalId] quickAckId:(int32_t)[messageInternalIdToQuickAckId[messageInternalId] intValue]];
                        requestContext.willInitializeApi = requestsWillInitializeApi;
                        request.requestContext = requestContext;
                    }
                }
            }
            
            for (MTDropResponseContext *dropContext in _dropReponseContexts)
            {
                MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[dropMessageIdToMessageInternalId[@(dropContext.dropMessageId)]];
                if (preparedMessage != nil)
                {
                    dropContext.messageId = preparedMessage.messageId;
                    dropContext.messageSeqNo = preparedMessage.seqNo;
                }
            }
        }];
    }
    
    return nil;
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)message
{
    if ([message.body isKindOfClass:[MTRpcResultMessage class]])
    {
        MTRpcResultMessage *rpcResultMessage = message.body;
        
        id maybeInternalMessage = [MTInternalMessageParser parseMessage:rpcResultMessage.data];
        
        if ([maybeInternalMessage isKindOfClass:[MTDropRpcResultMessage class]])
        {
            NSInteger index = -1;
            for (MTDropResponseContext *dropContext in _dropReponseContexts)
            {
                index++;
                if (dropContext.messageId == rpcResultMessage.requestMessageId)
                {
                    [_dropReponseContexts removeObjectAtIndex:(NSUInteger)index];
                    break;
                }
            }
        }
        else
        {
            bool requestFound = false;
            
            int index = -1;
            for (MTRequest *request in _requests)
            {
                index++;
                
                if (request.requestContext != nil && request.requestContext.messageId == rpcResultMessage.requestMessageId)
                {
                    requestFound = true;
                    
                    bool restartRequest = false;
                    
                    id rpcResult = nil;
                    MTRpcError *rpcError = nil;
                    
                    if ([maybeInternalMessage isKindOfClass:[MTRpcError class]])
                        rpcError = maybeInternalMessage;
                    else
                    {
                        rpcResult = request.responseParser([MTInternalMessageParser unwrapMessage:rpcResultMessage.data]);
                        if (rpcResult == nil)
                        {
                            rpcError = [[MTRpcError alloc] initWithErrorCode:500 errorDescription:@"TL_PARSING_ERROR"];
                        }
                    }
                    
                    if (rpcResult != nil)
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTRequestMessageService#%p response for %" PRId64 " is %@]", self, request.requestContext.messageId, rpcResult);
                        }
                    }
                    else
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTRequestMessageService#%p response for %" PRId64 " is error: %d: %@]", self, request.requestContext.messageId, (int)rpcError.errorCode, rpcError.errorDescription);
                        }
                    }
                    
                    if (rpcResult != nil && request.requestContext.willInitializeApi)
                    {
                        MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:mtProto.datacenterId];
                        
                        if (![_apiEnvironment.apiInitializationHash isEqualToString:authInfo.authKeyAttributes[@"apiInitializationHash"]])
                        {
                            NSMutableDictionary *authKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:authInfo.authKeyAttributes];
                            authKeyAttributes[@"apiInitializationHash"] = _apiEnvironment.apiInitializationHash;
                            
                            authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:authInfo.saltSet authKeyAttributes:authKeyAttributes];
                            [_context updateAuthInfoForDatacenterWithId:mtProto.datacenterId authInfo:authInfo];
                        }
                    }
                    
                    if (rpcError != nil)
                    {
                        if (rpcError.errorCode == 401)
                        {
                            if ([rpcError.errorDescription rangeOfString:@"SESSION_PASSWORD_NEEDED"].location != NSNotFound)
                            {
                                if (!request.passthroughPasswordEntryError)
                                {
                                    [_context updatePasswordInputRequiredForDatacenterWithId:mtProto.datacenterId required:true];
                                }
                            }
                            else
                            {
                                id<MTRequestMessageServiceDelegate> delegate = _delegate;
                                if ([delegate respondsToSelector:@selector(requestMessageServiceAuthorizationRequired:)])
                                {
                                    [delegate requestMessageServiceAuthorizationRequired:self];
                                }
                                
                                MTProto *mtProto = _mtProto;
                                if (mtProto.requiredAuthToken != nil && ([rpcError.errorDescription rangeOfString:@"SESSION_REVOKED"].location != NSNotFound || [rpcError.errorDescription rangeOfString:@"AUTH_KEY_UNREGISTERED"].location != NSNotFound))
                                {
                                    if (request.errorContext == nil)
                                        request.errorContext = [[MTRequestErrorContext alloc] init];
                                    request.errorContext.waitingForTokenExport = true;
                                    
                                    restartRequest = true;
                                }
                            }
                        }
                        else if (rpcError.errorCode == -500 || rpcError.errorCode == 500)
                        {
                            if (request.errorContext == nil)
                                request.errorContext = [[MTRequestErrorContext alloc] init];
                            request.errorContext.internalServerErrorCount++;
                            
                            if (request.shouldContinueExecutionWithErrorContext != nil && request.shouldContinueExecutionWithErrorContext(request.errorContext))
                            {
                                restartRequest = true;
                                request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + 2.0);
                            }
                        }
                        else if (rpcError.errorCode == 420 || [rpcError.errorDescription rangeOfString:@"FLOOD_WAIT_"].location != NSNotFound)
                        {
                            if (request.errorContext == nil)
                                request.errorContext = [[MTRequestErrorContext alloc] init];
                            
                            if ([rpcError.errorDescription rangeOfString:@"FLOOD_WAIT_"].location != NSNotFound)
                            {
                                int errorWaitTime = 0;
                                
                                NSScanner *scanner = [[NSScanner alloc] initWithString:rpcError.errorDescription];
                                [scanner scanUpToString:@"FLOOD_WAIT_" intoString:nil];
                                [scanner scanString:@"FLOOD_WAIT_" intoString:nil];
                                if ([scanner scanInt:&errorWaitTime])
                                {
                                    request.errorContext.floodWaitSeconds = errorWaitTime;
                                    
                                    if (request.shouldContinueExecutionWithErrorContext != nil)
                                    {
                                        if (request.shouldContinueExecutionWithErrorContext(request.errorContext))
                                        {
                                            restartRequest = true;
                                            request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + (CFAbsoluteTime)errorWaitTime);
                                        }
                                    }
                                    else
                                    {
                                        restartRequest = true;
                                        request.errorContext.minimalExecuteTime = MAX(request.errorContext.minimalExecuteTime, MTAbsoluteSystemTime() + (CFAbsoluteTime)errorWaitTime);
                                    }
                                }
                            }
                        }
                        else if (rpcError.errorCode == 400 && [rpcError.errorDescription rangeOfString:@"CONNECTION_NOT_INITED"].location != NSNotFound)
                        {
                            [_context performBatchUpdates:^
                            {
                                MTDatacenterAuthInfo *authInfo = [_context authInfoForDatacenterWithId:mtProto.datacenterId];
                                
                                NSMutableDictionary *authKeyAttributes = [[NSMutableDictionary alloc] initWithDictionary:authInfo.authKeyAttributes];
                                [authKeyAttributes removeObjectForKey:@"apiInitializationHash"];
                                
                                authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authInfo.authKey authKeyId:authInfo.authKeyId saltSet:authInfo.saltSet authKeyAttributes:authKeyAttributes];
                                [_context updateAuthInfoForDatacenterWithId:mtProto.datacenterId authInfo:authInfo];
                            }];
                        }
                        
//#warning TODO other service errors
                    }
                    
                    request.requestContext = nil;
                    
                    if (restartRequest)
                    {
                        
                    }
                    else
                    {
                        void (^completed)(id result, NSTimeInterval completionTimestamp, id error) = [request.completed copy];
                        [_requests removeObjectAtIndex:(NSUInteger)index];
                        
                        if (completed)
                            completed(rpcResult, message.timestamp, rpcError);
                    }
                    
                    break;
                }
            }
            
            if (!requestFound) {
                if (MTLogEnabled()) {
                    MTLog(@"[MTRequestMessageService#%p response %" PRId64 " didn't match any request]", self, message.messageId);
                }
            }
            else if (_requests.count == 0)
            {
                id<MTRequestMessageServiceDelegate> delegate = _delegate;
                if ([delegate respondsToSelector:@selector(requestMessageServiceDidCompleteAllRequests:)])
                    [delegate requestMessageServiceDidCompleteAllRequests:self];
            }
            
            [self updateRequestsTimer];
        }
    }
}

- (void)mtProto:(MTProto *)__unused mtProto receivedQuickAck:(int32_t)quickAckId
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.quickAckId == quickAckId)
        {
            if (request.acknowledgementReceived != nil)
                request.acknowledgementReceived();
        }
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryConfirmed:(NSArray *)messageIds
{
    for (NSNumber *nMessageId in messageIds)
    {
        int64_t messageId = (int64_t)[nMessageId longLongValue];
        
        for (MTRequest *request in _requests)
        {
            if (request.requestContext != nil && request.requestContext.messageId == messageId)
            {
                request.requestContext.delivered = true;
                
                break;
            }
        }
    }
}

- (void)mtProto:(MTProto *)mtProto messageDeliveryFailed:(int64_t)messageId
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId)
        {
            request.requestContext = nil;
            requestTransaction = true;
            
            break;
        }
    }
    
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (dropContext.messageId == messageId)
        {
            dropContext.messageId = 0;
            dropContext.messageSeqNo = 0;
            requestTransaction = true;
            
            break;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.transactionId != nil && [transactionIds containsObject:request.requestContext.transactionId])
        {
            request.requestContext.transactionId = nil;
            requestTransaction = true;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.transactionId != nil)
        {
            request.requestContext.transactionId = nil;
            requestTransaction = true;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (bool)mtProto:(MTProto *)__unused mtProto shouldRequestMessageWithId:(int64_t)responseMessageId inResponseToMessageId:(int64_t)messageId currentTransactionId:(id)currentTransactionId
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId)
        {
            if (request.requestContext.transactionId == nil || [request.requestContext.transactionId isEqual:currentTransactionId]) {
                request.requestContext.responseMessageId = responseMessageId;
                return true;
            } else {
                MTLog(@"[MTRequestMessageService#%x will not request message %" PRId64 " (transaction was not completed)]", (int)self, messageId);
                MTLog(@"[MTRequestMessageService#%x but today it will]", (int)self);
                return true;
            }
        }
    }
    
    return false;
}

- (void)mtProto:(MTProto *)mtProto messageResendRequestFailed:(int64_t)messageId
{
    bool requestTransaction = false;
    
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.responseMessageId == messageId)
        {
            request.requestContext = nil;
            requestTransaction = true;
        }
    }
    
    if (requestTransaction)
        [mtProto requestTransportTransaction];
}

- (void)mtProto:(MTProto *)mtProto updateReceiveProgressForToken:(id)progressToken progress:(float)progress packetLength:(NSInteger)packetLength
{
    if ([progressToken respondsToSelector:@selector(longLongValue)])
    {
        int64_t messageId = [(NSNumber *)progressToken longLongValue];
        
        for (MTRequest *request in _requests)
        {
            if (request.requestContext != nil && request.requestContext.messageId == messageId && request.progressUpdated)
                request.progressUpdated(progress, packetLength);
        }
    }
}

- (void)mtProtoDidChangeSession:(MTProto *)mtProto
{
    for (MTRequest *request in _requests)
    {
        request.requestContext = nil;
    }
    
    [_dropReponseContexts removeAllObjects];
    
    if (_requests.count != 0)
        [mtProto requestTransportTransaction];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    bool resendSomeRequests = false;
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && (request.requestContext.messageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(request.requestContext.messageId)]))
        {
            request.requestContext = nil;
            
            resendSomeRequests = true;
        }
    }
    
    if (resendSomeRequests)
        [mtProto requestTransportTransaction];
}

- (void)mtProtoAuthTokenUpdated:(MTProto *)mtProto
{
    bool resendSomeRequests = false;
    for (MTRequest *request in _requests)
    {
        if (request.errorContext != nil && request.errorContext.waitingForTokenExport)
        {
            request.errorContext.waitingForTokenExport = false;
            resendSomeRequests = true;
        }
    }
    
    if (resendSomeRequests)
        [mtProto requestTransportTransaction];
}

/*- (int32_t)possibleSignatureForResult:(int64_t)messageId found:(bool *)found
{
    for (MTRequest *request in _requests)
    {
        if (request.requestContext != nil && request.requestContext.messageId == messageId)
        {
            if (found != NULL)
                *found = true;
            
            return [_serialization rpcRequestBodyResponseSignature:request.body];
        }
    }
    
    for (MTDropResponseContext *dropContext in _dropReponseContexts)
    {
        if (dropContext.messageId == messageId)
        {
            if (found != NULL)
                *found = true;
            
            return 0;
        }
    }
    
    return 0;
}*/

@end
