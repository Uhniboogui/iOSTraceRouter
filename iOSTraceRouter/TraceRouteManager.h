//
//  TraceRouteManager.h
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^CompletionBlock)(NSString *, NSError *);

@interface TraceRouteManager : NSObject
@property (assign, nonatomic) int tryCount;
@property (assign, nonatomic) int maxTTL;
@property (assign, nonatomic) int responseTimeoutMsec;
@property (assign, nonatomic) int overallTimeoutSec;

+ (instancetype)sharedInstance;
- (void)tracerouteForHost:(NSString *)host completion:(CompletionBlock)completion;

@end
