//
//  INSRenderModelType.h
//  INSCoreMedia
//
//  Created by HFY on 2021/11/4.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSRenderType.h"
#import <GLKit/GLKit.h>
NS_ASSUME_NONNULL_BEGIN

@class INSMetalFilter;
@class INSVideoAsset;
@class INSSequenceStabilizer;
@class INSEyePointManager;
@class INSVisionField;

typedef NS_ENUM(NSInteger, INSDisplayType) {
    
    /// 不能用于直接配置，只能用于resolveRenderModelTypeWithAsset
    INSDisplayTypeAuto = 0,
    /// sphere model
    /// Detect file, if file is insv, insp, use sphere stitch model, otherwise, \n
    /// treat the source file is a panorama file, and show with sphere model
    /// 不能用于直接配置，只能用于resolveRenderModelTypeWithAsset
    INSDisplayTypeSphereAuto = 1,
    /// For insv, insp file, use sphere stitch model
    INSDisplayTypeSphereStitch = 2,
    /// For equirectangular projected degree mp4, jpg panorama file, use sphere model
    INSDisplayTypeSphereEquirectangular = 3,
    /// For insv, insp file, with only a single fisheye, use sphere model
    INSDisplayTypeSphereFisheyeDewarp = 4,
    
    // Complex cubemap/equirect background stream and cubemap tile stream support
    INSDisplayTypeCubeTileProjection = 5,
    // For cubemap projected, use sphere model
    INSDisplayTypeSphereCubemap = 6,
    
    //for cubemap projected, render to 2:1 equirenctangular
    INSDisplayTypePlaneCubemap2Equi = 7,

    //for cubemap tile projected, render to 2:1 equirenctangular
    INSDisplayTypePlaneCubeTile2Equi = 8,
    
    /// plane stitch model
    /// Detect file, if file is insv, insp, use plane stitch model, otherwise, \n
    /// treat the source file is a panorama file, and show with plane model
    /// 不能用于直接配置，只能用于resolveRenderModelTypeWithAsset
    INSDisplayTypePlaneAuto = 10,
    /// For insv, insp file, use plane stitch model
    INSDisplayTypePlaneStitch = 11,
    /// For equirectangular projected mp4, jpg panorama file, use plane stitch model \n
    /// display for PLANE and PLANE_EQUIRECTANGULAR are almost the same, but when using \n
    /// PLANE_EQUIRECTANGULAR with plane stitch model, it can add stickers to the sphere
    INSDisplayTypePlaneEquirectangular = 12,
    /// For insv, insp file, with only a single fisheye, use plane stitch model
    INSDisplayTypePlaneFisheyeDewarp = 13,
    
    /// plane
    /// played as normal video
    INSDisplayTypePlane = 20,
};

typedef NS_ENUM(NSInteger, INSDisplayTypeGroup) {
    /// projected to sphere model
    INSDisplayTypeGroupSphere,
    /// projected to equirectangular model
    INSDisplayTypeGroupPlaneStitch,
    /// played as normal video
    INSDisplayTypeGroupPlane,
};


typedef NS_ENUM(NSInteger, INSDynamicStitchType) {
    INSDynamicStitchTypeUndefined = 0,           // disables stitch
    INSDynamicStitchTypeDynamicImage = 1,
    INSDynamicStitchTypeDynamicVideo = 2,
    INSDynamicStitchTypeDynamicTemplate = 3,
};

typedef NS_ENUM(NSInteger, INSOpticalFlowType) {
    // 动态拼接
    INSOpticalFlowTypeDynamicStitch = 0,
    // 光流拼接
    INSOpticalFlowTypeDisflow = 1,
    // AI拼接
    INSOpticalFlowTypeAiFlow = 2,
};

typedef NS_ENUM(NSInteger, INSAIFlowBottomPrecision) {
    INSAIFlowBottomPrecisionUnknown = -1,
    INSAIFlowBottomPrecisionLow = 0,
    INSAIFlowBottomPrecisionMiddle = 1,
    INSAIFlowBottomPrecisionHigh = 2,
};

