/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTDatacenterAuthMessageService.h"

#import "MTLogging.h"
#import "MTContext.h"
#import "MTProto.h"
#import "MTSerialization.h"
#import "MTSessionInfo.h"
#import "MTIncomingMessage.h"
#import "MTOutgoingMessage.h"
#import "MTMessageTransaction.h"
#import "MTPreparedMessage.h"
#import "MTDatacenterAuthInfo.h"
#import "MTDatacenterSaltInfo.h"
#import "MTBuffer.h"
#import "MTEncryption.h"

#import "MTInternalMessageParser.h"
#import "MTServerDhInnerDataMessage.h"
#import "MTResPqMessage.h"
#import "MTServerDhParamsMessage.h"
#import "MTSetClientDhParamsResponseMessage.h"

static NSArray *defaultPublicKeys() {
    static NSArray *serverPublicKeys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        serverPublicKeys = [[NSArray alloc] initWithObjects:
                            [[NSDictionary alloc] initWithObjectsAndKeys:@"-----BEGIN RSA PUBLIC KEY-----\n"
                             "MIIBCgKCAQEAxq7aeLAqJR20tkQQMfRn+ocfrtMlJsQ2Uksfs7Xcoo77jAid0bRt\n"
                             "ksiVmT2HEIJUlRxfABoPBV8wY9zRTUMaMA654pUX41mhyVN+XoerGxFvrs9dF1Ru\n"
                             "vCHbI02dM2ppPvyytvvMoefRoL5BTcpAihFgm5xCaakgsJ/tH5oVl74CdhQw8J5L\n"
                             "xI/K++KJBUyZ26Uba1632cOiq05JBUW0Z2vWIOk4BLysk7+U9z+SxynKiZR3/xdi\n"
                             "XvFKk01R3BHV+GUKM2RYazpS/P8v7eyKhAbKxOdRcFpHLlVwfjyM1VlDQrEZxsMp\n"
                             "NTLYXb6Sce1Uov0YtNx5wEowlREH1WOTlwIDAQAB\n"
                             "-----END RSA PUBLIC KEY-----", @"key", [[NSNumber alloc] initWithUnsignedLongLong:0x9a996a1db11c729bUL], @"fingerprint", nil],
                            [[NSDictionary alloc] initWithObjectsAndKeys:@"-----BEGIN RSA PUBLIC KEY-----\n"
                             "MIIBCgKCAQEAsQZnSWVZNfClk29RcDTJQ76n8zZaiTGuUsi8sUhW8AS4PSbPKDm+\n"
                             "DyJgdHDWdIF3HBzl7DHeFrILuqTs0vfS7Pa2NW8nUBwiaYQmPtwEa4n7bTmBVGsB\n"
                             "1700/tz8wQWOLUlL2nMv+BPlDhxq4kmJCyJfgrIrHlX8sGPcPA4Y6Rwo0MSqYn3s\n"
                             "g1Pu5gOKlaT9HKmE6wn5Sut6IiBjWozrRQ6n5h2RXNtO7O2qCDqjgB2vBxhV7B+z\n"
                             "hRbLbCmW0tYMDsvPpX5M8fsO05svN+lKtCAuz1leFns8piZpptpSCFn7bWxiA9/f\n"
                             "x5x17D7pfah3Sy2pA+NDXyzSlGcKdaUmwQIDAQAB\n"
                             "-----END RSA PUBLIC KEY-----", @"key", [[NSNumber alloc] initWithUnsignedLongLong:0xb05b2a6f70cdea78UL], @"fingerprint", nil],
                            [[NSDictionary alloc] initWithObjectsAndKeys:@"-----BEGIN RSA PUBLIC KEY-----\n"
                             "MIIBCgKCAQEAwVACPi9w23mF3tBkdZz+zwrzKOaaQdr01vAbU4E1pvkfj4sqDsm6\n"
                             "lyDONS789sVoD/xCS9Y0hkkC3gtL1tSfTlgCMOOul9lcixlEKzwKENj1Yz/s7daS\n"
                             "an9tqw3bfUV/nqgbhGX81v/+7RFAEd+RwFnK7a+XYl9sluzHRyVVaTTveB2GazTw\n"
                             "Efzk2DWgkBluml8OREmvfraX3bkHZJTKX4EQSjBbbdJ2ZXIsRrYOXfaA+xayEGB+\n"
                             "8hdlLmAjbCVfaigxX0CDqWeR1yFL9kwd9P0NsZRPsmoqVwMbMu7mStFai6aIhc3n\n"
                             "Slv8kg9qv1m6XHVQY3PnEw+QQtqSIXklHwIDAQAB\n"
                             "-----END RSA PUBLIC KEY-----", @"key", [[NSNumber alloc] initWithUnsignedLongLong:0xc3b42b026ce86b21UL], @"fingerprint", nil],
                            [[NSDictionary alloc] initWithObjectsAndKeys:@"-----BEGIN RSA PUBLIC KEY-----\n"
                             "MIIBCgKCAQEAwqjFW0pi4reKGbkc9pK83Eunwj/k0G8ZTioMMPbZmW99GivMibwa\n"
                             "xDM9RDWabEMyUtGoQC2ZcDeLWRK3W8jMP6dnEKAlvLkDLfC4fXYHzFO5KHEqF06i\n"
                             "qAqBdmI1iBGdQv/OQCBcbXIWCGDY2AsiqLhlGQfPOI7/vvKc188rTriocgUtoTUc\n"
                             "/n/sIUzkgwTqRyvWYynWARWzQg0I9olLBBC2q5RQJJlnYXZwyTL3y9tdb7zOHkks\n"
                             "WV9IMQmZmyZh/N7sMbGWQpt4NMchGpPGeJ2e5gHBjDnlIf2p1yZOYeUYrdbwcS0t\n"
                             "UiggS4UeE8TzIuXFQxw7fzEIlmhIaq3FnwIDAQAB\n"
                             "-----END RSA PUBLIC KEY-----", @"key", [[NSNumber alloc] initWithUnsignedLongLong:0x71e025b6c76033e3UL], @"fingerprint", nil],
                            nil];
    });
    return serverPublicKeys;
}

