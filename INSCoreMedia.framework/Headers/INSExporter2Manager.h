//
//  INSExporter2Manager.h
//  INSCoreMedia
//
//  Created by 那强 on 2023/1/3.
//  Copyright © 2023 insta360. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "INSMultiTileExportProtocol.h"
#import "INSFloatageDrawProtocol.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INSExporter2State) {
    INSExporter2StateError = -1,
    INSExporter2StateComplete = 0,
    INSExporter2StateCancel = 1,
    INSExporter2StateInterrupt = 2,
    INSExporter2StateDisconnect = 3,
    INSExporter2StateInitError = 4,
};

@class INSExporter2Session;
@class INSExporter2Manager;
@protocol INSRExporter2ManagerDelegate  <NSObject>
// In main thread
- (void)exporter2Manager:(INSExporter2Manager *)manager progress:(float)progress;

// In main thread。
- (void)exporter2Manager:(INSExporter2Manager *)manager state:(INSExporter2State)state error:(nullable NSError*)error;

// 用于全景埋点检测
- (void)exporter2Manager:(INSExporter2Manager *)manager correctOffset:(NSString*)correctOffset errorNum:(int)errorNum totalNum:(int)totalNum clipIndex:(int)clipIndex type:(NSString*)type;
@end

@interface INSExporter2Manager : NSObject


/// 不同的导出逻辑，封装在exporter2Session的不同派生类中
@property (nonatomic, readonly) INSExporter2Session* exporter2Session;

/// 对导出状态、进度的信息的回调，回调方法内部全部dispatch到main_queue中执行.
@property (nonatomic, weak, nullable) id<INSRExporter2ManagerDelegate> delegate;

@property (nonatomic, weak, nullable) id<INSMultiTileExportProtocol> multiTileDelegate;

@property (nonatomic, strong, nullable) id<INSFloatageDrawProtocol> floatageDraw;

/// 构造方案
/// - Parameter exporter2Session: INSMetalExporter2Session or INSRenderExporter2Session
- (instancetype)initWithExporter2Session:(INSExporter2Session *)exporter2Session;


/// 异步方法，启动导出，会在独立的线程执行导出pipeline
- (NSError*)start;

/// cancel 与interrupt作用相同，调用后，会在delegate方法中，收到相应的状态更新
- (void)cancel;


- (void)pause;

- (void)errorResumeWithUrls:(NSArray<NSArray<NSString *>*>*)urls enableX264Decoder:(BOOL)enableX264Decoder;

- (void)resume;


- (void)interrupt;

/// 在结束一次导出流程里，必须被调用的方法来释放导出资源
/// 这里尤为需要注意的是，必须等到有回调爆出INSExporter2State的明确状态后，才能调用shutdown以及退出页面的操作，防止野指针.
/// 其中INSExporter2State的INSExporter2StateDisconnect 这个状态不能shuntdown
- (void)shutdown;

- (void)enableDebug:(BOOL)enable;

+ (void)setBcvDebug:(BOOL)flag;

@end

NS_ASSUME_NONNULL_END
