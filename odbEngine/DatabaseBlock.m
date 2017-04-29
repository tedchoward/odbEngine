//
//  DatabaseBlock.m
//  odbEngine
//
//  Created by Ted Howard on 4/6/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "DatabaseBlock.h"
#import "Database.h"
#import "DatabaseBlock+Internal.h"

#include "Utils.h"

#pragma pack(2)
typedef struct __database_header_t__ {
    uint32_t size;
    uint32_t variance;
} database_header_t;

typedef struct __database_trailer_t__ {
    uint32_t size;
} database_trailer_t;
#pragma options align=reset

const size_t kDatabaseHeaderSize = sizeof(database_header_t);
const size_t kDatabaseTrailerSize = sizeof(database_trailer_t);


@interface DatabaseBlock () {
    UInt32 _address;
    BOOL _free;
    UInt32 _size;
    UInt32 _variance;
    NSFileHandle *_fileHandle;
}

@property (nonatomic) BOOL headerParsed;

@end

@implementation DatabaseBlock

#pragma mark - Internal Methods

- (void)setAddress:(UInt32)address {
    _address = address;
}

- (void)setFree:(BOOL)free {
    _free = free;
}

- (void)setSize:(UInt32)size {
    _size = size;
}

- (void)setVariance:(UInt32)variance {
    _variance = variance;
}

- (NSFileHandle *)fileHandle {
    return _fileHandle;
}

- (void)setFileHandle:(NSFileHandle *)fileHandle {
    _fileHandle = fileHandle;
}

- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length {
    [_fileHandle seekToFileOffset:offset];
    return [_fileHandle readDataOfLength:length];
}

- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset {
    [_fileHandle seekToFileOffset:offset];
    [_fileHandle writeData:data];
}

- (UInt32)dataOffset {
    return _address + kDatabaseHeaderSize;
}

- (void)parseHeader {
    if (_headerParsed) {
        return;
    }
    
    NSData *data = [self readDataAtOffset:_address length:kDatabaseHeaderSize];
    database_header_t *header = (database_header_t *)data.bytes;
    
    self.variance = CFSwapInt32BigToHost(header->variance);
    UInt32 size = CFSwapInt32BigToHost(header->size);
    self.free = (size & 0x80000000L) == 0x80000000L;
    self.size = size & 0x7FFFFFFFL;
    self.headerParsed = YES;
}


#pragma mark - public methods

- (UInt32)address {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    return _address;
}

- (BOOL)free {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    return _free;
}

- (UInt32)size {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    return _size;
}

