#import "TGBridgeUserInfoSignals.h"
#import "TGBridgeUserInfoSubscription.h"
#import "TGBridgeResponse.h"
#import "TGBridgeUser.h"
#import "TGBridgeClient.h"

@implementation TGBridgeUserInfoSignals

+ (SSignal *)userInfoWithUserId:(int32_t)userId;
{
    return [[self usersInfoWithUserIds:@[ @(userId) ]] map:^TGBridgeUser *(NSDictionary *users)
    {
        return users[@(userId)];
    }];
}

+ (SSignal *)usersInfoWithUserIds:(NSArray *)userIds
{
    return [[[TGBridgeClient instance] requestSignalWithSubscription:[[TGBridgeUserInfoSubscription alloc] initWithUserIds:userIds]] map:^NSDictionary *(id next)
    {
        return next;
    }];
}

@end
