//
//  INSAsset.h
//  INSCoreMedia
//
//  Created by Jormungand on 2023/2/9.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>


#import "INSExtraGPSData.h"
#import "INSExtraAAAData.h"
#import "INSExtraTimeMapperData.h"
#import "INSExtraSpeedData.h"
#import "INSExtraTboxData.h"
#import "INSAssetInfo.h"
#import "INSExtraGyroData.h"
#import "INSExtraInfoParser.h"
#import "INSDemuxerInfo.h"
#import "INSExtraMetadata.h"
#import "INSQuaternionData.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSAssetParserOption){
    ExtraNone = 0,
    ExtraMetadata = 1 << 0,
    ExtraThumbnail = 1 << 2,
    ExtraGyro = 1 << 3,
    ExtraExposure = 1 << 4,
    
    Exif = 1 << 8,
    XMP = 1 << 9,
    
    Demux = 1 << 16,
    
    ExtraInfo = ExtraMetadata | ExtraThumbnail | ExtraGyro | ExtraExposure,
    ImageAll = ExtraInfo | Exif,
    VideoAll = ExtraInfo | XMP | Demux,
    All = ExtraInfo | Exif | XMP | Demux
};

typedef NSString* INSExtraMetadataKey;

///@brief ExtraInfo 写入的 'key' 值 VideoAsset/ImageAsset 可以共同使用
typedef NS_ENUM(NSInteger,INSExtraInfoFrameType)
{
	INSExtraInfoFrameTypeMetadata  			= 0x01,		/// extraMetadata
	INSExtraInfoFrameTypeThumbnail 			= 0x02,		/// extraThumbnailData
	INSExtraInfoFrameTypeGyro				= 0x03,		/// extraGyroData
	INSExtraInfoFrameTypeExposure			= 0x04,		/// extraExposureData
	INSExtraInfoFrameTypeThumbnailExt		= 0x05,		/// extraThumbnailExtData
	INSExtraInfoFrameTypeTimelapseTimestamp = 0x06,		/// extraTimelaposeData
	INSExtraInfoFrameTypeGps				= 0x07,		/// extraGPSData
	INSExtraInfoFrameTypeStarNum			= 0x08,		/// extraGPSStarNumData
	INSExtraInfoFrameTypeAAA				= 0x09,		/// extraAAAData
	INSExtraInfoFrameTypeAnchors 			= 0x0a,		/// extraAnchorsData
	INSExtraInfoFrameTypeAAASimulation		= 0x0b,		/// extraAAASimulationData
	INSExtraInfoFrameTypeExposureSecondary	= 0x0c,		/// extraSecondaryExposureData
	INSExtraInfoFrameTypeMagnetic			= 0x0d,
	INSExtraInfoFrameTypeEuler				= 0x0e,
	INSExtraInfoFrameTypeGyroSecondary		= 0x0f,		/// extraSecondaryGryoData
	INSExtraInfoFrameTypeSpeed				= 0x10,		/// extraSpeedData
	INSExtraInfoFrameTypeTBox				= 0x11,		/// extraTboxData
    INSExtraInfoFrameTypeEditor             = 0x12,     /// extraEditorData
    
	INSExtraInfoFrameTypeMap				= 0x80,
};

