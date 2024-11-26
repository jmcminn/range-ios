//
//  INSImageMetadataProcessor.h
//  INSCoreMedia
//
//  Created by pengwx on 2017/10/26.
//  Copyright © 2017年 insta360. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, INSImageDataType){
    INSImageDataTypeJPEG,
    INSImageDataTypePNG,
};

@class INSImageXmp;
@class INSImageExif;

NS_ASSUME_NONNULL_BEGIN

@interface INSImageMetadataProcessor : NSObject

/// @brief 构造函数，仅根据 image 解析宽高信息并赋值给 xmp 和 exif
- (instancetype) initWithUIImage:(UIImage *)image ouputType:(INSImageDataType)type compression:(CGFloat)compression;

/// @brief 构造函数，内部调用 readImageMetadata 解析图片全部信息并赋值给 xmp 和 exif
/// @param imageData - 通过图片路径生成
- (instancetype) initWithImageData:(NSData*)imageData width:(NSUInteger)width height:(NSUInteger)height;

@property (nonatomic, strong, nullable) INSImageXmp *xmp;
@property (nonatomic, strong, nullable) INSImageExif *exif;

/// @brief 将 xmp 和 exif 中的数据写入图片
- (NSData* _Nullable) getImageData;

@end

NS_ASSUME_NONNULL_END
