/*
* Copyright (c) 2020, SmartDeviceLink Consortium, Inc.
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*
* Redistributions of source code must retain the above copyright notice, this
* list of conditions and the following disclaimer.
*
* Redistributions in binary form must reproduce the above copyright notice,
* this list of conditions and the following
* disclaimer in the documentation and/or other materials provided with the
* distribution.
*
* Neither the name of the SmartDeviceLink Consortium Inc. nor the names of
* its contributors may be used to endorse or promote products derived
* from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
* AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
* IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
* ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
* LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
* CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
* SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
* INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
* CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
* ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
* POSSIBILITY OF SUCH DAMAGE.
*/

#import "SDLEnum.h"

/**
 The type of system capability to get more information on. Used in GetSystemCapability.
 */
typedef SDLEnum SDLSystemCapabilityType NS_TYPED_ENUM;

/**
 The app services capability
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeAppServices;

/**
 The navigation capability
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeNavigation;

/**
 The phone call capability
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypePhoneCall;

/**
 The video streaming capability
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeVideoStreaming;

/**
 The remote control capability
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeRemoteControl;

/**
 Contains information about the locations of each seat
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeSeatLocation;

/**
 The Display type capability
 
 @since SDL 6.0
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeDisplays;

/**
 * @since SDL 7.0.0
 */
extern SDLSystemCapabilityType const SDLSystemCapabilityTypeDriverDistraction;
