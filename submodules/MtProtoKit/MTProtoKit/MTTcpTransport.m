/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTTcpTransport.h"

#import "MTLogging.h"
#import "MTQueue.h"
#import "MTTimer.h"
#import "MTTime.h"

#import "MTDatacenterAddressSet.h"

#import "MTTransportTransaction.h"
#import "MTOutgoingMessage.h"
#import "MTIncomingMessage.h"
#import "MTMessageTransaction.h"
#import "MTPreparedMessage.h"

#import "MTTcpConnection.h"
#import "MTTcpConnectionBehaviour.h"

#import "MTSerialization.h"
#import "MTBuffer.h"
#import "MTPongMessage.h"

#import "MTContext.h"
#import "MTApiEnvironment.h"

static const NSTimeInterval MTTcpTransportSleepWatchdogTimeout = 60.0;

@interface MTTcpTransportContext : NSObject

@property (nonatomic, strong) MTDatacenterAddress *address;
@property (nonatomic, strong) MTTcpConnection *connection;
@property (nonatomic) bool isUsingProxy;

@property (nonatomic) bool connectionConnected;
@property (nonatomic) bool connectionIsValid;
@property (nonatomic, strong) MTTcpConnectionBehaviour *connectionBehaviour;
@property (nonatomic) bool stopped;

@property (nonatomic) bool isNetworkAvailable;

@property (nonatomic) bool willRequestTransactionOnNextQueuePass;

@property (nonatomic) NSTimeInterval transactionLockTime;
@property (nonatomic) bool isWaitingForTransactionToBecomeReady;
@property (nonatomic) bool requestAnotherTransactionWhenReady;

@property (nonatomic) bool didSendActualizationPingAfterConnection;
@property (nonatomic) int64_t currentActualizationPingMessageId;
@property (nonatomic, strong) MTTimer *actualizationPingResendTimer;

@property (nonatomic, strong) MTTimer *connectionWatchdogTimer;
@property (nonatomic, strong) MTTimer *sleepWatchdogTimer;
@property (nonatomic) CFAbsoluteTime sleepWatchdogTimerLastTime;

@end

@implementation MTTcpTransportContext



@end

@interface MTTcpTransport () <MTTcpConnectionDelegate, MTTcpConnectionBehaviourDelegate>
{
    MTTcpTransportContext *_transportContext;
    __weak MTContext *_context;
    NSInteger _datacenterId;
    MTNetworkUsageCalculationInfo *_usageCalculationInfo;
}

@end

@implementation MTTcpTransport

+ (MTQueue *)tcpTransportQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[MTQueue alloc] initWithName:"org.mtproto.tcpTransportQueue"];
    });
    return queue;
}

- (instancetype)initWithDelegate:(id<MTTransportDelegate>)delegate context:(MTContext *)context datacenterId:(NSInteger)datacenterId address:(MTDatacenterAddress *)address usageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo
{
#ifdef DEBUG
    NSAssert(context != nil, @"context should not be nil");
    NSAssert(datacenterId != 0, @"datacenterId should not be nil");
    NSAssert(address != nil, @"address should not be nil");
#endif
    
    self = [super initWithDelegate:delegate context:context datacenterId:datacenterId address:address usageCalculationInfo:usageCalculationInfo];
    if (self != nil)
    {
        _context = context;
        _datacenterId = datacenterId;
        _usageCalculationInfo = usageCalculationInfo;
        
        MTTcpTransportContext *transportContext = [[MTTcpTransportContext alloc] init];
        _transportContext = transportContext;
        
        [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
            transportContext.address = address;
            
            transportContext.connectionBehaviour = [[MTTcpConnectionBehaviour alloc] initWithQueue:[MTTcpTransport tcpTransportQueue]];
            transportContext.connectionBehaviour.delegate = self;
            
            transportContext.isNetworkAvailable = true;
            
            transportContext.isUsingProxy = context.apiEnvironment.socksProxySettings != nil;
        }];
    }
    return self;
}

- (void)dealloc
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
        transportContext.connection.delegate = nil;
        
        transportContext.connectionBehaviour.needsReconnection = false;
        transportContext.connectionBehaviour.delegate = nil;
        
        [transportContext.actualizationPingResendTimer invalidate];
        transportContext.actualizationPingResendTimer = nil;
        
        [transportContext.connectionWatchdogTimer invalidate];
        transportContext.connectionWatchdogTimer = nil;
        
        [transportContext.sleepWatchdogTimer invalidate];
        transportContext.sleepWatchdogTimer = nil;
    }];
}

