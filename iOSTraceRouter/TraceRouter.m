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

struct ICMPHeader {
    uint8_t     type;
    uint8_t     code;
    uint16_t    checksum;
    uint16_t    identifier;
    uint16_t    sequenceNumber;
    // data...
};
typedef struct ICMPHeader ICMPHeader;

enum {
    kICMPTypeEchoReply   = 0,           // code is always 0
    kICMPTypeEchoRequest = 8,            // code is always 0
    kICMPTypeTimeExceed = 11            // code is 0 for "TTL expired in transit"
};

struct IPHeader {
    uint8_t     versionAndHeaderLength;
    uint8_t     differentiatedServices;
    uint16_t    totalLength;
    uint16_t    identification;
    uint16_t    flagsAndFragmentOffset;
    uint8_t     timeToLive;
    uint8_t     protocol;
    uint16_t    headerChecksum;
    uint8_t     sourceAddress[4];
    uint8_t     destinationAddress[4];
    // options...
    // data...
};
typedef struct IPHeader IPHeader;

static uint16_t in_cksum(const void *buffer, size_t bufferLen)
// This is the standard BSD checksum code, modified to use modern types.
{
    size_t              bytesLeft;
    int32_t             sum;
    const uint16_t *    cursor;
    union {
        uint16_t        us;
        uint8_t         uc[2];
    } last;
    uint16_t            answer;
    
    bytesLeft = bufferLen;
    sum = 0;
    cursor = buffer;
    
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (bytesLeft > 1) {
        sum += *cursor;
        cursor += 1;
        bytesLeft -= 2;
    }
    
    /* mop up an odd byte, if necessary */
    if (bytesLeft == 1) {
        last.uc[0] = * (const uint8_t *) cursor;
        last.uc[1] = 0;
        sum += last.us;
    }
    
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff); /* add hi 16 to low 16 */
    sum += (sum >> 16);         /* add carry */
    answer = (uint16_t) ~sum;   /* truncate to 16 bits */
    
    return answer;
}


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

@property (nonatomic, assign, readwrite) uint16_t sequenceNumber;

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

- (void)didFailWithErrorCode:(NSUInteger)errorCode reason:(NSString *)reason description:(NSDictionary *)description
{
    NSLog(@"didFailWithErrorCode : %d, reason : %@, description: %@", errorCode, reason, description);
    // handle error with error code
    
    // clean up tracerouter object
    if (socketRef) {
        CFSocketInvalidate(socketRef);
        CFRelease(socketRef);
        socketRef = nil;
    }
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
        [self didFailWithErrorCode:0 reason:@"Run Loop Source for Socket is NULL" description:nil];
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
    [traceRouter readReceivedData];
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
        [self didFailWithErrorCode:0 reason:@"Open Socket Failed" description:nil];
        return;
    }
    
    if ([self canSetReceiveTimeoutSocketOption] == NO) {
        NSLog(@"SET Option for receive time out failed");
        [self didFailWithErrorCode:0 reason:@"SET option for receive time out failed" description:nil];
        return;
    }
    
    traceroute_start_time_msec = [[self class] currentTimeMillis];
    traceroute_end_time_msec = traceroute_start_time_msec + (overall_timeout_sec * 1000);
    
    // must register current thread to run loop
    
    [self sendICMPPacket];
}

- (void)sendICMPPacket
{
    NSData *payload;
    NSMutableData *icmpPacket;
    ICMPHeader *icmpHeaderPtr;
    ssize_t bytesSent;
    
    payload = [[NSString stringWithFormat:@"%44zd", 0] dataUsingEncoding:NSASCIIStringEncoding];
    icmpPacket = [NSMutableData dataWithLength:sizeof(*icmpHeaderPtr) + [payload length]];
    
    icmpHeaderPtr = [icmpPacket mutableBytes];
    icmpHeaderPtr->type = kICMPTypeEchoRequest;
    icmpHeaderPtr->code = 0;
    icmpHeaderPtr->identifier = OSSwapHostToBigInt16(self.identifier);
    icmpHeaderPtr->sequenceNumber = OSSwapHostToBigInt16(self.sequenceNumber);
    icmpHeaderPtr->checksum = 0;
    memcpy(&icmpHeaderPtr[1], [payload bytes], [payload length]);
    
    // The IP checksum returns a 16-bit number that's already in correct byte order
    // (due to wacky 1's complement maths), so we just put it into the packet as a 16-bit unit.
    icmpHeaderPtr->checksum = in_cksum([icmpPacket bytes], [icmpPacket length]);
    
    if (socketRef != NULL) {
        NSLog(@"icmpPacket bytes:\n%@", icmpPacket);
        bytesSent = sendto(CFSocketGetNative(socketRef),
                           [icmpPacket bytes],
                           [icmpPacket length],
                           0,
                           (struct sockaddr *)[self.hostAddress bytes],
                           (socklen_t)[self.hostAddress length]
                           );
    } else {
        bytesSent = -1;
    }
    
    if (bytesSent != [icmpPacket length]) {
        NSLog(@"Byte Sent error");
        [self didFailWithErrorCode:0 reason:@"Byte Sent error" description:nil];
        return;
    }
}

- (void)readReceivedData
{
    struct sockaddr_in recvAddr;
    socklen_t recvAddrLen;
    ssize_t bytesRead;
    void *buffer;
    enum { kBufferSize = 256 };
    // 65535 is the maximum IP Packet size, which seems like a reasonable bound
    
    buffer = malloc(kBufferSize);
    recvAddrLen = sizeof(recvAddr);
    
    bytesRead = recvfrom(CFSocketGetNative(socketRef), buffer, kBufferSize, 0, (struct sockaddr *)&recvAddr, &recvAddrLen);
    
    if (bytesRead > 0) {
        NSMutableData *recvPacket = [NSMutableData dataWithBytes:buffer length:(NSUInteger)bytesRead];
        NSLog(@"recvPacket:\n%@", recvPacket);
        
        CFSocketInvalidate(socketRef);
        CFRelease(socketRef);
        
    }
}

#pragma mark - Utility Functions
+ (double)currentTimeMillis
{
    struct timeval t;
    gettimeofday(&t, NULL);
    
    return (t.tv_sec * 1000) + (t.tv_usec / 1000);
}
@end