- (UInt32)variance {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    return _variance;
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle address:(UInt32)address {
    self = [super init];
    
    if (self) {
        self.headerParsed = NO;
        self.address = address;
        [self setFileHandle:fileHandle];
        
//        [self parseHeader];
    }
    
    return self;
}


- (NSData *)readData {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    return [self readDataAtOffset:[self dataOffset] length:(_size - _variance)];
}


- (void)writeData:(NSData *)data {
    NSAssert(data.length <= _size, @"data.length <= _size");
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    self.free = NO;
    self.variance = _size - (UInt32) data.length;
    
    [self writeData:data atOffset:_address + kDatabaseHeaderSize];
    
    [self writeHeader];
    [self writeTrailer];
}

#pragma mark - Private methods

- (DatabaseBlock *)readBlockToTheLeft {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    NSData *leftTrailerData = [self readDataAtOffset:_address - kDatabaseTrailerSize length:kDatabaseTrailerSize];
    database_trailer_t *leftTrailer = (database_trailer_t *)leftTrailerData.bytes;
    
    UInt32 leftTrailerSize = CFSwapInt32BigToHost(leftTrailer->size);
    UInt32 leftSize = leftTrailerSize & 0x7FFFFFFFL;
    UInt32 leftAddress = _address - kDatabaseTrailerSize - leftSize - kDatabaseHeaderSize;
    
    DatabaseBlock *left = [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:leftAddress];
    
    return left;
}

- (DatabaseBlock *)readBlockToTheRight {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    UInt32 rightAddress = _address + kDatabaseHeaderSize + _size + kDatabaseTrailerSize;
    return [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:rightAddress];
}


- (void)writeHeader {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    database_header_t header;
    UInt32 size = _size;
    
    if (_free) {
        size |= 0x80000000L;
    }
    
    header.size = CFSwapInt32HostToBig(size);
    header.variance = CFSwapInt32HostToBig(_variance);
    
    NSData *data = [NSData dataWithBytes:&header length:kDatabaseHeaderSize];
    [self writeData:data atOffset:_address];
}

- (void)writeTrailer {
    if (!_headerParsed) {
        [self parseHeader];
    }
    
    database_trailer_t trailer;
    UInt32 size = _size;
    
    if (_free) {
        size |= 0x80000000L;
    }
    
    trailer.size = CFSwapInt32HostToBig(size);
    NSData *data = [NSData dataWithBytes:&trailer length:kDatabaseTrailerSize];
    [self writeData:data atOffset:(_address + kDatabaseHeaderSize + _size)];
}

@end


// TODO: move to Database class
//@implementation DatabaseBlock (release)
//
//- (void)releaseBlock {
//    BOOL mergedRight = [self mergeRight];
//    BOOL mergedLeft = [self mergeLeft];
//    
//    if (mergedRight || mergedLeft) {
//        return;
//    }
//    
//    // No merging
//    // Mark the block as free
//    self.free = YES;
//    [self writeHeader];
//    [self writeTrailer];
//    
//    // Insert block at the front of the linked-list and in-memory array
//    [self writeNextFreeBlockAddress:_database.availList];
//    _database.availList = _address;
//    [_database insertAvailableBlock:[AvailableBlock availableBlockWithAddress:_address size:_size] atIndex:0];
//    
//    _database.dirty = YES;
//    [_database flushHeader];
//}
//
///**
// * Take a previously in-use block and merge it with the block immediately to the
// * right of it (if the right block is free) making the merged block free
// */
//- (BOOL)mergeRight {
//    UInt32 rightBlockAddress = _address + kDatabaseHeaderSize + _size + kDatabaseTrailerSize;
//    UInt64 eof = dbGetEof(_fileHandle);
//    
//    if (rightBlockAddress == eof) {
//        /* There is no block to the right */
//        return NO;
//    }
//    
//    if (rightBlockAddress > eof) {
//        /* reached the end of the file */
//        [NSException raise:@"ERROR_DB_MERGE_INVALID_BLOCK" format:@"Internal database error: attempted to merge with an invalid block."];
//    }
//    
//    DatabaseBlock *rightBlock = [[DatabaseBlock alloc] initWithDatabase:_database fileHandle:_fileHandle address:rightBlockAddress];
//    
//    if (rightBlock.size < MIN_BLOCK_SIZE) {
//        [NSException raise:@"ERROR_DB_MERGE_INVALID_BLOCK" format:@"Internal database error: attempted to merge with an invalid block."];
//    }
//    
//    if (!rightBlock.free) {
//        /* the block to the right is in use */
//        return NO;
//    }
//    
//    AvailableBlock *previousAvailableBlock = [_database findPreviousAvailableBlockOfBlock:rightBlock];
//    if (previousAvailableBlock == nil) {
//        return NO;
//    }
//    
//    /**
//     * Available nodes are a linked-list
//     * - Find the node that stores the address for the `rightBlock`
//     * - Write the address of the current block at that node
//     */
//    DatabaseBlock *prevBlock = [[DatabaseBlock alloc] initWithDatabase:_database fileHandle:_fileHandle address:previousAvailableBlock.address];
//    [prevBlock writeNextFreeBlockAddress:_address];
//    
//    /* Calculate the new merged size */
//    self.size += rightBlock.size + kDatabaseHeaderSize + kDatabaseTrailerSize;
//    self.free = YES;
//    
//    [self writeHeader];
//    [self writeNextFreeBlockAddress:[rightBlock readNextFreeBlockAddress]];
//    [self writeTrailer];
//    
//    [_database setAvailableBlock:[AvailableBlock availableBlockWithAddress:_address size:_size] atIndex:previousAvailableBlock.index + 1];
//    
//    self.availListIndex = previousAvailableBlock.index + 1;
//    
//    return YES;
//}
//
//- (BOOL)mergeLeft {
//    if (_address == FIRST_PHYSICAL_ADDRESS) {
//        return NO;
//    }
//    
//    if (_address < FIRST_PHYSICAL_ADDRESS) {
//        [NSException raise:@"ERROR_DB_MERGE_INVALID_BLOCK" format:@"Internal database error: attempted to merge with an invalid block."];
//    }
//    
//    DatabaseBlock *leftBlock = [self readBlockToTheLeft];
//    if (leftBlock.size < MIN_BLOCK_SIZE) {
//        [NSException raise:@"ERROR_DB_MERGE_INVALID_BLOCK" format:@"Internal database error: attempted to merge with an invalid block."];
//    }
//    
//    if (!leftBlock.free) {
//        return NO;
//    }
//    
//    AvailableBlock *availBlock = [_database findPreviousAvailableBlockOfBlock:self];
//    NSAssert(availBlock.address != leftBlock.address, @"availBlock.address != leftBlock.address");
//    leftBlock.availListIndex = availBlock.index;
//    
//    if (_availListIndex != -1) {
//        /* The current block is on the AvailList. We need to remove it from both
//         * the linked-list and `_database`'s in-memory array.
//         */
//        
//        [leftBlock writeNextFreeBlockAddress:[self readNextFreeBlockAddress]];
//        
//        [_database removeAvailaleBlockAtIndex:_availListIndex];
//    }
//    
//    /* calculate the new merged size and write header and trailer */
//    self.size += leftBlock.size + kDatabaseHeaderSize + kDatabaseTrailerSize;
//    self.address = leftBlock.address;
//    self.free = YES;
//    
//    [self writeHeader];
//    [self writeTrailer];
//    
//    /* update the AvailableBlock record to reflect the new size */
//    [_database setAvailableBlock:[AvailableBlock availableBlockWithAddress:_address size:_size] atIndex:leftBlock.availListIndex];
//    
//    return YES;
//}
//
//@end
