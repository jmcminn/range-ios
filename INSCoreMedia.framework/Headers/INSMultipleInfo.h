//
//  INSMultipleInfo.h
//  INSCoreMedia
//
//  Created by pengwx on 2018/1/20.
//  Copyright © 2018年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSRenderType.h"


NS_ASSUME_NONNULL_BEGIN

@class INSTrim;
@class INSPlayRateRange;
@class INSLookHerePoint;
//@class INSProjectionParam;
@class INSProjectionInfo;
@class INSScreenRecorder;
@class INSTimeScale;
@class INSDisplay;
@class INSDisplayConfigManager;

typedef NS_ENUM(NSInteger, INSMultipleInfoHandleMode) {
    INSMultipleInfoHandleModeDefault = 0,
    INSMultipleInfoHandleModeSingleRecorder = 1,
};

@interface INSMultipleInfo : NSObject<NSCoding>

- (instancetype) initWithInitialProjection:(INSProjectionInfo*)initialProjection  videoDurationMs:(double)videoDuration;

@property (nonatomic) double videoDurationMs;
@property (nonatomic, strong) INSProjectionInfo *initialProjection;
@property (nonatomic, strong, nullable) INSTrim *trim;
@property (nonatomic, strong, nullable) NSArray<INSLookHerePoint*>* lookHerePoints;
@property (nonatomic, strong, nullable) NSArray<INSScreenRecorder*>* screenRecords;

/**
 变速时间段
 */
@property (nonatomic, strong, nullable) NSArray<INSTimeScale*>* timeScales;

/**
 特殊的mode，如果是依赖AnimationRecorder，且只有一种，则使用INSMultipleInfoHandleModeSingleRecorder
 */
@property (nonatomic) INSMultipleInfoHandleMode handleMode;

/**
 * 在使用了autoFov机制后，INSMultipleInfo的动画逻辑会覆盖掉autoFov的逻辑，所以用这个变量是否动态fov优先于动画的打点
 * 如果设置为YES，则打点数据的fov值将不会生效，而是使用autofov的值，慎用。一般用于go系列开启动态fov的单鱼眼或者广角的情况，防止打点对动态fov数据的影响
 * 这个值默认为NO. 即动画数据覆盖autofov的值。
 */
@property (nonatomic) BOOL disableFov;

/**
 不再使用，仅做兼容one的代码, 新的使用timeScales
 */
@property (nonatomic, strong, readonly, nullable) NSArray<INSPlayRateRange*>* playRateRanges;
@property (nonatomic, readonly) double playDuration;

- (INSMultipleInfo*) infoWithDisplay:(INSDisplay*)display displayConfigManager:(INSDisplayConfigManager*)manager;

@end



NS_ASSUME_NONNULL_END
