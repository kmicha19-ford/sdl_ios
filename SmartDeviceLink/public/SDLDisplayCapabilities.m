//  SDLDisplayCapabilities.m
//

#import "SDLDisplayCapabilities.h"

#import "NSMutableDictionary+Store.h"
#import "SDLRPCParameterNames.h"
#import "SDLImageField.h"
#import "SDLScreenParams.h"
#import "SDLTextField.h"

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-implementations"
@implementation SDLDisplayCapabilities

- (instancetype)initWithTextFields:(NSArray<SDLTextField *> *)textFields mediaClockFormats:(NSArray<SDLMediaClockFormat> *)mediaClockFormats graphicSupported:(BOOL)graphicSupported {
    self = [self init];
    if (!self) {
        return nil;
    }
    self.textFields = textFields;
    self.mediaClockFormats = mediaClockFormats;
    self.graphicSupported = @(graphicSupported);
    return self;
}

- (instancetype)initWithTextFields:(NSArray<SDLTextField *> *)textFields mediaClockFormats:(NSArray<SDLMediaClockFormat> *)mediaClockFormats graphicSupported:(BOOL)graphicSupported displayName:(nullable NSString *)displayName imageFields:(nullable NSArray<SDLImageField *> *)imageFields templatesAvailable:(nullable NSArray<NSString *> *)templatesAvailable screenParams:(nullable SDLScreenParams *)screenParams numCustomPresetsAvailable:(nullable NSNumber<SDLUInt> *)numCustomPresetsAvailable {
    self = [self initWithTextFields:textFields mediaClockFormats:mediaClockFormats graphicSupported:graphicSupported];
    if (!self) {
        return nil;
    }
    self.displayName = displayName;
    self.imageFields = imageFields;
    self.templatesAvailable = templatesAvailable;
    self.screenParams = screenParams;
    self.numCustomPresetsAvailable = numCustomPresetsAvailable;
    return self;
}

- (void)setDisplayType:(SDLDisplayType)displayType {
    [self.store sdl_setObject:displayType forName:SDLRPCParameterNameDisplayType];
}

- (SDLDisplayType)displayType {
    NSError *error = nil;
    return [self.store sdl_enumForName:SDLRPCParameterNameDisplayType error:&error];
}

- (void)setDisplayName:(nullable NSString *)displayName {
    [self.store sdl_setObject:displayName forName:SDLRPCParameterNameDisplayName];
}

- (nullable NSString *)displayName {
    return [self.store sdl_objectForName:SDLRPCParameterNameDisplayName ofClass:NSString.class error:nil];
}

- (void)setTextFields:(NSArray<SDLTextField *> *)textFields {
    [self.store sdl_setObject:textFields forName:SDLRPCParameterNameTextFields];
}

- (NSArray<SDLTextField *> *)textFields {
    NSError *error = nil;
    return [self.store sdl_objectsForName:SDLRPCParameterNameTextFields ofClass:SDLTextField.class error:&error];
}

- (void)setImageFields:(nullable NSArray<SDLImageField *> *)imageFields {
    [self.store sdl_setObject:imageFields forName:SDLRPCParameterNameImageFields];
}

- (nullable NSArray<SDLImageField *> *)imageFields {
    return [self.store sdl_objectsForName:SDLRPCParameterNameImageFields ofClass:SDLImageField.class error:nil];
}

- (void)setMediaClockFormats:(NSArray<SDLMediaClockFormat> *)mediaClockFormats {
    [self.store sdl_setObject:mediaClockFormats forName:SDLRPCParameterNameMediaClockFormats];
}

- (NSArray<SDLMediaClockFormat> *)mediaClockFormats {
    NSError *error = nil;
    return [self.store sdl_enumsForName:SDLRPCParameterNameMediaClockFormats error:&error];
}

- (void)setGraphicSupported:(NSNumber<SDLBool> *)graphicSupported {
    [self.store sdl_setObject:graphicSupported forName:SDLRPCParameterNameGraphicSupported];
}

- (NSNumber<SDLBool> *)graphicSupported {
    NSError *error = nil;
    return [self.store sdl_objectForName:SDLRPCParameterNameGraphicSupported ofClass:NSNumber.class error:&error];
}

- (void)setTemplatesAvailable:(nullable NSArray<NSString *> *)templatesAvailable {
    [self.store sdl_setObject:templatesAvailable forName:SDLRPCParameterNameTemplatesAvailable];
}

- (nullable NSArray<NSString *> *)templatesAvailable {
    return [self.store sdl_objectsForName:SDLRPCParameterNameTemplatesAvailable ofClass:NSString.class error:nil];
}

- (void)setScreenParams:(nullable SDLScreenParams *)screenParams {
    [self.store sdl_setObject:screenParams forName:SDLRPCParameterNameScreenParams];
}

- (nullable SDLScreenParams *)screenParams {
    return [self.store sdl_objectForName:SDLRPCParameterNameScreenParams ofClass:SDLScreenParams.class error:nil];
}

- (void)setNumCustomPresetsAvailable:(nullable NSNumber<SDLInt> *)numCustomPresetsAvailable {
    [self.store sdl_setObject:numCustomPresetsAvailable forName:SDLRPCParameterNameNumberCustomPresetsAvailable];
}

- (nullable NSNumber<SDLInt> *)numCustomPresetsAvailable {
    return [self.store sdl_objectForName:SDLRPCParameterNameNumberCustomPresetsAvailable ofClass:NSNumber.class error:nil];
}

@end
#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
