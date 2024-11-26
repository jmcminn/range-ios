//
//  MapSetupKit.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2023/3/7.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@protocol INSCallbackSetupImageMapProtocol;
@class INSPlayerImage;
@interface INSMapSetupKit : NSObject

@property (nonatomic, weak) id <INSCallbackSetupImageMapProtocol> mapSetDelegate;

- (void)preCacheMap:(int)clipNums;

- (void)cleanMapCache;

- (void)playImageMapsSetup:(INSPlayerImage *)playImage;

@end

NS_ASSUME_NONNULL_END
