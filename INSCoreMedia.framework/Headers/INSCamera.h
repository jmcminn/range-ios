//
//  INSCamera.h
//  INSVideoPlayApp
//
//  Created by pwx on 14/1/16.
//  Copyright © 2016年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSCameraProjectType) {
    INSCameraProjectTypeNone = 0,
    INSCameraProjectTypePerspective = 1,
    INSCameraProjectTypePanini = 4
};

@interface INSCamera : NSObject<NSCoding>


- (instancetype)initWithOrthoLeft:(float)left right:(float)right bottom:(float)bottom top:(float)top nearZ:(float)nearZ farZ:(float)farZ;

- (instancetype)initWithPerspectiveYFov:(float)yFov aspect:(float)aspect nearZ:(float)nearZ farZ:(float)farZ;


//projection 矩阵参数
@property (nonatomic, assign) float xFov;
@property (nonatomic, assign) float yFov;
@property (nonatomic, assign) float zNear;
@property (nonatomic, assign) float zFar;
@property (nonatomic, assign) float aspect;                         //  值：宽/高
@property (nonatomic, assign) float left;
@property (nonatomic, assign) float right;
@property (nonatomic, assign) float bottom;
@property (nonatomic, assign) float top;
@property (nonatomic, assign) float nearZ;
@property (nonatomic, assign) float farZ;
@property (nonatomic, assign) GLKMatrix4 projectionMat4;            //投影矩阵
#pragma mark - view 矩阵参数
@property (nonatomic, assign) GLKVector3 eye;                       //默认值：(0, 0, 0)         鱼眼设置第三个值,即eye.z
@property (nonatomic, assign) GLKVector3 center;                    //默认值：(0, 0, -1)
@property (nonatomic, assign) GLKVector3 up;                        //默认值：(0, 1, 0)
@property (nonatomic, assign) GLKMatrix4 viewMat4;                  //视图矩阵
@property (nonatomic, assign) float distance;
#pragma mark - view 刷新标记
@property (atomic, assign) BOOL refreshFlag;                        // 刷新标记，用于是否更新屏幕刷新画面
#pragma mark - panini param
// panini 过渡模型矩阵参数类型
@property (nonatomic, assign) INSCameraProjectType projectType;
@property (nonatomic, assign) INSCameraProjectType transitionProjectType;
@property (nonatomic, assign) double transitionProjectTypeAlpha;

- (INSCamera*)copyValue;

+ (float)xFovFromYFov:(float)yFov width:(float)width height:(float)height;
+ (float)yFovFromXFov:(float)xFov width:(float)width height:(float)height;
@end

NS_ASSUME_NONNULL_END
