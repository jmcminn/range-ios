//
//  INSCoreMedia.h
//  INSCoreMedia
//
//  Created by pengwx on 16/12/21.
//  Copyright © 2016年 insta360. All rights reserved.
//

#import <UIKit/UIKit.h>

//! Project version number for INSCoreMedia.
FOUNDATION_EXPORT double INSCoreMediaVersionNumber;

//! Project version string for INSCoreMedia.
FOUNDATION_EXPORT const unsigned char INSCoreMediaVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <INSCoreMedia/PublicHeader.h>


//sdk

//fundation
#import <INSCoreMedia/INSPlayerProtocol.h>
#import <INSCoreMedia/INSPlayerImage.h>

#import <INSCoreMedia/UIImage+INSMediaSDK.h>

#import <INSCoreMedia/INSMediaGyro.h>
#import <INSCoreMedia/INSMediaGyro+Feature.h>
#import <INSCoreMedia/INSMediaGps.h>
#import <INSCoreMedia/INSMediaOrientation.h>
#import <INSCoreMedia/INSMediaEuler.h>
#import <INSCoreMedia/INSMotionData.h>
#import <INSCoreMedia/INSMediaCropWindow.h>
#import <INSCoreMedia/INSMediaAAA.h>

//multi view
#import <INSCoreMedia/INSMultiViewInfo.h>
#import <INSCoreMedia/INSMultiViewCell.h>
#import <INSCoreMedia/INSMultiViewCircleCell.h>
#import <INSCoreMedia/INSMultiviewConfiguration.h>

//util
#import <INSCoreMedia/INSMetadata.h>
#import <INSCoreMedia/INSLogo.h>
#import <INSCoreMedia/INSWatermark.h>
#import <INSCoreMedia/INSImageExif.h>
#import <INSCoreMedia/INSImageXmp.h>
#import <INSCoreMedia/INSTrim.h>
#import <INSCoreMedia/INSPlayRateRange.h>
#import <INSCoreMedia/INSImageMetadataProcessor.h>
#import <INSCoreMedia/INSSingleHDRInfo.h>
#import <INSCoreMedia/INSCoordinateScale.h>
#import <INSCoreMedia/INSMediaPos.h>
#import <INSCoreMedia/INSStitchingInfo.h>

//render
#import <INSCoreMedia/INSLens.h>
#import <INSCoreMedia/INSLens+Feature.h>
#import <INSCoreMedia/INSLensOffset.h>
#import <INSCoreMedia/INSLensOffset+Feature.h>
#import <INSCoreMedia/INSOffsetCalculator.h>
#import <INSCoreMedia/INSOffsetParser.h>
#import <INSCoreMedia/INSTailClear.h>

#import <INSCoreMedia/INS3DObject.h>
#import <INSCoreMedia/INSCamera.h>
#import <INSCoreMedia/INSRenderManager.h>
#import <INSCoreMedia/INSDisplayLink.h>

#import <INSCoreMedia/INSRenderProtocol.h>
#import <INSCoreMedia/INSRenderType.h>
#import <INSCoreMedia/INSRender.h>
#import <INSCoreMedia/INSDuplicateRender.h>

#import <INSCoreMedia/INSFlatPanoRender.h>
#import <INSCoreMedia/INSPreviewRender.h>
#import <INSCoreMedia/INSSphericalPanoRender.h>
#import <INSCoreMedia/INSSphericalParallaxRender.h>
#import <INSCoreMedia/INSSphericalRender.h>
#import <INSCoreMedia/INSParallaxPanoRender.h>
#import <INSCoreMedia/INSNormalRender.h>
#import <INSCoreMedia/INSMultiviewRender.h>
#import <INSCoreMedia/INSMultiviewPanoRender.h>
#import <INSCoreMedia/INSMultiviewFlatRender.h>
#import <INSCoreMedia/INS120FPSThumbnailRender.h>
#import <INSCoreMedia/INSRender+GestureRecognizer.h>
#import <INSCoreMedia/INSFlatGyroAdjustRender.h>
#import <INSCoreMedia/INSVR180FlatPanoRender.h>
#import <INSCoreMedia/INSVR180SphericalPanoRender.h>
#import <INSCoreMedia/INSNormalRender.h>

//offscreen render
#import <INSCoreMedia/INSOffscreenRender.h>
#import <INSCoreMedia/INSMultiviewPanoOffscreenRender.h>
#import <INSCoreMedia/INSMultiviewFlatOffscreenRender.h>
#import <INSCoreMedia/INSFlatPanoOffscreenRender.h>
#import <INSCoreMedia/INSFlatGyroAdjustOffscreenRender.h>
#import <INSCoreMedia/INSSphericalFlatOffscreenRender.h>
#import <INSCoreMedia/INSSphericalPanoOffscreenRender.h>
#import <INSCoreMedia/INSNormalOffscreenRender.h>
#import <INSCoreMedia/INSVR180FlatPanoOffscreenRender.h>
#import <INSCoreMedia/INSVR180SphericalPanoOffscreenRender.h>
#import <INSCoreMedia/INSWidePanoOffscreenRender.h>

