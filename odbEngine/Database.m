//
//  Database.m
//  odbEngine
//
//  Created by Ted Howard on 7/11/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#include "Utils.h"

#import "Database.h"
#import "DatabaseBlock.h"
#import "AvailableDatabaseBlock.h"

#define DATABASE_HEADER_LENGTH 88

#define DB_CURRENT_VERSION 6
#define DB_FIRST_VERSION_WITH_CACHED_SHADOW_AVAIL_LIST 6

#define majorVersion(v) (v & 0x0f0)
#define minorVersion(v) (v & 0x00f)

#define setDirty(fileHeader) (fileHeader.flags |= 0x0001)
#define clearDirty(fileHeader) (fileHeader.flags &= ~0x0001)
#define isDirty(fileHeader) (fileHeader.flags & 0x0001)


#pragma pack(2)
typedef struct __database_file_header_t__ {
    uint8_t systemId;
    uint8_t versionNumber;
    uint32_t availList; // the address of the first available block
    int16_t oldFileDescriptor;
    int16_t flags;
    uint32_t views[3];
    
    int32_t releaseStack; // was `Handle`
    
    int32_t databaseFileDescriptor;
    int32_t headerLength;
    int16_t longVersionMajor;
    int16_t longVersionMinor;
    
    union {
        uint8_t growthSpace[50];
        
        struct {
            uint32_t availListBlock;
            // ODBMemoryStreamRef availListShadow;
            // handlestream availlistshadow;
            // boolean flreadonlyl;
        } extensions;
    } u;
    
} database_file_header_t;

typedef struct __available_node_shadow_t__ {
    uint32_t address;
    uint32_t size;
} available_node_shadow_t;
#pragma options align=reset

@interface Database ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic) UInt32 availListBlock;
@property (nonatomic, strong) NSArray *views;
@property (nonatomic) SInt32 headerLength;
@property (nonatomic) SInt16 longVersionMajor;
@property (nonatomic) SInt16 longVersionMinor;
@property (nonatomic) UInt8 version;
@property (nonatomic, strong) NSMutableArray *shadowAvailList;
@property (nonatomic) BOOL readOnly;
@end

@implementation Database