static NSDictionary *selectPublicKey(NSArray *fingerprints, NSArray<NSDictionary *> *publicKeys)
{
    for (NSDictionary *keyDesc in publicKeys)
    {
        int64_t keyFingerprint = [[keyDesc objectForKey:@"fingerprint"] longLongValue];
        for (NSNumber *nFingerprint in fingerprints)
        {
            if ([nFingerprint longLongValue] == keyFingerprint)
                return keyDesc;
        }
}

return nil;
}

typedef enum {
    MTDatacenterAuthStageWaitingForPublicKeys = 0,
    MTDatacenterAuthStagePQ = 1,
    MTDatacenterAuthStageReqDH = 2,
    MTDatacenterAuthStageKeyVerification = 3,
    MTDatacenterAuthStageDone = 4
} MTDatacenterAuthStage;

@interface MTDatacenterAuthMessageService ()
{
    MTSessionInfo *_sessionInfo;
    
    MTDatacenterAuthStage _stage;
    int64_t _currentStageMessageId;
    int32_t _currentStageMessageSeqNo;
    id _currentStageTransactionId;
    
    NSData *_nonce;
    NSData *_serverNonce;
    NSData *_newNonce;
    
    NSData *_dhP;
    NSData *_dhQ;
    int64_t _dhPublicKeyFingerprint;
    NSData *_dhEncryptedData;
    
    MTDatacenterAuthInfo *_authInfo;
    NSData *_encryptedClientData;
    
    NSArray<NSDictionary *> *_publicKeys;
}

@end

@implementation MTDatacenterAuthMessageService

- (instancetype)initWithContext:(MTContext *)context
{
    self = [super init];
    if (self != nil)
    {
        _sessionInfo = [[MTSessionInfo alloc] initWithRandomSessionIdAndContext:context];
    }
    return self;
}