// TODO: INSColdShoeMode与INSStitchInfo中的命名冲突了，相似的情况建议定义在一个公共文件中，两边同时引用
typedef NS_ENUM(NSInteger, INSColdShoeType) {
    INSColdShoeTypeNone = 0,
    INSColdShoeTypeOnBothSide = 1,
    INSColdShoeTypeOnLeft = 2,
    INSColdShoeTypeOnRight = 3,
};


typedef NS_OPTIONS(NSUInteger, INSHWAccelFlag) {
    INSHWAccelFlagNone = 0,
    INSHWAccelFlagCuda = 1,
    INSHWAccelFlagOpenCL = 1 << 1,
    INSHWAccelFlagMetal = 1 << 2,
    INSHWAccelFlagVulkan = 1 << 3,
    INSHWAccelFlagAll = INSHWAccelFlagNone | INSHWAccelFlagCuda | INSHWAccelFlagOpenCL | INSHWAccelFlagMetal | INSHWAccelFlagVulkan,
};

typedef NS_ENUM(NSUInteger, INSStitchModeOfDIS) {
    INSStitchModeOfDISStable = 0,
    INSStitchModeOfDISAggressive = 1,
};

typedef NS_ENUM(NSInteger, INSImageLayout) {
    INSImageLayoutHorizontalMerged,
    INSImageLayoutOneBulletTime,
    INSImageLayoutRespective2Images,
    INSImageLayoutLeftHalf,
    INSImageLayoutRightHalf,
    INSImageLayoutTopHalf,
    INSImageLayoutBottomHalf,
    INSImageLayoutLeftRight,
    INSImageLayoutTopBottom
};

typedef NS_ENUM(NSInteger, INSPlaneStitchRotationMode) {
    INSPlaneStitchRotationModeDefault,
    INSPlaneStitchRotationModeHorizontal,
    INSPlaneStitchRotationModeVertical,
};

typedef NS_ENUM(NSUInteger, INSAutoBoxFilteringMethod) {
    INSAutoBoxFilteringMethodCompact = 0,
    INSAutoBoxFilteringMethodAccurate = 1,
};

typedef NS_ENUM(NSInteger, INSPlaneContentMode) {
    /// depends on the RenderModel, by default, SphereRenderModel is FitScreen,
    /// others are Contain;
    INSPlaneContentModeAuto = 0,

    ////////////////////////////////
    /// types for plane models,
    /// As large as possible while still containing the source entirely within the target screen(viewport).
    INSPlaneContentModeContain = 1,

    /// Fill the target screen(viewport) by distorting the source's aspect ratio. Plane models only.
    INSPlaneContentModeFill = 2,

    /// Covering the entire target screen(viewport), at most one direction(with or height) will be cropped.
    // Plane models only.
    INSPlaneContentModeCover = 3,

    ////////////////////////////////

    /// types for sphere models
    /// Fill the target screen(viewport) with the sphere content, by auto adjust the camera projection aspect to \n
    /// screen aspect value. This means camera aspect value may be changed while rendering according screen size.
    /// Sphere models only
    INSPlaneContentModeFitScreen = 10,

    /// As large as possible while still containing the source entirely within the target screen(viewport). \n
    /// The source content region is decide by camera params, such as aspect, fov, distance. \n
    /// This means user MUST set params such as aspect to camera!
    INSPlaneContentModeFitCamera = 11,
    
    ////////////////////////////////

    /// scale the content to fit the viewport, with keeping the aspect ratio.
    /// Deprecated, use Contain for plane model, use FitCamera for sphere model
    INSPlaneContentModeScaleAspectFit /* attr_deprecated */ = 1,

    /// scale the content to fill the viewport, the content maybe stretched.
    /// Deprecated, use Fill or Cover for plane model, use FitScreen for sphere Model
    INSPlaneContentModeScaleToFill /* attr_deprecated */ = 2,
};

