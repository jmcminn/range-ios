//
//  INSExtraMetadata.h
//  INSCoreMedia
//
//  Created by zeng bin on 5/2/17.
//  Copyright © 2017 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "INSMediaGps.h"
#import "INSMediaGyro.h"
#import "INSMediaOrientation.h"
#import "INSMediaEuler.h"
#import "INSMediaCropWindow.h"
//#import "INSFilter.h"
#import "INSFilterType.h"
#import "INSGyroType.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef INSTA360_CAMERA_NAMES
#define INSTA360_CAMERA_NAMES

/// name of insta360 Nano
extern NSString *const kInsta360CameraNameNano;

/// name of insta360 ONE
extern NSString *const kInsta360CameraNameOne;

/// name of insta360 Nano S
extern NSString *const kInsta360CameraNameNanoS;

/// name of insta360 One2(OneX)
extern NSString *const kInsta360CameraNameOne2;

/// name of insta360 EVO
extern NSString *const kInsta360CameraNameEVO;

/// name of insta360 Wearable/Go
extern NSString *const kInsta360CameraNameGo;

/// name of insta360 Akiko/OneR
extern NSString *const kInsta360CameraNameOneR;

/// name of insta360 OneX2
extern NSString *const kInsta360CameraNameOneX2;

/// name of insta360 OneH
extern NSString *const kInsta360CameraNameOneH;

/// name of insta360 Go 2
extern NSString *const kInsta360CameraNameGo2;

/// name of insta360 OneRS
extern NSString *const kInsta360CameraNameOneRS;

/// name of Invisible Drone 360 Camera (Sphere)
extern NSString *const kInsta360CameraNameSphere;

/// name of insta360 X3
extern NSString *const kInsta360CameraNameX3;

/// name of insta360 go3
extern NSString *const kInsta360CameraNameGo3;

/// name of insta360 go3 s
extern NSString *const kInsta360CameraNameGo3S;

/// name of insta360 go3 se
extern NSString *const kInsta360CameraNameGo3SE;

/// name of insta360 Ace
extern NSString *const kInsta360CameraNameIAC1;

/// name of insta360 X4
extern NSString *const kInsta360CameraNameX4;
#endif
/// name of insta360 Lite
extern NSString *const kInsta360CameraNameLite;

/// name of insta360 Ace2
extern NSString *const kInsta360CameraNameIAC2;

/// name of insta360 Ace3
extern NSString *const kInsta360CameraNameIAC3;


typedef NS_ENUM(NSUInteger, INSPhotoHDRState) {
    INSPhotoHDRStateNotHDR = 0,
    INSPhotoHDRStateNeedProcess = 1,
    INSPhotoHDRStateProcessed = 2,
};

typedef NS_ENUM(NSUInteger, INSTriggerSource) {
    INSTriggerSourceUnknown = 0,
    INSTriggerSourceCameraButton = 1,
    INSTriggerSourceRemoteControl = 2,
    INSTriggerSourceUSB = 3,
    INSTriggerSourceBtRemote = 4,
};

typedef NS_ENUM(NSUInteger, INSExtraLogoType) {
    INSExtraLogoTypeUnknown = 0,
    INSExtraLogoTypeNoLogo = 1,
    INSExtraLogoTypeInstaLogo = 2,
};

