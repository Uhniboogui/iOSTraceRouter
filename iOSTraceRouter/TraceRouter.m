//
//  TraceRouter.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "TraceRouter.h"
#include <sys/time.h>

@interface TraceRouter()
{
    int try_cnt;
    int max_ttl;
    int response_timeout_msec;
    int overall_timeout_sec;
    
    double traceroute_start_time_msec;
    double traceroute_end_time_msec;
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

- (BOOL)canGetHostIP
{
#warning not implemented
    return YES;
}

- (BOOL)canUseSocket
{
#warning not implemented
    return YES;
}

- (BOOL)canSetReceiveTimeoutSocketOption
{
#warning not implemented
    return YES;
}

- (void)startTraceRoute
{
    NSLog(@"Start Trace Route!");
    if ([self canGetHostIP] == NO) {
        return;
    }
    
    if ([self canUseSocket] == NO) {
        return;
    }
    
    if ([self canSetReceiveTimeoutSocketOption] == NO) {
        return;
    }
    
    traceroute_start_time_msec = [[self class] currentTimeMillis];
    traceroute_end_time_msec = traceroute_start_time_msec + (overall_timeout_sec * 1000);
    
    // must register current thread to run loop
    
    [self sendICMPPacket];
}

- (void)sendICMPPacket
{
    
}

#pragma mark - Utility Functions
+ (double)currentTimeMillis
{
    struct timeval t;
    gettimeofday(&t, NULL);
    
    return (t.tv_sec * 1000) + (t.tv_usec / 1000);
}
@end
