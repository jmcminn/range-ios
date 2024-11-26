//
//  INSProjectionInfo.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/6/30.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@class INSMediaEuler;

@interface INSProjectionInfo : NSObject<NSCopying, NSCoding>

@property (nonatomic) float xFov;
@property (nonatomic) float yFov;
@property (nonatomic) float distance;
@property (nonatomic) float preRoll;
@property (nonatomic) float aspect;
@property (nonatomic) GLKQuaternion orientation;
@property (nonatomic) float modelAlpha;
//@property (nonatomic) float yaw;
//@property (nonatomic) float pitch;

- (instancetype)init;

- (instancetype)initWithXFov:(float)xFov distance:(float)distance aspect:(float)aspect;

- (INSProjectionInfo *)copyValue;
/// 用户指定正确的aspect来进行配置
-(float)getxFovByAspect:(float)aspect;

- (NSString*) toString;

// 返回对应的欧拉角，主要是云导出时使用，**弧度**
- (INSMediaEuler *) getEulerAngle;

@end

NS_ASSUME_NONNULL_END
