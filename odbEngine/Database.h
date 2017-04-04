//
//  Database.h
//  odbEngine
//
//  Created by Ted Howard on 7/11/16.
//  Copyright © 2016 Ted C. Howard. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Database : NSObject
+ (Database *)newDatabaseWithFileHandle:(NSFileHandle *)fileHandle;

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle readOnly:(BOOL)readOnly;

@end
