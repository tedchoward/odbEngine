//
//  AvailableNodeShadow.m
//  odbEngine
//
//  Created by Ted Howard on 7/29/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import "AvailableNodeShadow.h"
#import "Database.h"

#pragma pack(2)
typedef struct __available_node_shadow_t__ {
    uint32_t address;
    int32_t size;
} available_node_shadow_t;
#pragma options align=reset

extern const NSUInteger kAvailableNodeShadowSize = sizeof(available_node_shadow_t);

@interface AvailableNodeShadow ()
@property (nonatomic) NSUInteger address;
@property (nonatomic) NSInteger size;
@end

@implementation AvailableNodeShadow

- (instancetype)initWithData:(NSData *)data {
    self = [super init];
    
    if (self) {
        available_node_shadow_t shadowAvailNode;
        [data getBytes:&shadowAvailNode length:sizeof(available_node_shadow_t)];
        self.address = CFSwapInt32BigToHost(shadowAvailNode.address);
        self.size = CFSwapInt32BigToHost(shadowAvailNode.size);
    }
    
    return self;
}

- (void)readFromDatabase:(Database *)database {
}

@end