- (void)setUsageCalculationInfo:(MTNetworkUsageCalculationInfo *)usageCalculationInfo {
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^{
        _usageCalculationInfo = usageCalculationInfo;
        [_transportContext.connection setUsageCalculationInfo:usageCalculationInfo];
    }];
}

- (bool)needsParityCorrection
{
    return true;
}

- (void)updateConnectionState
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportNetworkAvailabilityChanged:isNetworkAvailable:)])
            [delegate transportNetworkAvailabilityChanged:self isNetworkAvailable:transportContext.isNetworkAvailable];
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:isUsingProxy:)])
            [delegate transportConnectionStateChanged:self isConnected:transportContext.connectionConnected isUsingProxy:transportContext.isUsingProxy];
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:transportContext.currentActualizationPingMessageId != 0];
    }];
}

- (void)setDelegateNeedsTransaction
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (!transportContext.willRequestTransactionOnNextQueuePass)
        {
            transportContext.willRequestTransactionOnNextQueuePass = true;
            
            dispatch_async([MTTcpTransport tcpTransportQueue].nativeQueue, ^
            {
                transportContext.willRequestTransactionOnNextQueuePass = false;
                
                if (transportContext.connection == nil)
                    [transportContext.connectionBehaviour requestConnection];
                else if (transportContext.connectionConnected)
                    [self _requestTransactionFromDelegate];
            });
        }
    }];
}

- (void)startIfNeeded
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection == nil)
        {
            [self startConnectionWatchdogTimer];
            [self startSleepWatchdogTimer];
            
            MTContext *context = _context;
            transportContext.connection = [[MTTcpConnection alloc] initWithContext:context datacenterId:_datacenterId address:transportContext.address interface:nil usageCalculationInfo:_usageCalculationInfo];
            transportContext.connection.delegate = self;
            [transportContext.connection start];
        }
    }];
}

- (void)reset
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.connection stop];
    }];
}

- (void)stop
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self activeTransactionIds:^(NSArray *activeTransactionId)
        {
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
                [delegate transportTransactionsMayHaveFailed:self transactionIds:activeTransactionId];
        }];
        
        transportContext.stopped = true;
        transportContext.connectionConnected = false;
        transportContext.connectionIsValid = false;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:isUsingProxy:)])
            [delegate transportConnectionStateChanged:self isConnected:false isUsingProxy:transportContext.isUsingProxy];
        
        transportContext.connectionBehaviour.needsReconnection = false;
        
        transportContext.connection.delegate = nil;
        [transportContext.connection stop];
        transportContext.connection = nil;
        
        [self stopConnectionWatchdogTimer];
        [self stopSleepWatchdogTimer];
        
        [transportContext.actualizationPingResendTimer invalidate];
        transportContext.actualizationPingResendTimer = nil;
    }];
}

- (void)startSleepWatchdogTimer
{
/*#if false
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.sleepWatchdogTimer == nil)
        {
            transportContext.sleepWatchdogTimerLastTime = MTAbsoluteSystemTime();
            
            __weak MTTcpTransport *weakSelf = self;
            transportContext.sleepWatchdogTimer = [[MTTimer alloc] initWithTimeout:MTTcpTransportSleepWatchdogTimeout repeat:true completion:^
            {
                CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
                
                __strong MTTcpTransport *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    if (ABS(currentTime - strongSelf->_transportContext.sleepWatchdogTimerLastTime) > MTTcpTransportSleepWatchdogTimeout * 2.0)
                    {
                        if (MTLogEnabled()) {
                            MTLog(@"[MTTcpTransport#%p system sleep detected, resetting connection]", strongSelf);
                        }
                        [strongSelf reset];
                    }
                    strongSelf->_transportContext.sleepWatchdogTimerLastTime = currentTime;
                }
            } queue:[MTTcpConnection tcpQueue].nativeQueue];
            [_sleepWatchdogTimer start];
        }
    }];
#endif*/
}

- (void)restartSleepWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        transportContext.sleepWatchdogTimerLastTime = MTAbsoluteSystemTime();
        [transportContext.sleepWatchdogTimer resetTimeout:MTTcpTransportSleepWatchdogTimeout];
    }];
}

- (void)stopSleepWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.sleepWatchdogTimer invalidate];
        transportContext.sleepWatchdogTimer = nil;
    }];
}