typedef NS_ENUM(NSInteger, INSPovMode) {
    INSPovModeNONE = 0,
    INSPovModeASPECT_4x3_TO_16x9,
};

typedef NS_ENUM(NSInteger, INSResolveRenderModelTypeErrorCode) {
    INSResolveRenderModelTypeErrorCodeUnknown = 0,
    INSResolveRenderModelTypeErrorCodeInvalidAssetInfo,
};

typedef NS_ENUM(NSInteger, INSRenderModelCameraFace) {
    INSRenderModelCameraFaceLeft = 0,
    INSRenderModelCameraFaceRight,
};

@interface INSProjectionDesc : NSObject

@property (nonatomic) int projectionType;
@property (nonatomic) int panoWidth;
@property (nonatomic) int baseCubeWidthExtend;
@property (nonatomic) int width;

- (instancetype) initProjectionType: (int)projectionType panoWidth:(int)panoWidth baseCubeWidthExtend: (int)baseCubeWidthExtend width:(int)width;

@end

/// bmg根据这个选项，在内部进行相应offset的转换操作，如当你识别到当前素材待了潜水壳，那么需要把enableDivingWater设置为true，内部即可帮助转换到相应的潜水壳offset中
@interface INSOffsetConvertOption : NSObject

/// 防水壳
@property (nonatomic) BOOL enableWaterProof;

/// 潜水壳水下
@property (nonatomic) BOOL enableDivingWater;

/// 潜水壳水上
@property (nonatomic) BOOL enableDivingAir;

/// 潜水壳水下 相当于INSOffsetConvertTypeOneX3Fisheye_2_VER2DivingWater
@property (nonatomic) BOOL enableDivingWaterV2;

/// 潜水壳水上 相当于INSOffsetConvertTypeOneX3Fisheye_2_VER2DivingAir
@property (nonatomic) BOOL enableDivingAirV2;

// 卡扣式弧面镜
@property (nonatomic) BOOL enableProtectiveShell;

// 黏贴式球面镜
@property (nonatomic) BOOL enableProtectiveShellSphere;

// A/S 平均
@property (nonatomic) BOOL enableAverageShell;
@end

@class INSAsset;
@interface INSRenderModelType : NSObject<NSCopying, NSMutableCopying>

/// Creating an object, help you to decide which displayType you should use. And you can motify any param after this. Remember that some param you still need to set a value to it explicitly.
/// - Parameters:
///   - asset: asset
///   - displayType: one of INSDisplayType, but when you input INSDisplayTypeAuto, INSDisplayTypeSphereAuto, or INSDisplayTypePlaneAuto, which are special.
///     INSDisplayTypeAuto will return an render-model-type object, whose displayType could be any one of INSDisplayType, and is most suitable.
///     INSDisplayTypeSphereAuto will return one of .sphereStitch\.equirectangular\.fisheyeDewarp. However, return .plane if the file CANNOT play in a sphere-like render model, this will NOT cause an NSError, so you'd better check the displayType we create for you.
///     INSDisplayTypePlaneAuto will return one of .planeStitch\.planeEquirectangular\ .planeFisheyeDewarp. And alse, renturn .plane if if the file CANNOT play in a plane-stitch-like render model and no error throw.
///   - offsetConvertOption: if you want to convert offset that asset passed to some special type, like waterproof, you can give this param a value.
///   - error: if any error has been thrown, the instance will return defaultRenderModelType, and you could use +defaultRenderModelType to create a plane render model type.
+ (instancetype)resolveRenderModelTypeWithAsset:(INSAsset*)asset
                                    displayType:(INSDisplayType)displayType
                            offsetConvertOption:(INSOffsetConvertOption * _Nullable)offsetConvertOption
                                          error:(NSError *_Nullable * _Nullable)error;


