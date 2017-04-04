//
//  Database.m
//  odbEngine
//
//  Created by Ted Howard on 7/11/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import "Database.h"
#import "DatabaseHeader.h"
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
    uint32_t availList;
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

- (bool)readShadowAvailList {
    UInt64 eof = dbGetEof(_fileHandle);
    if (eof == -1) {
        return NO;
    }
    
    if (_availListBlock == 0) {
        return NO;
    }
    
    NSData *data = [self readBlockAtAddress:_availListBlock];
    if (data == nil) {
        return NO;
    }
    
    NSMutableArray *ary = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0, cnt = (data.length / kAvailableNodeShadowSize); i < cnt; i++) {
        NSData *subData = [data subdataWithRange:NSMakeRange((i + kAvailableNodeShadowSize), kAvailableNodeShadowSize)];
        [ary addObject:[[AvailableNodeShadow alloc] initWithData:subData]];
    }
    
    if (((AvailableNodeShadow *)ary[0]).address != _availListBlock) {
        // error
        return NO;
    }
    
    if (((AvailableNodeShadow *)ary[0]).address != 0) {
        
    }
    
    
    return NO;
}

@end

static UInt64 dbGetEof(NSFileHandle *fileHandle) {
    UInt64 offset = fileHandle.offsetInFile;
    UInt64 eof = [fileHandle seekToEndOfFile];
    [fileHandle seekToFileOffset:offset];
    return eof;
}
