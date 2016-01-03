//
//  TraceRouteResult.h
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TraceRouter.h"

#define kHostName @"HostName"
#define kRoundTripTime @"RoundTripTime"

@interface TraceRouteResult : NSObject<TraceRouterDelegate>
@property (strong, nonatomic, readonly) NSString *hostName;
@property (strong, nonatomic, readonly) NSString *hostIPAddr;
@property (strong, nonatomic, readonly) NSMutableArray *resultsForTTL;
// TTL IP DomainName RoundTripTime

@property (assign, nonatomic, readonly) BOOL isCompleted;
@property (assign, nonatomic, readonly) double elapsedTime;

- (instancetype) initWithHostname:(NSString *)hostName;
@end