/// @brief Metadata 写入的 'key' 值 VideoAsset/ImageAsset 可以共同使用
///        这里不一定是所有的属性都支持修改写入
/// @brief bool 对应App NSNumber
extern INSExtraMetadataKey kINSIsSelfie;   						/// 屏幕与镜头朝相同的方向, 该值为true; 反之为false
extern INSExtraMetadataKey kINSIsFlowstateOnline;				/// 是否机内防抖 YES:是  NO:否. One R 才有
extern INSExtraMetadataKey kINSIsDewarp;					    /// 在做机内防抖时，是否进行了畸变矫正
extern INSExtraMetadataKey kINSIsRawGyro;						/// 是否为2khz陀螺仪数据
extern INSExtraMetadataKey kINSRemovePurple;					///	去除紫边
/// @brief string 对应App NSString
extern INSExtraMetadataKey kINSSerialNumber;					/// serialNumber参数，可以为nil
extern INSExtraMetadataKey kINSCameraType;						///	相机类型
extern INSExtraMetadataKey kINSFwVersion;						/// 固件版本
extern INSExtraMetadataKey kINSFileType;						/// 文件类型, insp、insv文件默认无，导出jpg、mp4文件值为"stitch", 依此判断文件类型
extern INSExtraMetadataKey kINSOffset;							/// v1，offset参数，可以为nil
extern INSExtraMetadataKey kINSOriginalOffset;					/// v1，原始的offset参数，可以为nil
extern INSExtraMetadataKey kINSIp;								/// ip
extern INSExtraMetadataKey kINSHdrIdentifier;					/// 如果hdrState 为INSPhotoHDRStateNeedProcess，则需根据hdrIdentifier 来区分不同组合的照片
extern INSExtraMetadataKey kINSGammaMode;						/// "linear", "log"，如果为空，认定为"linear"
extern INSExtraMetadataKey kINSFilter; 							/// 滤镜，无滤镜时返回 INSFilterTypeNull
extern INSExtraMetadataKey kINSBeautifyFilter;		 			/// 美颜滤镜，无滤镜时返回 INSFilterTypeNull
extern INSExtraMetadataKey kINSAdjustFilters;					///  *  新版调色滤镜, 多个滤镜用 "\n" 进行分隔，格式为 "filter1_parameter1\nfilter2_parameter2"
extern INSExtraMetadataKey kINSLutFilter;						///  lut 调色, 默认返回 INSFilterTypeNull, 无滤镜时返回INSFilterType3DLutOff
extern INSExtraMetadataKey kINSFileGroupInfoIdentify;			///  file group info  ???? 不一定正确
extern INSExtraMetadataKey kINSEvoStatusId;						/// 3d相机折叠状态ID，用时间戳表示:YYYYMM HHMMSS
extern INSExtraMetadataKey kINSOriginalOffset3d;				/// 3d相机平铺状态下的初始offset
extern INSExtraMetadataKey kINSOffsetV2;						/// v2，offset参数，可以为nil
extern INSExtraMetadataKey kINSOffsetV3;					    /// v3，offset参数，可以为nil
extern INSExtraMetadataKey kINSOriginalOffsetV2;				/// v2，原始的offset参数，可以为nil
extern INSExtraMetadataKey kINSOriginalOffsetV3;				/// v3，原始的offset参数，可以为nil

/// @brief unit64 对应App NSNumber
extern INSExtraMetadataKey kINSCreateTime;						/// 创建时间, GMT时间
extern INSExtraMetadataKey kINSExportTime;						/// 文件的导出时间, GMT时间
extern INSExtraMetadataKey kINSFileSize;						/// 文件大小
/// @brief int64 对应App NSNumber
extern INSExtraMetadataKey kINSFirstFrameTimestamp;				/// 第一帧对应的相机系统时间，单位 ms
extern INSExtraMetadataKey kINSFirstGpsTimestamp;				/// 第一帧视频对应的UTC时间戳，表示的是世界时间，可以用来定位GPS数据位置
/// @brief uint32对应App NSNumber
extern INSExtraMetadataKey kINSTotalTime;						/// 时长, 照片为0
extern INSExtraMetadataKey kINSTimelapseInterval;				/// timelapse 文件每帧的拍摄间隔, 单位:秒
extern INSExtraMetadataKey kINSTotalFrames;						/// 视频文件总帧数, go才有
extern INSExtraMetadataKey kINSGroupInfoIndex;					/// NULL 暂时没有注释
extern INSExtraMetadataKey kINSGroupInfoTotal;					/// NULL 暂时没有注释

/// @brief int32 对应Enum枚举类型
extern INSExtraMetadataKey kINSHdrState;						/// 是否为HDR 照片，且是否已经拼接
extern INSExtraMetadataKey kINSTriggerSource;					/// 触发来源，相机按键、USB、远程遥控器等
extern INSExtraMetadataKey kINSFrameRate;						/// 视频帧率, 照片应该设置为0. (e.g. 30, 60, 120)
extern INSExtraMetadataKey kINSLogoType;						/// Logo类型
extern INSExtraMetadataKey kINSFileSubMediaType;				/// file group info
extern INSExtraMetadataKey kINSEvoStatusMode;					/// 3D相机折叠状态, 非3D相机为unknown
/// @brief int 对应Enum枚举类型
extern INSExtraMetadataKey kINSBatteryType;						/// 577鱼眼需要知道电池类型: 厚电池、薄电池、竖拍电池. One R 才有
extern INSExtraMetadataKey kINSCameraPosture;					/// 相机的姿态，旋转量. One R 才有
extern INSExtraMetadataKey kINSFovType;							/// 图像视角类型，视频与图片文件都存在. One R才有
extern INSExtraMetadataKey kINSGyroFilterType;					/// 滤镜，无滤镜时返回 INSFilterTypeNull
extern INSExtraMetadataKey kINSExpectOutputType;				/// One X2才有
extern INSExtraMetadataKey kINSFocusSensor;						/// One X2才有
extern INSExtraMetadataKey kINSAudioMode;						/// AudioModeType = 61 声音模式
extern INSExtraMetadataKey kINSRawCaptureType;					/// raw模式拍摄的子格式
extern INSExtraMetadataKey kINSVideoPtsType;					/// 推荐使用的不同时间戳映射机制，可能需要在解码时间戳与获取防抖矩阵的时间戳做一次映射。当（videoPtsMapType == .readingInExposureFile）
extern INSExtraMetadataKey kINSOffsetState;						/// 外置镜头类型
extern INSExtraMetadataKey kINSPureShotProcessType;             /// Pureshot类型


