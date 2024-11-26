//
//  INSBitmapData.h
//  INSCoreMedia
//
//  Created by pengwx on 2018/11/24.
//  Copyright © 2018年 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@class UIImage;
@interface INSBitmapData : NSObject
@property (nonatomic, assign) BOOL invalid;
@property (nonatomic, copy) NSString * uid;
@property (nonatomic) int width;
@property (nonatomic) int height;
@property (nonatomic) int colorType;
@property (nonatomic, strong, nullable) NSData *colorData;
@property (nonatomic, strong, nullable) UIImage *image;

@end


NS_ASSUME_NONNULL_END
