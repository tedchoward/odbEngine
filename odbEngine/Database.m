//
//  Database.m
//  odbEngine
//
//  Created by Ted Howard on 7/11/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import "Database.h"
#import "DatabaseHeader.h"
#import "DatabaseBlock.h"
#import "AvailableBlock.h"
#import "AvailableNodeShadow.h"

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

static UInt64 dbGetEof(NSFileHandle *fileHandle);


@interface Database ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic) NSUInteger availList;
@property (nonatomic) NSUInteger availListBlock;
@property (nonatomic) BOOL dirty;
@property (nonatomic, strong) NSArray *views;
@property (nonatomic) NSInteger headerLength;
@property (nonatomic) NSInteger longVersionMajor;
@property (nonatomic) NSInteger longVersionMinor;
@property (nonatomic) NSInteger version;
@property (nonatomic, strong) NSArray *shadowAvailList;
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
    
    self.views = [ary copy];
    
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

- (NSData *)readBlockAtAddress:(NSUInteger)address {
    if (address == 0) {
        return nil;
    }
    
    [_fileHandle seekToFileOffset:address];
    NSData *headerData = [_fileHandle readDataOfLength:kDatabaseHeaderSize];
    DatabaseHeader *header = [[DatabaseHeader alloc] initWithData:headerData];
    
    NSInteger count = header.size - header.variance;
    
    if (header.free || count < 0) {
        return nil;
    }
    
    NSData *blockData = [_fileHandle readDataOfLength:count];
    return blockData;
}

- (NSUInteger)allocateData:(NSData *)data {
  return -1;
}

- (NSUInteger)assignData:(NSData *)data ofLength:(NSUInteger)length atAddress:(NSUInteger)address {
  NSAssert(address == 0, @"Only new allocation currently implemented");
  
//  if (address == 0) {
    // allocate new address
  
  return 0;
  
//  }
//
//  
//  [_fileHandle seekToFileOffset:address];
//  DatabaseHeader *header = [[DatabaseHeader alloc] initWithData:[_fileHandle readDataOfLength:kDatabaseHeaderSize]];
//  
//  if (header.free) {
//    //ERROR
//    return 0;
//  }
//  
//  if (length > header.size) {
//    
//  }
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
    
    NSData *block = [self readBlockAtAddress:address];
    
    return NO;
}


#pragma mark - ShadowAvailList

- (BOOL)buildAvailableBlockList {
    
    if (_availList != 0) {
        return [self readShadowAvailList];
    }
    
    NSUInteger address = _availList;
    NSMutableArray *blockList = [[NSMutableArray alloc] init];
    NSUInteger eof = dbGetEof(_fileHandle);
    
    while (address != 0) {
        DatabaseBlock *block = [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:address];
        if (!block.free || (block.address + block.size) > eof) {
            [NSException raise:@"ERROR_DB_FREE_LIST" format:NSLocalizedString(@"ERROR_DB_FREE_LIST", @"This database has a damaged free list. Use the Save a Copy command to create a new, compacted database.")];
        }
        
        AvailableBlock *availableBlock = [[AvailableBlock alloc] init];
        availableBlock.address = block.address;
        availableBlock.size = block.size;
        [blockList addObject:availableBlock];
        
        address = [block readNextFreeBlockAddress];
    }
    
    self.shadowAvailList = [blockList copy];
    
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
    
    DatabaseBlock *block = [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:_availListBlock];
    NSData *data = [block readData];
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    
    available_node_shadow_t *diskAvailList = (available_node_shadow_t *)data.bytes;
    for (NSUInteger i = 0, cnt = (data.length / sizeof(available_node_shadow_t)); i < cnt; i++) {
        AvailableBlock *availableBlock = [[AvailableBlock alloc] init];
        availableBlock.address = CFSwapInt32BigToHost(diskAvailList[i].address);
        availableBlock.size = CFSwapInt32BigToHost(diskAvailList[i].size);
        
        [ary addObject:availableBlock];
    }
    
    NSUInteger firstAddress = ((AvailableBlock *)ary.firstObject).address;
    
    // Sanity Check: The first address should match the start of the availList in the header
    if (firstAddress != _availList) {
        [NSException raise:@"ERROR_DB_INCONSISTENT_AVAIL_LIST" format:NSLocalizedString(@"ERROR_DB_INCONSISTENT_AVAIL_LIST", @"This database has an inconsistent list of free blocks. Use the Save a Copy command to create a new, compacted database.")];
    }
    
    // Sanity Check: The first block should be a valid free block
    if (firstAddress != 0) {
        DatabaseBlock *firstBlock = [[DatabaseBlock alloc] initWithFileHandle:_fileHandle address:firstAddress];
        if (!firstBlock.free || (firstBlock.address + firstBlock.size) > eof) {
            [NSException raise:@"ERROR_DB_INCONSISTENT_AVAIL_LIST" format:NSLocalizedString(@"ERROR_DB_INCONSISTENT_AVAIL_LIST", @"This database has an inconsistent list of free blocks. Use the Save a Copy command to create a new, compacted database.")];
        }
    }
    
    self.shadowAvailList = [ary copy];
    
    return YES;
}


- (void)clearShadowAvailList {
    if (!_readOnly) {
        if (_availListBlock != 0) {
            NSUInteger address = _availListBlock;
            self.availListBlock = 0;
            self.dirty = YES;
            [self flushHeader];
        }
    }
}

@end

static UInt64 dbGetEof(NSFileHandle *fileHandle) {
    UInt64 offset = fileHandle.offsetInFile;
    UInt64 eof = [fileHandle seekToEndOfFile];
    [fileHandle seekToFileOffset:offset];
    return eof;
}
