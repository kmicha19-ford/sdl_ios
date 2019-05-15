//  SDLIAPTransport.h


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SDLIAPTransport.h"

#import "EAAccessory+SDLProtocols.h"
#import "EAAccessoryManager+SDLProtocols.h"
#import "SDLGlobals.h"
#import "SDLIAPConstants.h"
#import "SDLIAPControlSession.h"
#import "SDLIAPControlSessionDelegate.h"
#import "SDLIAPDataSession.h"
#import "SDLIAPDataSessionDelegate.h"
#import "SDLIAPSession.h"
#import "SDLLogMacros.h"
#import "SDLStreamDelegate.h"
#import "SDLTimer.h"
#import <CommonCrypto/CommonDigest.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const BackgroundTaskName = @"com.sdl.transport.iap.backgroundTask";
int const CreateSessionRetries = 3;

@interface SDLIAPTransport () <SDLIAPControlSessionDelegate, SDLIAPDataSessionDelegate>

@property (nullable, strong, nonatomic) SDLIAPControlSession *controlSession;
@property (nullable, strong, nonatomic) SDLIAPDataSession *dataSession;
@property (assign, nonatomic) int retryCounter;
@property (assign, nonatomic) BOOL sessionSetupInProgress;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskId;
@property (assign, nonatomic) BOOL accessoryConnectDuringActiveSession;

@end


@implementation SDLIAPTransport

- (instancetype)init {
    SDLLogV(@"SDLIAPTransport init");
    self = [super init];
    if (!self) {
        return nil;
    }

    _sessionSetupInProgress = NO;
    _dataSession = nil;
    _controlSession = nil;
    _retryCounter = 0;
    _accessoryConnectDuringActiveSession = NO;

    // Get notifications if an accessory connects in future
    [self sdl_startEventListening];

    // Wait for setup to complete before scanning for accessories

    return self;
}

#pragma mark - Background Task

/**
 *  Starts a background task that allows the app to search for accessories and while the app is in the background.
 */
- (void)sdl_backgroundTaskStart {
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        SDLLogV(@"A background task is already running. No need to start a background task.");
        return;
    }

    self.backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithName:BackgroundTaskName expirationHandler:^{
        SDLLogD(@"Background task expired");
        [self sdl_backgroundTaskEnd];
    }];

    SDLLogD(@"Started a background task with id: %lu", (unsigned long)self.backgroundTaskId);
}

/**
 *  Cleans up a background task when it is stopped.
 */
- (void)sdl_backgroundTaskEnd {
    if (self.backgroundTaskId == UIBackgroundTaskInvalid) {
        SDLLogV(@"No background task running. No need to stop the background task. Returning...");
        return;
    }
    
    SDLLogD(@"Ending background task with id: %lu", (unsigned long)self.backgroundTaskId);
    [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskId];
    self.backgroundTaskId = UIBackgroundTaskInvalid;
}

#pragma mark - Notifications

/**
 *  Registers for system notifications about connected accessories and the app life cycle.
 */
- (void)sdl_startEventListening {
    SDLLogV(@"SDLIAPTransport started listening for events");
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sdl_accessoryConnected:)
                                                 name:EAAccessoryDidConnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sdl_accessoryDisconnected:)
                                                 name:EAAccessoryDidDisconnectNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sdl_applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sdl_applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
}

/**
 *  Unsubscribes to notifications.
 */
