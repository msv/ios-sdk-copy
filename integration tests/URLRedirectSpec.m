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
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(URLRedirectSpec)

describe(@"URLRedirect datastore api", ^{
    __block SMClient *client = nil;
    __block NSString *hostRedirectPath = nil;
    beforeEach(^{
        NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
        NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
        NSString *publicKey = [credentials objectForKey:@"PublicKeyClusterRedirect"];
 
        hostRedirectPath = [NSString stringWithFormat:@"%@-%@", publicKey, @"APIHost"];
 
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
 
        client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:@"api.staging.stackmob.com" publicKey:publicKey userSchema:@"user" userPrimaryKeyField:@"username" userPasswordField:@"password"];
        [SMClient setDefaultClient:client];
    });
    afterEach(^{
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:hostRedirectPath];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    it(@"redicrects successfully on read, datastore", ^{
#if CHECK_RECEIVE_SELECTORS
        [[client should] receive:@selector(setApiHost:) withCount:1];
#endif
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        SMQuery *todo = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] performQuery:todo options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [[theValue([error code]) should] equal:theValue(404)];
            [[client.session.regularOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            [[client.session.secureOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            [[client.session.tokenClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Next call should 404 with no redirect this time
        SMQuery *todo2 = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] performQuery:todo2 options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [[theValue([error code]) should] equal:theValue(404)];
            [[client.session.regularOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            [[client.session.secureOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            [[client.session.tokenClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"redicrects successfully on update, core data", ^{
        
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        SMCoreDataStore *cds = [client coreDataStoreWithManagedObjectModel:aModel];
        NSManagedObjectContext *context = [cds contextForCurrentThread];
        
        NSArray *persistentStores = [cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
#if CHECK_RECEIVE_SELECTORS
        [[client should] receive:@selector(setApiHost:) withCount:1];
#endif
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:context];
        [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
        [todo setValue:@"title" forKey:@"title"];
        
        NSError *error = nil;
        BOOL success = [context saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(-108)];
        [[client.session.regularOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        [[client.session.secureOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        [[client.session.tokenClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        
        // Should not cause another redirect
        todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:context];
        [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
        [todo setValue:@"title" forKey:@"title"];
        
        error = nil;
        success = [context saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(-108)];
        [[client.session.regularOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        [[client.session.secureOAuthClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        [[client.session.tokenClient.baseURL.host should] equal:@"mattsmells.staging.stackmob.com"];
        
    });
});

SPEC_END