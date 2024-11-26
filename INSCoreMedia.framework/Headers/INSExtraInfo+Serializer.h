//
//  INSExtraInfo+Serializer.h
//  INSCoreMedia
//
//  Created by zeng bin on 5/3/17.
//  Copyright © 2017 insta360. All rights reserved.
//
#import "INSExtraInfo.h"
#import "INSExtraProtobufInfo.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSExtraInfoProcessError) {
    // 文件尾内容错误
    INSExtraInfoContentErrorCode = -1,
    // 运行时出错
    INSRuntimeErrorCode = -2,
    // 文件尾解析错误
    INSExtraInfoParseErrorCode = -3,
    // 访问文件错误
    INSFileAccessErrorCode = -4,
};

extern const NSErrorDomain kINSExtraInfoErrorDomain;

extern const int kINSEstimateExtraInfoRequiredLen;

extern const int kV3MaxParseExtraInfoLen;

@interface INSExtraInfo (Serializer)

/**
 *  扩展数据，gyro数据 + metadata数据 + thumb + thunbExt + gps + frame pts + 3a + highlight
 */
@property (nonatomic, strong, readonly) NSData *extraData;

/**
 *  使用extraInfo数据来初始化对象
 *  @param data extraInfo数据
 *  @return 如果data数据是一个完整的extrainfo数据，返回实例对象，否则返回nil
 */
- (nullable instancetype)initWithExtraInfoData:(NSData *)data;

/**
 *  使用去除gyro data的extraInfo数据初始化
 *  @param data extraInfo数据
 *  @param gyroFileInfo 陀螺仪数据在文件中必要信息
 */
- (nullable instancetype)initWithExtraInfoData:(NSData *)data gyroFileInfo:(INSExtraGyroFileInfo *)gyroFileInfo;


/// 当前extraInfo写入指定文件
/// @param filePath 目标文件
/// @param shouldFix 是否进行文件尾修复
- (NSError* _Nullable) writeToFile:(NSString *)filePath fixContentData:(BOOL)shouldFix;

/**
 *  根据很少的文件尾数据来估计文件尾的总长度，不一定是真实长度。
 *
 *  @param data 文件的尾部数据，100 字节即可
 *
 *  @return 如果成功则返回对整个extraInfo的估计长度，返回-1 表示不包含文件尾数据
 *
 */
+ (int)estimateExtraInfoLen:(NSData *)data;

/**
 *  获取video扩展数据的长度，包括uuid等
 *  @param data 文件的尾部数据，必须不小于40个字节
 *  @return 如果成功则返回整个extraInfo的长度，否则返回-1
 */
+ (int)getExtraInfoLen:(NSData *)data;


/**
 写入extra数据，（仅支持本地文件）
 @param filePath 文件完整路径名
 @param data 需要写入替换的数据
 @return 成功返回YES，失败返回NO
 */
+ (BOOL)writeExtraDataToFile:(NSString *)filePath data:(NSData *)data;

/// compose extrainfos inputed, then write to a dst file, replacing the origin extrainfo of the dst file.
/// the property in INSExtraInfo, gyroData\exposureData\framePtsData\gpsData\gpsStarNumData\aaaData\highLightData will be composed into the result extrainfo.
/// @param filePath 目标视频
/// @param extraInfos 文件尾信息集合，顺序必须保持一致
/// @param primaryInfo 用来确认最终文件尾数据使用的 metadata\thumbnail\ext_thumbnail，如果设置为nil，则使用extraInfos中第一个元素
/// @return NO failed, YES success
+(BOOL)writeExtraDataToFile:(NSString *)filePath
                 extraInfos:(NSArray<INSExtraInfo *> *)extraInfos
                primaryInfo:(INSExtraInfo * _Nullable)primaryInfo;

/// nano1 only
+ (INSExtraProtobufInfo *)parseV2PBInfoWithData:(NSData *)data cursor:(NSInteger *)cursor;

/// nano1 only
- (NSData *)protobufData;

///nano1 only
- (NSData *)getExtraJsonData;

/// @brief 该函数不是开放给应用层使用的，而是供 INSVideoAsset 中 open 函数生成 extraInfo 之后调用该函数进行二次解析
/// @param result - 一次解析的结果，INSVideoAsset 中调用时传入YES 即可
/// @note 该函数是将原来
/// parseContent:(NSData *)data cursor:(NSInteger *)cursorversion:(NSInteger)version info:(INSExtraInfo *)extraInfo
/// 中的代码抽离得到的，因此当前类中仍然也要使用
+ (BOOL)parseResult:(BOOL)result info:(INSExtraInfo *)extraInfo;


/// 只通过INSExtraGyroData的构造方法，对于防抖还不够，需要把文件尾其他字段的数据也传入。以下信息虽然nullable但是不能随便传nil，必须按照实际文件尾的解析情况
/// @param gyroData 已经通过构造函数传入gyro二进制数据的INSExtraGyroData对象
/// @param metadata metadata数据
/// @param exposureData 曝光时间数据
/// @param framePtsData Timelapse\Timeshift文件的时间戳映射数据
/// @param timeMapperData 多段下载素材的时间映射数据
+ (void)configGyroData:(INSExtraGyroData *)gyroData metadata:(INSExtraMetadata *)metadata exposureData:(NSData  * _Nullable)exposureData framePtsData:(NSData  * _Nullable)framePtsData timeMapperData:(INSExtraTimeMapperData  * _Nullable)timeMapperData;

@end

NS_ASSUME_NONNULL_END