- (void)reset:(MTProto *)mtProto
{
    _currentStageMessageId = 0;
    _currentStageMessageSeqNo = 0;
    _currentStageTransactionId = nil;
    
    _nonce = nil;
    _serverNonce = nil;
    _newNonce = nil;
    
    _dhP = nil;
    _dhQ = nil;
    _dhPublicKeyFingerprint = 0;
    _dhEncryptedData = nil;
    
    _authInfo = nil;
    _encryptedClientData = nil;
    
    if (mtProto.cdn) {
        _publicKeys = [mtProto.context publicKeysForDatacenterWithId:mtProto.datacenterId];
        if (_publicKeys == nil) {
            _stage = MTDatacenterAuthStageWaitingForPublicKeys;
            [mtProto.context publicKeysForDatacenterWithIdRequired:mtProto.datacenterId];
        } else {
            _stage = MTDatacenterAuthStagePQ;
        }
    } else {
        _publicKeys = defaultPublicKeys();
        _stage = MTDatacenterAuthStagePQ;
    }
    
    [mtProto requestSecureTransportReset];
    [mtProto requestTransportTransaction];
}

- (void)mtProtoDidAddService:(MTProto *)mtProto
{
    [self reset:mtProto];
}
    
- (void)mtProtoPublicKeysUpdated:(MTProto *)mtProto datacenterId:(NSInteger)datacenterId publicKeys:(NSArray<NSDictionary *> *)publicKeys {
    if (_stage == MTDatacenterAuthStageWaitingForPublicKeys) {
        if (mtProto.datacenterId == datacenterId) {
            _publicKeys = publicKeys;
            if (_publicKeys != nil && _publicKeys.count != 0) {
                _stage = MTDatacenterAuthStagePQ;
                [mtProto requestTransportTransaction];
            }
        }
    }
}

