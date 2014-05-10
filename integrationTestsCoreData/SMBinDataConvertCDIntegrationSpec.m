/*
 * Copyright 2012-2013 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Kiwi/Kiwi.h>
#import "StackMob.h"
#import "SMClient.h"
#import "SMCoreDataStore.h"
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Superpower.h"
#import "SMBinaryDataConversion.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMBinDataConvertCDIntegrationSpec)

describe(@"SMBinDataConvertCDIntegration", ^{
    __block SMTestProperties *testProperties = nil;
    __block Superpower *superpower = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
    });
    describe(@"should successfully set binary data when translated to string", ^{
        __block NSString *dataString = nil;
        beforeEach(^{
             [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
            NSError *error = nil;
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString* pathToImageFile = [bundle pathForResource:@"goatPic" ofType:@"jpeg"];
            NSData *theData = [NSData dataWithContentsOfFile:pathToImageFile options:NSDataReadingMappedIfSafe error:&error];
            [error shouldBeNil];
            dataString = [SMBinaryDataConversion stringForBinaryData:theData name:@"whatever" contentType:@"image/jpeg"];
            [dataString shouldNotBeNil];
            [superpower setName:@"cool"];
            [superpower setValue:dataString forKey:@"pic"];
            [superpower assignObjectId];
        });
        it(@"should persist to StackMob and update after a refresh call", ^{
             [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                [testProperties.moc refreshObject:superpower mergeChanges:YES];
                NSString *picString = [superpower valueForKey:@"pic"];
                [[[picString substringToIndex:4] should] equal:@"http"];
            }];
            
            sleep(SLEEP_TIME);
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:testProperties.moc withObject:[superpower objectID] andBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
        });
        it(@"should update the object successfully without overwriting the data", ^{
             [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            __block NSString *picURL = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                [testProperties.moc refreshObject:superpower mergeChanges:YES];
                picURL = [superpower valueForKey:@"pic"];
            }];
            
            sleep(SLEEP_TIME);
            
            [superpower setName:@"the coolest"];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                NSString *picString = [superpower valueForKey:@"pic"];
                [[picString should] equal:picURL];
            }];
            
            sleep(SLEEP_TIME);
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:testProperties.moc withObject:[superpower objectID] andBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            sleep(SLEEP_TIME);
        });
    });
});

SPEC_END
