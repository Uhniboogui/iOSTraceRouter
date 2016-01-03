//
//  TraceRouter.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "TraceRouter.h"

@interface TraceRouter()
{
    int try_cnt;
    int max_ttl;
    int response_timeout_msec;
    int overall_timeout_sec;
}
@property (nonatomic, copy, readwrite) NSData *hostAddress;
@property (nonatomic, strong, readwrite) NSString *hostName;
@property (nonatomic, assign, readwrite) uint16_t identifier;

@property (copy) completionBlock completion;
@property (copy) failureBlock failure;
@end

@implementation TraceRouter
- (instancetype) initWithHostname:(NSString *)hostName
                         tryCount:(int)tryCount
                           maxTTL:(int)maxTTL
          responseTimeoutMilliSec:(int)responseTimeoutMilliSec
                overallTimeoutSec:(int)overallTimeoutSec
                  completionBlock:(completionBlock)completionBlock
                     failureBlock:(failureBlock)failureBlock
{
    self = [super init];
    
    if (self) {
        self.hostName = hostName;
        
        response_timeout_msec = responseTimeoutMilliSec;
        max_ttl = maxTTL;
        try_cnt = tryCount;
        overall_timeout_sec = overallTimeoutSec;
        
        self.completion = completionBlock;
        self.failure = failureBlock;
        
        self.identifier = (uint16_t)arc4random();
    }
    
    return self;
}

- (void)dealloc
{
    NSLog(@"TraceRouter for host %@ deallocate", self.hostName);
}

- (void)startTraceRoute
{
    NSLog(@"Start Trace Route!");
}
@end