typedef NS_ENUM(NSUInteger, INSSubMediaType) {
    INSSubMediaTypeVideoNormal = 0,
    INSSubMediaTypeVideoBulletTime = 1,
    INSSubMediaTypeVideoTimelapse = 2,
    INSSubMediaTypePhotoNormal = 3,
    INSSubMediaTypePhotoHdr = 4,
    INSSubMediaTypePhotoIntervalShooting = 5,
    INSSubMediaTypeVideoHdr = 6,
    INSSubMediaTypePhotoBurst = 7,
    INSSubMediaTypeVideoStaticTimelapse = 8,
    INSSubMediaTypeVideoTimeshift = 9,
    INSSubMediaTypePhotoAebNightMode = 10,
    INSSubMediaTypeVideoSuperNormal = 11,
    INSSubMediaTypeVideoLooprecording = 12,
    INSSubMediaTypePhotoStarlapse = 13,
    INSSubMediaTypePhotoPanoMode = 14,
    INSSubMediaTypeVideoFpv = 15,
    INSSubMediaTypeVideoMovie = 16,
    INSSubMediaTypeVideoSlowMotion = 17,
    INSSubMediaTypeVideoSelfie = 18,//是一种特殊的视频格式，并不意味着是反插视频
    INSSubMediaTypePhotoPureShotPlus = 19,//PureShotPlus 图片
    INSSubMediaTypeVideoPure = 20,
    INSSubMediaTypeVideoStarLapse = 21,//星空延时
    INSSubMediaTypePhotoStartrail = 22,
    INSSubMediaTypeVideoDashCam = 23,   //行车记录仪
};

typedef NS_ENUM(NSUInteger, INSOffsetConvertState) {
    INSOffsetConvertStateWaterProof = 0,
    INSOffsetConvertStateDivingWater,
    INSOffsetConvertStateDivingAir,
    INSOffsetConvertStateStitchOptimization,
    INSOffsetConvertStateProtect,// 保护壳, one r新增
    INSOffsetConvertStateSphereProtect,
    INSOffsetConvertStateFpvProtect,
    INSOffsetConvertStateVer2DivingWater,
    INSOffsetConvertStateVer2DivingAir,
    INSOffsetConvertStateOneX3FisheyeSphereProtectPlasticCement, // x3塑胶壳
    INSOffsetConvertStateOneX3FisheyeSphereProtectGlass,    //x3玻璃壳
    INSOffsetConvertStateOneX3AverageShell,   // X3 A/S平均曲线
    INSOffsetConvertStateSphereProtectClass, //玻璃保护镜
    INSOffsetConvertStateSpherePlasticCement, //塑胶保护镜
    INSOffsetConvertStateAverageShell, // 平均曲线
    
};

typedef NS_ENUM(NSUInteger, INS3DCameraEVOMode) {
    INS3DCameraEVOModeUnknown = 0,
    INS3DCameraEVOModeDegree180,
    INS3DCameraEVOModeDegree360,
};

typedef NS_ENUM(NSUInteger, INSGPSSource) {
    INSGPSSourceGSV = 0,
    INSGPSSourceDashboard,
    INSGPSSourceRemote,
};

typedef NS_ENUM(NSUInteger, INSCameraBatteryType) {
    INSCameraBatteryTypeThick = 0,  // 薄电池
    INSCameraBatteryTypeThin = 1, // 厚电池
    INSCameraBatteryTypeVertical = 2, // 竖拍电池
};

typedef NS_ENUM(NSUInteger, INSCameraPosture) {
    INSCameraPosture0 = 0,
    INSCameraPosture90 = 1,
    INSCameraPosture180 = 2,
    INSCameraPosture270 = 3,
};

typedef NS_ENUM(NSUInteger, INSImageFovType) {
    INSImageFovTypeUnknown = 0,
    INSImageFovTypeWide = 1,
    INSImageFovTypeLinear = 2,
    INSImageFovTypeUltrawide = 3,
    INSImageFovTypeNarrow = 4,
    INSImageFovTypePov = 5,
    INSImageFovTypeLinearPlus = 6,
    INSImageFovTypeLinearHorizontal = 7,
    INSImageFovTypeFpv = 8,
    INSImageFovTypeSuper = 9,
    INSImageFovTypeTinyPlanet = 10,
    INSImageFovTypeInfinityWide = 11,
    INSImageFovTypeLinearhorizon360 = 12,
    INSImageFovTypeMaxView = 13,
    INSImageFovTypeDewarp = 14,
    INSImageFovTypeMegaView = 15,
    INSImageFovTypeBullteTime = 16,
    INSImageFovTypeNum = 17,
};