//filter
#import <INSCoreMedia/INSFilterType.h>
#import <INSCoreMedia/INSFilter.h>
#import <INSCoreMedia/INSFilter+type.h>
#import <INSCoreMedia/INSSharpenFilter.h>
#import <INSCoreMedia/INS3DLutFilter.h>
#import <INSCoreMedia/INSFilterHelper.h>

#import <INSCoreMedia/INSProjectionStrategy.h>
#import <INSCoreMedia/INSProjectionInfo.h>
#import <INSCoreMedia/INSProjectionParam.h>
#import <INSCoreMedia/INSEyePoint.h>
#import <INSCoreMedia/INSVisionField.h>
#import <INSCoreMedia/INSRenderView.h>
#import <INSCoreMedia/INSRenderView+Mask.h>
#import <INSCoreMedia/INSRenderView+BulletTime.h>
#import <INSCoreMedia/INSRender+Mask.h>
#import <INSCoreMedia/INSMask.h>
#import <INSCoreMedia/INSFlatMask.h>
#import <INSCoreMedia/INSMaskInfo.h>
#import <INSCoreMedia/INSMaskRes.h>

//record
#import <INSCoreMedia/INSScreenRecorder.h>
#import <INSCoreMedia/INSScreenTrackerRecorderDelegate.h>
#import <INSCoreMedia/INSBgm.h>
#import <INSCoreMedia/INSTemplateRecorder.h>
#import <INSCoreMedia/INSDirectionRecorder.h>
#import <INSCoreMedia/INSBigboomRecorder.h>
#import <INSCoreMedia/INSLeadRoleRecorder.h>
#import <INSCoreMedia/INSSaliencyRecorder.h>
#import <INSCoreMedia/INSTransitionRecorder.h>
#import <INSCoreMedia/INSEulerModel.h>

//previewer2
#import <INSCoreMedia/INSClip.h>
#import <INSCoreMedia/INSEmptyClip.h>
#import <INSCoreMedia/INSFileClip.h>
#import <INSCoreMedia/INSBgmClip.h>
#import <INSCoreMedia/INSImageClip.h>
#import <INSCoreMedia/INSDataSources.h>
#import <INSCoreMedia/INSPreviewer2.h>
#import <INSCoreMedia/INSTimeScale.h>
#import <INSCoreMedia/INSTimeScaleUtil.h>
#import <INSCoreMedia/INSFileClipPos.h>
#import <INSCoreMedia/INSPreviewer2Pos.h>
#import <INSCoreMedia/INSClipConfig.h>
#import <INSCoreMedia/INSEmSegment.h>
#import <INSCoreMedia/INSPreviewer3.h>
#import <INSCoreMedia/INSPreviewer3Pos.h>

#import <INSCoreMedia/INSIntervalFramePlayer.h>

//animation
#import <INSCoreMedia/INSAnimation.h>
#import <INSCoreMedia/INSAnimationState.h>
#import <INSCoreMedia/INSAsteroidAnimation.h>
#import <INSCoreMedia/INSDailyDisplayAnimation.h>

//gyro
#import <INSCoreMedia/INSGyroType.h>
#import <INSCoreMedia/INSGyroDataSource.h>
#import <INSCoreMedia/INSiPhoneGyroDataSource.h>
#import <INSCoreMedia/INSLiteGyroDataSource.h>
#import <INSCoreMedia/INSGyroRecorder.h>
#import <INSCoreMedia/INSGyroPBPlayer.h>
#import <INSCoreMedia/INSGyroPlayer.h>
#import <INSCoreMedia/INSGyroRealtimePlayer.h>
#import <INSCoreMedia/INSGyroFileWriter.h>
#import <INSCoreMedia/INSGyroFilePlayer.h>
#import <INSCoreMedia/INSExposureRecorder.h>
#import <INSCoreMedia/INSGyroPlayerWrapData.h>
#import <INSCoreMedia/INSExtraGyroDataGroup.h>
#import <INSCoreMedia/INSGyroPBPlayer+Image.h>