/// create a plane render model type.
+ (instancetype)defaultRenderModelType;

/// 禁用的原因是，防止用户胡乱配置，rendermodeltype只配置displayType是没有用的，必须有配套的配置，所以必须使用上述类方法构造对象
- (instancetype)init NS_UNAVAILABLE;

//- (void)setProjectionDesc:(int) projectionType panoWidth:(int) panoWidth baseCubeWidthExtend:(int) baseCubeWidthExtend width:(int)width;

@property (nonatomic) INSProjectionDesc* projectionDesc;

@property (nonatomic) INSDisplayType displayType;

@property (nonatomic) INSDisplayType secondaryDisplayType;

/**
 * @brief 如果你通过resolveRenderModelTypeWithAsset方法生成一个RenderModelType对象，那么无需设置Offset，内部会自动解析出Asset中各个版本的offset
 * @warning 后续改属性会改为readonly，这里赋值操作**并不能决定**内部用哪个版本的offset，内部永远会优先使用v3 v2版本，除非使用preferOffsetV2V3 = false 来使用offsetV1. 这个属性也只返回当前使用的offset，并不是外部设置的什么，就会返回什么
 * @warning 如果 offset 空，会清除内部的拼接状态，会出错。
 * @warning **待定** 如果外部通过抽帧识别，需要使用保护镜、防水壳、潜水壳的转换，则在resolveRenderModelTypeWithAsset时，配置正确的offsetConvertOption
 */
@property (nonatomic, nullable) NSString *offset;

//@property (nonatomic, nullable, readonly) NSString *offsetV1;
//
//@property (nonatomic, nullable, readonly) NSString *offsetV2;
//
//@property (nonatomic, nullable, readonly) NSString *offsetV3;

/// 默认为true，此时依次使用 V3 > V2 > V1
@property (nonatomic) BOOL preferOffsetV2V3;

//             if (子弹时间素材) {
//                  size_t  samplsCount = samples 个数； (主要是检测到x4的单路双轨)
//                  if (samplesCount == 2) {
//                      layout 设置为 Respective2Images；
//                  }else {
//                      layout 设置为 bullettime
//                  }
//            } else {
//                  size_t  samplsCount = samples 个数；
//                  if (samplesCount == 2) {
//                      layout 设置为 Respective2Images；
//                  }else {
//                      layout 设置为 HorizontalMerged
//                  }
//             }
@property (nonatomic) INSImageLayout imageLayout;

@property (nonatomic) INSImageLayout secondaryStreamImageLayout;

@property (nonatomic) INSPlaneContentMode contentMode;

/// 开启flowstate计算拼接map，消除rollingshutter，一般应该为YES，默认NO
@property (nonatomic) BOOL preferDynamicVertex;

/// 区分动态拼接 、光流拼接、AI拼接，动态拼接一般用于预览，默认为动态拼接
@property (nonatomic) INSOpticalFlowType opticalFlowType;

/// 区分动态拼接的模式，按照Video\Image\Template区分，默认为Undefined，一般不能使用默认值，会有拼接缝问题
@property (nonatomic) INSDynamicStitchType dynamicStitchType;

@property (nonatomic) int dynamicStitchAccuracyLevel;

@property (nonatomic) INSColdShoeType coldShoeType;

/// 是否开启异步拼接，不强制要求帧和map同步，错几帧也是允许的。
/// 默认为NO，如果预览性能跟不上的情况下，可以开启来提高拼接map计算的使用效率
@property (nonatomic) BOOL asyncStitch;

/// 多少帧更新计算1次动态拼接 map，interval间隔越大，处理越快，效果越差
/// 0 或者负数表示取快速
/// 默认为0
@property (nonatomic) int stitchInterval;

@property (nonatomic) BOOL dynamicStitchDroneFlag;

@property (nonatomic) INSStitchModeOfDIS stitchModeOfDIS;

@property (nonatomic) BOOL beltImgIntensityAdjust;