- (void)sdl_stopEventListening {
    SDLLogV(@"SDLIAPTransport stopped listening for events");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark EAAccessory Notifications

/**
 *  Handles a notification sent by the system when a new accessory has been detected by attempting to connect to the new accessory.
 *
 *  @param notification Contains information about the connected accessory
 */
- (void)sdl_accessoryConnected:(NSNotification *)notification {
    EAAccessory *newAccessory = [notification.userInfo objectForKey:EAAccessoryKey];

    if ([self sdl_isDataSessionActive:self.dataSession newAccessory:newAccessory]) {
        self.accessoryConnectDuringActiveSession = YES;
        return;
    }

    double retryDelay = self.sdl_retryDelay;
    SDLLogD(@"Accessory Connected (%@), Opening in %0.03fs", notification.userInfo[EAAccessoryKey], retryDelay);
    
    if ([[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
        SDLLogD(@"Accessory connected while app is in background. Starting background task.");
        [self sdl_backgroundTaskStart];
    }

    self.retryCounter = 0;
    [self performSelector:@selector(sdl_connect:) withObject:nil afterDelay:retryDelay];
}

/**
 *  Checks if the newly connected accessory connected while a data session is already opened. This can happen when a session is established over bluetooth and then the user connects to the same head unit with a USB cord.
 *
 *  @param dataSession  The current data session
 *  @param newAccessory The newly connected accessory
 *  @return             True if the accessory connected while a data session is already in progress; false if not
 */
- (BOOL)sdl_isDataSessionActive:(nullable SDLIAPDataSession *)dataSession newAccessory:(EAAccessory *)newAccessory {
    if (dataSession == nil || !dataSession.isSessionInProgress) {
        return NO;
    }

    if (dataSession.isSessionInProgress && (dataSession.connectionID != newAccessory.connectionID)) {
        SDLLogD(@"Switching transports from Bluetooth to USB. Waiting for disconnect notification.");
        return YES;
    }

    return NO;
}

/**
 *  Handles a notification sent by the system when an accessory has been disconnected by cleaning up after the disconnected device.
 *
 *  @param notification Contains information about the connected accessory
 */
- (void)sdl_accessoryDisconnected:(NSNotification *)notification {
    EAAccessory *accessory = [notification.userInfo objectForKey:EAAccessoryKey];
    SDLLogD(@"Accessory with serial number %@ and connectionID %lu disconnecting.", accessory.serialNumber, (unsigned long)accessory.connectionID);

    if (self.accessoryConnectDuringActiveSession == YES) {
        SDLLogD(@"Switching transports from Bluetooth to USB. Will reconnect over Bluetooth after disconnecting the USB session.");
        self.accessoryConnectDuringActiveSession = NO;
    }

    if (!self.controlSession.isSessionInProgress && !self.dataSession.isSessionInProgress) {
        SDLLogV(@"Accessory (%@, %@), disconnected, but no session is in progress.", accessory.name, accessory.serialNumber);
        [self sdl_closeSessions];
    } else if (accessory.connectionID == self.dataSession.connectionID) {
        // The data session has been established. Tell the delegate that the transport has disconnected. The lifecycle manager will destroy and create a new transport object.
        SDLLogV(@"Accessory (%@, %@) disconnected during a data session", accessory.name, accessory.serialNumber);
        [self sdl_destroyTransport];
    } else if (accessory.connectionID == self.controlSession.connectionID) {
        // The data session has yet to be established so the transport has not yet connected. DO NOT unregister for notifications from the accessory.
        SDLLogV(@"Accessory (%@, %@) disconnected during a control session", accessory.name, accessory.serialNumber);
        [self sdl_closeSessions];
    } else {
        SDLLogV(@"Accessory (%@, %@) disconnecting during an unknown session", accessory.name, accessory.serialNumber);
        [self sdl_closeSessions];
    }
}

/**
 *  Closes and cleans up the sessions after a control session has been closed. Since a data session has not been established, the lifecycle manager has not transitioned to state started. Do not unregister for notifications from accessory connections/disconnections otherwise the library will not be able to connect to an accessory again.
 */
- (void)sdl_closeSessions {
    self.retryCounter = 0;
    self.sessionSetupInProgress = NO;
    [self.controlSession stopSession];
    [self.dataSession stopSession];
}

/**
 *  Tells the lifecycle manager that the data session has been closed. The lifecycle manager will destroy it's `SDLIAPTransport` object and then create a new one to listen for a new connection to the accessory.
 */
- (void)sdl_destroyTransport {
    self.retryCounter = 0;
    self.sessionSetupInProgress = NO;
    [self disconnect];
    [self.delegate onTransportDisconnected];
}

#pragma mark App Lifecycle Notifications

/**
 *  Handles a notification sent by the system when the app enters the foreground.
 *
 *  If the app is still searching for an accessory, a background task will be started so the app can still search for and/or connect with an accessory while it is in the background.
 *
 *  @param notification Notification
 */
- (void)sdl_applicationWillEnterForeground:(NSNotification *)notification {
    SDLLogV(@"App foregrounded, attempting connection");
    [self sdl_backgroundTaskEnd];
    [self connect];
}

/**
 *  Handles a notification sent by the system when the app enters the background.
 *
 *  @param notification Notification
 */
- (void)sdl_applicationDidEnterBackground:(NSNotification *)notification {
    SDLLogV(@"App backgrounded, starting background task");
    [self sdl_backgroundTaskStart];
}

#pragma mark - Stream Lifecycle

#pragma mark SDLTransportTypeProtocol

/**
 *  Sends data to Core
 *
 *  @param data The data to be sent to Core
 */
- (void)sendData:(NSData *)data {
    if (!self.dataSession.sessionInProgress) { return; }
    [self.dataSession.session sendData:data];
}

/**
 *  Attempts to connect to an accessory.
 */
- (void)connect {
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state != UIApplicationStateActive) {
        SDLLogV(@"App inactive on connect, starting background task");
        [self sdl_backgroundTaskStart];
    }

    [self sdl_connect:nil];
}

/**
 *  Cleans up after a disconnected accessory by closing any open I/O streams.
 */
- (void)disconnect {
    // Stop event listening here so that even if the transport is disconnected by the proxy we unregister for accessory local notifications
    [self sdl_stopEventListening];

    [self.controlSession stopSession];
    [self.dataSession stopSession];
}


#pragma mark Helpers

/**
 *  Starts the process to connect to an accessory. If no accessory specified, scans for a valid accessory.
 *
 *  @param accessory The accessory to attempt connection with or nil to scan for accessories.
 */
- (void)sdl_connect:(nullable EAAccessory *)accessory {
    if ((self.dataSession == nil || !self.dataSession.isSessionInProgress) && !self.sessionSetupInProgress) {
        // No data session has been established are not attempting to set one up, attempt to connect
        SDLLogV(@"No data session in progress. Starting setup.");
        self.sessionSetupInProgress = YES;
        [self sdl_establishSessionWithAccessory:accessory];
    } else if (self.dataSession.isSessionInProgress) {
        SDLLogV(@"Data session I/O streams already opened. Ignoring attempt to create session.");
    } else {
        SDLLogV(@"Data session I/O streams are currently being opened. Ignoring attempt to create session.");
    }
}

/**
 *  Helper method for creating a Control session
 *
 *  @param accessory        The SDL enabled accessory
 *  @return                 A SDLIAPControlSession object
 */
- (SDLIAPControlSession *)sdl_createControlSessionWithAccessory:(EAAccessory *)accessory {
    SDLIAPSession *session = [[SDLIAPSession alloc] initWithAccessory:accessory forProtocol:ControlProtocolString];
    return [[SDLIAPControlSession alloc] initWithSession:session delegate:self];
}

/**
 *  Helper method for creating a Data session
 *
 *  @param accessory        The SDL enabled accessory
 *  @param protocol         The protocol string needed to open the session
 *  @return                 A SDLIAPDataSession object
 */
- (SDLIAPDataSession *)sdl_createDataSessionWithAccessory:(EAAccessory *)accessory forProtocol:(NSString *)protocol {
    SDLIAPSession *session = [[SDLIAPSession alloc] initWithAccessory:accessory forProtocol:protocol];
    return [[SDLIAPDataSession alloc] initWithSession:session delegate:self];
}

/**
 *  Attempts to connect an accessory using the control or legacy protocols, then returns whether or not a session was created.
 *
 *  @param accessory    The accessory to attempt a connection with
 *  @return             Whether or not we succesfully created a session.
 */
- (BOOL)sdl_connectAccessory:(EAAccessory *)accessory {
    BOOL connecting = NO;

    if (![self.class sdl_plistContainsAllSupportedProtocolStrings]) {
        return connecting;
    }

    if ([accessory supportsProtocol:MultiSessionProtocolString] && SDL_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9")) {
        self.dataSession = [self sdl_createDataSessionWithAccessory:accessory forProtocol:MultiSessionProtocolString];
        [self.dataSession startSession];
        connecting = YES;
    } else if ([accessory supportsProtocol:ControlProtocolString]) {
        self.controlSession = [self sdl_createControlSessionWithAccessory:accessory];
        [self.controlSession startSession];
        connecting = YES;
    } else if ([accessory supportsProtocol:LegacyProtocolString]) {
        self.dataSession = [self sdl_createDataSessionWithAccessory:accessory forProtocol:LegacyProtocolString];
        [self.dataSession startSession];
        connecting = YES;
    }

    return connecting;
}

/**
 *  Attempts to establish a session with the passed accessory. If nil is passed the accessory manager is checked for connected SDL enabled accessories.
 *
 *  @param accessory The accessory to try to establish a session with, or nil to scan all connected accessories.
 */
- (void)sdl_establishSessionWithAccessory:(nullable EAAccessory *)accessory {
    SDLLogD(@"Attempting to connect accessory: %@", accessory.name);
    if (self.retryCounter < CreateSessionRetries) {
        self.retryCounter++;

        EAAccessory *sdlAccessory = accessory;
        // If called from sdl_connectAccessory, the notification will contain the SDL accessory to connect to and we can connect without searching the accessory manager's connected accessory list. Otherwise, we fall through to a search.
        if (sdlAccessory != nil && [self sdl_connectAccessory:sdlAccessory]) {
            // Connection underway, exit
            SDLLogV(@"Connection already underway");
            return;
        }

        if (![self.class sdl_plistContainsAllSupportedProtocolStrings]) {
            return;
        }

        // Determine if we can start a multi-app session or a legacy (single-app) session
        if ((sdlAccessory = [EAAccessoryManager findAccessoryForProtocol:MultiSessionProtocolString]) && SDL_SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9")) {
            self.dataSession = [self sdl_createDataSessionWithAccessory:sdlAccessory forProtocol:MultiSessionProtocolString];
            [self.dataSession startSession];
        } else if ((sdlAccessory = [EAAccessoryManager findAccessoryForProtocol:ControlProtocolString])) {
            self.controlSession = [self sdl_createControlSessionWithAccessory:sdlAccessory];
            [self.controlSession startSession];
        } else if ((sdlAccessory = [EAAccessoryManager findAccessoryForProtocol:LegacyProtocolString])) {
            self.dataSession = [self sdl_createDataSessionWithAccessory:sdlAccessory forProtocol:LegacyProtocolString];
            [self.dataSession startSession];
        } else {
            // No compatible accessory
            SDLLogV(@"No accessory supporting SDL was found, dismissing setup");
            self.sessionSetupInProgress = NO;
        }
    } else {
        // We have surpassed the number of retries allowed
        SDLLogW(@"Surpassed allowed retry attempts (%d), dismissing setup", CreateSessionRetries);
        self.sessionSetupInProgress = NO;
    }
}

/**
 *  Stops any ongoing sessions if necessary and tries to find an accessory which which to create a session.
 */
- (void)sdl_retryEstablishSession {
    // Current strategy disallows automatic retries.
    self.sessionSetupInProgress = NO;
    [self.controlSession stopSession];
    [self.dataSession stopSession];

    // Search connected accessories
    [self sdl_connect:nil];
}


#pragma mark - Session Delegates

#pragma mark Control Session

/**
 *  Called when the control session got the protocol string successfully and the data session can be opened with the protocol string.
 *
 *  @param controlSession   The control session
 *  @param protocolString   The protocol string to be used to open the data session
 *  @param accessory        The accessory with which to create a data session
 */
- (void)controlSession:(nonnull SDLIAPSession *)controlSession didGetProtocolString:(nonnull NSString *)protocolString forConnectedAccessory:(nonnull EAAccessory *)accessory {
    self.dataSession = [self sdl_createDataSessionWithAccessory:accessory forProtocol:protocolString];
    [self.dataSession startSession];
}

/**
 *  Called when the control session should be retried.
 */
- (void)retryControlSession {
    [self sdl_retryEstablishSession];
}

#pragma mark Data Session

/**
 *  Called when the data session receives data from Core
 *
 *  @param dataIn The received data
 */
- (void)dataReceived:(nonnull NSData *)dataIn {
    [self.delegate onDataReceived:dataIn];
    [self sdl_backgroundTaskStart];
}

/**
 *  Called when the data session should be retried.
 */
- (void)retryDataSession {
    [self sdl_retryEstablishSession];
}

/**
 *  Called when the data session has been established. Notify the delegate that the transport has been connected.
 */
- (void)transportConnected {
    self.sessionSetupInProgress = NO;
    [self.delegate onTransportConnected];
}


#pragma mark - Helpers

#pragma mark Protocol Strings

/**
 *  Checks if the app's info.plist contains all the required protocol strings.
 *
 *  @return True if the app's info.plist has all required protocol strings; false if not.
 */
+ (BOOL)sdl_plistContainsAllSupportedProtocolStrings {
    if ([self.class sdl_supportsRequiredProtocolStrings] != nil) {
        NSString *failedString = [self.class sdl_supportsRequiredProtocolStrings];
        SDLLogE(@"A required External Accessory protocol string is missing from the info.plist: %@", failedString);
        NSAssert(NO, @"Some SDL protocol strings are not supported, check the README for all strings that must be included in your info.plist file. Missing string: %@", failedString);
        return NO;
    }
    return YES;
}

/**
 *  Compares all required protocol strings against the protocol strings in the info.plist dictionary.
 *
 *  @return A missing protocol string or nil if all strings are supported.
 */
+ (nullable NSString *)sdl_supportsRequiredProtocolStrings {
    NSArray<NSString *> *protocolStrings = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedExternalAccessoryProtocols"];

    if (![protocolStrings containsObject:MultiSessionProtocolString]) {
        return MultiSessionProtocolString;
    }

    if (![protocolStrings containsObject:LegacyProtocolString]) {
        return LegacyProtocolString;
    }

    for (int i = 0; i < 30; i++) {
        NSString *indexedProtocolString = [NSString stringWithFormat:@"%@%i", IndexedProtocolStringPrefix, i];
        if (![protocolStrings containsObject:indexedProtocolString]) {
            return indexedProtocolString;
        }
    }

    return nil;
}

#pragma mark Retry Delay

/**
 *  Generates a random number of seconds between 1.5 and 9.5 used to delay the retry control and data session attempts.
 *
 *  @return A random number of seconds.
 */
- (double)sdl_retryDelay {
    const double MinRetrySeconds = 1.5;
    const double MaxRetrySeconds = 9.5;
    double RetryRangeSeconds = MaxRetrySeconds - MinRetrySeconds;

    static double appDelaySeconds = 0;

    // HAX: This pull the app name and hashes it in an attempt to provide a more even distribution of retry delays. The evidence that this does so is anecdotal. A more ideal solution would be to use a list of known, installed SDL apps on the phone to try and deterministically generate an even delay.
    if (appDelaySeconds == 0) {
        NSString *appName = [[NSProcessInfo processInfo] processName];
        if (appName == nil) {
            appName = @"noname";
        }

        // Run the app name through an md5 hasher
        const char *ptr = [appName UTF8String];
        unsigned char md5Buffer[CC_MD5_DIGEST_LENGTH];
        CC_MD5(ptr, (unsigned int)strlen(ptr), md5Buffer);

        // Generate a string of the hex hash
        NSMutableString *output = [NSMutableString stringWithString:@"0x"];
        for (int i = 0; i < 8; i++) {
            [output appendFormat:@"%02X", md5Buffer[i]];
        }

        // Transform the string into a number between 0 and 1
        unsigned long long firstHalf;
        NSScanner *pScanner = [NSScanner scannerWithString:output];
        [pScanner scanHexLongLong:&firstHalf];
        double hashBasedValueInRange0to1 = ((double)firstHalf) / 0xffffffffffffffff;

        // Transform the number into a number between min and max
        appDelaySeconds = ((RetryRangeSeconds * hashBasedValueInRange0to1) + MinRetrySeconds);
    }

    return appDelaySeconds;
}


#pragma mark - Lifecycle Destruction

- (void)dealloc {
    SDLLogV(@"SDLIAPTransport");
    [self disconnect];
    [self sdl_backgroundTaskEnd];
    self.controlSession = nil;
    self.dataSession = nil;
    self.delegate = nil;
    self.sessionSetupInProgress = NO;
    self.accessoryConnectDuringActiveSession = NO;
}

@end

NS_ASSUME_NONNULL_END