+ (Database *)newDatabaseWithFileHandle:(NSFileHandle *)fileHandle {
  database_file_header_t fileHeader;
  memset(&fileHeader, 0, sizeof(fileHeader));
  
  fileHeader.systemId = 0;
  fileHeader.versionNumber = DB_CURRENT_VERSION;
  fileHeader.headerLength = CFSwapInt32HostToBig(DATABASE_HEADER_LENGTH);
  fileHeader.longVersionMajor = CFSwapInt16HostToBig(DB_CURRENT_VERSION);
  fileHeader.longVersionMinor = CFSwapInt16HostToBig(0);
  
  NSData *headerData = [NSData dataWithBytes:&fileHeader length:sizeof(fileHeader)];
  [fileHandle writeData:headerData];
  [fileHandle synchronizeFile];
  
  return [[Database alloc] initWithFileHandle:fileHandle readOnly:NO];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle readOnly:(BOOL)readOnly {
    self = [super init];
    
    if (self) {
        self.fileHandle = fileHandle;
        self.readOnly = readOnly;
        NSData *data = [fileHandle readDataOfLength:DATABASE_HEADER_LENGTH];
        [self parseHeaderData:data];
    }
    
    return self;
}

- (void)parseHeaderData:(NSData *)data {
    NSAssert(data.length == 88, @"data.length == 88");
    
    database_file_header_t diskHeader;
    [data getBytes:&diskHeader length:sizeof(database_file_header_t)];
    
    self.availList = CFSwapInt32BigToHost(diskHeader.availList);
    self.availListBlock = CFSwapInt32BigToHost(diskHeader.u.extensions.availListBlock);
    UInt16 flags = CFSwapInt16BigToHost(diskHeader.flags);
    self.dirty = flags & 0x001;
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    for (int i = 0, cnt = 3; i < cnt; i++) {
        [ary addObject:@(CFSwapInt32BigToHost(diskHeader.views[i]))];
    }
    
    self.views = ary;
    
    self.headerLength = CFSwapInt32BigToHost(diskHeader.headerLength);
    self.longVersionMajor = CFSwapInt16BigToHost(diskHeader.longVersionMajor);
    self.longVersionMinor = CFSwapInt16BigToHost(diskHeader.longVersionMinor);
    self.version = diskHeader.versionNumber;
    
    if (diskHeader.versionNumber != DB_CURRENT_VERSION) {
        if (majorVersion(diskHeader.versionNumber) != majorVersion(DB_CURRENT_VERSION)) {
            // error
            return;
        }
        
        if (diskHeader.versionNumber < DB_FIRST_VERSION_WITH_CACHED_SHADOW_AVAIL_LIST) {
            self.availListBlock = 0;
        }
        
        self.version = DB_CURRENT_VERSION;
        self.dirty = YES;
    }
    
    [self buildAvailableBlockList];
}

- (DatabaseBlock *)readBlockAtAddress:(UInt32)address {
    DatabaseBlock *block = [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:address];
    
    if (block.free) {
        return [[AvailableDatabaseBlock alloc] initWithFileHandle:_fileHandle address:address];
    }
    
    return block;
}

- (AvailableDatabaseBlock *)availableBlockAtIndex:(NSUInteger)index {
    return _shadowAvailList[index];
}

- (AvailableDatabaseBlock *)findPreviousAvailableBlockOfBlock:(AvailableDatabaseBlock *)currentBlock {
    
    for (NSUInteger i = 0, cnt = _shadowAvailList.count; i < cnt; i++) {
        AvailableDatabaseBlock *block = _shadowAvailList[i];
        if (block.address == currentBlock.address) {
            if (i > 0) {
                return _shadowAvailList[i - 1];
            } else {
                return nil;
            }
        }
    }
    
    [NSException raise:@"ERROR_DB_FREE_LIST" format:@"This database has a damaged free list. Use the Save a Copy command to create a new, compacted database."];
    
    return nil;
}

- (void)setAvailableBlock:(AvailableDatabaseBlock *)availableBlock atIndex:(NSUInteger)index {
    _shadowAvailList[index] = availableBlock;
    availableBlock.index = index;
}

- (void)insertAvailableBlock:(AvailableDatabaseBlock *)availableBlock atIndex:(NSUInteger)index {
    [_shadowAvailList insertObject:availableBlock atIndex:index];
}

- (void)removeAvailaleBlockAtIndex:(NSUInteger)index {
    AvailableDatabaseBlock *block = _shadowAvailList[index];
    block.index = -1;
    [_shadowAvailList removeObjectAtIndex:index];
}

- (UInt32)allocateData:(NSData *)data {
    
    NSUInteger smallestAcceptableBlockSize = MAX(data.length, MIN_BLOCK_SIZE);
    
    for (AvailableDatabaseBlock *availableBlock in _shadowAvailList) {
        if (availableBlock.cachedSize >= smallestAcceptableBlockSize) {
            // We found our block!
            UInt32 variance = availableBlock.size - (UInt32) data.length;
            if (variance >= MIN_BLOCK_SIZE + kDatabaseHeaderSize + kDatabaseTrailerSize) {
                // We have enough left over to be it's own block
                //TODO: [block splitBlockAtAddress:availableBlock.address + (UInt32) data.length];
            }
            
            BOOL blockIsInAvailList = availableBlock.free;
            [availableBlock writeData:data];
            
            if (blockIsInAvailList) {
                // remove from avail list
            }
            
            return availableBlock.address;
        }
    }
    
    // If we get here, there are no available blocks that are big enough.
    // We need to allocate a new block at the end of the file
    
    //TODO: do this
    
    return -1;
}

- (UInt32)assignData:(NSData *)data atAddress:(UInt32)address {
    return address;
}

- (BOOL)flushHeader {
    if (_dirty) {
        self.dirty = NO;
        
        database_file_header_t diskHeader;
        memset(&diskHeader, 0, sizeof(diskHeader));
        diskHeader.availList = CFSwapInt32HostToBig((uint32_t) _availList);
        diskHeader.u.extensions.availListBlock = CFSwapInt32HostToBig((uint32_t) _availListBlock);
        
        for (NSUInteger i = 0, cnt = _views.count; i < cnt; i++) {
            diskHeader.views[i] = CFSwapInt32HostToBig((uint32_t) [_views[i] unsignedIntegerValue]);
        }
        
        diskHeader.headerLength = CFSwapInt32HostToBig((int32_t) _headerLength);
        diskHeader.longVersionMajor = CFSwapInt16HostToBig((int16_t) _longVersionMajor);
        diskHeader.longVersionMinor = CFSwapInt16HostToBig((int16_t) _longVersionMinor);
        diskHeader.versionNumber = _version;
        
        [_fileHandle writeData:[NSData dataWithBytes:&diskHeader length:sizeof(diskHeader)]];
        [_fileHandle synchronizeFile];
    }
    
    return YES;
}

- (BOOL)releaseBlock:(NSUInteger)address {
    if (address == 0) {
        return YES;
    }
    
    [self clearShadowAvailList];
    
//    NSData *block = [self readBlockAtAddress:address];
    
    return NO;
}


#pragma mark - ShadowAvailList

- (BOOL)buildAvailableBlockList {
    
    if (_availList != 0) {
        return [self readShadowAvailList];
    }
    
    UInt32 address = _availList;
    NSMutableArray *blockList = [[NSMutableArray alloc] init];
    UInt64 eof = dbGetEof(_fileHandle);
    NSUInteger index = 0;
    
    while (address != 0) {
        AvailableDatabaseBlock *block = (AvailableDatabaseBlock *) [self readBlockAtAddress:address];
        if (!block.free || (block.address + block.size) > eof) {
            [NSException raise:@"ERROR_DB_FREE_LIST" format:NSLocalizedString(@"ERROR_DB_FREE_LIST", @"This database has a damaged free list. Use the Save a Copy command to create a new, compacted database.")];
        }
        
        block.index = index;
        block.cachedSize = block.size;
        
        [blockList addObject:block];
        
        address = [block readNextFreeBlockAddress];
        index += 1;
    }
    
    self.shadowAvailList = blockList;
    
    return YES;
}

- (BOOL)readShadowAvailList {
    UInt64 eof = dbGetEof(_fileHandle);
    if (eof == -1) {
        return NO;
    }
    
    if (_availListBlock == 0) {
        return NO;
    }
    
    DatabaseBlock *block = [self readBlockAtAddress:_availListBlock];
    NSData *data = [block readData];
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    
    available_node_shadow_t *diskAvailList = (available_node_shadow_t *)data.bytes;
    for (NSUInteger i = 0, cnt = (data.length / sizeof(available_node_shadow_t)); i < cnt; i++) {
        UInt32 address = CFSwapInt32BigToHost(diskAvailList[i].address);
        AvailableDatabaseBlock *availableBlock = [[AvailableDatabaseBlock alloc] initWithFileHandle:_fileHandle address:address];
        availableBlock.cachedSize = CFSwapInt32BigToHost(diskAvailList[i].size);
        availableBlock.index = i;
        [ary addObject:availableBlock];
    }
    
    UInt32 firstAddress = ((AvailableDatabaseBlock *)ary.firstObject).address;
    
    // Sanity Check: The first address should match the start of the availList in the header
    if (firstAddress != _availList) {
        [NSException raise:@"ERROR_DB_INCONSISTENT_AVAIL_LIST" format:NSLocalizedString(@"ERROR_DB_INCONSISTENT_AVAIL_LIST", @"This database has an inconsistent list of free blocks. Use the Save a Copy command to create a new, compacted database.")];
    }
    
    // Sanity Check: The first block should be a valid free block
    if (firstAddress != 0) {
        AvailableDatabaseBlock * firstBlock = (AvailableDatabaseBlock *)ary.firstObject;
        if (!firstBlock.free || (firstBlock.address + firstBlock.size) > eof) {
            [NSException raise:@"ERROR_DB_INCONSISTENT_AVAIL_LIST" format:NSLocalizedString(@"ERROR_DB_INCONSISTENT_AVAIL_LIST", @"This database has an inconsistent list of free blocks. Use the Save a Copy command to create a new, compacted database.")];
        }
    }
    
    self.shadowAvailList = ary;
    
    return YES;
}


- (void)clearShadowAvailList {
    if (!_readOnly) {
        if (_availListBlock != 0) {
            UInt32 address = _availListBlock;
            self.availListBlock = 0;
            self.dirty = YES;
            [self flushHeader];
        }
    }
}

@end