typedef NS_ENUM(NSUInteger, INSFWGyroStabMode) {
    INSFWGyroStabModeUnknown = 0,
    INSFWGyroStabModeBrute = 1,
    INSFWGyroStabModeAkf = 2,
};

typedef NS_ENUM(NSUInteger, INSSensorDeviceType) {
    INSSensorDeviceTypeUnknown = 0,
    INSSensorDeviceTypeFront = 1,
    INSSensorDeviceTypeRear = 2,
    INSSensorDeviceTypeAll = 3,
};

typedef NS_ENUM(NSUInteger, INSExpectOutputType) {
    INSExpectOutputTypeDefault = 0,
    INSExpectOutputTypeInstaPano = 1,
    INSExpectOutputTypeMultiCamera = 2,
    INSExpectOutputTypeOneTake = 3,
};

typedef NS_ENUM(NSUInteger, INSAudioModeType) {
    INSAudioModeTypeUnknown = 0,
    INSAudioModeTypeFocus = 1,
    INSAudioModeTypeStereo = 2,
    INSAudioModeTypeCircle360 = 3,
    INSAudioModeTypeRsStere0 = 4,
    INSAudioModeTypeExtmicdev = 5,
    INSAudioModeTypeAirpoddev = 6,
    INSAudioModeTypeReserve1 = 7,
    INSAudioModeTypeReserve2 = 8,
};

typedef NS_ENUM(NSUInteger, INSRawCaptureType) {
    INSRawCaptureTypeOff = 0,
    INSRawCaptureTypeDNG = 1,
    INSRawCaptureTypeRAW = 2,
    INSRawCaptureTypePureshot = 3,
    INSRawCaptureTypePureshotRaw = 4,
};

typedef NS_ENUM(NSUInteger, INSVideoPtsMapType) {
    //default case, should use decoder with fisrt frame timestamp
    INSVideoPtsMapTypeUnknown = 0,
    //decoder with fisrt-frame-timestamp
    INSVideoPtsMapTypeDecoderWithFFT = 1,
    //reading in exposure data, finding with the decode-time\frame-index as well
    INSVideoPtsMapTypeReadingInExposureFile = 2,
};

typedef NS_ENUM(NSUInteger, INSLens283MType) {
    INSLens283MTypeUnknown = 0,
    INSLens283MTypeLowTransparency = 1,
    INSLens283MTypeHighTransparency = 2,
};

typedef NS_ENUM(NSUInteger, INSPBMetaOffsetState) {
    /** 无外置镜 */
    INSPBOffsetStateCommon = 0,
    
    /** 黏贴式球面镜 */
    INSPBOffsetStateSphereProtect = 1,
    
    /** 潜水壳水下 */
    INSPBOffsetStateDivingWater = 2,
    
    /** 23年新潜水壳水下 */
    INSPBOffsetState_DivingWaterVer23 = 3,
    
    /** X4 塑胶保护镜(A) */
    INSPBOffsetState_SpherePlasticCement = 4,
    
    /** X4 玻璃保护镜(S) */
    INSPBOffsetState_SphereProtectClass = 5,
    
    /**  自动识别 */
    INSPBOffsetState_AllProtectAuto = 6,
};

typedef NS_ENUM(NSUInteger, INSTimeScaleX) {
    INSTimeScale1X = 0,
    INSTimeScale4X = 1,
    INSTimeScale8X = 2,
    INSTimeScale1_4X = 3,
    INSTimeScale1_8X = 4,
};

typedef NS_ENUM(NSUInteger, INSHdrProcessType) {

    INSHdrProcessTypeExternal = 0,
    INSHdrProcessTypeInner = 1,
};

typedef NS_ENUM(NSUInteger, INSThumbnailType) {

    INSThumbnailTypeUnknown = 0,
    INSThumbnailTypeYuv = 1,
    INSThumbnailTypeJpeg = 2,
    INSThumbnailTypeH264 = 3,
};

typedef NS_ENUM(NSUInteger, INSPureShotProcessType) {
    
    INSPureShotProcessTypeExternal = 0,
    INSPureShotProcessTypeInner = 1,
};

