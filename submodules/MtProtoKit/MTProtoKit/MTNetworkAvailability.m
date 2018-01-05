/*
 * This is the source code of BTCchat for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#import "MTNetworkAvailability.h"

#import "MTLogging.h"
#import "MTQueue.h"
#import "MTTimer.h"

#import <sys/socket.h>
#import <netinet/in.h>
#import <SystemConfiguration/SystemConfiguration.h>

#import <objc/message.h>

static void MTAvailabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

@class MTNetworkAvailability;

@interface MTNetworkAvailabilityContext : NSObject

@property (nonatomic, weak) MTNetworkAvailability *context;

@end

@implementation MTNetworkAvailabilityContext

@end

static const void *MTNetworkAvailabilityContextRetain(const void *info)
{
    return (__bridge_retained void *)((__bridge id)info);
}

static void MTNetworkAvailabilityContextRelease(const void *info)
{
    void *retainedThing = (__bridge void *)((__bridge id)info);
    id unretainedThing = (__bridge_transfer id)retainedThing;
    unretainedThing = nil;
}

@interface MTNetworkAvailability ()
{
    SCNetworkReachabilityRef _reachability;
    MTTimer *_timer;
    
    NSString *_lastReachabilityState;
}

@end

@implementation MTNetworkAvailability

- (instancetype)initWithDelegate:(id<MTNetworkAvailabilityDelegate>)delegate
{
    self = [super init];
    if (self != nil)
    {
        _delegate = delegate;
        
        [[MTNetworkAvailability networkAvailabilityQueue] dispatchOnQueue:^
         {
             struct sockaddr_in zeroAddress;
             bzero(&zeroAddress, sizeof(zeroAddress));
             zeroAddress.sin_len = sizeof(zeroAddress);
             zeroAddress.sin_family = AF_INET;
             
             _reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
             if (_reachability != NULL)
             {
                 MTNetworkAvailabilityContext *availabilityContext = [[MTNetworkAvailabilityContext alloc] init];
                 availabilityContext.context = self;
                 SCNetworkReachabilityContext context = { 0, (__bridge void *)availabilityContext, &MTNetworkAvailabilityContextRetain, &MTNetworkAvailabilityContextRelease, NULL };
                 
                 [self updateReachability:kSCNetworkReachabilityFlagsReachable notify:false];
                 [self updateFlags:true];
                 
                 __weak MTNetworkAvailability *weakSelf = self;
                 _timer = [[MTTimer alloc] initWithTimeout:5.0 repeat:true completion:^
                           {
                               __strong MTNetworkAvailability *strongSelf = weakSelf;
                               if (strongSelf != nil) {
                                   [strongSelf updateFlags:true];
                               }
                           } queue:[MTNetworkAvailability networkAvailabilityQueue].nativeQueue];
                 [_timer start];
                 
                 if (SCNetworkReachabilitySetCallback(_reachability, &MTAvailabilityCallback, &context))
                     SCNetworkReachabilitySetDispatchQueue(_reachability, [MTNetworkAvailability networkAvailabilityQueue].nativeQueue);
             }
         }];
    }
    return self;
}

- (void)dealloc
{
    SCNetworkReachabilityRef reachability = _reachability;
    _reachability = nil;
    
    MTTimer *timer = _timer;
    _timer = nil;
    
    [[MTNetworkAvailability networkAvailabilityQueue] dispatchOnQueue:^
     {
         [timer invalidate];
         
         SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
         SCNetworkReachabilitySetDispatchQueue(reachability, NULL);
     }];
}

+ (MTQueue *)networkAvailabilityQueue
{
    static MTQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
                  {
                      queue = [[MTQueue alloc] initWithName:"org.mtproto.MTNetwotkAvailability"];
                  });
    return queue;
}

- (void)updateFlags:(bool)notify
{
    [[MTNetworkAvailability networkAvailabilityQueue] dispatchOnQueue:^
     {
         
         if (_reachability != nil)
         {
             SCNetworkReachabilityFlags currentFlags = 0;
             if (SCNetworkReachabilityGetFlags(_reachability, &currentFlags))
                 [self updateReachability:currentFlags notify:notify];
         }
     }];
}

- (void)updateReachability:(SCNetworkReachabilityFlags)flags notify:(bool)notify
{
    [[MTNetworkAvailability networkAvailabilityQueue] dispatchOnQueue:^
     {
         BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
         BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
         BOOL canConnectionAutomatically = (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
                                            ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0));
         BOOL canConnectWithoutUserInteraction = (canConnectionAutomatically &&
                                                  (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
         BOOL isNetworkReachable = (isReachable && (!needsConnection || canConnectWithoutUserInteraction));
         
         bool isWWAN = false;
#if TARGET_OS_IPHONE
         isWWAN = (flags & kSCNetworkReachabilityFlagsIsWWAN);
#endif
         NSString *currentReachabilityState = [[NSString alloc] initWithFormat:@"%s_%s_%s", isWWAN ? "M" : "L", canConnectWithoutUserInteraction ? "+U" : "-U", isNetworkReachable ? "+" : "-"];
         if (![currentReachabilityState isEqualToString:_lastReachabilityState])
         {
             _lastReachabilityState = currentReachabilityState;
             if (MTLogEnabled()) {
                 MTLog(@"[MTNetworkAvailability#%p state: %@]", self, _lastReachabilityState);
             }
             
             if (notify)
             {
                 id<MTNetworkAvailabilityDelegate> delegate = _delegate;
                 if ([delegate respondsToSelector:@selector(networkAvailabilityChanged:networkIsAvailable:)])
                     [delegate networkAvailabilityChanged:self networkIsAvailable:isNetworkReachable];
             }
         }
     }];
}

@end

static void MTAvailabilityCallback(__unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    MTNetworkAvailabilityContext *availabilityContext = ((__bridge MTNetworkAvailabilityContext *)info);
    MTNetworkAvailability *availability = availabilityContext.context;
    [availability updateReachability:flags notify:true];
}
