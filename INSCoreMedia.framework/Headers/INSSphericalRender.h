//
//  INSSphericalRender.h
//  INSVideoPlayApp
//
//  Created by pwx on 28/2/16.
//  Copyright © 2016年 insta360. All rights reserved.
//


#import "INSDuplicateRender.h"

NS_ASSUME_NONNULL_BEGIN

@class INSGyroPlayer;

@interface INSSphericalRender : INSDuplicateRender

@property(nonatomic, strong, nullable) INSGyroPlayer *fakeGyroPlayer;

@end

NS_ASSUME_NONNULL_END
