//
//  VCSingletonTemplate.h
//  VCash
//
//  Created by Limin Ren on 2017/8/17.
//  Copyright © 2017年 Goopal. All rights reserved.
//  单例模板

// .h文件
#define SingletonTemplateH(name) + (instancetype)shared##name

// .m文件
#define SingletonTemplateM(name)\
static id _instance=nil;\
+ (instancetype)allocWithZone:(struct _NSZone *)zone\
{\
static dispatch_once_t onceToken;\
dispatch_once(&onceToken, ^{\
_instance = [super allocWithZone:zone];\
});\
return _instance;\
}\
+(instancetype)shared##name\
{\
return [[self alloc]init];\
}\
-(id)copyWithZone:(NSZone *)zone\
{\
return _instance;\
}
