//
//  INSGyroPlayerWrapData.h
//  INSCoreMedia
//
//  Created by HFY on 2021/1/7.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface INSGyroPlayerWrapData : NSObject

@end

/**
In INSGyroPBPlayer, we use default value is {50, 650, 9.0/16.0, 180.0, 1,0, 0.0} if you don't udpate this param
rate = resolution of height / width of render
*/

@interface INSGyroStabFilterSetting : NSObject

// media offset, 设置之前先用INSLensOffset检查offset是否合法
@property (nonatomic) NSString *offset;

// render xfov
@property (nonatomic) double xFov;

// render distance
@property (nonatomic) double distance;

//resolution of height / width of render
@property (nonatomic) double renderRatio;

// 附加的旋转 radains
@property (nonatomic) double extraRotate;

// 默认为5;
@property (nonatomic) int winSize;

// 默认29.97
@property (nonatomic) double frameRate;

// 是否在freeFootage模式下开启重力矫正 默认NO
@property (nonatomic) BOOL gravityCalibrate;

// 动态fov的最大变化量，为大于0的值，该值由需求段确认， 如果当前fov为70，且该值设置为5，则动态fov范围为[65,70], 默认为0表示不添加动态fov
@property (nonatomic) double autoFovChangeRange;


// 如果是TC2机型 需要防抖约束限制 设置true 默认false
@property (nonatomic) BOOL boundaryRedundancySwitch;

// TC2机型 用于配置防抖空间冗余区域  冗余区域的比例，比例越小，用于防抖的画面越大, 常规取值范围[0,0.02]
@property (nonatomic) double boundaryRedundancyRate;


- (instancetype) initWithOffset:(NSString *)offset
                           xFov:(double)xFov
                       distance:(double)distance
                    renderRatio:(double)renderRatio;

- (instancetype) initWithOffset:(NSString *)offset
                           xFov:(double)xFov
                       distance:(double)distance
                    renderRatio:(double)renderRatio
                    extraRotate:(double)extraRotate;

- (instancetype) initWithOffset:(NSString *)offset
                           xFov:(double)xFov
                       distance:(double)distance
                    renderRatio:(double)renderRatio
                    extraRotate:(double)extraRotate
         boundaryRedundancyRate:(double)boundaryRedundancyRate;

@end

typedef NS_ENUM(NSInteger, INSGyroStabilizerBulletMode) {
    INSGyroStabilizerBulletModeNormal = 0,
    INSGyroStabilizerBulletModeRemovePitch = 1,
    INSGyroStabilizerBulletModeAutoReflection = 2,
};

@interface INSGyroFrameAccurateTime : NSObject

@property (nonatomic, readonly) NSArray <NSNumber *> * timestampLists;

- (instancetype)initWithTimestampLists:(NSArray <NSNumber *> *)timestampLists;

@end

@interface INSGyroStabFilterTrimInfo : NSObject

@property (nonatomic, readonly) double start;

@property (nonatomic, readonly) double end;

@property (nonatomic, readonly) double over;


/// 配置防抖filter的trim信息
/// @param start trim 起始in ms
/// @param end trim 结束
/// @param over 实际trim区间为[start - over , end + over],   请暂时输入500
- (instancetype)initWithStart:(double)start end:(double)end over:(double)over;

@end

@interface INSGyroStabFilterFeedParam : NSObject

@property (nullable, nonatomic) NSArray <INSGyroFrameAccurateTime*> *frameAccurateTimestampList;

@property (nullable, nonatomic) INSGyroStabFilterTrimInfo *trimInfo;

/// 是否是HDR视频，根据实际情况设置，如果是的话，内部会做特殊处理. 默认NO
@property (nonatomic) BOOL isHDRVideo;

/// 默认为NO，即在这之前，只有普通视频使用frameAccurateTimestampList feed到算法库，Timelapse、Timeshift视频使用的是文件尾携带的type = 0x06 framePtsData类型。
/// 若设置为YES，则表示Timelapse、Timeshift视频会使用 **frameAccurateTimestampList** + **framePtsData ** 来重新过滤framePtsData，后feed到算法
@property (nonatomic) BOOL timelapseUseInputListMap;

@end


@interface INSGyroDataCustomScope : NSObject

//输入时间戳 (毫秒)
@property (nonatomic) double timeStampMs;
//防抖数据范围
@property (nonatomic) double delta;

@end


NS_ASSUME_NONNULL_END
