//
//  TGRequestHelper.m
//  Telegraph
//
//  Created by mayongshuai on 2017/12/12.
//

#import "TGTransferHelper.h"
#import "thirdparty/AFNetworking/AFHTTPRequestOperation.h"

@implementation TGTransferHelper

+ (void)sessionRequest:(NSString*)urlString
{
    // 快捷方式获得session对象
    NSURLSession *session = [NSURLSession sharedSession];
    NSURL *requestURL = [NSURL URLWithString:urlString];
    
    // 通过URL初始化task,在block内部可以直接对返回的数据进行处理
    NSURLSessionTask *task = [session dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        
        NSLog(@"%@", [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil]);
        
    }];
    
    // 启动任务
    // [task resume];
}

+ (void*)request:(NSString*)urlString
{
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    
    [operation setSuccessCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    [operation setFailureCallbackQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    [operation setCompletionBlockWithSuccess:^(__unused AFHTTPRequestOperation *operation, __unused id responseObject)
     {
         NSString *response = [[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding];
         
         /*NSLog(@"url %@ is response %@",url,response);
         id result = [NSJSONSerialization JSONObjectWithData:responseObject options:NSJSONReadingMutableContainers error:nil];
         
         NSDictionary* dict=[self dictionaryWithJsonString:response];
         
         NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
         [userDefault setObject:result forKey:@"catch"];
         [userDefault synchronize];
         //         [subscriber putNext:[operation responseData]];
         //         [subscriber putCompletion];*/
     } failure:^(__unused AFHTTPRequestOperation *operation, __unused NSError *error)
     {
         //         [subscriber putError:nil];
     }];
    
    [operation start];
}

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err)
    {
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

@end
