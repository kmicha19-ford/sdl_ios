//
//  SDLPresentAlertOperation.m
//  SmartDeviceLink
//
//  Created by Nicole on 11/12/20.
//  Copyright © 2020 smartdevicelink. All rights reserved.
//

#import "SDLPresentAlertOperation.h"

#import "SDLAlert.h"
#import "SDLAlertAudioData.h"
#import "SDLAlertView.h"
#import "SDLArtwork.h"
#import "SDLConnectionManagerType.h"
#import "SDLFile.h"
#import "SDLFileManager.h"
#import "SDLGlobals.h"
#import "SDLLogMacros.h"
#import "SDLSoftButtonCapabilities.h"
#import "SDLSoftButtonObject.h"
#import "SDLSoftButtonState.h"
#import "SDLTextField.h"
#import "SDLTTSChunk.h"
#import "SDLVersion.h"
#import "SDLWindowCapability.h"
#import "SDLWindowCapability+ScreenManagerExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface SDLPresentAlertOperation()

@property (strong, nonatomic) NSUUID *operationId;
@property (weak, nonatomic) id<SDLConnectionManagerType> connectionManager;
@property (weak, nonatomic) SDLFileManager *fileManager;
@property (copy, nonatomic, nullable) SDLWindowCapability *currentCapabilities;
@property (strong, nonatomic, readwrite) SDLAlertView *alertView;
@property (assign, nonatomic) UInt16 cancelId;

@property (copy, nonatomic, nullable) NSError *internalError;

@end

@implementation SDLPresentAlertOperation

- (instancetype)initWithConnectionManager:(id<SDLConnectionManagerType>)connectionManager fileManager:(SDLFileManager *)fileManager currentWindowCapability:(SDLWindowCapability *)currentWindowCapability alertView:(SDLAlertView *)alertView cancelID:(UInt16)cancelID {

    self = [super init];
    if (!self) { return self; }

    _connectionManager = connectionManager;
    _fileManager = fileManager;
    _alertView = alertView;
    _cancelId = cancelID;
    _operationId = [NSUUID UUID];
    _currentCapabilities = currentWindowCapability;

    return self;
}

- (void)start {
    [super start];
    if (self.isCancelled) { return; }

    dispatch_group_t uploadFilesTask = dispatch_group_create();
    dispatch_group_enter(uploadFilesTask);

    dispatch_group_enter(uploadFilesTask);
    [self sdl_uploadImagesWithCompletionHandler:^{
        dispatch_group_leave(uploadFilesTask);
    }];

    dispatch_group_enter(uploadFilesTask);
    [self sdl_uploadAudioFilesWithCompletionHandler:^{
        dispatch_group_leave(uploadFilesTask);
    }];

    dispatch_group_leave(uploadFilesTask);

    // This will always run after all `leave`s
    __weak typeof(self) weakSelf = self;
    dispatch_group_notify(uploadFilesTask, [SDLGlobals sharedGlobals].sdlProcessingQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf sdl_presentAlert];
    });
}

#pragma mark File, Image and Alert Uploads

/// Upload the alert audio files.
/// @param handler Called when all images have been uploaded
- (void)sdl_uploadAudioFilesWithCompletionHandler:(void (^)(void))handler {
    if (![self sdl_supportsAlertAudioFile]) {
        SDLLogV(@"Module does not support audio files for alerts");
        return handler();
    }

    NSMutableArray<SDLFile *> *filesToBeUploaded = [NSMutableArray array];
    for (SDLAlertAudioData *audioData in self.alertView.audio) {
        if (audioData.audioFile ==  nil) { continue; }
        [filesToBeUploaded addObject:audioData.audioFile];
    }

    if (filesToBeUploaded.count == 0) {
        SDLLogV(@"No audio files to upload for alert");
        return handler();
    }

    SDLLogD(@"Uploading audio files for alert");
    __weak typeof(self) weakself = self;
    [self.fileManager uploadFiles:filesToBeUploaded progressHandler:^BOOL(SDLFileName * _Nonnull fileName, float uploadPercentage, NSError * _Nullable error) {
        __strong typeof(weakself) strongself = weakself;
        SDLLogV(@"Uploaded alert audio file: %@, error: %@, percent complete: %f.2%%", fileName, error, uploadPercentage * 100);
        if (strongself.isCancelled) {
            [strongself finishOperation];
            return NO;
        }

        return YES;
    } completionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            SDLLogE(@"Error uploading alert audio files: %@", error);
        } else {
            SDLLogD(@"All alert audio files uploaded");
        }

        handler();
    }];
}

/// Upload the alert icon and soft button images.
/// @param handler Called when all images have been uploaded
- (void)sdl_uploadImagesWithCompletionHandler:(void (^)(void))handler {
    NSMutableArray<SDLArtwork *> *artworksToBeUploaded = [NSMutableArray array];

    if ([self sdl_supportsAlertIcon] && [self sdl_artworkNeedsUpload:self.alertView.icon]) {
        [artworksToBeUploaded addObject:self.alertView.icon];
    }

    for (SDLSoftButtonObject *object in self.alertView.softButtons) {
        if ([self sdl_supportsSoftButtonImages] && [self sdl_artworkNeedsUpload:object.currentState.artwork]) {
            [artworksToBeUploaded addObject:object.currentState.artwork];
        }
    }

    [self sdl_uploadImages:artworksToBeUploaded completionHandler:handler];
}

