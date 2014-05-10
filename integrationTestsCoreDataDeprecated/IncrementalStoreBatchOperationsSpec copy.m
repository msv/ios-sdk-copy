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
#import "SMTestProperties.h"

SPEC_BEGIN(IncrementalStoreBatchOperationsSpec)

describe(@"Inserting/Updating/Deleting many objects works fine", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *fetchError = nil;
        NSArray *resultsArray = [testProperties.moc executeFetchRequest:fetch error:&fetchError];
        for (NSManagedObject *obj in resultsArray) {
            [testProperties.moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        
        sleep(SLEEP_TIME);
        
    });
    it(@"inserts and updates without error", ^{
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 30; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject assignObjectId];
            
            [arrayOfObjects addObject:newManagedObject];
        }
        
        __block BOOL saveSuccess = NO;
        __block NSError *error = nil;
        
        saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        
        for (unsigned int i=0; i < [arrayOfObjects count]; i++) {
            if ([[arrayOfObjects objectAtIndex:i] isFault]) {
                NSLog(@"isFault");
            }
            [[arrayOfObjects objectAtIndex:i] setValue:@"jack" forKey:@"title"];
        }
        
        saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        
    });
});

describe(@"With a non-401 error", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
        if ([testProperties.client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [testProperties.client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
    });
    afterEach(^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[testProperties.client dataStore] deleteObjectId:@"primarykey" inSchema:@"todo" onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        sleep(SLEEP_TIME);
    });
    it(@"General Error should return", ^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"title"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        
        // Produce a 409
        NSManagedObject *secondManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [secondManagedObject setValue:@"bob" forKey:@"title"];
        [secondManagedObject setValue:@"primarykey" forKey:[secondManagedObject primaryKeyField]];
        
        success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beNo];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        
        [failedInsertedObjects shouldNotBeNil];
        [[theValue([failedInsertedObjects count]) should] equal:theValue(1)];
        NSDictionary *dict = [failedInsertedObjects objectAtIndex:0];
        NSError *failedError = [dict objectForKey:SMFailedManagedObjectError];
        [[theValue([failedError code]) should] equal:theValue(SMErrorConflict)];
        NSLog(@"Error is %@", [error userInfo]);
        
    });
    
    
});



describe(@"With 401s", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
        if ([testProperties.client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [testProperties.client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
    });
    afterEach(^{
        
    });
    
    it(@"Not logged in, 401 should get added to failed operations and show up in error", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
#if CHECK_RECEIVE_SELECTORS
        [[testProperties.client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
#endif
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        [failedInsertedObjects shouldNotBeNil];
        [[theValue([failedInsertedObjects count]) should] equal:theValue(1)];
        NSDictionary *dict = [failedInsertedObjects objectAtIndex:0];
        NSError *failedError = [dict objectForKey:SMFailedManagedObjectError];
        [[theValue([failedError code]) should] equal:theValue(SMErrorUnauthorized)];
        
    });
    
    it(@"Failed refresh before requests are attemtped should error appropriately", ^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        NSError *error = nil;
        
        [[testProperties.client.dataStore.session stubAndReturn:@"1234"] refreshToken];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenFailed)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [failedInsertedObjects shouldBeNil];
    });
    
});


describe(@"401s requiring logins", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
        [SMIntegrationTestHelpers createUser:@"dude" password:@"sweet" dataStore:testProperties.client.dataStore];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                NSLog(@"logged in, %@", result);
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldNotBeNil];
                syncReturn(semaphore);
            }];
        });
        
        
    });
    afterEach(^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        if ([testProperties.client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [testProperties.client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
        
        [SMIntegrationTestHelpers deleteUser:@"dude" dataStore:testProperties.client.dataStore];
    });
    it(@"After successful refresh, should send out requests again", ^{
        
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        [[testProperties.client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        //[[client.dataStore.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
#if CHECK_RECEIVE_SELECTORS
        [[testProperties.client.dataStore.session should] receive:@selector(doTokenRequestWithEndpoint:credentials:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:1 arguments:@"refreshToken", any(), any(), any(), any(), any(), any()];
        
        [[testProperties.client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
#endif
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([failedInsertedObjects count] ) should] equal:theValue(1)];
        NSDictionary *dictionary = [failedInsertedObjects objectAtIndex:0];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
    });
    
});


describe(@"timeouts with refreshing", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
    });
    it(@"waits 5 seconds and fails", ^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        [[testProperties.client.dataStore.session stubAndReturn:@"1234"] refreshToken];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(YES)] refreshing];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenInProgress)];
        
    });
    
});

describe(@"With 401s and other errors", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
        [SMIntegrationTestHelpers createUser:@"dude" password:@"sweet" dataStore:testProperties.client.dataStore];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                NSLog(@"logged in, %@", result);
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"bob" forKey:@"title"];
        [todo setValue:@"primarykey" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        
        
    });
    afterEach(^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[testProperties.client dataStore] deleteObjectId:@"primarykey" inSchema:@"todo" onSuccess:^(NSString *objectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        if ([testProperties.client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [testProperties.client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
        
        [SMIntegrationTestHelpers deleteUser:@"dude" dataStore:testProperties.client.dataStore];
        
    });
    it(@"Only 401s should be refreshed if possible", ^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // Set up scenario
        [[testProperties.client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[testProperties.client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        //[[client.dataStore.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
        
        // Add objects for 401 and 409
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"bob" forKey:@"title"];
        [todo setValue:@"primarykey" forKey:[todo primaryKeyField]];
        
        // Should create total of 2 operations, one for the 409 and 1 for the 401 (first time, retry happens from token client)
#if CHECK_RECEIVE_SELECTORS
        [[testProperties.client.dataStore.session.tokenClient should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        [[testProperties.client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
#endif
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beNo];
        
        // Test failure
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([failedInsertedObjects count] ) should] equal:theValue(2)];
        NSDictionary *dictionary = [failedInsertedObjects objectAtIndex:0];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
        dictionary = [failedInsertedObjects objectAtIndex:1];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
        
        
    });
    
});

describe(@"Calling refresh block", ^{
    __block SMTestProperties *testProperties = nil;
    
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
    });
    it(@"refresh token failure, async save", ^{
        [[testProperties.client.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"bob" forKey:@"name"];
        [todo setValue:@"primarykey" forKey:[todo primaryKeyField]];
        
        __block BOOL refreshFailed = NO;
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.client.session setTokenRefreshFailureBlock:^(NSError *error, SMFailureBlock originalFailureBlock) {
                [[[error userInfo] objectForKey:SMFailedRefreshBlock] shouldBeNil];
                [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenFailed)];
                refreshFailed = YES;
                syncReturn(semaphore);
            }];
            [testProperties.moc saveOnSuccess:^(NSArray *results) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
            }];
        });
        
        [[theValue(refreshFailed) should] beYes];
    });
    it(@"refresh token failure, async fetch", ^{
        [[testProperties.client.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
        
        __block BOOL refreshFailed = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.client.session setTokenRefreshFailureBlock:^(NSError *error, SMFailureBlock originalFailureBlock) {
                [[[error userInfo] objectForKey:SMFailedRefreshBlock] shouldBeNil];
                [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenFailed)];
                refreshFailed = YES;
                //NSLog(@"got to token refresh block");
                syncReturn(semaphore);
            }];
            __block NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            [testProperties.moc executeFetchRequest:fetch onSuccess:^(NSArray *results) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                //NSLog(@"got here");
            }];
        });
        
        [[theValue(refreshFailed) should] beYes];
    });
});
SPEC_END