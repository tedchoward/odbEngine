//
//  AvailableDatabaseBlock.m
//  odbEngine
//
//  Created by Ted Howard on 4/29/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "AvailableDatabaseBlock.h"
#import "DatabaseBlock+Internal.h"

@implementation AvailableDatabaseBlock

- (UInt32) readNextFreeBlockAddress {
    if (!self.free) {
        return 0;
    }
    
    NSData *data = [self readDataAtOffset:[self dataOffset] length:sizeof(uint32_t)];
    
    uint32_t address;
    [data getBytes:&address length:sizeof(uint32_t)];
    
    return CFSwapInt32BigToHost(address);
}

- (void)writeNextFreeBlockAddress:(UInt32)nextFreeBlockAddress {
    UInt32 address = CFSwapInt32HostToBig(nextFreeBlockAddress);
    NSData *data = [NSData dataWithBytes:&address length:sizeof(UInt32)];
    
    [self writeData:data atOffset:self.address + kDatabaseHeaderSize];
}


//TODO: Move to Database class
//- (DatabaseBlock *)splitBlockAtAddress:(UInt32)address {
//    DatabaseBlock *newBlock = [[DatabaseBlock alloc] initWithDatabase:[self database] fileHandle:[self fileHandle] address:address];
//    
//    UInt32 nextFreeBlockAddress = [self readNextFreeBlockAddress];
//    newBlock.free = YES;
//    newBlock.variance = 0;
//    [newBlock setSize:(self.size - (address - self.address) - (UInt32) (kDatabaseHeaderSize + kDatabaseTrailerSize))];
//    
//    [newBlock writeHeader];
//    [newBlock writeTrailer];
//    [newBlock writeNextFreeBlockAddress:nextFreeBlockAddress];
//    
//    AvailableBlock *prevAvail = [_database findPreviousAvailableBlockOfBlock:self];
//    DatabaseBlock *prevBlock = [[DatabaseBlock alloc] initWithDatabase:_database fileHandle:_fileHandle address:prevAvail.address];
//    [prevBlock writeNextFreeBlockAddress:address];
//    
//    [_database setAvailableBlock:[AvailableBlock availableBlockWithAddress:address size:newBlock.size] atIndex:prevAvail.index + 1];
//    
//    [self setSize:(self.size - (newBlock.size + (UInt32) kDatabaseHeaderSize + (UInt32) kDatabaseTrailerSize))];
//    self.free = NO;
//    [self writeHeader];
//    [self writeTrailer];
//    
//    return newBlock;
//}

@end
