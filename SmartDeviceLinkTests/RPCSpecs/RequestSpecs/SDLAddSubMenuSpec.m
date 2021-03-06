//
//  SDLAddSubMenuSpec.m
//  SmartDeviceLink


#import <Foundation/Foundation.h>

#import <Quick/Quick.h>
#import <Nimble/Nimble.h>

#import "SDLAddSubMenu.h"
#import "SDLImage.h"
#import "SDLRPCParameterNames.h"
#import "SDLRPCFunctionNames.h"

QuickSpecBegin(SDLAddSubMenuSpec)

describe(@"Getter/Setter Tests", ^ {
    __block UInt32 menuId = 4345645;
    __block UInt8 position = 27;
    __block NSString *menuName = @"Welcome to the menu";
    __block SDLImage *image = nil;
    __block SDLMenuLayout testLayout = SDLMenuLayoutList;
    __block NSNumber *parentID = @44;

    beforeEach(^{
        image = [[SDLImage alloc] initWithName:@"Test" isTemplate:false];
    });

    it(@"should correctly initialize with initWithMenuID:menuName:", ^{
        SDLAddSubMenu *testRequest = [[SDLAddSubMenu alloc] initWithMenuID:menuId menuName:menuName];

        expect(testRequest.menuID).to(equal(@(menuId)));
        expect(testRequest.position).to(beNil());
        expect(testRequest.menuName).to(equal(menuName));
        expect(testRequest.menuIcon).to(beNil());
        expect(testRequest.parentID).to(beNil());
    });

    it(@"should correctly initialize with initWithMenuID:menuName:menuLayout:menuIcon:position:parentID:", ^{
        SDLAddSubMenu *testRequest = [[SDLAddSubMenu alloc] initWithMenuID:menuId menuName:menuName position:@(position) menuIcon:image menuLayout:testLayout parentID:parentID];

        expect(testRequest.menuID).to(equal(@(menuId)));
        expect(testRequest.position).to(equal(@(position)));
        expect(testRequest.menuName).to(equal(menuName));
        expect(testRequest.menuIcon).to(equal(image));
        expect(testRequest.menuLayout).to(equal(testLayout));
        expect(testRequest.parentID).to(equal(parentID));
    });

    it(@"Should set and get correctly", ^ {
        SDLAddSubMenu *testRequest = [[SDLAddSubMenu alloc] init];
        
        testRequest.menuID = @4345645;
        testRequest.position = @27;
        testRequest.menuName = @"Welcome to the menu";
        testRequest.menuIcon = image;
        testRequest.menuLayout = testLayout;
        testRequest.parentID = parentID;
        
        expect(testRequest.menuID).to(equal(@(menuId)));
        expect(testRequest.position).to(equal(@(position)));
        expect(testRequest.menuName).to(equal(menuName));
        expect(testRequest.menuIcon).to(equal(image));
        expect(testRequest.menuLayout).to(equal(testLayout));
        expect(testRequest.parentID).to(equal(parentID));
    });
    
    it(@"Should get correctly when initialized", ^ {
        NSDictionary *dict = @{SDLRPCParameterNameRequest:
                                                           @{SDLRPCParameterNameParameters:
                                                                 @{SDLRPCParameterNameMenuID: @(menuId),
                                                                   SDLRPCParameterNamePosition: @(position),
                                                                   SDLRPCParameterNameMenuName: menuName,
                                                                   SDLRPCParameterNameMenuIcon: @{
                                                                           SDLRPCParameterNameValue: image.value
                                                                   },
                                                                   SDLRPCParameterNameMenuLayout: testLayout,
                                                                   SDLRPCParameterNameParentID: parentID
                                                                   },
                                                             SDLRPCParameterNameOperationName:SDLRPCFunctionNameAddSubMenu}};
        SDLAddSubMenu *testRequest = [[SDLAddSubMenu alloc] initWithDictionary:dict];

        expect(testRequest.menuID).to(equal(@(menuId)));
        expect(testRequest.position).to(equal(@(position)));
        expect(testRequest.menuName).to(equal(menuName));
        expect(testRequest.menuIcon.value).to(equal(@"Test"));
        expect(testRequest.menuLayout).to(equal(testLayout));
        expect(testRequest.parentID).to(equal(parentID));
    });
    
    it(@"Should return nil if not set", ^ {
        SDLAddSubMenu *testRequest = [[SDLAddSubMenu alloc] init];
        
        expect(testRequest.menuID).to(beNil());
        expect(testRequest.position).to(beNil());
        expect(testRequest.menuName).to(beNil());
        expect(testRequest.menuIcon).to(beNil());
        expect(testRequest.menuLayout).to(beNil());
        expect(testRequest.parentID).to(beNil());
    });
});

QuickSpecEnd
