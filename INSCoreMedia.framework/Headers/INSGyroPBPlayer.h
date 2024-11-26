//
//  INSGyroPBPlayer.h
//  INSCoreMedia
//
//  Created by pengwx on 17/3/23.
//  Copyright © 2017年 insta360. All rights reserved.
//


#import "INSGyroPlayer.h"
#import <UIKit/UIKit.h>

@class INSExposurePlayer;
@class INSExtraGyroData;
@class INSEmSegment;

NS_ASSUME_NONNULL_BEGIN

@interface INSGyroPBPlayer : INSGyroPlayer

@property (nonatomic, readonly) INSGyroDataType gyroDataType;

/**
 用于普通视频输入防抖数据，默认正向+反向输入

 @param pbGyro 防抖数据
 @return INSGyroPlayer
 */
- (nullable instancetype) initWithPBGyroData:(INSExtraGyroData *)pbGyro;


/**
 用于普通视频输入防抖数据，可选正向输入或者反向输入

 @param pbGyro 防抖数据
 @param reverseInput YES-有反向输入 NO-无反向输入
 @return INSGyroPlayer
 */
- (nullable instancetype) initWithPBGyroData:(INSExtraGyroData *)pbGyro reverseInput:(BOOL)reverseInput;

/**
 optimize batch算法输入防抖数据，加载速度比较慢，适用于导出

 @param pbGyro 防抖数据
 @param reverseInput YES-有反向输入 NO-无反向输入
 @return INSGyroPlayer
 */
- (nullable instancetype) initWithNewVersionPBGyroData:(INSExtraGyroData *)pbGyro reverseInput:(BOOL)reverseInput;

- (nullable instancetype) initWithNewVersionPBGyroData:(INSExtraGyroData *)pbGyro reverseInput:(BOOL)reverseInput releaseMemory:(BOOL)releaseMemory;

/**
 用于定点延时摄影，这类文件的陀螺仪数据是多个图片的陀螺仪数据连接在一起，时间戳不是一直连续的，所以规定这类陀螺仪数据，每段用timestap=-1为flag，gravity_x为序号，表示这段数据所属的帧

 @param pbGyro 陀螺仪数据
 @return INSGyroPlayer
 */
- (nullable instancetype) initWithMultipleBatchPBGyroData:(INSExtraGyroData *)pbGyro;


- (void) updateTimeManagerWithTimeMapperData:(INSExtraTimeMapperData* _Nullable)timeMapperData;

/**
 是否开启减少迭代的加速方案
 */
- (void)setSpeedUpFlag:(BOOL)speedUpFlag;
/**
 是否正在进行流式加载,cancelInputOverflowGyroData 之前可作为判定条件 YES:流式输入中 NO:没有输入
 */
@property (nonatomic) BOOL inputing;


@property (nonatomic, readonly) int64_t endVideoTimestamp;

/// trim掉算法持有的防抖四元数，这个接口调用后，无法再次trim，因为每次trim后会释放掉之前的数据；
/// INSGyroStabFilterTrimInfo 中的over属性，是在trimStart end的基础上，向外扩展的量，建议设置为2000
/// @return YES 成功  NO失败， 失败则不允许使用，应该有额外的处理，如用全量的代替。
- (BOOL)trimStabilizerAlgoData:(INSGyroStabFilterTrimInfo *)trimInfo;

@end


@interface INSGyroPBPlayer (GyroDataOverFlow)
/**
 流式加载陀螺仪数据的初始化方法，不要同时调用同步和异步加载的接口
 
 @param sweepTimeMs 扫描时间，单位毫秒
 @param gyroAdjustTimeMs 防抖调整时间，单位毫秒
 @param exposureAdjustTimeMs 曝光调整时间，单位毫秒

 @return INSGyroPlayer
 */
- (nullable instancetype) initOverFlowPBGyroPlayer:(double) sweepTimeMs gyroAdjustTimeMs:(double) gyroAdjustTimeMs exposureAdjustTimeMs:(double) exposureAdjustTimeMs;

/**
 异步流式填充算法库

 @param pbGyro 陀螺仪信息
 @param process 加载过程的回调
 */
- (void)startInputOverflowGyroData:(INSExtraGyroData *)pbGyro progress:(nullable void (^)(NSError * _Nullable error, NSInteger expectedCount, NSInteger inputedCount, BOOL inputing))process;


/**
 同步流式填充算法库，调用cancel可以立即返回，并抛出错误

 @param pbGyro 陀螺仪信息
 @param error 错误处理
 */

- (void)inputOverflowGyroData:(INSExtraGyroData *)pbGyro error:(NSError * _Nullable *)error;

/**
 取消流式加载
 */
- (void) cancelInputOverflowGyroData;
/* 根据时间戳获取前后指定范围的防抖数据，减少流式加载的耗时
 @param pbGyro 陀螺仪信息
 @param error 错误处理
 @param gyroDataWithInScope 自定义范围
 */