/// Helper method for uploading images
/// @param images The images to upload
/// @param completionHandler Called when all images have been uploaded
- (void)sdl_uploadImages:(NSArray<SDLArtwork *> *)images completionHandler:(void (^)(void))completionHandler {
    if (images.count == 0) {
        SDLLogV(@"No images to upload for alert");
        completionHandler();
        return;
    }

    SDLLogD(@"Uploading images for alert");
    __weak typeof(self) weakself = self;
    [self.fileManager uploadArtworks:[images copy] progressHandler:^BOOL(NSString * _Nonnull artworkName, float uploadPercentage, NSError * _Nullable error) {
        __strong typeof(weakself) strongself = weakself;
        SDLLogV(@"Uploaded alert images: %@, error: %@, percent complete: %f.2%%", artworkName, error, uploadPercentage * 100);
        if (strongself.isCancelled) {
            [strongself finishOperation];
            return NO;
        }

        return YES;
    } completionHandler:^(NSArray<NSString *> * _Nonnull artworkNames, NSError * _Nullable error) {
        if (error != nil) {
            SDLLogE(@"Error uploading alert images: %@", error);
        } else {
            SDLLogD(@"All alert images uploaded");
        }

        completionHandler();
    }];
}

- (void)sdl_presentAlert {
    [self.connectionManager sendConnectionRequest:self.alert withResponseHandler:^(__kindof SDLRPCRequest * _Nullable request, __kindof SDLRPCResponse * _Nullable response, NSError * _Nullable error) {
        if (self.isCancelled) {
            [self finishOperation];
            return;
        }

        if (error != nil) {
            self.internalError = error;
        }

        [self finishOperation];
    }];
}

#pragma mark - Private Getters / Setters

- (SDLAlert *)alert {
    SDLAlert *alert = [[SDLAlert alloc] init];
    alert.alertText1 = self.alertView.text;
    alert.alertText2 = self.alertView.secondaryText;
    alert.alertText3 = self.alertView.tertiaryText;
    alert.duration = @((NSUInteger)(self.alertView.timeout * 1000));
    alert.alertIcon = self.alertView.icon.imageRPC;
    alert.progressIndicator = @(self.alertView.showWaitIndicator);
    alert.cancelID = @(self.cancelId);

    NSMutableArray<SDLSoftButton *> *softButtons = [NSMutableArray arrayWithCapacity:alert.softButtons.count];
    for (SDLSoftButtonObject *button in self.alertView.softButtons) {
        [softButtons addObject:button.currentStateSoftButton];
    }
    alert.softButtons = softButtons;

    NSMutableArray<SDLTTSChunk *> *ttsChunks = [NSMutableArray array];
    BOOL playTone = NO;
    for (SDLAlertAudioData *audioData in self.alertView.audio) {
        if (audioData.playTone == YES) {
            playTone = YES;
        }
        if (audioData.audioFile != nil) {
            [ttsChunks addObjectsFromArray:[SDLTTSChunk fileChunksWithName:audioData.audioFile.name]];
        }
        if (audioData.prompt != nil) {
            [ttsChunks addObjectsFromArray:audioData.prompt];
        }
    }
    alert.playTone = @(playTone);
    alert.ttsChunks = ttsChunks;

    return alert;
}

- (BOOL)sdl_artworkNeedsUpload:(SDLArtwork *)artwork {
    return (artwork != nil && ![self.fileManager hasUploadedFile:artwork] && !artwork.isStaticIcon);
}

- (BOOL)sdl_supportsSoftButtonImages {
    SDLSoftButtonCapabilities *softButtonCapabilities = self.currentCapabilities.softButtonCapabilities.firstObject;
    return softButtonCapabilities.imageSupported.boolValue;
}

- (BOOL)sdl_supportsAlertAudioFile {
    return [SDLGlobals sharedGlobals].rpcVersion.major >= 5;
}

- (BOOL)sdl_supportsAlertIcon {
    return  [self.currentCapabilities hasImageFieldOfName:SDLImageFieldNameAlertIcon];
}

- (BOOL)sdl_supportsAlertTextField1 {
    return [self.currentCapabilities hasTextFieldOfName:SDLTextFieldNameAlertText1];
}

- (BOOL)sdl_supportsAlertTextField2 {
    return [self.currentCapabilities hasTextFieldOfName:SDLTextFieldNameAlertText2];
}

- (BOOL)sdl_supportsAlertTextField3 {
    return [self.currentCapabilities hasTextFieldOfName:SDLTextFieldNameAlertText3];
}

#pragma mark - Property Overrides

- (void)finishOperation {
    SDLLogV(@"Finishing present alert operation");
    [super finishOperation];
}

- (nullable NSString *)name {
    return @"com.sdl.alertManager.present";
}

- (NSOperationQueuePriority)queuePriority {
    return NSOperationQueuePriorityNormal;
}

- (nullable NSError *)error {
    return self.internalError;
}

@end

NS_ASSUME_NONNULL_END
