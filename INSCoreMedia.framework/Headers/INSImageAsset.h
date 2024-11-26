//
//  INSImageAsset.h
//  INSCoreMedia
//
//  Created by Jormungand on 2023/2/9.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSImageXmp.h"
#import "INSImageExif.h"
#import "INSAsset.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, ImageAssetDataType){
    ImageAssetDataTypeJPEG,
    ImageAssetDataTypePNG,
};

typedef NS_ENUM(NSInteger,ImageAssetErrorCode){
    ImageAssetSuccess = 0,
    ImageAssetParserError = -1001,
    ImageAssetGetInfoInfoError = - 1002,
};


#pragma mark - INSImageAsset

@class INSAssetInfo;
@interface INSImageAsset : INSAsset

@property (nonatomic, strong, nullable) INSImageXmp *xmp;
@property (nonatomic, strong, nullable) INSImageExif *exif;


/// ImageAssetInitFunction 下面是提供三种INSImageAsset初始化方法
/// a、[initWithImageUrl]  支持传入本地和远程的图片的URL 且https的支持使用缓存 推荐使用缓存 bmg 二次加载耗时短
/// b、[initWithImageData] 支持传入解包后的图片数据 需要传入图片的宽和高
/// c、[initWithUIImage]   支持传入UIImage图片数据 需要指定图片类型type和compression:
///                 compression:  Please note that using JPEG format allows you to control the compression quality (from 0.0 to 1.0).
///                               A lower compression quality value will result in higher image quality and larger file size,
///                               while a higher value will reduce the image quality but result in a smaller file size.
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithImagePath:(NSString *)imagePath cacheDir:( NSString* _Nullable )cacheDir;
- (instancetype)initWithImageData:(NSData*)imageData;
- (instancetype)initWithUIImage:(UIImage *)image ouputType:(ImageAssetDataType)type compression:(CGFloat)compression defaultExifXmp:(BOOL)defaultExifXmp;
- (instancetype)initWithImageUrl:(NSURL *)imageUrl cacheDir:( NSString* _Nullable )cacheDir DEPRECATED_MSG_ATTRIBUTE("Please use -initWithImagePath:cacheDir");;

/// @brief 同INSVideoAsset一样 open
- (NSError* _Nullable)open;

/// @brief 将对xmp和exif的修改重写入 并获取修改后的数据 (getImageData)
- (NSData* _Nullable) rewriteModification;


/// @brief 两种copy函数，支持从 NSData形式的图像变量 及 另一个 INSImageAsset 拷贝
/// @note 调用后需要调用 save 保存修改操作
- (void)copyMetaDataFromData:(NSData*)data;
- (void)copyMetaDataFromOther:(INSImageAsset*) other;

@end

NS_ASSUME_NONNULL_END
