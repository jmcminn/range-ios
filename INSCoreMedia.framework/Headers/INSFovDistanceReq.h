//
//  INSFovDistance.h
//  INSCoreMedia
//
//  Created by 蔡鹏 on 2023/7/24.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>
#import "INSEyePoint.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSFovDistanceReq : NSObject
@property (nonatomic) float fov;
@property (nonatomic) float distance;
@property (nonatomic) float aspect;
@property (nonatomic) bool applyAutoFov;
@end

@interface INSOrientationReq : NSObject
@property (nonatomic) GLKQuaternion orientation;
@end

@interface INSPreRollReq : NSObject
@property (nonatomic) float preRoll;
@end

@interface INSYawReq : NSObject
@property (nonatomic) float yaw;  //偏航角, 角度值，内部会转成弧度
@end

@interface INSPitchReq : NSObject
@property (nonatomic) float pitch; // 俯仰角, 角度值，内部会转成弧度
@end

@interface INSFovReq : NSObject
@property (nonatomic) float fov;
@end

@interface INSDistanceReq : NSObject
@property (nonatomic) float distance;
@end

@interface INSAspectReq : NSObject
@property (nonatomic) float aspect;
@end

/// 调整view比例的时候需要设置
@interface INSRenderViewSizeReq : NSObject
@property (nonatomic) float width;
@property (nonatomic) float height;
@end

/// 设置extra rotate，用与autofov场景，矫正autofov值
@interface INSExtraRotateReq : NSObject
@property (nonatomic) int rotate;
@end


@interface INSProjectionTypeReq : NSObject
// 0.0 表示 omini
// 1.0 表示 panini
// 如果INSProjectionType设置为Panini，我们会检测下面的参数
@property (nonatomic) INSProjectionType modelType;
// 当modelType为panini时，是否要使用下面的参数
// 默认值为true.
@property (nonatomic) bool needUseBelowParam;
/// aspect 为 16:9 或者 2.35:1
@property (nonatomic) float aspect;
@property (nonatomic) float startXFovDeg;
@property (nonatomic) float startDistance;
@property (nonatomic) float endXFovDeg;
@property (nonatomic) float endDistance;
@end

NS_ASSUME_NONNULL_END
