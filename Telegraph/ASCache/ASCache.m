//
//  ASCache.m
//  Shop
//
//  Created by AMDS on 14/9/8.
//  Copyright (c) 2014年 AMDS. All rights reserved.
//

#import "define.h"
#import "ASCache.h"
#import "NSString+MD5.h"

@interface ASCache()

@property (nonatomic,strong) NSString * cachePath;

@end

@implementation ASCache

+ (ASCache*)shared
{
    static ASCache * instance = nil;
    if (!instance) {
        instance = [[ASCache alloc]init];
    }
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cachePath = [kPathCache stringByAppendingPathComponent:@"ascache"];
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager]fileExistsAtPath:_cachePath isDirectory:&isDir] || !isDir) {
            
            [[NSFileManager defaultManager]createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
            
        }
    }
    return self;
}

- (void)store:(id)aModel forIdentifier:(NSString*)identifier
{
    identifier = [identifier MD5];
    
    NSString * cachefile = [_cachePath stringByAppendingPathComponent:identifier];
    
    //开始编码存数据
    BOOL bRes = [NSKeyedArchiver archiveRootObject:aModel toFile:cachefile];
    
    if (!bRes) {
        NSLog(@"缓存失败！");
    }
}

- (id)getByIdentifier:(NSString*)identifier
{
    identifier = [identifier MD5];
    NSString * cachefile = [_cachePath stringByAppendingPathComponent:identifier];
    @try
    {
        if (![[NSFileManager defaultManager]fileExistsAtPath:cachefile]) {
            return nil;
        }
        
        NSURL *cacheFilePath = [NSURL fileURLWithPath:cachefile];
        NSData *data = [NSData dataWithContentsOfURL:cacheFilePath];
        
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    @catch(NSException* ex)
    {
        [[NSFileManager defaultManager]removeItemAtPath:cachefile error:nil];
        return nil;
    }
}

- (id)getByIdentifier:(NSString*)identifier forTime:(double)aInterval
{
    identifier = [identifier MD5];
    NSString * cachefile = [_cachePath stringByAppendingPathComponent:identifier];
    @try {
        if (![[NSFileManager defaultManager]fileExistsAtPath:cachefile]) {
            return nil;
        }
        
        NSDictionary *fileAttributes = [[NSFileManager defaultManager]attributesOfItemAtPath:cachefile error:nil];
        
        NSDate * modifyDate = [fileAttributes fileModificationDate];
        
        NSDate * currentDate = [NSDate date];
        
        NSTimeInterval intelval = [currentDate timeIntervalSince1970] - [modifyDate timeIntervalSince1970];
        
        if (intelval > aInterval) {
            
            [[NSFileManager defaultManager]removeItemAtPath:cachefile error:nil];
            
            return nil;
        }
        
        NSURL *cacheFilePath = [NSURL fileURLWithPath:cachefile];
        NSData *data = [NSData dataWithContentsOfURL:cacheFilePath];
        
        return [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch (NSException *exception) {
        [[NSFileManager defaultManager]removeItemAtPath:cachefile error:nil];
        return nil;
    }
}

- (void)removeByIdentifier:(NSString*)identifier
{
    identifier = [identifier MD5];
    
    NSString * cachefile = [_cachePath stringByAppendingPathComponent:identifier];
    
    if ([[NSFileManager defaultManager]fileExistsAtPath:cachefile]) {
        [[NSFileManager defaultManager]removeItemAtPath:cachefile error:nil];
    }
}

- (void)clear
{
    [[NSFileManager defaultManager]removeItemAtPath:_cachePath error:nil];
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager]fileExistsAtPath:_cachePath isDirectory:&isDir] || !isDir) {
        
        [[NSFileManager defaultManager]createDirectoryAtPath:_cachePath withIntermediateDirectories:YES attributes:nil error:nil];
        
    }
}

@end
