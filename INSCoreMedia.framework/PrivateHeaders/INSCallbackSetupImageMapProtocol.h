//
//  Header.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2023/3/8.
//  Copyright © 2023 insta360. All rights reserved.
//

#ifndef Header_h
#define Header_h

@protocol INSCallbackSetupImageMapProtocol <NSObject>
@optional
- (void)willSetMap:(INSMapInfo *)mapInfo clipIndex:(int)clipIndex;
- (void)willSetCutSceneMap:(INSMapInfo *)mapInfo clipIndex:(int)clipIndex cutMap:(INSMapInfo *)cutMapInfo cutClipIndex:(int)cutClipIndex;
@end

#endif /* Header_h */
