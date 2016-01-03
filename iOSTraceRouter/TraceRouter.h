//
//  TraceRouter.h
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TraceRouterDelegate;

typedef void (^completionBlock)(id<TraceRouterDelegate> *);
typedef void (^failureBlock)(NSError *);

@interface TraceRouter : NSObject
@property (nonatomic, strong) id<TraceRouterDelegate> resultDelegate;

- (instancetype) initWithHostname:(NSString *)hostName
                         tryCount:(int)tryCount
                           maxTTL:(int)maxTTL
          responseTimeoutMilliSec:(int)responseTimeoutMilliSec
                overallTimeoutSec:(int)overallTimeoutSec
                  completionBlock:(completionBlock)completionBlock
                     failureBlock:(failureBlock)failureBlock;
- (void)startTraceRoute;
@end

@protocol TraceRouterDelegate <NSObject>
- (void)didReceiveResponseForTTL:(int)ttl fromAddr:(struct sockaddr_in)fromAddr roundTripTime:(double)roundTripTime;
- (void)didFinishTraceRouteNormally:(BOOL)endFlag elapsedTime:(double)elapsedTime;
@end