#import <INSCoreMedia/INSExtraInfo.h>
#import <INSCoreMedia/INSExtraInfo+Serializer.h>
#import <INSCoreMedia/INSExtraMetadata.h>
#import <INSCoreMedia/INSExtraMetadata+Serializer.h>
#import <INSCoreMedia/INSExtraGyroData.h>
#import <INSCoreMedia/INSExtraGyroData+Serializer.h>
#import <INSCoreMedia/INSMediaGyro+ExtraInfo.h>
#import <INSCoreMedia/INSMediaGps+ExtraInfo.h>
#import <INSCoreMedia/INSExtraGPSData.h>
#import <INSCoreMedia/INSExtraInfo+GyroDataOverflow.h>
#import <INSCoreMedia/INSExtraInfoTrim.h>
#import <INSCoreMedia/INSTailClipInfo.h>
#import <INSCoreMedia/INSExtraAAAData.h>
#import <INSCoreMedia/INSExtraHighlightData.h>
#import <INSCoreMedia/INSMediaHighlight.h>
#import <INSCoreMedia/INSHighlightPlayer.h>
#import <INSCoreMedia/INSMediaHighlight+Orientation.h>
//muxer
#import <INSCoreMedia/INSMuxer.h>
#import <INSCoreMedia/INSH264Muxer.h>
#import <INSCoreMedia/INSPixelMuxer.h>
#import <INSCoreMedia/INSLiveMuxer.h>
#import <INSCoreMedia/INSPixelBufferMuxer.h>

//media
#import <INSCoreMedia/INSPlayer.h>
#import <INSCoreMedia/INSAVPlayer.h>
#import <INSCoreMedia/INSARPlayer.h>

//exporter
#import <INSCoreMedia/INSExporterDataBase.h>
#import <INSCoreMedia/INSRational.h>
#import <INSCoreMedia/INSExporterInfo.h>
#import <INSCoreMedia/INSExporterManager.h>
#import <INSCoreMedia/INSExporter.h>
#import <INSCoreMedia/INSRenderExporter.h>
#import <INSCoreMedia/INSFixFrameExporter.h>
#import <INSCoreMedia/INSSequenceExporter.h>
#import <INSCoreMedia/INSSequentialExporter.h>

//exporter2
#import <INSCoreMedia/INSExporter2Info.h>
#import <INSCoreMedia/INSExporter2Manager.h>

//parser
#import <INSCoreMedia/INSImageInfoParser.h>
#import <INSCoreMedia/INSVideoInfoParser.h>
#import <INSCoreMedia/INSAudioInfoParser.h>
#import <INSCoreMedia/INSExtraInfoParser.h>
#import <INSCoreMedia/INSVideoFrameExtracter.h>
#import <INSCoreMedia/INSHTTPSystemProxyBlackList.h>
#import <INSCoreMedia/INSTransitionParser.h>
#import <INSCoreMedia/INSAsset.h>
#import <INSCoreMedia/INSImageAsset.h>
#import <INSCoreMedia/INSVideoAsset.h>
#import <INSCoreMedia/INSThumbNailParser.h>
#import <INSCoreMedia/INSIDRFrameDecoder.h>

//tools
#import <INSCoreMedia/INSMediaTool.h>
#import <INSCoreMedia/INSSingleLensCalculator.h>
#import <INSCoreMedia/INSLiteDetector.h>
#import <INSCoreMedia/INSLLog.h>
#import <INSCoreMedia/INSViewOrientation.h>
#import <INSCoreMedia/INSVideoTimePicker.h>
#import <INSCoreMedia/INSDemuxerCacheProxy.h>

//image
#import <INSCoreMedia/INSHDRGenerator.h>
#import <INSCoreMedia/INSBlender.h>

//look here
#import <INSCoreMedia/INSLookHerePoint.h>
#import <INSCoreMedia/INSRenderView+LookHere.h>

//projection converter
#import <INSCoreMedia/INSProjectionConverter.h>
#import <INSCoreMedia/INSMultipleConverter.h>
#import <INSCoreMedia/INSMultipleInfo.h>

//floatage
#import <INSCoreMedia/INSFloatageCell.h>
#import <INSCoreMedia/INSFloatageCellManager.h>
#import <INSCoreMedia/INSFloatagePosition.h>
#import <INSCoreMedia/INSFloatageView.h>
#import <INSCoreMedia/INSFloatageDrawProtocol.h>
#import <INSCoreMedia/INSBitmapData.h>
#import <INSCoreMedia/INSFloatageExportDraw.h>

//display
#import <INSCoreMedia/INSDisplay.h>
#import <INSCoreMedia/INSDisplayConfigManager.h>

//json serialize
#import <INSCoreMedia/INSJsonSerializeTool.h>
#import <INSCoreMedia/INSJsonSerializeMultiview.h>
#import <INSCoreMedia/INSJsonSerializeDisplay.h>
#import <INSCoreMedia/INSJsonSerializeAnimation.h>
