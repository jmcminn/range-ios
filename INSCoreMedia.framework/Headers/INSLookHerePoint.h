//
//  INSLookHerePoint.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/12/26.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <INSCoreMedia/INSMediaPos.h>
#import <INSCoreMedia/INSEulerModel.h>

NS_ASSUME_NONNULL_BEGIN

/// 追踪中包含打点的过渡方式
///
/// 1. INSLookHerePointTransitionTypeAllKeyFrame
///    该关键帧需要和后面的关键帧（如果有），当做一个整体来进行过渡
///    追踪中的第一个关键帧前1s，和最后一个关键帧后1s，有平滑
///
/// 2. INSLookHerePointTransitionTypeSingleKeyFrame
///    该关键帧通过recorder数据进行过渡, 以关键帧左右各1s作为range，进行过渡
///    如果下一个关键帧，和当前关键帧的时间间距小于1s，则两个关键帧要当做整体进行过渡
typedef NS_ENUM(NSInteger, INSLookHerePointTransitionType) {
    INSLookHerePointTransitionTypeAllKeyFrame = 0,
    INSLookHerePointTransitionTypeSingleKeyFrame
};

@class INSDisplay;
@class INSDisplayConfigManager;
@class INSEulerModel;
@interface INSLookHerePoint : NSObject<NSCoding, NSCopying, NSMutableCopying>

@property (nonatomic) float xFov;
@property (nonatomic) float distance;
@property (nonatomic) float preRoll;
@property (nonatomic) GLKQuaternion anchorOrientation;
@property (nonatomic) GLKQuaternion orientation;
@property (nonatomic, strong, nullable)INSDisplay *display;
@property(nonatomic, strong)INSMediaPos *srcTimePos;
@property (nonatomic) GLKVector3 spherePos;
@property (nonatomic) INSLookHerePointTransitionType transitionType;
@property (nonatomic, copy, nullable) NSString *uniqueId;

-(instancetype)initWithJsonDictionary:(NSDictionary*)dic;
-(NSDictionary*)serializeJsonDictionary;

- (INSLookHerePoint*) lookHerePointWithDisplay:(INSDisplay*)display displayConfigManager:(INSDisplayConfigManager*)manager;

/// 将 INSLookHerePoint 转换为 INSEulerModel 的函数，供App导出编辑数据给PC使用
/// @param aspect - width / height
-(INSEulerModel*)GetEulerByLookHerePoint:(float)aspect;

@end

NS_ASSUME_NONNULL_END
