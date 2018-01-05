//
//  TGRequestHelper.h
//  Telegraph
//
//  Created by mayongshuai on 2017/12/12.
//

#import <Foundation/Foundation.h>

@interface TGTransferHelper : NSObject

+ (void)sessionRequest:(NSString*)urlString;

+(void*)request:(NSString*)urlString;

@end
