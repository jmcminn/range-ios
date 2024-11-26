//
//  INSSingleHDRInfo.h
//  INSCoreMedia
//
//  Created by HFY on 2020/1/12.
//  Copyright © 2020 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN




@interface INSUnderwaterInfo : NSObject

-(instancetype)init NS_UNAVAILABLE;
-(instancetype)initLutFilePath:(NSString* _Nullable)lutPath;

@property(nonatomic)float strength;
@property(nonatomic)float balance;
@property(nonatomic, strong, readonly, nullable)NSString *lutPath;

-(BOOL)isEualInfo:(INSUnderwaterInfo*)underwaterInfo;

@end

@interface INSRealSmartMotionBlurInfo : NSObject

@property(nonatomic) bool isPano;           // 仅当滤镜输入画面为2:1全景时设置true，默认false
@property(nonatomic) float blurStrength;    // 模糊强度，默认值1.0
@property(nonatomic) float blurThresh;      // 模糊阈值，默认值1.0
@property(nonatomic) float scale;           // 用于算法图像的分辨率缩放，默认值1.0

-(BOOL)isEualInfo:(INSRealSmartMotionBlurInfo *)info;

@end

typedef NS_ENUM(NSInteger, INSDeepLearningSysType);

@interface INSColorPlusInfo :NSObject

@property (nonatomic, assign) BOOL needRefresh;

@property(nonatomic) NSString *modelPath;

@property(nonatomic) INSDeepLearningSysType sysType;

//default value 33
@property(nonatomic)int sampleSize;

//default value 0.1
@property(nonatomic)float movingAverageRatio;

//default NO
@property(nonatomic, readonly)BOOL enableLocalContrast;

// default NO 
@property(nonatomic, readonly)BOOL enableColorPlus;

// default NO
@property(nonatomic, readonly)BOOL enableExtra;

// new colorplus
@property(nonatomic, readonly)BOOL enableNewLTM;

// 后续通过更改该值可调节 colorplus 和 LTM 强度
@property(nonatomic)float colorplusLutStrength;

-(BOOL)isEualInfo:(INSColorPlusInfo*)info;

-(instancetype)init NS_UNAVAILABLE;

-(instancetype)initWithColorplus:(BOOL)colorplus localContrast:(BOOL)localContrast;

-(instancetype)initWithColorplus:(BOOL)colorplus localContrast:(BOOL)localContrast enableExtra:(BOOL)enableExtra;

/**
  * @param colorplus
  * @param localContrast ：控制LTM开关
  * @param enableExtra：全景导出时置为true，减小色差线
  * @param enableNewLTM：控制LTM的新旧版本，false为旧版，true为新版
  */
-(instancetype)initWithColorplus:(BOOL)colorplus localContrast:(BOOL)localContrast enableExtra:(BOOL)enableExtra enableNewLTM:(BOOL)enableNewLTM;

@end


@class INSMediaAAA;
@interface INSSingleDenoiseInfo : NSObject

/// default is 10
@property (nonatomic) int downSampleScale;

/// radius 导向滤波时影响的局部区域的范围，越大影响范围越大，一般设置为10的倍数，默认使用10
@property (nonatomic) int radius;

/// 用来区分局部区域是细节还是噪声，越大越最终结果模糊，一般设置为0.0001，可以设置为0.1-0.00001之间
@property (nonatomic) double eps;

/// 3A 数据，在文件尾拿到，可以解析出iso值，iso值大于isoThreshold，会开启降噪
@property (nonatomic, nullable) NSArray<INSMediaAAA *> *mediaAAA;

/// use INSExtraInfo.framePtsData
@property (nonatomic, nullable) NSData* framePtsData;

/// 当前帧的iso值大于或等于isoThreshold，才会应用降噪，默认为100; 如果设置为0，意味着一定开启
@property (nonatomic) int isoThreshold;

@end


@interface INSCartoonInfo : NSObject

@property (nonatomic, readonly) double scale;

-(instancetype)initWithScale:(double)scale;

@end


@interface INSMotionlapseInfo : NSObject

@property(nonatomic) NSString *filePath; // Json文件

@property(nonatomic) double startTimeMs;  // 起始时间

@property(nonatomic) double endTimeMs; // 终止时间

@property(nonatomic) BOOL isDebug;

- (BOOL)isEqualInfo:(INSMotionlapseInfo*)info;

@end

NS_ASSUME_NONNULL_END