/// 用于模板拼接， 用户可设置，用来覆盖默认的根据镜头类型获取的默认融合角度。
@property (nonatomic) float customTemplateStitchBlendAngle;

/// AI底部光流精度， 0代表低精度，1代表中精度，2代表高精度，**当前AI底部高精度需求仅需要配置1**
/// 默认为：INSAIFlowBottomPrecisionLow，表示关闭。 log for ’ai bottom precision:‘
@property (nonatomic) INSAIFlowBottomPrecision aiFlowBottomPercision;

/// 近景拼缝波动优化 是否开启
/// 默认为：NO，表示关闭。log for 'expand flow work region:'
@property (nonatomic) BOOL expandFlowWorkRegion;

/// 计算纹理时，是否采用盒采样进行像素滤波; negtive value is disable box filter. If 0, bmg will calc a size inside automatically.
/// 对清晰度要求不高的情况下（如缩略图），建议设置为负数，来关闭这个降低性能的行为；一般情况，可以设置为0，内部来计算；特殊需求可以设置为其他正值
@property (nonatomic) float fixedBoxFilteringSize;

/// 当 _fixedBoxFilteringSize = 0 时生效，自动计算盒采样时，是否会把内部计算的值转为一个int，默认会进行转换。设置为SCALE_FACTOR_ACCURATE表示保留浮点形式
@property (nonatomic) INSAutoBoxFilteringMethod autoBoxFilteringMethod;

/**
 * @brief set plane model type rotation degree
 */
@property (nonatomic) int planeRotationDegree;

/**
 * @brief 消色差，set image fusion enable or not
 * @note image fusion and color adjust \b MUST not be true at same time. NOT support
 */
@property (nonatomic) BOOL colorFusion;

/**
 * @brief set color adjust enable or not
 * @details vaild with lens type:ONEX_WATERPROOF,AKIKO_FISHEYE577_PROTECT,ONEXS_FISHEYE577_PROTECT
 * 只有这几种保护镜才开启、且必须开启，否则拼接效果会有问题。（即使打开了colorFusion，也需要打开colorAdjust）
 * 对于不属于上述保护镜的素材，同时开启colorFusion与colorAdjust会导致黑屏。
 * 用于拼接的offset，不能是原始offset，应该是设备转换后的。
 * @note color adjust and image fusion \b MUST not be true at same time
 */
@property (nonatomic) BOOL colorAdjust;

/**
 * @brief 577 fisheye standup/vertical battery, 竖拍电池
 * see extra_info/extra_metadata_keys kBatteryType or INSExtraMetadata‘s INSCameraBatteryType
 */
@property (nonatomic) BOOL blendAngleOptimize;

/**
 * @brief 导出设置为false，预览时设置为true，默认false
 */
@property (nonatomic) BOOL blendRealTimeRunning;

/**
 * 用于拼接算法的流程，默认为  radians(6.0) 即0.104720f,  ios设置为radians(4) 即 0.0698131
 */
@property (nonatomic) float blendAngleRad;

@property (nonatomic) BOOL useExternalMap;
/**
 * @brief enable or disable secondary stream support. Default value is false. 副码流
 * NOTE: While secondary stream enabled, rendermodel will create two render object, one for main stream,
 * one for secondary stream. This will consume more resource,
 * so, please enable this ONLY while the file has secondary stream,
 * and the player will push both frames from main stream and secondary stream
 */
@property (nonatomic) BOOL secondaryStreamEnable;

@property (nonatomic) INSHWAccelFlag hwAccelFlag;

@property (nonatomic) INSPovMode povModel;

/// 单鱼眼图片黑色背景属性 YES表示超出图片范围背景会设置为黑色
/// 之前还存在一个enableOutOfImageColorClear属性 表示X3的自拍模式、
/// 子弹时间将多余的部分显示黑色，但是在新的bmg渲染迁移框架中默认开启的
/// 不需要再单独设置
@property (nonatomic) BOOL singleFisheyeImageBlackBackground;

