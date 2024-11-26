//
//  INSExtraTboxData.h
//  INSCoreMedia
//
//  Created by 谷瑾之 on 2023/5/6.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSExtraTimeMapperData.h"
#import "INSMediaTbox.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSExtraTboxData : NSObject

- (instancetype)initWithTboxData:(NSData *)tboxData;

@property (nonatomic, readonly) NSMutableArray<INSMediaTbox*>* tboxArrary;

@property (nonatomic,nullable) NSData* tboxRawData;

NS_ASSUME_NONNULL_END

@end
