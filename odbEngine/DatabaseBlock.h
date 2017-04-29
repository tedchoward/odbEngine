//
//  DatabaseBlock.h
//  odbEngine
//
//  Created by Ted Howard on 4/6/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MIN_BLOCK_SIZE 32L
#define FIRST_PHYSICAL_ADDRESS 88L

extern const size_t kDatabaseHeaderSize;
extern const size_t kDatabaseTrailerSize;

@class Database;

@interface DatabaseBlock : NSObject
@property (readonly) UInt32 address;
@property (readonly) BOOL free;
@property (readonly) UInt32 size;
@property (readonly) UInt32 variance; // number of unused bytes in the block

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle address:(UInt32)address;

- (NSData *)readData;
- (void)writeData:(NSData *)data;
@end