typedef NS_ENUM(NSUInteger, INSSceneProtoType) {
    
    INSSceneTypeUnknown = 0,
    INSSceneTypeUnderWater= 1,
};

typedef NS_ENUM(NSUInteger, INSReprocessingType) {
    
    INSReprocessingTypeUnknown = 0,
    INSReprocessingTypeInside = 1,
};

typedef NS_ENUM(NSUInteger, INSWaterMarkType) {
    INSWaterMarkTypeUnknow = 0,
    INSWaterMarkTypeOff = 1,
    INSWaterMarkTypeOn = 2,
};


typedef NS_ENUM(NSUInteger, INSPanoRecordType) {
    INSPanoRecordTypeUnknown = 0,
    INSPanoRecordTypeSplitFile = 1,
    INSPanoRecordTypeMultiTrack = 2,
};

typedef NS_ENUM(NSUInteger, INSPanoRecordMultiTrackOrder) {
    INSPanoRecordTrackOrderUnknown = 0,
    INSPanoRecordTrackOrderTrack0Stream10 = 1,
    INSPanoRecordTrackOrderTrack0Stream00 = 2,
};

typedef NS_ENUM(NSUInteger, INSThumbnailStitchType) {
    INSThumbnailStitchTypeUnknown = 0,
    INSThumbnailStitchTypeOriginal = 1,
    INSThumbnailStitchTypeStitched = 2,
};

typedef NS_ENUM(NSUInteger, INSImageStitchType) {
    INSImageStitchTypeUnknown = 0,
    INSImageStitchTypeOriginal = 1,
    INSImageStitchTypeStitched = 2,
};

typedef NS_ENUM(NSUInteger, INSOnlineFlowstateLevel) {
    
    INSOnlineFlowstateLevelUnknow = 0,
    INSOnlineFlowstateLevelStandard = 1,
    INSOnlineFlowstateLevelHigh = 2,
    INSOnlineFlowstateLevelLow = 3,
    INSOnlineFlowstateLevelOff = 4,
};

typedef NS_ENUM(NSUInteger, INSFileSplitType) {
    
    INSFileSplitTypeUnknow = 0,
    INSFileSplitTypeNotSplit = 1,  //未分段
    INSFileSplitTypeSplitted = 2,   //已分段

};

typedef  NS_ENUM(NSInteger, INSGuardDetectedType) {
    INSGuardDetectedTypeUnknow = 0,
    INSGuardDetectedTypeA = 1,
    INSGuardDetectedTypeS = 2,
    INSGuardDetectedTypeOff = 3,
    INSGuardDetectedTypeAS = 4, /** AS平均 */
};

typedef NS_ENUM(NSInteger, INSCoolingShellSelectedState) {
    INSCoolingShellSelectedStateUnknow = 0,
    INSCoolingShellSelectedStateAuto = 1,
    INSCoolingShellSelectedStateOn = 2,
    INSCoolingShellSelectedStateOff = 3,
};

typedef NS_ENUM(NSInteger, INSCoolingShellAlgoDetectedState) {
    INSCoolingShellAlgoDetectedStateUnknow = 0,
    INSCoolingShellAlgoDetectedStateOn = 1,
    INSCoolingShellAlgoDetectedStateOff = 2,
};

typedef NS_ENUM(NSInteger, INSAISwitchState) {
    INSAISwitchStateUnknow = 0,
    INSAISwitchStateOff = 1,
    INSAISwitchStateOn = 2,
};

typedef NS_ENUM(NSInteger, INSResolutionType) {
    INSResolutionTypeUnknow = 0,
    INSResolutionTypePlus = 1,
};

@interface INSDynamicGyroAccRangeInfo : NSObject

@property (nonatomic) double accelerometerRange;

@property (nonatomic) double gyrovelocitymeterRange;

@end



@interface INSFrameRateAVRational : NSObject

@property (nonatomic, readwrite) uint32_t num;

