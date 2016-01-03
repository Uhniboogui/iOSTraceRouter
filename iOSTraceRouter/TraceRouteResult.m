//
//  TraceRouteResult.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "TraceRouteResult.h"
#include <netdb.h>

@interface TraceRouteResult()
@property (strong, nonatomic, readwrite) NSString *hostName;
@property (strong, nonatomic, readwrite) NSString *hostIPAddr;
@property (strong, nonatomic, readwrite) NSMutableArray *resultsForTTL;
@property (assign, nonatomic, readwrite) BOOL isCompleted;
@property (assign, nonatomic, readwrite) double elapsedTime;
@end

@implementation TraceRouteResult

- (instancetype) initWithHostname:(NSString *)hostName
{
    self = [super init];
    
    if (self) {
        self.hostName = hostName;
        self.resultsForTTL = [[NSMutableArray alloc] init];
        self.isCompleted = NO;
        self.elapsedTime = 0.f;
    }
    
    return self;
}

- (void)didReceiveResponseForTTL:(int)ttl fromAddr:(struct sockaddr_in)fromAddr roundTripTime:(double)roundTripTime
{
    NSLog(@"Received ttl : %d / addr(networkorder) : %d / roundTripTime: %.6f", ttl, fromAddr.sin_addr.s_addr, roundTripTime);
}

- (void)didFinishTraceRouteNormally:(BOOL)endFlag elapsedTime:(double)elapsedTime
{
    self.isCompleted = endFlag;
    self.elapsedTime = elapsedTime;
}

@end
