//
//  Utils.m
//  odbEngine
//
//  Created by Ted Howard on 4/24/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#include "Utils.h"

UInt64 dbGetEof(NSFileHandle *fileHandle) {
    UInt64 offset = fileHandle.offsetInFile;
    UInt64 eof = [fileHandle seekToEndOfFile];
    [fileHandle seekToFileOffset:offset];
    return eof;
}