/// @brief vec2 对应App NSValue
extern INSExtraMetadataKey kINSResolutionSize;					/// 分辨率的尺寸，该尺寸并不是文件的真实尺寸，而是用户最终通过渲染或者导出时宽高信息. 如，在用户设置16:9时，实际上生成文件的demension(4000,3000)，此时该变量则为(3840,2160). OneR才有

/// @brief INSMediaGyro
extern INSExtraMetadataKey kINSGyro;							/// gyro参数， 可以为nil，所有数据应为标准坐标系下的数据（Nano 正常使用时为标准）
/// @brief INSMediaGps
extern INSExtraMetadataKey kINSGps;								/// gps参数，可以为nil
/// @brief INSMediaOrientation
extern INSExtraMetadataKey kINSOrientation;						/// orientation参数， 可以为nil
/// @brief CGSize 对应App NSValue
extern INSExtraMetadataKey kINSDimension;						/// 图像的尺寸
/// @brief CGPoint 对应 App NSValue
extern INSExtraMetadataKey kINSImageTranslate;					/// 后得到图像与原始图像的偏移 (如120 fps 的视频，为 (0, 24))
/// @brief 这里对应的是 metadata 中的两个参数 thumbnailGyroIndex 和thumbnailGyroTimestamp
/// 	   推荐 App修改的时候一起修改 {thumbnailGyroIndex,thumbnailGyroTimestamp}
extern INSExtraMetadataKey kINSThumbnailGyroInfo;
/// @brief INSMediaEuler
extern INSExtraMetadataKey kINSEuler;							/// 欧拉角，可以为nil
/// @brief INSMediaCropWindow
extern INSExtraMetadataKey kINSWindowCropInfo;					/// crop window
/// @brief vector数据
extern INSExtraMetadataKey kINSGpsSource;						/// gps数据来源，可为多个. 见INSGPSSource
/// @brief INSDynamicGyroAccRangeInfo-> 数组
extern INSExtraMetadataKey kINSGyroConfigInfo;
/// @brief uint32 音频轨道数
extern INSExtraMetadataKey kINSAudioTrackNum;
/// @brief int 水印
extern INSExtraMetadataKey kINSWaterMarkType;



@interface INSAsset : NSObject

/// @brief 通过bmg的INSAsset重构Extra数据的解析方法 直接在基类中定义property 子类中重写getter方法
///  	   a、一部分是OC层已经定义好对应的数据结构 这部分我们直接进行转换即可.
///  	   b、一部分需要直接返回二进制数据给App 他们自己进行三方工具或者是协议解.
///  	   c、一部分因为暂时不会使用到 所以同样 返回二进制数据 这部分以后在进行处理.

@property (nullable,nonatomic) INSExtraMetadata* extraMetadata;

@property (nullable,nonatomic) INSExtraGPSData* extraGPSData;

@property (nullable,nonatomic) INSExtraAAAData* extraAAAData;

@property (nullable,nonatomic) INSExtraTimeMapperData* extraTimeMapperData;

@property (nullable,nonatomic) INSExtraTboxData* extraTboxData;

@property (nullable,nonatomic) INSExtraEditorData* extraEditorData;

@property (nullable,nonatomic) NSData* extraSpeedData;

@property (nullable,nonatomic) NSData* extraGPSStarNumData;

@property (nullable,nonatomic) NSData* extraThumbnailData;

@property (nullable,nonatomic) NSData* extraThumbnailExtData;

@property (nullable,nonatomic) NSData* extraTimelaposeData;

@property (nullable,nonatomic) NSData* extraAnchorsData; 		///HIGHLIGHT 

