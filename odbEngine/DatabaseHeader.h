//
//  DatabaseHeader.h
//  odbEngine
//
//  Created by Ted Howard on 7/29/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

const NSUInteger kDatabaseHeaderSize;

@interface DatabaseHeader : NSObject

@property (readonly) BOOL free;
@property (readonly) NSInteger size;
@property (readonly) NSInteger variance;

- (instancetype)initWithData:(NSData *)data;

@end