- (MTMessageTransaction *)mtProtoMessageTransaction:(MTProto *)mtProto
{
    if (_currentStageTransactionId == nil)
    {
        switch (_stage)
        {
            case MTDatacenterAuthStageWaitingForPublicKeys:
                break;
            case MTDatacenterAuthStagePQ:
            {
                if (_nonce == nil)
                {
                    uint8_t nonceBytes[16];
                    __unused int result = SecRandomCopyBytes(kSecRandomDefault, 16, nonceBytes);
                    _nonce = [[NSData alloc] initWithBytes:nonceBytes length:16];
                }
                
                MTBuffer *reqPqBuffer = [[MTBuffer alloc] init];
                [reqPqBuffer appendInt32:(int32_t)0x60469778];
                [reqPqBuffer appendBytes:_nonce.bytes length:_nonce.length];
                
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:reqPqBuffer.data metadata:@"reqPq" messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStagePQ && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            case MTDatacenterAuthStageReqDH:
            {
                MTBuffer *reqDhBuffer = [[MTBuffer alloc] init];
                [reqDhBuffer appendInt32:(int32_t)0xd712e4be];
                [reqDhBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [reqDhBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [reqDhBuffer appendTLBytes:_dhP];
                [reqDhBuffer appendTLBytes:_dhQ];
                [reqDhBuffer appendInt64:_dhPublicKeyFingerprint];
                [reqDhBuffer appendTLBytes:_dhEncryptedData];
                
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:reqDhBuffer.data metadata:@"reqDh" messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStageReqDH && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            case MTDatacenterAuthStageKeyVerification:
            {
                MTBuffer *setDhParamsBuffer = [[MTBuffer alloc] init];
                [setDhParamsBuffer appendInt32:(int32_t)0xf5045f1f];
                [setDhParamsBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [setDhParamsBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [setDhParamsBuffer appendTLBytes:_encryptedClientData];
                
                MTOutgoingMessage *message = [[MTOutgoingMessage alloc] initWithData:setDhParamsBuffer.data metadata:@"setDhParams" messageId:_currentStageMessageId messageSeqNo:_currentStageMessageSeqNo];
                return [[MTMessageTransaction alloc] initWithMessagePayload:@[message] prepared:nil failed:nil completion:^(NSDictionary *messageInternalIdToTransactionId, NSDictionary *messageInternalIdToPreparedMessage, __unused NSDictionary *messageInternalIdToQuickAckId)
                {
                    if (_stage == MTDatacenterAuthStageKeyVerification && messageInternalIdToTransactionId[message.internalId] != nil && messageInternalIdToPreparedMessage[message.internalId] != nil)
                    {
                        MTPreparedMessage *preparedMessage = messageInternalIdToPreparedMessage[message.internalId];
                        _currentStageMessageId = preparedMessage.messageId;
                        _currentStageMessageSeqNo = preparedMessage.seqNo;
                        _currentStageTransactionId = messageInternalIdToTransactionId[message.internalId];
                    }
                }];
            }
            default:
                break;
        }
    }
    
    return nil;
}

- (void)mtProto:(MTProto *)mtProto receivedMessage:(MTIncomingMessage *)message
{
    if (_stage == MTDatacenterAuthStagePQ && [message.body isKindOfClass:[MTResPqMessage class]])
    {
        MTResPqMessage *resPqMessage = message.body;
        
        if ([_nonce isEqualToData:resPqMessage.nonce])
        {
            NSDictionary *publicKey = selectPublicKey(resPqMessage.serverPublicKeyFingerprints, _publicKeys);
            
            if (publicKey == nil && mtProto.cdn && resPqMessage.serverPublicKeyFingerprints.count == 1 && _publicKeys.count == 1) {
                publicKey = @{@"key": _publicKeys[0][@"key"], @"fingerprint": resPqMessage.serverPublicKeyFingerprints[0]};
            }
            
            if (publicKey == nil)
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p couldn't find valid server public key]", self);
                }
                [self reset:mtProto];
            }
            else
            {
                NSData *pqBytes = resPqMessage.pq;
                
                uint64_t pq = 0;
                for (int i = 0; i < (int)pqBytes.length; i++)
                {
                    pq <<= 8;
                    pq |= ((uint8_t *)[pqBytes bytes])[i];
                }
                
                uint64_t factP = 0;
                uint64_t factQ = 0;
                if (!MTFactorize(pq, &factP, &factQ))
                {
                    [self reset:mtProto];
                    
                    return;
                }
                
                _serverNonce = resPqMessage.serverNonce;
                
                NSMutableData *pBytes = [[NSMutableData alloc] init];
                uint64_t p = factP;
                do
                {
                    [pBytes replaceBytesInRange:NSMakeRange(0, 0) withBytes:&p length:1];
                    p >>= 8;
                } while (p > 0);
                _dhP = pBytes;
                
                NSMutableData *qBytes = [[NSMutableData alloc] init];
                uint64_t q = factQ;
                do
                {
                    [qBytes replaceBytesInRange:NSMakeRange(0, 0) withBytes:&q length:1];
                    q >>= 8;
                } while (q > 0);
                _dhQ = qBytes;
                
                _dhPublicKeyFingerprint = [[publicKey objectForKey:@"fingerprint"] longLongValue];
                
                uint8_t nonceBytes[32];
                __unused int result = SecRandomCopyBytes(kSecRandomDefault, 32, nonceBytes);
                _newNonce = [[NSData alloc] initWithBytes:nonceBytes length:32];
                
                MTBuffer *innerDataBuffer = [[MTBuffer alloc] init];
                [innerDataBuffer appendInt32:(int32_t)0x83c95aec];
                [innerDataBuffer appendTLBytes:pqBytes];
                [innerDataBuffer appendTLBytes:_dhP];
                [innerDataBuffer appendTLBytes:_dhQ];
                [innerDataBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [innerDataBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [innerDataBuffer appendBytes:_newNonce.bytes length:_newNonce.length];
                
                NSData *innerDataBytes = innerDataBuffer.data;
                
                NSMutableData *dataWithHash = [[NSMutableData alloc] init];
                [dataWithHash appendData:MTSha1(innerDataBytes)];
                [dataWithHash appendData:innerDataBytes];
                while (dataWithHash.length < 255)
                {
                    uint8_t random = 0;
                    arc4random_buf(&random, 1);
                    [dataWithHash appendBytes:&random length:1];
                }
                
                NSData *encryptedData = MTRsaEncrypt([publicKey objectForKey:@"key"], dataWithHash);
                if (encryptedData.length < 256)
                {
                    NSMutableData *newEncryptedData = [[NSMutableData alloc] init];
                    for (int i = 0; i < 256 - (int)encryptedData.length; i++)
                    {
                        uint8_t random = 0;
                        arc4random_buf(&random, 1);
                        [newEncryptedData appendBytes:&random length:1];
                    }
                    [newEncryptedData appendData:encryptedData];
                    encryptedData = newEncryptedData;
                }
                
                _dhEncryptedData = encryptedData;
                
                _stage = MTDatacenterAuthStageReqDH;
                _currentStageMessageId = 0;
                _currentStageMessageSeqNo = 0;
                _currentStageTransactionId = nil;
                [mtProto requestTransportTransaction];
            }
        }
    }
    else if (_stage == MTDatacenterAuthStageReqDH && [message.body isKindOfClass:[MTServerDhParamsMessage class]])
    {
        MTServerDhParamsMessage *serverDhParamsMessage = message.body;
        
        if ([_nonce isEqualToData:serverDhParamsMessage.nonce] && [_serverNonce isEqualToData:serverDhParamsMessage.serverNonce])
        {
            if ([serverDhParamsMessage isKindOfClass:[MTServerDhParamsOkMessage class]])
            {
                NSMutableData *tmpAesKey = [[NSMutableData alloc] init];
                
                NSMutableData *newNonceAndServerNonce = [[NSMutableData alloc] init];
                [newNonceAndServerNonce appendData:_newNonce];
                [newNonceAndServerNonce appendData:_serverNonce];
                
                NSMutableData *serverNonceAndNewNonce = [[NSMutableData alloc] init];
                [serverNonceAndNewNonce appendData:_serverNonce];
                [serverNonceAndNewNonce appendData:_newNonce];
                [tmpAesKey appendData:MTSha1(newNonceAndServerNonce)];
                
                NSData *serverNonceAndNewNonceHash = MTSha1(serverNonceAndNewNonce);
                NSData *serverNonceAndNewNonceHash0_12 = [[NSData alloc] initWithBytes:((uint8_t *)serverNonceAndNewNonceHash.bytes) length:12];
                
                [tmpAesKey appendData:serverNonceAndNewNonceHash0_12];
                
                NSMutableData *tmpAesIv = [[NSMutableData alloc] init];
                
                NSData *serverNonceAndNewNonceHash12_8 = [[NSData alloc] initWithBytes:(((uint8_t *)serverNonceAndNewNonceHash.bytes) + 12) length:8];
                [tmpAesIv appendData:serverNonceAndNewNonceHash12_8];
                
                NSMutableData *newNonceAndNewNonce = [[NSMutableData alloc] init];
                [newNonceAndNewNonce appendData:_newNonce];
                [newNonceAndNewNonce appendData:_newNonce];
                [tmpAesIv appendData:MTSha1(newNonceAndNewNonce)];
                
                NSData *newNonce0_4 = [[NSData alloc] initWithBytes:((uint8_t *)_newNonce.bytes) length:4];
                [tmpAesIv appendData:newNonce0_4];
                
                NSData *answerWithHash = MTAesDecrypt(((MTServerDhParamsOkMessage *)serverDhParamsMessage).encryptedResponse, tmpAesKey, tmpAesIv);
                NSData *answerHash = [[NSData alloc] initWithBytes:((uint8_t *)answerWithHash.bytes) length:20];
                
                NSMutableData *answerData = [[NSMutableData alloc] initWithBytes:(((uint8_t *)answerWithHash.bytes) + 20) length:(answerWithHash.length - 20)];
                bool hashVerified = false;
                for (int i = 0; i < 16; i++)
                {
                    NSData *computedAnswerHash = MTSha1(answerData);
                    if ([computedAnswerHash isEqualToData:answerHash])
                    {
                        hashVerified = true;
                        break;
                    }
                    
                    [answerData replaceBytesInRange:NSMakeRange(answerData.length - 1, 1) withBytes:NULL length:0];
                }
                
                if (!hashVerified)
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't decode DH params]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                MTServerDhInnerDataMessage *dhInnerData = [MTInternalMessageParser parseMessage:answerData];
                
                if (![dhInnerData isKindOfClass:[MTServerDhInnerDataMessage class]])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p couldn't parse decoded DH params]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                if (![_nonce isEqualToData:dhInnerData.nonce])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH nonce]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                if (![_serverNonce isEqualToData:dhInnerData.serverNonce])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH server nonce]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                int32_t innerDataG = dhInnerData.g;
                if (innerDataG < 0 || !MTCheckIsSafeG((unsigned int)innerDataG))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                NSData *innerDataGA = dhInnerData.gA;
                NSData *innerDataDhPrime = dhInnerData.dhPrime;
                if (!MTCheckIsSafeGAOrB(innerDataGA, innerDataDhPrime))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g_a]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                if (!MTCheckMod(innerDataDhPrime, (unsigned int)innerDataG, mtProto.context.keychain))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH g (2)]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                if (!MTCheckIsSafePrime(innerDataDhPrime, mtProto.context.keychain))
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH prime]", self);
                    }
                    [self reset:mtProto];
                    
                    return;
                }
                
                uint8_t bBytes[256];
                __unused int result = SecRandomCopyBytes(kSecRandomDefault, 256, bBytes);
                NSData *b = [[NSData alloc] initWithBytes:bBytes length:256];
                
                int32_t tmpG = innerDataG;
                tmpG = (int32_t)OSSwapInt32(tmpG);
                NSData *g = [[NSData alloc] initWithBytes:&tmpG length:4];
                
                NSData *g_b = MTExp(g, b, innerDataDhPrime);
                
                NSData *authKey = MTExp(innerDataGA, b, innerDataDhPrime);
                
                NSData *authKeyHash = MTSha1(authKey);
                int64_t authKeyId = *((int64_t *)(((uint8_t *)authKeyHash.bytes) + authKeyHash.length - 8));
                NSMutableData *serverSaltData = [[NSMutableData alloc] init];
                for (int i = 0; i < 8; i++)
                {
                    int8_t a = ((int8_t *)_newNonce.bytes)[i];
                    int8_t b = ((int8_t *)_serverNonce.bytes)[i];
                    int8_t x = a ^ b;
                    [serverSaltData appendBytes:&x length:1];
                }
                
                _authInfo = [[MTDatacenterAuthInfo alloc] initWithAuthKey:authKey authKeyId:authKeyId saltSet:@[[[MTDatacenterSaltInfo alloc] initWithSalt:*((int64_t *)serverSaltData.bytes) firstValidMessageId:((int64_t)message.timestamp) * 4294967296 lastValidMessageId:((int64_t)(message.timestamp + 29.0 * 60.0)) * 4294967296]] authKeyAttributes:nil];
                
                //client_DH_inner_data#6643b654 nonce:int128 server_nonce:int128 retry_id:long g_b:bytes = Client_DH_Inner_Data;
                MTBuffer *clientDhInnerDataBuffer = [[MTBuffer alloc] init];
                [clientDhInnerDataBuffer appendInt32:(int32_t)0x6643b654];
                [clientDhInnerDataBuffer appendBytes:_nonce.bytes length:_nonce.length];
                [clientDhInnerDataBuffer appendBytes:_serverNonce.bytes length:_serverNonce.length];
                [clientDhInnerDataBuffer appendInt64:0];
                [clientDhInnerDataBuffer appendTLBytes:g_b];
                
                NSData *clientInnerDataBytes = clientDhInnerDataBuffer.data;
                
                NSMutableData *clientDataWithHash = [[NSMutableData alloc] init];
                [clientDataWithHash appendData:MTSha1(clientInnerDataBytes)];
                [clientDataWithHash appendData:clientInnerDataBytes];
                while (clientDataWithHash.length % 16 != 0)
                {
                    uint8_t randomByte = 0;
                    arc4random_buf(&randomByte, 1);
                    [clientDataWithHash appendBytes:&randomByte length:1];
                }
                
                _encryptedClientData = MTAesEncrypt(clientDataWithHash, tmpAesKey, tmpAesIv);
                
                _stage = MTDatacenterAuthStageKeyVerification;
                _currentStageMessageId = 0;
                _currentStageMessageSeqNo = 0;
                _currentStageTransactionId = nil;
                [mtProto requestTransportTransaction];
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p couldn't set DH params]", self);
                }
                [self reset:mtProto];
            }
        }
    }
    else if (_stage == MTDatacenterAuthStageKeyVerification && [message.body isKindOfClass:[MTSetClientDhParamsResponseMessage class]])
    {
        MTSetClientDhParamsResponseMessage *setClientDhParamsResponseMessage = message.body;
        
        if ([_nonce isEqualToData:setClientDhParamsResponseMessage.nonce] && [_serverNonce isEqualToData:setClientDhParamsResponseMessage.serverNonce])
        {
            NSData *authKeyAuxHashFull = MTSha1(_authInfo.authKey);
            NSData *authKeyAuxHash = [[NSData alloc] initWithBytes:((uint8_t *)authKeyAuxHashFull.bytes) length:8];
            
            NSMutableData *newNonce1 = [[NSMutableData alloc] init];
            [newNonce1 appendData:_newNonce];
            uint8_t tmp1 = 1;
            [newNonce1 appendBytes:&tmp1 length:1];
            [newNonce1 appendData:authKeyAuxHash];
            NSData *newNonceHash1Full = MTSha1(newNonce1);
            NSData *newNonceHash1 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash1Full.bytes) + newNonceHash1Full.length - 16) length:16];
            
            NSMutableData *newNonce2 = [[NSMutableData alloc] init];
            [newNonce2 appendData:_newNonce];
            uint8_t tmp2 = 2;
            [newNonce2 appendBytes:&tmp2 length:1];
            [newNonce2 appendData:authKeyAuxHash];
            NSData *newNonceHash2Full = MTSha1(newNonce2);
            NSData *newNonceHash2 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash2Full.bytes) + newNonceHash2Full.length - 16) length:16];
            
            NSMutableData *newNonce3 = [[NSMutableData alloc] init];
            [newNonce3 appendData:_newNonce];
            uint8_t tmp3 = 3;
            [newNonce3 appendBytes:&tmp3 length:1];
            [newNonce3 appendData:authKeyAuxHash];
            NSData *newNonceHash3Full = MTSha1(newNonce3);
            NSData *newNonceHash3 = [[NSData alloc] initWithBytes:(((uint8_t *)newNonceHash3Full.bytes) + newNonceHash3Full.length - 16) length:16];
            
            if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseOkMessage class]])
            {
                if (![newNonceHash1 isEqualToData:((MTSetClientDhParamsResponseOkMessage *)setClientDhParamsResponseMessage).nextNonceHash1])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 1]", self);
                    }
                    [self reset:mtProto];
                }
                else
                {
                    _stage = MTDatacenterAuthStageDone;
                    _currentStageMessageId = 0;
                    _currentStageMessageSeqNo = 0;
                    _currentStageTransactionId = nil;
                    
                    id<MTDatacenterAuthMessageServiceDelegate> delegate = _delegate;
                    if ([delegate respondsToSelector:@selector(authMessageServiceCompletedWithAuthInfo:)])
                        [delegate authMessageServiceCompletedWithAuthInfo:_authInfo];
                }
            }
            else if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseRetryMessage class]])
            {
                if (![newNonceHash2 isEqualToData:((MTSetClientDhParamsResponseRetryMessage *)setClientDhParamsResponseMessage).nextNonceHash2])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 2]", self);
                    }
                    [self reset:mtProto];
                }
                else
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p retry DH]", self);
                    }
                    [self reset:mtProto];
                }
            }
            else if ([setClientDhParamsResponseMessage isKindOfClass:[MTSetClientDhParamsResponseFailMessage class]])
            {
                if (![newNonceHash3 isEqualToData:((MTSetClientDhParamsResponseFailMessage *)setClientDhParamsResponseMessage).nextNonceHash3])
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH answer nonce hash 3]", self);
                    }
                    [self reset:mtProto];
                }
                else
                {
                    if (MTLogEnabled()) {
                        MTLog(@"[MTDatacenterAuthMessageService#%p server rejected DH params]", self);
                    }
                    [self reset:mtProto];
                }
            }
            else
            {
                if (MTLogEnabled()) {
                    MTLog(@"[MTDatacenterAuthMessageService#%p invalid DH params response]", self);
                }
                [self reset:mtProto];
            }
        }
    }
}

- (void)mtProto:(MTProto *)mtProto protocolErrorReceived:(int32_t)__unused errorCode
{
    [self reset:mtProto];
}

- (void)mtProto:(MTProto *)mtProto transactionsMayHaveFailed:(NSArray *)transactionIds
{
    if (_currentStageTransactionId != nil && [transactionIds containsObject:_currentStageTransactionId])
    {
        _currentStageTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

- (void)mtProtoAllTransactionsMayHaveFailed:(MTProto *)mtProto
{
    if (_currentStageTransactionId != nil)
    {
        _currentStageTransactionId = nil;
        [mtProto requestTransportTransaction];
    }
}

@end
