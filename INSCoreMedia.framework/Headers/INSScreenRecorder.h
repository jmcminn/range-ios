//
//  INSScreenRecorder.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/5/18.
//  Copyright © 2017年 insta360. All rights reserved.
//

//
//  INSScreenRecorder.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/5/18.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSRenderProtocol.h"
#import "INSScreenTrackerRecorderDelegate.h"
#import "INSEulerModel.h"
#import "INSLookHerePoint.h"
//#import "INSPointInRecorder.h"

typedef NS_ENUM(NSInteger, INSRecorderType){
    INSRecorderTypeFreecapture,
    INSRecorderTypeTracking,
    INSRecorderTypeFreecaptureJumpcut,
    INSRecorderTypeTrackingJumpcut,
    INSRecorderTypeAutoPanoEditTracking,
};

NS_ASSUME_NONNULL_BEGIN

@class INSMediaPos;
@class INSProjectionInfo;
@class INSDisplay;
@class INSDisplayConfigManager;
@class INSScreenRecorderModel;
@class INSEulerModel;

@interface INSScreenRecorder : NSObject<INSRenderProtocol, INSScreenTrackerRecorderDelegate, NSCoding, NSCopying, NSMutableCopying>

- (instancetype) initWithDisplay:(INSDisplay*)display minStartTimestamp:(double)startTimestamp maxEndTimestamp:(double)endTimestamp reachEndTimestamp:(void(^_Nullable)(double endTimestamp))block;

-(instancetype)initWithJsonDictionary:(NSDictionary*)dic;
-(NSDictionary*)serializeJsonDictionary;

/// 旧追踪/freecapture 接口保留
- (void) startRecord;
- (void) stopRecord;

/**
 丢弃小于或等于时间戳timestamp的数据
 @param timestamp 时间戳
 */
- (void) discardHeaderDataWithTimestamp:(double)timestamp;

/**
 丢弃大于或等于时间戳timestamp的数据
 @param timestamp 时间戳
 */
- (void) discardTailDataWithTimestamp:(double)timestamp;

- (void) resetStartTimestamp:(double)timestamp;

- (void) addRecorder:(INSScreenRecorder*)recorder;

/**
 有记录的帧数
 @return 数量
 */
- (NSInteger) timestampCount;

/// 查询获取视角信息
- (INSProjectionInfo* _Nullable) findProjectionInfo2:(INSMediaPos*)mediaPos;
- (INSProjectionInfo* _Nullable) findProjectionInfo:(double)timestamp;
- (INSProjectionInfo* _Nullable) findOriginProjectionInfo:(double)timestamp;

- (INSScreenRecorderModel* _Nullable) findRecorderModel:(double)timestamp;
- (INSScreenRecorderModel* _Nullable) getRecorderAtIndex:(int)index;

- (void)resetXFov:(float)fov;
- (void)resetDistance:(float)distance;
/// pitch is (-M_PI / 2)
- (void)resetOrientationToBottom;


/// 以欧拉角参数修改当前持有的视角信息，弧度制，如果传入nil，则该分量不被修改
/// @param yaw 偏航角 number with double value，传入nil表示维持原值，对pitch、roll的配置遵循相同规则
/// @param pitch 俯仰角
/// @param roll 旋转角
/// @param relative 是否是相对值，如果设置为YES，会在原始值的基础上，加上设置的相对值；如果设置为NO，则这里设置的值会设置为
- (void)resetOrientationWithYaw:(NSNumber * _Nullable)yaw pitch:(NSNumber * _Nullable)pitch roll:(NSNumber * _Nullable)roll relative:(BOOL)relative;

/// 转换track得到的model数据，包括追踪框大小
/// @param dstXFov 转换后的fov
/// @param dstDistance  转换后的distance
/// @param dstAspect  转换后的aspect， aspect为宽/高
/// @param srcAspect track时使用的aspect， aspect为宽/高
-(void)trackerModelResetDstXFov:(float)dstXFov dstDistance:(float)dstDistance dstAspect:(float)dstAspect srcAspect:(float)srcAspect;

- (INSScreenRecorder*) screenRecorderWithDisplay:(INSDisplay*)display displayConfigManager:(INSDisplayConfigManager*)manager;

/// 将 INSScreenRecorderModel 转换为 INSEulerModel 的函数，供App导出编辑数据给PC使用
/// @param aspect - width / height
- (NSMutableArray <INSEulerModel*>*) GetEulerByScreenRecorder:(float)aspect;

/// 深度追踪支持结合打点数据，将打点数据加入 INSScreenRecorder
//- (void) addLookHerePointsToRecorderModels:(NSArray<INSPointInRecorder*>*) pointInRecorders;

@property (nonatomic) INSRecorderType recorderType;            //录制类型
@property (nonatomic) BOOL disableFilter;                      //默认为NO，为YES时会不使用滤波
/// 函数是否关闭INSDisplayConfigManager配置的值来对当前recorder的fov，distance进行转换，默认值NO，即不关闭转换
@property (nonatomic) BOOL disableDisplayConfigManager;
@property (nonatomic, strong) INSDisplay* display;
@property (nonatomic, readonly) double duration;              //原始时长， 单位：毫秒ms
@property (nonatomic, readonly) double startTimestamp;        //开始视频帧时间戳， 单位：毫秒ms
@property (nonatomic, readonly) double endTimestamp;          //结束视频帧时间戳， 单位：毫秒ms
@property (nonatomic,strong, readonly, nullable) INSProjectionInfo *frontProjectionInfo;
@property (nonatomic,strong, readonly, nullable) INSProjectionInfo *backProjectionInfo;
@property (nonatomic, copy, nullable) NSString *uniqueId;


/// 是否开启平滑处理， 默认YES
@property(nonatomic)BOOL enableSmooth;

- (id)awayFromCenterHandleData;

- (NSArray<INSScreenRecorderModel *> *)getAllRecorderModels;
- (void)addRecorderModels:(NSArray<INSScreenRecorderModel *> *)screenRecorderModel;

/// app想要修正整段追踪数据，需要传当前mediaPos下的视角给到sdk
/// sdk根据当前时刻的视角做整段偏移
- (void) adjustRecorderData:(INSProjectionInfo *)curProjectInfo mediaPos:(INSMediaPos *)curMediaPos;


/// @return (x,y,z) -> (yaw, pitch, roll)
+ (GLKVector3)eulerAngleFromQuaternion:(GLKQuaternion)quat;

/// @param euler(yaw, pitch, roll)
+ (GLKQuaternion)quaternionFronEulerAngle:(GLKVector3)euler;

@end

NS_ASSUME_NONNULL_END
