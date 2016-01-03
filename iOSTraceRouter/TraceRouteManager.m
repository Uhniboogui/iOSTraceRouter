//
//  TraceRouteManager.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "TraceRouteManager.h"

@implementation TraceRouteManager
+ (instancetype)sharedInstance {
    static TraceRouteManager *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] initManager];
    });
    return _sharedInstance;
}

- (instancetype)initManager
{
    self = [super init];
    
    if (self) {
        
        self.tryCount = 3;
        self.maxTTL = 64;
        self.responseTimeoutMsec = 20000; // 20sec
        self.overallTimeoutSec = 240; // 3 Min
    }
    
    return self;
}

- (instancetype)init
{
    return [TraceRouteManager sharedInstance];
}

- (void)tracerouteForHost:(NSString *)host completion:(CompletionBlock)completion
{
    completion(host, nil);
}


@end
