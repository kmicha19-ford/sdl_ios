//
//  SDLCloseApplicationResponseSpec.m
//  SmartDeviceLinkTests
//
//  Created by Nicole on 7/10/19.
//  Copyright © 2019 smartdevicelink. All rights reserved.
//

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "SDLCloseApplicationResponse.h"
#import "SDLRPCParameterNames.h"
#import "SDLRPCFunctionNames.h"

QuickSpecBegin(SDLCloseApplicationResponseSpec)

describe(@"Getter/Setter Tests", ^{
    __block SDLCloseApplicationResponse *testResponse = nil;

    it(@"Should initialize correctly", ^{
        testResponse = [[SDLCloseApplicationResponse alloc] init];
    });

    it(@"Should initialize correctly with a dictionary", ^{
        NSDictionary *dict = @{SDLRPCParameterNameRequest:@{
                                       SDLRPCParameterNameParameters:@{},
                                       SDLRPCParameterNameOperationName:SDLRPCFunctionNameCloseApplication}};
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        testResponse = [[SDLCloseApplicationResponse alloc] initWithDictionary:dict];
        #pragma clang diagnostic pop
    });

    afterEach(^{
        expect(testResponse.name).to(equal(SDLRPCFunctionNameCloseApplication));
        expect(testResponse.parameters).to(beEmpty());
    });
});

QuickSpecEnd