- (void)getGyroDataInCustomScope:(INSExtraGyroData *)pbGyro error:(NSError * _Nullable *)error  gyroDataCustomScope:(INSGyroDataCustomScope*)gyroDataCustomScope;

@end


@interface INSGyroPBPlayer (EmPlay)

/// 用循环录影的列表来初始化
- (nullable instancetype) initWithEmSegment:(NSArray<INSEmSegment*>*)emSegments;

/// 要把每个视频的陀螺仪信息加载到gyroPlayer实例中
- (void)appendGyroData:(INSExtraGyroData *)pbGyro;

/// 所有数据全部append之后，添加
- (BOOL)load DEPRECATED_MSG_ATTRIBUTE("Please use loadCacheData:");

/// 所有数据全部append之后调用，如果没有缓存数据，则传递nil
- (BOOL)loadCacheData:(NSData * _Nullable)cacheData;

/// 使用序列化文件来加载陀螺仪数据
/// @param gyroStabilizerDataPathUrl 陀螺仪序列化文件地址
/// @param gyroStabilizerDataExtPathUrl 第二路陀螺仪序列化文件地址
- (BOOL)loadGyroStabilizerDataUrl:(NSURL *_Nullable)gyroStabilizerDataPathUrl gyroStabilizerDataExtUrl:(NSURL * _Nullable)gyroStabilizerDataExtPathUrl;

@end


@interface INSGyroPBPlayer (Serializer)

- (nullable instancetype)initWithPBGyroData:(INSExtraGyroData *)pbGyro gyroStabilizerData:(NSData *)gyroStabilizerData  multipleBatch:(BOOL)multipleBatch DEPRECATED_MSG_ATTRIBUTE("Please use -initWithPBGyroData:gyroStabilizerData:gyroStabilizerDataExt:");
- (instancetype)initWithPBGyroData:(INSExtraGyroData *)pbGyro gyroStabilizerData:(NSData *)gyroStabilizerData gyroStabilizerDataExt:(NSData * _Nullable)gyroStabilizerDataExt multipleBatch:(BOOL)multipleBatch;

- (void)serializeStabilizerFilterCompletion:(void(^)(NSData * _Nullable gyroStabilizerData, NSError * _Nullable error))completion DEPRECATED_MSG_ATTRIBUTE("Please use -serializeStabilizerWithExtCompletion");
- (void)serializeStabilizerWithExtCompletion:(void(^)(NSData * _Nullable gyroStabilizerData,NSData * _Nullable gyroStabilizerDataExt, NSError * _Nullable error))completion;

/// 反序列化
/// @param pbGyro 序列化对象
/// @param gyroStabilizerDataPathUrl gyroStabilizerData文件地址
/// @param gyroStabilizerDataExtPathUrl gyroStabilizerDataExt文件地址
/// @param multipleBatch 批处理标志
/// @param releaseMemory 一般为NO，如果设置为YES，会导致INSGyroPBPlayer+Detector中的方法、INSDirectionTracker、INSAutoEditorPanoProcessor的相关接口使用时，重新加载陀螺仪数据，这些接口速度会变慢。
- (instancetype _Nullable)initWithPBGyroData:(INSExtraGyroData *)pbGyro gyroStabilizerDataUrl:(NSURL *)gyroStabilizerDataPathUrl gyroStabilizerDataExtUrl:(NSURL * _Nullable)gyroStabilizerDataExtPathUrl multipleBatch:(BOOL)multipleBatch releaseMemory:(BOOL)releaseMemory;
/// @param multipleBatch 批处理标志
- (instancetype _Nullable)initWithPBGyroData:(INSExtraGyroData *)pbGyro gyroStabilizerDataUrl:(NSURL *)gyroStabilizerDataPathUrl gyroStabilizerDataExtUrl:(NSURL * _Nullable)gyroStabilizerDataExtPathUrl multipleBatch:(BOOL)multipleBatch;


/// 序列化
/// @param fileUrl gyroStabilizerData序列化到这个地址
/// @param extFileURL gyroStabilizerDataExt序列化到这个地址
/// @param completion 序列化完毕通知回调
- (void)serializeStabilizerWithExtToFileURL:(NSURL *)fileUrl extFileURL:(NSURL *)extFileURL Completion:(void (^)(NSError * _Nullable error))completion;

@end

@interface INSGyroPBPlayer (BulletTime)


/// for bullet_time video anti-shake, you should call this first
/// @return YES if the bullet time adaptor can be use; NO if the video's gyro data feature is not typical bullet time
- (BOOL)onUseBulletTimeAdaptor;

/// update bullet adaptor setting, you should call onUseBulletTimeAdaptor first
/// @param bulletMode mode
/// @param extraPitch For RemovePitch mode, to add extra pitch, in radian
- (BOOL)setBulletTimeAdaptorWithMode:(INSGyroStabilizerBulletMode)bulletMode extraPitch:(double)extraPitch;
                  

@end

NS_ASSUME_NONNULL_END
