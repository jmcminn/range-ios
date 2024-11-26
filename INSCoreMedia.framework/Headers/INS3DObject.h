//
//  INS3DObject.h
//  INSVideoPlayApp
//
//  Created by pwx on 27/1/16.
//  Copyright © 2016年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@class INSCamera;
@class INSGeometry;
@class INSMaterial;
@class INSCorrectResult;
@interface INS3DObject : NSObject
{
    GLKMatrix4 _tModelView;
    GLKMatrix4 _modelViewMat;
    INSGeometry *_geometry;
}

@property (nonatomic, assign) GLKQuaternion adjustCoordinate;      //校正坐标系

@property (nonatomic, assign) GLKVector3 position;
@property (nonatomic, assign) GLKVector3 scale;

@property (nonatomic, assign) GLKVector3 eulerAngle;                        //欧拉角
@property (nonatomic, assign) GLKQuaternion orientation;                    //方向

@property (nonatomic, assign) GLfloat preRoll;                    //方向, 单位:度

@property (nonatomic, assign) GLKVector3 rotationEulerAngle;                //旋转欧拉角
@property (nonatomic, assign) GLKQuaternion rotationOrientation;            //旋转方向
@property (nonatomic, assign) GLKQuaternion preRollQuaternion;

@property (nonatomic, assign) GLenum frontFace;                             //
@property (nonatomic, strong, nullable) INSMaterial *material;                //材料
@property (nonatomic, strong, nullable) INSGeometry *geometry;                //几何体

@property (nonatomic, strong, readonly) NSMutableArray *objects;                 //3D模型
@property (nonatomic, readonly) GLKQuaternion quaternion;

@property (nonatomic, assign) GLKQuaternion gyroStabilityOrientation;
@property (nonatomic, assign) GLKQuaternion directionalOrientation;
@property (nonatomic, assign) GLKQuaternion applyQuaternion;

@property (nonatomic, readonly) GLKMatrix4 modelMat4;                             //包括adjustCoordinate
@property (nonatomic, readonly) GLKMatrix4 subModelMat4;                         //不包括adjustCoordinate

/// TC2水平矫正开关
@property(nonatomic)BOOL correctSwitch;

/// 矫正旋转量
@property(nullable, nonatomic)INSCorrectResult *correctResult;


@property (nonatomic, copy, nullable) void (^gyroPlayModelAutoFovBlock)(double autoFov);

#pragma mark - view 刷新标记
@property (atomic, assign) BOOL refreshFlag; // 由于有子object，所以该值不能用做最终值，需要用object3DRefreshFalg进行判断
/// 刷新标记，是否更新,用这个来判断是否刷新，因为内部封装了子object的refreshFlag校验
- (BOOL)object3DRefreshFalg;


-(GLKVector3)spatialAudioRotation;

//清理
- (void) clean;

- (void) addChildToFront:(INS3DObject *)child;

//添加3D物体
- (void) addChild:(INS3DObject*)child;

//移除3D物体
- (void) removeChild:(INS3DObject*)child;

- (void) removeAllChild;

- (void) removeChilds:(NSArray*)childs;

//渲染
- (void) renderWithCamera:(INSCamera*)camera projectMat:(GLKMatrix4*)pProjectMat ViewMat:(GLKMatrix4*)pViewMat parentMat:(GLKMatrix4*)pParentMat;

- (void) tinyCustomRender:(INSCamera *)camera;
@end

NS_ASSUME_NONNULL_END
