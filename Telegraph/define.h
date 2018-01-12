//
//  define.h
//  Telegraph
//
//  Created by Reason Lee on 12/01/2018.
//

#ifndef define_h
#define define_h

#define VCStr(x,y) [NSString stringWithFormat:@"%@%@",x,y]
#define kPathLibrary   VCStr(NSHomeDirectory(),@"/Library")
#define kPathCache     VCStr(kPathLibrary,     @"/Caches")

#define kDefaultConversationGroup @"BIYONGOfficial"
#define kWhiteListCacheIdentifier @"WhiteListIdentifier"
#define kBlackListCacheIdentifier @"BlackListIdentifier"
#define kDiscoverURLCacheIdentifier @"DiscoverURLIdentifier"

#define kBlackListURL @"https://0.plus/btcchat/common/config/query?keys=telegram_black_config"
#define kWhiteListURL @"https://0.plus/btcchat/common/config/query?keys=telegram_white_config"

#endif /* define_h */
