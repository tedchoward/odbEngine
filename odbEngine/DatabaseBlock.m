//
//  DatabaseBlock.m
//  odbEngine
//
//  Created by Ted Howard on 4/6/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "DatabaseBlock.h"

#pragma pack(2)
typedef struct __database_header_t__ {
    uint32_t size;
    uint32_t variance;
} database_header_t;

typedef struct __database_trailer_t__ {
    uint32_t size;
} database_trailer_t;
#pragma options align=reset

static NSData *dbRead(NSFileHandle *handle, NSUInteger offset, NSUInteger length);


@interface DatabaseBlock ()
@property (nonatomic) NSUInteger address;
@property (nonatomic) BOOL free;
@property (nonatomic) NSUInteger size;
@property (nonatomic) NSUInteger variance; // number of unused bytes in the block
@property (nonatomic, strong) NSFileHandle *fileHandle;

@property (readonly) NSUInteger dataOffset;
@end

@implementation DatabaseBlock

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle address:(NSUInteger)address {
    self = [super init];
    
    if (self) {
        self.address = address;
        self.fileHandle = fileHandle;
        
        database_header_t header;
        NSData *data = [_fileHandle readDataOfLength:sizeof(database_header_t)];
        [data getBytes:&header length:sizeof(database_header_t)];
        
        self.variance = CFSwapInt32BigToHost(header.variance);
        UInt32 size = CFSwapInt32BigToHost(header.size);
        self.free = (size & 0x80000000L) == 0x80000000L;
        self.size = size & 0x7FFFFFFFL;
    }
    
    return self;
}

- (NSUInteger)dataOffset {
    return _address + sizeof(database_header_t);
}

- (NSData *)readData {
    return dbRead(_fileHandle, self.dataOffset, _size - _variance);
}

- (NSUInteger) readNextFreeBlockAddress {
    if (!_free) {
        return 0;
    }
    
    NSData *data = dbRead(_fileHandle, self.dataOffset, sizeof(uint32_t));
    
    uint32_t address;
    [data getBytes:&address length:sizeof(uint32_t)];
    
    return CFSwapInt32BigToHost(address);
}

NSData *dbRead(NSFileHandle *handle, NSUInteger offset, NSUInteger length) {
    NSUInteger originalOffset = handle.offsetInFile;
    [handle seekToFileOffset:offset];
    NSData *data = [handle readDataOfLength:length];
    [handle seekToFileOffset:originalOffset];
    return data;
}

@end