@property (nonatomic, readwrite) uint32_t den;

@end

typedef NS_ENUM(NSInteger, INSFolderType) {
    INSFolderTypeUnknow = 0,
    INSFolderTypeIntervalVideo=1,//间隔录像
};

@interface INSFolderInfo : NSObject
@property (nonatomic) INSFolderType type;
@property (nonatomic) uint32_t index; //当前是第i个素材
@property (nonatomic) NSString* identify;//表示当前素材是属于那一组的间隔录像
@property (nonatomic) uint32_t maxNum;//表示这组间隔录像有多少个视频片段
@end

typedef NS_ENUM(NSInteger, INSAiPlatform) {
  INSAiPlatform_Cv5 = 0,
  INSAiPlatform_Cv22 = 1,
  INSAiPlatform_H22 = 2,
};

typedef NS_ENUM(NSInteger, INSAiAlgorithm) {
  INSAiAlgorithm_Single = 0,
  INSAiAlgorithm_Pano = 1,
};

typedef NS_ENUM(NSInteger, INSAutoClipDataStorage) {
  INSAutoClipDataStorage_StorageTypeNormal = 0,
  INSAutoClipDataStorage_StorageTypeLoop = 1,
};

@interface INSAiLibVersion : NSObject

@property(nonatomic, readwrite) uint32_t major;

@property(nonatomic, readwrite) uint32_t minor;

@property(nonatomic, readwrite) uint32_t patch;

@end


@interface INSAutoClipVersion : NSObject

@property(nonatomic) INSAiPlatform platform;

@property(nonatomic) INSAiAlgorithm algorithm;

@property(nonatomic, nullable) INSAiLibVersion *modelVer;
/** Test to see if @c modelVer has been set. */
@property(nonatomic) BOOL hasModelVer;

@property(nonatomic, nullable) INSAiLibVersion *svcVer;
/** Test to see if @c svcVer has been set. */
@property(nonatomic) BOOL hasSvcVer;

@end

@interface INSAutoClipVideoInfo : NSObject
@property(nonatomic) INSAutoClipVersion *version;
@property(nonatomic) BOOL hasVersion;
@property(nonatomic) float sampleRate;
@property (nonatomic) int imgW;
@property (nonatomic) int imgH;
@property(nonatomic) uint32_t imgPitch;
@property(nonatomic) INSAutoClipDataStorage autoclipDataStorage;
@property (nonatomic) double fps;
@property (nonatomic) int seqDiff;
@property (nonatomic) int ptsDiff;
@property (nonatomic) int totalFrame;
@property(nonatomic) uint32_t resumeNum;
@property(nonatomic, nullable) NSArray<NSNumber *> *lastFrameIdArray;  // int
@property(nonatomic) NSUInteger lastFrameIdArray_Count;
@property(nonatomic) uint32_t directionSeqDiff;
@property(nonatomic) int64_t firstCapPts;
@end

@interface INSExtraMetadata : NSObject<NSCopying, NSMutableCopying>

/**
 *  version
 */
@property (nonatomic) NSInteger version;

/**
 *  v1，offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *offset;

/**
 *  v1，原始的offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *originalOffset;

/**
 *  v2，offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *offsetV2;

/**
 *  v2，原始的offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *originalOffsetV2;

/**
 *  v3，offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *offsetV3;

/**
 *  v3，原始的offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *originalOffsetV3;

/**
 *  v6，offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *offsetV6;

/**
 *  v6，原始的offset参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *originalOffsetV6;

/**
 *  serialNumber参数，可以为nil
 */
@property (nullable, nonatomic, copy) NSString *serialNumber;

/**
 *  gps参数，可以为nil
 */
@property (nullable, nonatomic) INSMediaGps *gps;

/**
 *  gyro参数， 可以为nil，所有数据应为标准坐标系下的数据（Nano 正常使用时为标准）
 */
@property (nullable, nonatomic) INSMediaGyro *gyro;


