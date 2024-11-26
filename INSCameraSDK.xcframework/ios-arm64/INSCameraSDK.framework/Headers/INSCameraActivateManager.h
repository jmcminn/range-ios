//
//  INSCameraActivateManager.h
//  INSCameraSDK
//
//  Created by Willing Yang on 2024/10/14.
//

#import <Foundation/Foundation.h>
#import "INSCameraCommands.h"

NS_ASSUME_NONNULL_BEGIN

@interface INSCameraActivateManager : NSObject

+ (instancetype)shareManager;

- (void)activateCameraWithSerial:(NSString *)serialNumber commandManager:(id<INSCameraBasicCommands>)commandManager
                      completion:(void (^)(NSDictionary * _Nullable, NSError * _Nullable))completion;

@end

NS_ASSUME_NONNULL_END
