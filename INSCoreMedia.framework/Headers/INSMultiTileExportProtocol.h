//
//  INSMultiTileExportProtocl.h
//  INSCoreMedia
//
//  Created by zhou on 2023/11/8.
//  Copyright © 2023 insta360. All rights reserved.
//

#ifndef INSMultiTileExportProtocol_h
#define INSMultiTileExportProtocol_h

#import "INSProjectionInfo.h"
#import "INSRenderModelType.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSMultiTileCameraTransform : NSObject
@property (nonatomic) INSProjectionInfo *proj;
@property (nonatomic) int w;
@property (nonatomic) int h;
@property (nonatomic) double timestamp;
@property (nonatomic) INSRenderModelCameraFace facing;
-(void) print;
@end

@protocol INSMultiTileExportProtocol <NSObject>

- (NSMutableArray<INSMultiTileCameraTransform*>*)GetMultiTileCameraWithClipIndex: (const int)clipIndex Timestamps:(const NSMutableArray<NSNumber*> *) timestamps;  // timestamp in double
@end

NS_ASSUME_NONNULL_END

#endif /* INSMultiTileExportProtocol_h */
