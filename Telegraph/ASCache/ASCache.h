//
//  ASCache.h
//  Shop
//
//  Created by AMDS on 14/9/8.
//  Copyright (c) 2014年 AMDS. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ASCache : NSObject

+ (ASCache*)shared;

- (void)store:(id)aModel forIdentifier:(NSString*)identifier;

- (id)getByIdentifier:(NSString*)identifier;

- (id)getByIdentifier:(NSString*)identifier forTime:(double)aInterval;

- (void)removeByIdentifier:(NSString*)identifier;

- (void)clear;

@end