/// 手电筒模式
@property (nonatomic) BOOL touchMode;

@property (nonatomic) NSString* cameraType;

@property (nonatomic) NSString* modelPath;

@property (nonatomic) BOOL coolingCase;

/// 消黑边算法属性 范围限制X3 X3所有机型 设置为true
@property (nonatomic) BOOL dynamicAlphaFlag;

@property (nonatomic) BOOL usingFisheyeMask;

/// X系列（X3开始有、X4沿用）**单鱼眼的子弹时间、跟拍模式**都应该设置为true。也就是双鱼眼的文件，各有一半的有效内容，一定设置为true
/// isSelfieVideo或者isHalfFisheyeBulletTime 为true时，这个值应该true，目前你不用关心他的配置，CoreMedia内部帮忙设置了
@property (nonatomic) BOOL isHalfFisheye;

/// X系列（X3开始有、X4沿用）的**跟拍文件**，则应该设置为true，否则影响拼接效果，如果你用resolveRenderModelTypeWithAsset生成的话，那么数值应该是正确的
/// 可以通过文件尾的metadata字段：INSExtraMetadata.subMediaType 为INSSubMediaTypeVideoSelfie 或者 assetInfo.isX3Selfie (这里虽然命名为X3，但是X4也是这个逻辑)
/// **此时halfFisheye 也应该应该为true**
@property (nonatomic) BOOL isSelfieVideo;

/// X系列（X3开始有、X4沿用）的**单球子弹时间**，则应该设置为true，如果你用resolveRenderModelTypeWithAsset生成的话，那么数值应该是正确的
/// 可以通过INSExtraMetadata.subMediaType 为INSSubMediaTypeVideoBulletTime或者assetInfo.isBulletTimeVideo， 并且是X3、X4的素材
///   if (assetInfo.isBulletTimeVideo.value_or(false) && (assetInfo.captureCameraName.value_or("") == InstaCamera::X3->Name() || assetInfo.captureCameraName.value_or("") == InstaCamera::X4->Name()))
/// **此时halfFisheye 应该为true**
@property (nonatomic) BOOL isHalfFisheyeBulletTime;

/// 默认100，对于**8k的素材** **导出**，需要配置为200
@property (nonatomic) uint32_t sphereSlicesNum;

/// 默认50，对于**8k的素材** **导出**，需要配置为100
@property (nonatomic) uint32_t sphereStacksNum;

/// 开启水平矫正 矫正mp4视频的水平视角位置  设置INSHorizontalCorrector给渲染模型后 可以在更新渲染模型时设置该开关 无需重新创建INSHorizontalCorrector
@property (nonatomic) BOOL enablePlaneHorizonCorrect;
/// 用于配置无防抖时的额外旋转，对齐到防抖关效果
@property (nonatomic) BOOL dngCorrection;

@property (nonatomic) BOOL enableCloudDirectionLock;


/// 用于全帧自动识别算法，用于统计数据买点
@property (nonatomic) BOOL stitchClassifyFlag;
@end



