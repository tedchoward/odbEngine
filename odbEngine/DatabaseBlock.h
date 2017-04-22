//
//  DatabaseBlock.h
//  odbEngine
//
//  Created by Ted Howard on 4/6/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DatabaseBlock : NSObject
@property (readonly) NSUInteger address;
@property (readonly) BOOL free;
@property (readonly) NSUInteger size;
@property (readonly) NSUInteger variance; // number of unused bytes in the block

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle address:(NSUInteger)address;

- (NSData *)readData;
- (NSUInteger)readNextFreeBlockAddress;
@end
