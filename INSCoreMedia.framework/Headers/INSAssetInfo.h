//
//  INSAssetInfo.h
//  INSCoreMedia
//
//  Created by HFY on 2021/11/3.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

///@brief INSAssetInfo 和INSExtraMetadata存在一定程度上的重叠 但是INSExtraMetadata 有比较完整的序列化和反序列化接口
///       INSAssetInfo 中的 assetInfo 会被平台组内部使用
///	      INSAssetInfo中会存放一些INSExtraMetadata中没有的数据
/// 	  [TODO] 是否可以将INSAssetInfo其他的属性全部删除掉 使用INSExtraMetadata代替

NS_ASSUME_NONNULL_BEGIN

@class INSExtraMetadata;
typedef NS_ENUM(NSInteger ,INSGyroDeviceType)
{
	INSGyroDeviceTypeUnknown 	= -1,
	INSGyroDeviceType20948  	=  0,
	INSGyroDeviceType40609  	=  1,
};

typedef NS_ENUM(NSInteger, INSTrackOrderType) {
    INSTrackOrderTypeUnknown = 0,
    INSTrackOrderTypeStream10 = 1,
    INSTrackOrderTypeStream01 = 2,
};
@interface INSAssetInfo : NSObject

//@property(nonatomic) INSExtraMetadata *metaData; you see INSAsset.h

@property (nonatomic) BOOL isVideo;
@property (nonatomic) BOOL isInsFormat;
@property (nonatomic) BOOL isFisheye3dFormat;
@property (nonatomic) BOOL isPanoFormat;
@property (nonatomic) BOOL isBulletTimeVideo;
@property (nonatomic) BOOL isStaticTimelapseVideo;
@property (nonatomic) BOOL isLoopVideo;
@property (nonatomic) BOOL isNormalPlane;
@property (nonatomic) BOOL hasVideo;
@property (nonatomic) BOOL hasAudio;

///resolution width of the video file that recorded by **camera**
@property (nonatomic) int width;
@property (nonatomic) int height;

@property(nonatomic) double videoFramerate;
@property(nonatomic) double videoDurationS;


@property(nonatomic) double bitrate;
@property(nonatomic) double audioDurationS;

@property(nonatomic) NSString *videoCodecName;  // 视频编码 如：h264
@property(nonatomic) NSString *path;
@property(nonatomic) NSInteger gyroDataSize;
@property(nonatomic) NSInteger exposureDataSize;
@property(nonatomic) NSString *sphereMappingTypeName;
@property(nonatomic) NSString *stereo3dTypeName;
@property(nonatomic) NSInteger planeRotationDegree;

@property(nonatomic) double videoBitrate;
@property(nonatomic) double audioBitrate;

@property(nonatomic) NSInteger audioChannelCount;
@property(nonatomic) int64_t audioChannelLayout;
@property(nonatomic) NSInteger audioSampleRate;
@property(nonatomic) NSString *audioCodecName;

@property int32_t cameraLensType;
@property int32_t cameraLensVersion;
@property int32_t cameraLensCount;
@property INSGyroDeviceType gyroDeviceType;



@property(nonatomic) INSExtraMetadata *extraMetadata;


@property (nonatomic) float autoClipParamFps;
@property (nonatomic) int32_t autoClipParamTotalFrame;
@property (nonatomic) int32_t autoClipParamImgWidth;
@property (nonatomic) int32_t autoClipParamImgHeight;

@property (nonatomic) double fov;
@property (nonatomic) double distance;

@property (nonatomic) int32_t videoTrackCount;
@property (nonatomic) BOOL reverseTrackOrder;
@property (nonatomic) BOOL torchMode; // 手电筒模式

@property (nonatomic) int32_t folderType;
@property (nonatomic) uint32_t folderInfoIndex;
@property (nonatomic) NSString* folderInfoIdentify;
@property (nonatomic) uint32_t folderInfoMaxNum;

@property (nonatomic) float resolutionSizeHeight;
@property (nonatomic) float resolutionSizeWidth;

@property (nonatomic) uint32_t batteryType;
//
@end

NS_ASSUME_NONNULL_END