#pragma -mark Extension for INSRenderModelType
@interface INSRenderModelType (Extension)
/// 不直接覆写属性的getter方法，因为上层希望拿到当前设置的值，
/// 而不是bmg的真实值，真实值通过getBMGXXX的方法获取
- (INSDisplayType)getBMGDisplayType;
- (nullable NSString *)getBMGOffset;
- (nullable NSString *)getBMGOffsetV1;
- (nullable NSString *)getBMGOffsetV2;
- (nullable NSString *)getBMGOffsetV3;
- (BOOL)getBMGPreferOffsetV2V3;
- (int)getBMGPlaneRotationDegree;
- (float)getBMGfixedBoxFilteringSize;
- (INSAutoBoxFilteringMethod)getBMGAutoBoxFilteringMethod;
- (BOOL)getBMGSecondaryStreamEnable;
- (INSImageLayout)getBMGImageLayout;
- (INSImageLayout)getBMGSecondaryStreamImageLayout;
- (BOOL)getBMGPreferDynamicVertex;
- (INSDynamicStitchType)getBMGDynamicStitchType;
- (INSHWAccelFlag)getBMGHwAccelFlag;
- (BOOL)getBMGAsyncStitch;
- (int)getBMGStitchInterval;
- (INSColdShoeType)getBMGColdShoeType;
- (int)getBMGDynamicStitchAccuracyLevel;
- (BOOL)getDynamicStitchDroneFlag;
- (BOOL)getBMGColorFusion;
- (BOOL)getBMGColorAdjust;
- (BOOL)getBMGBlendAngleOptimize;
- (BOOL)getBMGBlendRealTimeRunning;
- (INSStitchModeOfDIS)getBMGStitchModeOfDIS;
- (BOOL)getBMGBeltImgIntensityAdjust;
- (INSOpticalFlowType)getBMGOpticalFlowType;
- (INSPlaneContentMode)getBMGContentMode;
- (float)getBlendAngleRad;
- (INSPovMode)getPovModel;
- (BOOL)getBMGSingleFisheyeImageBlackBackground;
- (BOOL)getBMGIsHalfFisheye;
- (BOOL)getBMGIsSelfieVideo;
- (BOOL)getBMGIsHalfFisheyeBulletTime;

/// model category
- (INSDisplayTypeGroup)getBMGDisplayGroup;
/// default camera face
- (INSRenderModelCameraFace)getBMGDefaultCameraFace;
/// whether current type requires offset
- (BOOL)getBMGRequiedOffset;
- (BOOL)getBMGUseExternalMap;
/**
 * @brief check whether the lens offset is compatible with the render model type
 * @details compitible means it just can render, \n
 *          won't trigger assertion because of lens count less than the required lens count of the render model \n
 *          type must be resolved type(not SPHERE_AUTO or PLANE_AUTO), otherwise it will return false
 */
- (BOOL)isOffsetCompatible:(NSString *)offset;
- (BOOL) getTorchMode;
- (NSString*) getModelPath;
- (NSString*) getCameraType;
- (BOOL) getCoolingCase;
- (BOOL)getBMGDynamicAlphaFlag;
- (BOOL)getBMGUsingFisheyeMask;
- (nullable NSError *)IsValid;

- (BOOL)getBMGDynamicAlphaFlag;
- (BOOL)getBMGUsingFisheyeMask;

- (uint32_t)getBMGSphereSlicesNum;
- (uint32_t)getBMGSphereStacksNum;

- (INSAIFlowBottomPrecision)getBMGAIFlowBottomPrecision;
- (BOOL)getBMGExpandFlowWorkRegion;

- (BOOL)getEnablePlaneHorizonCorrect;

- (BOOL)getBMGDngCorrection;

- (BOOL)getEnableCloudDirectionLock;

- (BOOL)getStitchClassifyFlag;

@end


































// TODO: 挪走挪走
typedef bool (^INSIfHasRecognizeAtPointCallback)(CGPoint);
@interface INSSphereModelCameraControllerParam : NSObject
@property (nonatomic) INSIfHasRecognizeAtPointCallback judgeRecognizeCallback;
@property (nonatomic) INSIfHasRecognizeAtPointCallback judgeRecogCameraCallback;
@property (nonatomic) INSIfHasRecognizeAtPointCallback judgeRecogIsMultivewCellCallback;
@property (nonatomic) INSRenderType insRenderType;
@property (nonatomic) INSViewInteractiveMode insInteractiveMode;
@property (nonatomic) INSGyroSlipType insGyroSlipType;
@property (nonatomic) INSEyePointManager *insEyePointManager;
@property (nonatomic) INSVisionField *insVisionField;
@end

NS_ASSUME_NONNULL_END