/**
 * 文件中携带的一组陀螺仪裸数据，是未经任何旋转转换的gyro（后面的版本会删除）
 */
@property (nullable, nonatomic) NSData *mediaGyroData;

/**
 *  orientation参数， 可以为nil
 */
@property (nullable, nonatomic) INSMediaOrientation *orientation;

/**
 *  滤镜，无滤镜时返回 INSFilterTypeNull
 */
@property (nonatomic) INSFilterType filterType;

/**
 *  滤镜比例，如果滤镜是lut表实现，该值记录滤镜效果所占的比重，0.0f~1.0f,如果不是lut文件生成的滤镜，或者未被修改过，默认值为-1.0
 */
@property (nonatomic) CGFloat filterScale;

/**
 *  美颜滤镜，无滤镜时返回 INSFilterTypeNull
 */
@property (nonatomic) INSFilterType beautifyFilterType;

/**
 *  新版调色滤镜, 多个滤镜用 "\n" 进行分隔，格式为 "filter1_parameter1\nfilter2_parameter2"
 */
@property (nullable, nonatomic) NSString *adjustFilters;

/**
 *  lut 调色, 默认返回 INSFilterTypeNull, 无滤镜时返回INSFilterType3DLutOff
 */
@property (nonatomic) INSFilterType lutFilterType;

/**
 欧拉角，可以为nil
 */
@property (nullable, nonatomic) INSMediaEuler *euler;


/**
 去除紫边
 */
@property (nonatomic) BOOL removePurple;


/**
 陀螺仪防抖类型
 */
@property (nonatomic) INSGyroPlayMode gyroPlayMode;

/**
 *  创建时间, GMT时间
 */
@property (nullable, nonatomic, strong) NSDate *createDate;

/**
 *  文件的导出时间, GMT时间
 */
@property (nullable, nonatomic, strong) NSDate *exportTime;

/// 相机类型
@property (nullable, nonatomic, copy) NSString *cameraType;

/// 固件版本
@property (nullable, nonatomic, copy) NSString *fwVersion;

/// 文件类型, insp、insv文件默认无，导出jpg、mp4文件值为"stitch", 依此判断文件类型
@property (nullable, nonatomic, copy) NSString *fileType;

/// ip
@property (nullable, nonatomic, copy) NSString *ip;

/// 文件大小
@property (nonatomic) uint64_t fileSize;

/// 时长, 照片为0
@property (nonatomic) uint32_t totalTime;

/// 精确时长Ms
@property (nonatomic) uint32_t totalTimeMs;

/// 是否为HDR 照片，且是否已经拼接
@property (nonatomic) INSPhotoHDRState hdrState;

/// 如果hdrState 为INSPhotoHDRStateNeedProcess，则需根据hdrIdentifier 来区分不同组合的照片
@property (nullable, nonatomic) NSString *hdrIdentifier;

/// 触发来源，相机按键、USB、远程遥控器等
@property (nonatomic) INSTriggerSource triggerSource;

/// 图像的尺寸
@property (nonatomic) CGSize dimension;

/// 视频帧率, 照片应该设置为0. (e.g. 30, 60, 120)
@property (nonatomic) NSInteger frameRate;

/// 后得到图像与原始图像的偏移 (如120 fps 的视频，为 (0, 24))
@property (nonatomic) CGPoint imageTranslate;

/// "linear", "log"，如果为空，认定为"linear"
@property (nullable, nonatomic) NSString *gammaMode;

@property (nonatomic) int32_t thumbnailGyroIndex;

@property (nonatomic) int64_t thumbnailGyroTimestamp;

@property (nonatomic) INSExtraLogoType logoType;

/// 第一帧对应的相机系统时间，单位 ms
@property (nonatomic) double firstFrameTimestamp;

// 对应分辨率rolling shutter时间
@property (nonatomic) double rollingShutterTime;

//file group info
@property (nonatomic) INSSubMediaType fileGroupSubMediaType;

//file group info
@property (nonatomic) uint32_t fileGroupSubMediaIndex;

