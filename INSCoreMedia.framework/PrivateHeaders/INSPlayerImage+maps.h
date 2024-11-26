//
//  INSPlayerImage+maps.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2023/3/2.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <INSCoreMedia/INSCoreMedia.h>
#import "INSFusionMap.h"
#import "INSStitchingMap.h"
NS_ASSUME_NONNULL_BEGIN

@interface INSPlayerImage (maps)
@property (nonatomic, strong) INSFusionMatData * fusionMapData;
@property (nonatomic, strong) INSStitchingMatData * stitchingMapData;
@end

NS_ASSUME_NONNULL_END
