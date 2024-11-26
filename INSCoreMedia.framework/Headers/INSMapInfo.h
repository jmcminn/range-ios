//
//  INSMapInfo.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2023/3/2.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSGyroPlayer.h"
#import "INSStitchingInfo.h"
NS_ASSUME_NONNULL_BEGIN

@interface INSMapInfo : NSObject
/// 是否为外部回调值
@property (nonatomic, assign) BOOL isCallbacked;
@property (nonatomic, assign) double sweepTime;
@property (nonatomic, copy)   NSString *offset;
@property (nonatomic, strong) INSGyroPlayer *gyroPlayer;
@property (nonatomic, assign) BOOL enableRollingShutter;
@property (nonatomic, assign) BOOL forceUseVideoDynamic;
@property (nonatomic, strong) INSStitchingInfo *stitchingInfo;
@property (nonatomic, assign) INSStitchType stitchType;
@property (nonatomic, assign) INSRenderType rendertype;
@end

NS_ASSUME_NONNULL_END