@property (nullable,nonatomic) NSData* extraAAASimulationData;

@property (nullable,nonatomic) NSData* extraExposureData;

@property (nullable,nonatomic) NSData* extraGyroData;

@property (nullable,nonatomic) NSData* extraSecondaryExposureData;
 
@property (nullable,nonatomic) NSData* extraSecondaryGryoData;

@property (nullable,nonatomic) NSData* extraShellRecognitionData;    //用于壳识别数据

@property (nullable,atomic) INSQuaternionData* extraQuaternionData;  /// 用于TC2水平矫正
///
@property (nonatomic,assign) int64_t mediaFileSize; /// 去除文件尾的媒体文件长度, 单位：字节

@property (nonatomic,assign) int64_t totalFileSize; /// 文件总尺寸，包括文件尾在内, 单位：字节

/// @brief INSImageAsset/INSVideoAsset 获取bmg提取的公共的AssetInfo的数据 这部分数据可能和具体的
///        比如demuxerInfo Xmp Exif数据重复 ，需要在使用的时候注意辨别数据来源。
- (nullable INSAssetInfo *)getAssetInfo;

/// @brief http图片支持缓存加载 二次加载的时候可以设置这个缓存路径加快
/// TODO: 测试http的缓存加载是否生效 和性能相关
- (NSString *)getCacheDir;


/// @brief setNewExtraInfoVersion 默认使用的 Version3的文件尾
- (void) setNewExtraInfoVersion;

// GetSize系列接口，用于判断数据是否为空
- (size_t) getGyroDataSize;

- (size_t) getExposureDataSize;

- (size_t) getThreeADataSize;

- (size_t) getEditorDataSize;

- (size_t) getThreeASimulationDataSize;

- (size_t) getForwardDirectionDataSize;

- (size_t) getUpviewDataSize;

- (size_t) getShellRecognitionDataSize;

- (size_t) getAnchorsDataSize;

- (size_t) getThumbnailDataSize;

- (size_t) getThumbnailExtDataSize;

- (size_t) getTimelapseDataSize;

- (size_t) getGpsDataSize;

- (size_t) getStarNumDataSize;

- (size_t) getSecondaryExposureDataSize;

- (size_t) getSecondaryGyroDataSize;

- (size_t) getSpeedDataSize;

- (size_t) getTBoxDataSize;

- (size_t) getTimeMapDataSize;


#pragma mark 将单个extrainfo数据写入到当前的 asset 中去 ｜ 此时并非是整体 ALLIN 写入 而是单个属性分别写入
/// @attention  都是对当前的 asset 文件进行操作/且必须已经调用 open 后操作
/// @note 	如果是给一个(egg: trim下载)全新文件，本身不带文件尾信息的文件写入 需要先调用 setNewExtraInfoVersion写入文件尾版本 (default = version3)
///         如果是给当前的 asset 文件 修改 某个 extra 数据后写回 ，直接调用即可
/// @param 	extraType 写入的数据的数据类型
/// @param 	data 待写入的文件尾数据， 该数据的可能是其他文件的文件尾数据， 也可能是修改当前某个数据
/// @return YES/NO 是否写入成功
- (BOOL) writeExtraInformationSelf:(INSExtraInfoFrameType) extraType data:(NSData*) data;


#pragma mark 将单个metadata数据写入到当前的 asset 中去 ｜ 此时并非是整体 ALLIN 写入 而是单个属性分别写入
/// @attention  都是对当前的 asset 文件进行操作/且必须已经调用 open 后操作
/// @note 这里是修改当前的 Metadata 中的某些值
/// @param metadataKey 写入的 metadata 的 key
/// @param value 写入的 metadata 数据 | '(BOOL值类型)' | '(NSString值类型)'等等
/// @return YES/NO 是否写入成功
- (BOOL) writeMetadataInformationSelf: (NSString*) metadataKey value:(id) value;


///@breif 调用该接口将metadata 的写回永久写入到磁盘中 ｜ 仅仅针对 Metadata 数据
///		  这个接口是一个比较耗时的接口，所以建议是最后一次性调用
- (void) writeMetadataInformationSave;


/// @brief 调用这个接口会清理🧹INSAsset持有的属性资源 防止内存过高
-(void) resetExtraInfoData:(INSExtraInfoFrameType) type;


+ (nullable INSExtraInfo *)extraInfoWithAsset:(INSAsset *)asset;

@end

NS_ASSUME_NONNULL_END
