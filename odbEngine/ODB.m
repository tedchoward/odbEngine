//
//  ODB.m
//  odbEngine
//
//  Created by Ted Howard on 3/31/17.
//  Copyright © 2017 Ted C. Howard. All rights reserved.
//

#import "ODB.h"
#import "Database.h"

#define VERSION_NUMBER 0x03

#pragma pack(2)
typedef struct __database_file_rect_t__ {
  int16_t top;
  int16_t left;
  int16_t bottom;
  int16_t right;
} database_file_rect_t; // was Carbon `Rect`
#pragma options align=reset

#pragma pack(2)
typedef struct __database_file_window_info_t__ {
  database_file_rect_t windowRect;
  uint8_t fontName[33];
  int16_t fontNum;
  int16_t fontSize;
  int16_t fontStyle;
  int32_t w; // was `WindowPtr`
  uint8_t waste[10];
} database_file_window_info_t; // was `tycancoonwindowinfo`
#pragma options align=reset

#pragma pack(2)
typedef struct __database_file_record_t__ {
  int16_t versionNumber;
  uint32_t rootTableAddress;
  database_file_window_info_t windowInfo[6];
  uint32_t scriptStringAddress;
  uint16_t flags;
  int16_t ixPrimaryAgent;
  int16_t waste[28];
} database_file_record_t; // was `tyversion2cancoonrecord`
#pragma options align=reset

@interface ODB(private)
@property (nonatomic, strong) Database *databaseRecord;
@end

@implementation ODB

- (instancetype)initWithNewFile:(NSFileHandle *)fileHandle {
  self = [super init];
  
  if (self) {
    database_file_record_t info;
    memset(&info, 0, sizeof(info));
    uint32_t address = 0;
    
    self.databaseRecord = [Database newDatabaseWithFileHandle:fileHandle];
    
    info.versionNumber = CFSwapInt16HostToBig(VERSION_NUMBER);
  }
  
  return self;
}

@end
