//
//  DatabaseHeader.m
//  odbEngine
//
//  Created by Ted Howard on 7/29/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import "DatabaseHeader.h"

#pragma pack(2)
typedef struct __database_header_t__ {
    struct {
        int32_t size;
    } sizeFreeWord;
    
    int32_t variance;
} database_header_t;
#pragma options align=reset

extern const NSUInteger kDatabaseHeaderSize = sizeof(database_header_t);

@interface DatabaseHeader ()
@property (nonatomic) BOOL free;
@property (nonatomic) NSInteger size;
@property (nonatomic) NSInteger variance;
@end

@implementation DatabaseHeader

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    
    if (self) {
        database_header_t header;
        [data getBytes:&header length:sizeof(database_header_t)];
        
        self.variance = CFSwapInt32BigToHost(header.variance);
        SInt32 size = CFSwapInt32BigToHost(header.sizeFreeWord.size);
        self.free = (size & 0x80000000L) == 0x80000000L;
        self.size = size & 0x7FFFFFFFL;
    }
    
    return self;
}

@end
