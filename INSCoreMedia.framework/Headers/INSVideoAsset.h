//
//  INSVideoAsset.h
//  INSCoreMedia
//
//  Created by HFY on 2021/11/3.
//  Copyright © 2021 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSExtraInfo.h"
#import "INSAsset.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger,VideoAssetErrorCode){
    VideoAssetSuccess = 0,
    VideoAssetParserError = -1001,
    VideoAssetGetInfoInfoError = - 1002,
    VideoAssetPathNil = -1003,
};

typedef NS_ENUM(NSInteger,VideoAssetCloudVideoType){
    Original = 0,
    Agent = 1,
    StitchedPano = 2,
    Eacubemap = 3,
    CloudSingleFisheye = 4,
};


#pragma mark - INSVideoAsset
@class INSAssetInfo;
@interface INSVideoAsset : INSAsset

@property (nonatomic, readonly) NSString *path;

@property (nonatomic, readonly) INSAssetParserOption option;
 
@property (nonatomic, nullable, readonly) INSDemuxerInfo *demuxerInfo;


//@property (nullable, nonatomic, strong) INSExtraInfo *extraInfo;

- (instancetype)init NS_UNAVAILABLE;

/// 以字符串的init方法为主，依照底层接口形式，path支持三种形态：
/// 1. 视频文件的地址
/// 2. 循环录影文件的emu json文件地址
/// 3. 循环录影文件的emu json 字符串
- (instancetype)initWithPath:(NSString *)path cacheDir:(NSString * _Nullable)cacheDir option:(INSAssetParserOption)option;

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl option:(INSAssetParserOption)option DEPRECATED_MSG_ATTRIBUTE("Please use -initWithPath:cacheDir:option:");

- (instancetype)initWithVideoUrl:(NSURL *)videoUrl cacheDir:(NSString * _Nullable)cacheDir option:(INSAssetParserOption)option DEPRECATED_MSG_ATTRIBUTE("Please use -initWithPath:cacheDir:option:");

// open中已经完成了解析assetinfo和parse
- (nullable NSError *)open;


/// @brief cancel videoAsset的 open 操作对于 App 来说是耗时操作，需要支持取消 但是需要在另外一个线程调用
- (void) cancel;


-(NSData*)CopyEditorData;
-(double)GetFirstFrameTimeOffsetMs;

-(VideoAssetCloudVideoType)GetCloudVideoType;
@end

NS_ASSUME_NONNULL_END