- (void)startConnectionWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connectionWatchdogTimer == nil)
        {
            __weak MTTcpTransport *weakSelf = self;
            transportContext.connectionWatchdogTimer = [[MTTimer alloc] initWithTimeout:10.0 repeat:false completion:^
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionWatchdogTimeout];
            } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
            [transportContext.connectionWatchdogTimer start];
        }
    }];
}

- (void)stopConnectionWatchdogTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [transportContext.connectionWatchdogTimer invalidate];
        transportContext.connectionWatchdogTimer = nil;
    }];
}

- (void)connectionWatchdogTimeout
{
    MTTcpTransportContext *transportContext = _transportContext;
    [transportContext.connectionWatchdogTimer invalidate];
    transportContext.connectionWatchdogTimer = nil;
    
    id<MTTransportDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
        [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:true isProbablyHttp:false];
}

- (void)startActualizationPingResendTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.actualizationPingResendTimer != nil)
            [transportContext.actualizationPingResendTimer invalidate];
        
        __weak MTTcpTransport *weakSelf = self;
        transportContext.actualizationPingResendTimer = [[MTTimer alloc] initWithTimeout:3 repeat:false completion:^
        {
            __strong MTTcpTransport *strongSelf = weakSelf;
            [strongSelf resendActualizationPing];
        } queue:[MTTcpTransport tcpTransportQueue].nativeQueue];
        [transportContext.actualizationPingResendTimer start];
    }];
}

- (void)stopActualizationPingResendTimer
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.actualizationPingResendTimer != nil)
        {
            [transportContext.actualizationPingResendTimer invalidate];
            transportContext.actualizationPingResendTimer = nil;
        }
    }];
}

- (void)resendActualizationPing
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        
        if (transportContext.currentActualizationPingMessageId != 0)
        {
            transportContext.didSendActualizationPingAfterConnection = false;
            transportContext.currentActualizationPingMessageId = 0;
            
            [self _requestTransactionFromDelegate];
        }
    }];
}

- (void)tcpConnectionOpened:(MTTcpConnection *)connection
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        transportContext.connectionConnected = true;
        transportContext.connectionIsValid = false;
        [transportContext.connectionBehaviour connectionOpened];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:isUsingProxy:)])
            [delegate transportConnectionStateChanged:self isConnected:true isUsingProxy:transportContext.isUsingProxy];
        
        transportContext.didSendActualizationPingAfterConnection = false;
        transportContext.currentActualizationPingMessageId = 0;
        
        [self _requestTransactionFromDelegate];
    }];
}

- (void)tcpConnectionClosed:(MTTcpConnection *)connection
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        transportContext.connectionConnected = false;
        transportContext.connectionIsValid = false;
        transportContext.connection.delegate = nil;
        transportContext.connection = nil;
        
        [transportContext.connectionBehaviour connectionClosed];
        
        transportContext.didSendActualizationPingAfterConnection = false;
        transportContext.currentActualizationPingMessageId = 0;
        
        [self restartSleepWatchdogTimer];
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionStateChanged:isConnected:isUsingProxy:)])
            [delegate transportConnectionStateChanged:self isConnected:false isUsingProxy:transportContext.isUsingProxy];
        
        if ([delegate respondsToSelector:@selector(transportTransactionsMayHaveFailed:transactionIds:)])
            [delegate transportTransactionsMayHaveFailed:self transactionIds:@[connection.internalId]];
    }];
}

- (void)tcpConnectionReceivedData:(MTTcpConnection *)connection data:(NSData *)data
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        if (transportContext.currentActualizationPingMessageId != 0 && transportContext.actualizationPingResendTimer == nil)
            [self startActualizationPingResendTimer];
        
        __weak MTTcpTransport *weakSelf = self;
        [self _processIncomingData:data transactionId:connection.internalId requestTransactionAfterProcessing:false decodeResult:^(id transactionId, bool success)
        {
            if (success)
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsValid:transactionId];
            }
            else
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                [strongSelf connectionIsInvalid];
            }
        }];
    }];
}

- (void)connectionIsValid:(id)transactionId
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != nil && [transportContext.connection.internalId isEqual:transactionId])
        {
            transportContext.connectionIsValid = true;
            [transportContext.connectionBehaviour connectionValidDataReceived];
        }
        
        [self stopConnectionWatchdogTimer];
    }];
}

