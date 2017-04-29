//
//  AvailableDatabaseBlock.h
//  odbEngine
//
//  Created by Ted Howard on 4/29/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "DatabaseBlock.h"

@interface AvailableDatabaseBlock : DatabaseBlock
@property (nonatomic) NSUInteger index;
@property (nonatomic) UInt32 cachedSize;

//- (DatabaseBlock *)splitBlockAtAddress:(UInt32)address;
- (UInt32)readNextFreeBlockAddress;
- (void)writeNextFreeBlockAddress:(UInt32)nextFreeBlockAddress;
@end
