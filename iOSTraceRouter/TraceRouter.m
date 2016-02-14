//
//  TraceRouter.m
//  iOSTraceRouter
//
//  Created by ParkSh on 2016. 1. 3..
//  Copyright © 2016년 Songhyun. All rights reserved.
//

#import "TraceRouter.h"
#include <sys/time.h>
#include <arpa/inet.h>

@interface TraceRouter()
{
    int try_cnt;
    int max_ttl;
    int response_timeout_msec;
    int overall_timeout_sec;
    
    CFSocketRef socketRef;
    
    double traceroute_start_time_msec;
    double traceroute_end_time_msec;
}
@property (nonatomic, copy, readwrite) NSData *hostAddress;
@property (nonatomic, strong, readwrite) NSString *hostName;
@property (nonatomic, strong, readwrite) NSString *hostIPString;
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

- (BOOL)canGetHostAddress
{
    CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)self.hostName);
    
    if (hostRef == NULL) {
        //fail
        return NO;
    }
    
    if (CFHostStartInfoResolution(hostRef, kCFHostAddresses, NULL) == NO) {
        // pass an error instead of null to find out why it failed
        return NO;
    }
    
    Boolean result;
    NSArray *addresses = (__bridge NSArray *)CFHostGetAddressing(hostRef, &result);
    
    if (result == NO || addresses == nil) {
        return NO;
    }
    
    result = false;
    for (NSData *address in addresses) {
        const struct sockaddr *addrPtr;
        addrPtr = (struct sockaddr *)[address bytes];
        if ([address length] >= sizeof(struct sockaddr) && addrPtr->sa_family == AF_INET) {
            self.hostAddress = address;
            const struct sockaddr_in *addrPtr_in = (struct sockaddr_in *)[address bytes];
            self.hostIPString = [NSString stringWithCString:inet_ntoa(addrPtr_in->sin_addr) encoding:NSUTF8StringEncoding];
            CFRelease(hostRef);
            return YES;
        }
    }
    CFRelease(hostRef);
    // no matching ipv4 address
    return NO;
}

- (BOOL)canUseSocket
{
    int fd = -1;
    
    const struct sockaddr *addrPtr;
    addrPtr = (const struct sockaddr *)[self.hostAddress bytes];
    
    switch (addrPtr->sa_family) {
        case AF_INET:
            fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
            break;
        case AF_INET6:
            // ipv6 is not supported yet.
        default:
            break;
    }
    
    if (fd < 0) {
        // failed open socket
        return NO;
    }
    
    CFSocketContext socketContext = {0, (__bridge void *)(self), NULL, NULL, NULL};
    // version, info(associated with the CFSocket object when it is created, retain callback, release callback, copyDescription callback
    CFRunLoopSourceRef rls;
    
    socketRef = CFSocketCreateWithNative(NULL, fd, kCFSocketReadCallBack, SocketReadCallback, &socketContext);
    
    if (socketRef == NULL) {
        // fail...
        return NO;
    }
    
    // The socket will now take care of cleaning up our file descriptor.
    rls = CFSocketCreateRunLoopSource(NULL, socketRef, 0);
    if (rls == NULL) {
        //fail..
        return NO;
    }
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
    CFRelease(rls);
    // 여기서 release하는거 맞는지..;
    
    return YES;
}

static void SocketReadCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
// This C routine is called by CFSocket when there's data waiting on our ICMP socket.
// It just redirects the call to Objective-C code.
{
    TraceRouter *traceRouter;
    
    traceRouter = (__bridge TraceRouter *)info;
//    [traceRouter readReceivedData];
}


- (BOOL)canSetReceiveTimeoutSocketOption
{
    struct timeval tv;
    tv.tv_sec = response_timeout_msec / 1000;
    tv.tv_usec = response_timeout_msec % 1000;
    
    int res = setsockopt(CFSocketGetNative(socketRef), SOL_SOCKET, SO_RCVTIMEO, (char *)&tv, sizeof(struct timeval));
    
    return res >= 0;
}

- (void)startTraceRoute
{
    NSLog(@"Start Trace Route!");
    if ([self canGetHostAddress] == NO) {
        return;
    }
    
    NSLog(@"hostAddress : %@", self.hostAddress);
    NSLog(@"hostIPString : %@", self.hostIPString);
    
    if ([self canUseSocket] == NO) {
        NSLog(@"Open Socket Failed");
        return;
    }
    
    if ([self canSetReceiveTimeoutSocketOption] == NO) {
        NSLog(@"SET Option for receive time out failed");
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