- (void)connectionIsInvalid
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionProblemsStatusChanged:hasConnectionProblems:isProbablyHttp:)])
            [delegate transportConnectionProblemsStatusChanged:self hasConnectionProblems:true isProbablyHttp:true];
    }];
}

- (void)tcpConnectionReceivedQuickAck:(MTTcpConnection *)connection quickAck:(int32_t)quickAck
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportReceivedQuickAck:quickAckId:)])
            [delegate transportReceivedQuickAck:self quickAckId:quickAck];
    }];
}

- (void)tcpConnectionDecodePacketProgressToken:(MTTcpConnection *)connection data:(NSData *)data token:(int64_t)token completion:(void (^)(int64_t token, id packetProgressToken))completion
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportDecodeProgressToken:data:token:completion:)])
            [delegate transportDecodeProgressToken:self data:data token:token completion:completion];
    }];
}

- (void)tcpConnectionProgressUpdated:(MTTcpConnection *)connection packetProgressToken:(id)packetProgressToken packetLength:(NSUInteger)packetLength progress:(float)progress
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connection != connection)
            return;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportUpdatedDataReceiveProgress:progressToken:packetLength:progress:)])
            [delegate transportUpdatedDataReceiveProgress:self progressToken:packetProgressToken packetLength:packetLength progress:progress];
    }];
}

- (void)tcpConnectionBehaviourRequestsReconnection:(MTTcpConnectionBehaviour *)behaviour
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.connectionBehaviour != behaviour)
            return;
        
        if (!transportContext.stopped)
            [self startIfNeeded];
    }];
}

- (void)_requestTransactionFromDelegate
{
    MTTcpTransportContext *transportContext = _transportContext;
    if (transportContext.isWaitingForTransactionToBecomeReady)
    {
        if (!transportContext.didSendActualizationPingAfterConnection)
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%x unlocking transaction processing due to connection context update task]", (int)self);
            }
            transportContext.isWaitingForTransactionToBecomeReady = false;
            transportContext.transactionLockTime = 0.0;
        }
        else if (CFAbsoluteTimeGetCurrent() > transportContext.transactionLockTime + 1.0)
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%x unlocking transaction processing due to timeout]", (int)self);
            }
            transportContext.isWaitingForTransactionToBecomeReady = false;
            transportContext.transactionLockTime = 0.0;
        }
        else
        {
            if (MTLogEnabled()) {
                MTLog(@"[MTTcpTransport#%x skipping transaction request]", (int)self);
            }
            transportContext.requestAnotherTransactionWhenReady = true;
            
            return;
        }
    }
    
    id<MTTransportDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(transportReadyForTransaction:transportSpecificTransaction:forceConfirmations:transactionReady:)])
    {
        transportContext.isWaitingForTransactionToBecomeReady = true;
        transportContext.transactionLockTime = CFAbsoluteTimeGetCurrent();
        
        MTMessageTransaction *transportSpecificTransaction = nil;
        if (!transportContext.didSendActualizationPingAfterConnection)
        {
            transportContext.didSendActualizationPingAfterConnection = true;
            
            int64_t randomId = 0;
            arc4random_buf(&randomId, 8);
            
            MTBuffer *pingBuffer = [[MTBuffer alloc] init];
            [pingBuffer appendInt32:(int32_t)0x7abe77ec];
            [pingBuffer appendInt64:randomId];
            
            MTOutgoingMessage *outgoingMessage = [[MTOutgoingMessage alloc] initWithData:pingBuffer.data metadata:@"ping"];
            outgoingMessage.requiresConfirmation = false;
            
            __weak MTTcpTransport *weakSelf = self;
            transportSpecificTransaction = [[MTMessageTransaction alloc] initWithMessagePayload:@[outgoingMessage] prepared:nil failed:nil completion:^(__unused NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
            {
                MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[outgoingMessage.internalId];
                [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                {
                    if (preparedMessage != nil)
                    {
                        __strong MTTcpTransport *strongSelf = weakSelf;
                        if (strongSelf != nil) {
                            transportContext.currentActualizationPingMessageId = preparedMessage.messageId;
                            
                            id<MTTransportDelegate> delegate = strongSelf.delegate;
                            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)]) {
                                [delegate transportConnectionContextUpdateStateChanged:strongSelf isUpdatingConnectionContext:true];
                            }
                        }
                    }
                }];
            }];
            transportSpecificTransaction.requiresEncryption = true;
        }
        
        __weak MTTcpTransport *weakSelf = self;
        [delegate transportReadyForTransaction:self transportSpecificTransaction:transportSpecificTransaction forceConfirmations:transportSpecificTransaction != nil transactionReady:^(NSArray *transactionList)
        {
            [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
            {
                __strong MTTcpTransport *strongSelf = weakSelf;
                if (strongSelf != nil) {
                    for (MTTransportTransaction *transaction in transactionList)
                    {
                        if (transaction.payload.length != 0)
                        {
                            bool acceptTransaction = true;
/*#ifdef DEBUG
                            if (arc4random_uniform(10) < 5) {
                                acceptTransaction = false;
                            }
#endif*/
                            if (transportContext.connection != nil && acceptTransaction)
                            {
                                id transactionId = transportContext.connection.internalId;
                                [transportContext.connection sendDatas:@[transaction.payload] completion:^(bool success)
                                {
                                    if (transaction.completion)
                                        transaction.completion(success, transactionId);
                                } requestQuickAck:transaction.needsQuickAck expectDataInResponse:transaction.expectsDataInResponse];
                            }
                            else if (transaction.completion != nil)
                                transaction.completion(false, nil);
                        }
                    }
                    
                    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
                    {
                        transportContext.isWaitingForTransactionToBecomeReady = false;
                        
                        if (transportContext.requestAnotherTransactionWhenReady)
                        {
                            transportContext.requestAnotherTransactionWhenReady = false;
                            [strongSelf _requestTransactionFromDelegate];
                        }
                    }];
                }
            }];
        }];
    }
}

