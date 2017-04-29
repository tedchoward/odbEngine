//
//  Database.h
//  odbEngine
//
//  Created by Ted Howard on 7/11/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AvailableBlock;
@class DatabaseBlock;

@interface Database : NSObject
@property (nonatomic) UInt32 availList;
@property (nonatomic) BOOL dirty;

+ (Database *)newDatabaseWithFileHandle:(NSFileHandle *)fileHandle;

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle readOnly:(BOOL)readOnly;

- (void)insertAvailableBlock:(AvailableBlock *)availableBlock atIndex:(NSUInteger)index;
- (AvailableBlock *)availableBlockAtIndex:(NSUInteger)index;
- (AvailableBlock *)findPreviousAvailableBlockOfBlock:(DatabaseBlock *)currentBlock;
- (void)setAvailableBlock:(AvailableBlock *)availableBlock atIndex:(NSUInteger)index;
- (void)removeAvailaleBlockAtIndex:(NSUInteger)index;
- (BOOL)flushHeader;

- (UInt32)assignData:(NSData *)data atAddress:(UInt32)address;
@end
