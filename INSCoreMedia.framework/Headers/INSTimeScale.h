//
//  INSTimeScale.h
//  INSCoreMedia
//
//  Created by pengwx on 2018/7/2.
//  Copyright © 2018年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSTimeScaleType){
    INSTimeScaleTypeDefaultValue,
    INSTimeScaleTypeInterpolateFinalFrame,
    INSTimeScaleTypeInterpolateFinalFrameAI,
    INSTimeScaleTypeInterpolateSourceFrame,
    INSTimeScaleTypeRepeatSingleSourceFrame,
};

typedef NS_ENUM(NSInteger, INSShiftType){
    INSShiftTypeNormal,                   // 普通变速
    INSShiftTypeAI,                       // AI 变速
    INSShiftTypeCameraAnimation,          // X4 运镜类变速
    INSShiftTypeFreeze,                   // freeze 变速
};

@interface INSTimeScale : NSObject<NSCoding, NSCopying, NSMutableCopying>

- (instancetype) initWithFactor:(double)factor startTimeMs:(double)startTime endTimeMs:(double)endTime;
- (instancetype) initWithFactor:(double)factor startTimeMs:(double)startTime endTimeMs:(double)endTime repeatToFps:(double)repeatToFps videoKeyframeOnly:(BOOL)videoKeyframeOnly;
- (bool) isTimeMatchWithTime:(double) srcTimeMs;
- (bool) isTimeMatch2WithTime:(double) srcTimeMs;
- (void) setRepeatToFpsForExporter:(double)repeatToFps;
/**
 缩放因子
 */
@property (nonatomic) double factor;

/**
 开始时间
 单位：毫秒MS
 */
@property (nonatomic) double startTimeMs;

/**
 结束时间
 单位：毫秒MS
 */
@property (nonatomic) double endTimeMs;


///重复帧以期达到的目标帧率，默认30
@property (nonatomic)double repeatToFps;

///重复帧以期达到的目标帧率，默认0
@property (nonatomic)double repeatToFpsForExporter;

/// 仅播放关键帧,  默认NO
@property(nonatomic)BOOL videoKeyframeOnly;

@property(nonatomic)INSTimeScaleType type;

/**
 * 1 clip cut scene duration media time
 * 2 set when you don't want cutscene with motionblur
 * motionblur only react in single clip render
 */
@property(nonatomic)double clipEndCutSceneDurationMediaMs;

/**
 * 描述了执行motionBlur算法时，参与叠加的帧的数量，理论上，这个值越大，重叠效果明显
 * 导出的motionBlur通过这里配置，如果需要打开motionBlur, 则把这个值设置为一个正整数，按照调试后的效果，为16最好.
 * 1 meaningful when factor less than 1.f(discard frame)
 * 2 when maxMotionBlurNum_ > 0 means max motion blur num
 */
@property(nonatomic) int motionBlurNum;

/**
 * 描述变速类型，区分普通变速与 AI 变速
 */

@property (nonatomic, assign) INSShiftType shiftType;

@end

@interface INSTimestampInsert : NSObject

- (instancetype) initWithTimestamp:(double)timestamp isInsert:(bool)isInsert;

@property (nonatomic) double timestamp;

@property (nonatomic) bool isInsert;

+ (NSArray<INSTimestampInsert *> *)checkTimestampInsertWithTimestamps:(NSArray<NSNumber *> *)timestamps
                                                       timeScales:(NSArray<INSTimeScale *> *)timeScales
                                                                              inputFps:(double)inputFps
                                                                            exportFps:(double)exportFps;

@end

NS_ASSUME_NONNULL_END
