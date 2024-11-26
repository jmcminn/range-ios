//
//  INSDecoderInfo.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2022/6/29.
//  Copyright © 2022 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface INSDecoderInfo : NSObject
@property (nonatomic, assign) int clipIndex;
@property (nonatomic, assign) int partIndex;
@property (nonatomic, assign) int optionalFlag;
@property (nonatomic, assign) bool enableVideoHwaccel;
@property (nonatomic, assign) bool copyVideoHwaccel;
@property (nonatomic, assign) int codecId;
- (instancetype)initWithClipIndex:(int)clipIndex partIndex:(int)partIndex optionalFlag:(int)optionalFlag enableVideoHwaccel:(bool)enableVideoHwaccel copyVideoHwaccel:(bool)copyVideoHwaccel codecId:(int)codecId;
@end

NS_ASSUME_NONNULL_END
