//
//  DatabaseBlock+Internal.h
//  odbEngine
//
//  Created by Ted Howard on 4/29/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "DatabaseBlock.h"

@interface DatabaseBlock (Internal)
//@property (nonatomic) UInt32 address;
//@property (nonatomic) BOOL free;
//@property (nonatomic) UInt32 size;
//@property (nonatomic) UInt32 variance; // number of unused bytes in the block
//@property (nonatomic, strong) NSFileHandle *fileHandle;
//@property (nonatomic, weak) Database *database;
//
//@property (readonly) NSUInteger dataOffset;
//@property (nonatomic) NSInteger availListIndex;

- (void)setAddress:(UInt32)address;
- (void)setFree:(BOOL)free;
- (void)setSize:(UInt32)size;
- (void)setVariance:(UInt32)variance;

- (NSFileHandle *)fileHandle;
- (void)setFileHandle:(NSFileHandle *)fileHandle;

- (Database *)database;
- (void)setDatabase:(Database *)database;

- (UInt32)dataOffset;


- (NSData *)readDataAtOffset:(NSUInteger)offset length:(NSUInteger)length;
- (void)writeData:(NSData *)data atOffset:(NSUInteger)offset;

- (void)parseHeader;

@end
