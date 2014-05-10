/**
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
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Person.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMUpdateObjectsOptimizationSpec)

describe(@"updating an object only persists changed fields", ^{
    __block SMTestProperties *testProperties = nil;
    __block Person *person = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:@"bob" forKey:@"first_name"];
        [person setValue:@"jean" forKey:@"first_name"];
        [person assignObjectId];
        NSDictionary *personDict = [person SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil];
        
        // Add 1 for default values
        [[theValue([[[personDict objectForKey:@"SerializedDict"] allKeys] count]) should] equal:theValue(3)];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [testProperties.moc deleteObject:person];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        sleep(SLEEP_TIME);
    });
    it(@"should only persist the updated fields", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [person setValue:@"joe" forKey:@"first_name"];
        NSDictionary *personDict = [person SMDictionarySerialization:NO sendLocalTimestamps:NO cacheMap:nil];
        [[[personDict objectForKey:@"SerializedDict"] objectForKey:@"first_name"] shouldNotBeNil];
        [[[personDict objectForKey:@"SerializedDict"] objectForKey:@"person_id"] shouldNotBeNil];
        
        // Add 1 for default values
        [[theValue([[[personDict objectForKey:@"SerializedDict"] allKeys] count]) should] equal:theValue(2)];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    
});

SPEC_END