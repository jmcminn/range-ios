//
//  INSPlayerImageQueue.h
//  INSCoreMedia
//
//  Created by ruiwen feng on 2023/3/1.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

@protocol INSCallbackSetupImageMapProtocol;
@class INSPlayerImage;

@interface INSPlayerImageQueue : NSObject

/// 是否开启并行计算优化map
@property (nonatomic, assign) BOOL enableParallelSetupMaps;

/// 并行计算的delegate，需要向上层获取配置信息-《透传》
@property (nonatomic, weak)   id <INSCallbackSetupImageMapProtocol> mapSetDelegate;

@property (nonatomic, assign) NSUInteger maxCount;
/// 清除内部缓存的cache
- (void)cleanMapCache;

- (NSArray *)array;

- (NSUInteger)count;

- (void)removeAllObjects;

/// 提前缓存map
- (void)preCacheMap:(int)clipNums;

- (INSPlayerImage *)firstObject;

/// 推出缓存队首元素，可能为空
- (nullable INSPlayerImage *)popFirstPlayerImage;

- (void)addObject:(nullable INSPlayerImage *)playerImage;

- (void)addObjectNoDiscard:(nullable INSPlayerImage *)playerImage;

- (INSPlayerImageQueue *)newINSPlayerImageQueue;

- (void)removeObjectAtIndex:(NSUInteger)index;

- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(INSPlayerImage * playImage, NSUInteger idx, BOOL *stop))block;


@end

NS_ASSUME_NONNULL_END
