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
#import "SMTestProperties.h"
#import "User3.h"

SPEC_BEGIN(SMMergePolicyInsertsSpec)

//////////////////////////////
/////////INSERTS///////////
//////////////////////////////

describe(@"Insert 1 Offline, should send as an insert no merge, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
        
    });
    
    it(@"Should send object as an update, no merge policy should get called", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionInsertedOnServer)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
        
        // better testing that merge policy never gets called
        
    });
    
});

describe(@"Insert 1 Offline at T1, Insert 1 Online at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedOnServer)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    it(@"Last Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedCache)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    it(@"Server Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedCache)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    
});

describe(@"While offline, Insert 1 Online at T1, Insert 1 Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedOnServer)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    it(@"Last Mod Wins MP, Should send object as an update", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Insert 1 offline
        [NSThread sleepForTimeInterval:0.5];
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedOnServer)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    it(@"Server Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        // Sync
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            if ([objects count] == 1) {
                [[theValue([[objects objectAtIndex:0] actionTaken]) should] equal:theValue(SMSyncActionUpdatedCache)];
            }
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
        
    });
    
    
});

SPEC_END