//file group info
@property (nonatomic) uint32_t fileGroupSubMediaTotal;

//file group info
@property (nullable, nonatomic) NSString *fileGroupSubMediaIdentify;

// crop window
@property (nullable, nonatomic) INSMediaCropWindow *cropWindow;

// 对应分辨率的gyro timestamp
@property (nonatomic) double gyroTimestampAdjust;

// 是否支持gyro timestamp
@property (nonatomic) BOOL hasGyroTimestampAdjust;

// indicate which type the current `offset` is converted from. see INSOffsetConvertState, 仅对v1版本的offset有效
@property (nullable, nonatomic) NSMutableSet<NSNumber *> *offsetConvertStates;

// timelapse 文件每帧的拍摄间隔, 单位:秒
@property (nonatomic) double timelapseInterval;

// 陀螺仪矫正数据，上层无需关心，故使用裸数据类型，添加至此是为了防止文件尾写回到文件时这部分数据丢失
@property (nullable, nonatomic) NSData *gyroCalib;

// 3D相机折叠状态, 非3D相机为unknown
@property (nonatomic) INS3DCameraEVOMode evoStatusMode;

// 3d相机折叠状态ID，用时间戳表示:YYYYMM HHMMSS
@property (nullable, nonatomic) NSString *evoStatusId;

// 3d相机平铺状态下的初始offset
@property (nullable, nonatomic) NSString *originalOffset3D;

// gps数据来源，可为多个. 见INSGPSSource
@property (nullable, nonatomic) NSMutableSet<NSNumber *> *gpsSources;

// 第一帧视频对应的UTC时间戳，表示的是世界时间，可以用来定位GPS数据位置
@property (nonatomic) double firstGpsTimestamp;

// orientationCalib参数, 可以为nil, go才有
@property (nullable, nonatomic) INSMediaOrientation *orientationCalib;

// 文件是否在app收藏夹 go才有
@property (nonatomic) BOOL isCollected;

/**
 *  文件回收日期, GMT时间, go才有
 */
@property (nullable, nonatomic, strong) NSDate *recycleDate;

// 视频文件总帧数, go才有
@property (nonatomic) uint32_t frameNumber;

// 音频轨道数量
@property (nonatomic) uint32_t audioTrackNum;

// 屏幕与镜头朝相同的方向, 该值为true; 反之为false
@property (nonatomic) BOOL lensSelfies;

// 是否机内防抖 YES:是  NO:否. One R 才有
@property (nonatomic) BOOL isFlowstateOnline;

// 在做机内防抖时，是否进行了畸变矫正
@property (nonatomic) BOOL isDewarp;

// 分辨率的尺寸，该尺寸并不是文件的真实尺寸，而是用户最终通过渲染或者导出时宽高信息. 如，在用户设置16:9时，实际上生成文件的demension(4000,3000)，此时该变量则为(3840,2160). OneR才有
@property (nonatomic) CGSize resolutionSize;

// 577鱼眼需要知道电池类型: 厚电池、薄电池、竖拍电池. One R 才有
@property (nonatomic) INSCameraBatteryType batteryType;

// 相机的姿态，旋转量. One R 才有
@property (nonatomic) INSCameraPosture cameraPosture;

// 图像视角类型，视频与图片文件都存在. One R才有
@property (nonatomic) INSImageFovType fovType;

// 固件调延迟时间使用的防抖模式
@property (nonatomic) INSFWGyroStabMode fwGyroStabMode;

// One X2才有
@property (nonatomic) INSSensorDeviceType sensorDevice;

// One X2才有
@property (nonatomic) INSExpectOutputType expectedOutput;

// 标记文件尾中PB文件记录的timelapse interval 时间戳单位是否为ms，为了解决历史遗留问题
@property (nonatomic) BOOL timelapseIntervalInMillisecond;

// repeated float photo_rot = 60;    // 保存拍照时刻照片的旋转量，用于本机回放使用

// AudioModeType = 61
@property (nonatomic) INSAudioModeType audioMode;

