//
//  AvailableNodeShadow.h
//  odbEngine
//
//  Created by Ted Howard on 7/29/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const NSUInteger kAvailableNodeShadowSize;

@interface AvailableNodeShadow : NSObject
@property (readonly) NSUInteger address;
@property (readonly) NSInteger size;

- (instancetype)initWithData:(NSData *)data;
@end