- (void)activeTransactionIds:(void (^)(NSArray *activeTransactionId))completion
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (completion && transportContext.connection != nil)
            completion(@[transportContext.connection.internalId]);
    }];
}

- (void)_networkAvailabilityChanged:(bool)networkAvailable
{
    MTTcpTransportContext *transportContext = _transportContext;
    [super _networkAvailabilityChanged:networkAvailable];
    
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        transportContext.isNetworkAvailable = networkAvailable;
        
        if (networkAvailable)
            [transportContext.connectionBehaviour clearBackoff];
        
        [transportContext.connection stop];
    }];
}

- (void)mtProtoDidChangeSession:(MTProto *)__unused mtProto
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        [self stopActualizationPingResendTimer];
        transportContext.currentActualizationPingMessageId = 0;
        
        id<MTTransportDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
            [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
    }];
}

- (void)mtProtoServerDidChangeSession:(MTProto *)__unused mtProto firstValidMessageId:(int64_t)firstValidMessageId otherValidMessageIds:(NSArray *)otherValidMessageIds
{
    MTTcpTransportContext *transportContext = _transportContext;
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        if (transportContext.currentActualizationPingMessageId != 0 && (transportContext.currentActualizationPingMessageId < firstValidMessageId && ![otherValidMessageIds containsObject:@(transportContext.currentActualizationPingMessageId)]))
        {
            [self stopActualizationPingResendTimer];
            
            transportContext.currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

- (void)mtProto:(MTProto *)__unused mtProto receivedMessage:(MTIncomingMessage *)incomingMessage
{
    if ([incomingMessage.body isKindOfClass:[MTPongMessage class]])
    {
        MTTcpTransportContext *transportContext = _transportContext;
        [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
        {
            if (transportContext.currentActualizationPingMessageId != 0 && ((MTPongMessage *)incomingMessage.body).messageId == transportContext.currentActualizationPingMessageId)
            {
                [self stopActualizationPingResendTimer];
                
                transportContext.currentActualizationPingMessageId = 0;
                
                id<MTTransportDelegate> delegate = self.delegate;
                if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                    [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
            }
        }];
    }
}

- (void)mtProto:(MTProto *)__unused mtProto messageDeliveryFailed:(int64_t)messageId
{
    [[MTTcpTransport tcpTransportQueue] dispatchOnQueue:^
    {
        MTTcpTransportContext *transportContext = _transportContext;
        if (transportContext.currentActualizationPingMessageId != 0 && messageId == transportContext.currentActualizationPingMessageId)
        {
            [self stopActualizationPingResendTimer];
            transportContext.currentActualizationPingMessageId = 0;
            
            id<MTTransportDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(transportConnectionContextUpdateStateChanged:isUpdatingConnectionContext:)])
                [delegate transportConnectionContextUpdateStateChanged:self isUpdatingConnectionContext:false];
        }
    }];
}

@end