///是否为2khz陀螺仪数据
@property (nonatomic) BOOL isRawGyro;

/// raw模式拍摄的子格式
@property (nonatomic) INSRawCaptureType rawCaptureType;

/// 推荐使用的不同时间戳映射机制，可能需要在解码时间戳与获取防抖矩阵的时间戳做一次映射。当（videoPtsMapType == .readingInExposureFile）
@property (nonatomic) INSVideoPtsMapType videoPtsMapType;

/// 加速度计与角速度计的量程信息
@property (nonatomic, nullable) INSDynamicGyroAccRangeInfo *dynamicGyroAccRange;

@property (nonatomic) INSLens283MType lens283MType1;

@property (nonatomic) INSLens283MType lens283MType2;

@property (nonatomic) INSPBMetaOffsetState offsetState;

@property (nonatomic) double playTrimRecommendTimestamp;
//慢动作倍速
@property (nonatomic) INSTimeScaleX timeScale;

@property (nonatomic) INSHdrProcessType hdrProcessType;

@property (nonatomic) INSThumbnailType thumbnailType;

@property (nonatomic) INSPureShotProcessType pureShotProcessType;

@property (nonatomic) INSSceneProtoType sceneType;

@property (nonatomic) BOOL isCuttingThumbnail;

@property (nonatomic) INSReprocessingType reprocessingType;
// 水印
@property (nonatomic) INSWaterMarkType waterMarkType;

@property (nonatomic) BOOL preRecTime;

@property (nonatomic) INSFrameRateAVRational* frameRateAvRational;

///  视频轨道数量
@property (nonatomic) int32_t videoTrackCount;

///  视频轨道顺序翻转
@property (nonatomic) BOOL reverseVideoTrackOrder;

///全景录像类型
@property (nonatomic) INSPanoRecordType panoRecordType;

///全景多轨录像轨道顺序
@property (nonatomic) INSPanoRecordMultiTrackOrder panoRecordMultiTrackOrder;

///缩略图拼接类型
@property (nonatomic) INSThumbnailStitchType thumbnailStitchType;

///机内已拼接字段
@property (nonatomic) INSImageStitchType imageStitchType;

@property (nonatomic) INSOnlineFlowstateLevel onlineFlowstateLevel; // 在线防抖等级

@property (nonatomic) BOOL bHighLightEidted; ////标记编辑过高光信息

@property (nonatomic) INSFileSplitType fileSplitType;  //文件是否分段

@property (nonatomic) BOOL hasAutoClipPara;

@property (nonatomic) INSAutoClipVideoInfo* videoInfo;  //自动成片相关参数

/** 收藏标记 */
@property(nonatomic, readwrite) BOOL bFavorite;

/** 用于识别文件是否被修改过，修改+1 */
@property(nonatomic, readwrite) uint32_t editVersion;

/** 用于识别经过续录的文件*/
@property(nonatomic, readwrite) BOOL bContinueRecord;

/** 经过暂停的文件 */
@property(nonatomic, readwrite) BOOL bPausedRecord;

@property(nonatomic) double bFov;

@property(nonatomic) double bDistance;
/* 自拍手电筒模式*/
@property(nonatomic, readwrite) BOOL bTorchMode;

/** 保护镜自动识别结果, offset_states 为 auto 时有效 */
@property(nonatomic) INSGuardDetectedType guardDetectedType;

/** 散热壳手动设置状态 */
@property(nonatomic) INSCoolingShellSelectedState coolingShellSelectedState;

/** 散热壳算法识别结果 */
@property(nonatomic) INSCoolingShellAlgoDetectedState coolingShellAlgoDetectedState;

/** AI高光开关状态 */
@property(nonatomic) INSAISwitchState aiSwitchState;

/** 是否是 5.7k+ 分辨率标识 */
@property(nonatomic) INSResolutionType resolutionType;

/**间隔录像*/
@property(nonatomic, nullable) INSFolderInfo* folderInfo;
@end

NS_ASSUME_NONNULL_END
