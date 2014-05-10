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
#import "NSManagedObjectContext+Concurrency.h"
#import "StackMob.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "User3.h"
#import "Person.h"
#import "Superpower.h"
#import "SMTestProperties.h"

SPEC_BEGIN(NSManagedObjectContext_ConcurrencySpec)

describe(@"countForFetchRequest, network", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    beforeAll(^{
        testProperties = [[SMTestProperties alloc] init];
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 10; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            [arrayOfObjects addObject:newManagedObject];
        }
        __block BOOL saveSuccess = NO;
        __block NSError *error = nil;
        
        saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        for (NSManagedObject *obj in arrayOfObjects) {
            [testProperties.moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        sleep(SLEEP_TIME);
        
    });
    it(@"async works", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_group_enter(group);
        [testProperties.moc countForFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSUInteger result) {
            [[theValue(result) should] equal:theValue(10)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"async with predicate works", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        dispatch_group_enter(group);
        [testProperties.moc countForFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSUInteger result) {
            [[theValue(result) should] equal:theValue(10)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"async with incorrect schema fails smoothly", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Oauth2test"];
        dispatch_group_enter(group);
        [testProperties.moc countForFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSUInteger result) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"sync works", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
    it(@"sync with predicate works", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
    it(@"sync with incorrect schema fails smoothly", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Oauth2test"];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(NSNotFound)];
        [error shouldNotBeNil];
    });
    it(@"fetch request with maually set count result type works", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setResultType:NSCountResultType];
        NSArray *count = [testProperties.moc executeFetchRequest:fetch error:&error];
        
        [[[count objectAtIndex:0] should] equal:theValue(10)];
        [error shouldBeNil];
    });
});

describe(@"countForFetchRequest, cache", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    beforeAll(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 10; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            [arrayOfObjects addObject:newManagedObject];
        }
        __block BOOL saveSuccess = NO;
        __block NSError *error = nil;
        
        saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        error = nil;
        [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        
        [error shouldBeNil];
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        for (NSManagedObject *obj in arrayOfObjects) {
            [testProperties.moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
        
    });
    it(@"async works", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheOnly];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_group_enter(group);
        [testProperties.moc countForFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSUInteger result) {
            [[theValue(result) should] equal:theValue(10)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"async with predicates works", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheOnly];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        dispatch_group_enter(group);
        [testProperties.moc countForFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSUInteger result) {
            [[theValue(result) should] equal:theValue(10)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
    it(@"sync works", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheOnly];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
    it(@"sync with predicate works", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheOnly];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
    it(@"fetch request with maually set count result type works", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheOnly];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setResultType:NSCountResultType];
        NSArray *count = [testProperties.moc executeFetchRequest:fetch error:&error];
        
        [[[count objectAtIndex:0] should] equal:theValue(10)];
        [error shouldBeNil];
    });
    it(@"cacheElseNetwork, cache filled", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheElseNetwork];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
});

describe(@"CacheElseNetwork count", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    beforeAll(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        arrayOfObjects = [NSMutableArray array];
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("createqueue", NULL);
        for (int i=0; i < 10; i++) {
            NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bob", @"title", nil];
            dispatch_group_enter(group);
            [[testProperties.client dataStore] createObject:todoDict inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
                dispatch_group_leave(group);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                dispatch_group_leave(group);
            }];
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("createqueue", NULL);
        
        __block NSArray *todoObjects = nil;
        SMQuery *query = [[SMQuery alloc] initWithSchema:@"todo"];
        dispatch_group_enter(group);
        [[testProperties.client dataStore] performQuery:query options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            todoObjects = results;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        if (todoObjects) {
            [todoObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                dispatch_group_enter(group);
                [[testProperties.client dataStore] deleteObjectId:[obj objectForKey:@"todo_id"] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
                    dispatch_group_leave(group);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    dispatch_group_leave(group);
                }];
            }];
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
        
    });
    it(@"cacheElseNetwork, cache not filled", ^{
        [[testProperties.client coreDataStore] setCachePolicy:SMCachePolicyTryCacheElseNetwork];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'bob'"]];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:fetch error:&error];
        
        [[theValue(count) should] equal:theValue(10)];
        [error shouldBeNil];
    });
});

describe(@"fetching runs in the background", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        testProperties = [[SMTestProperties alloc] init];
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
        
        sleep(SLEEP_TIME);
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        for (NSManagedObject *obj in arrayOfObjects) {
            [testProperties.moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        
        
        sleep(SLEEP_TIME);
        
    });
    it(@"fetches, sync method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [results shouldNotBeNil];
        [error shouldBeNil];
        
    });
    it(@"fetches, async method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:fetch returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results shouldNotBeNil];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"Returning managed object vs. ids", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        testProperties = [[SMTestProperties alloc] init];
        
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
        
        sleep(SLEEP_TIME);
    });
    afterAll(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        for (NSManagedObject *obj in arrayOfObjects) {
            [testProperties.moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [testProperties.moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        
        sleep(SLEEP_TIME);
        
    });
    it(@"Properly returns managed objects, async method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:fetch returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[theValue([obj class] == [NSManagedObject class]) should] beYes];
            }];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(group);
        dispatch_release(queue);
#endif
        
    });
    it(@"Properly returns managed objects ids, async method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:fetch returnManagedObjectIDs:YES successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[theValue([obj isTemporaryID]) should] beNo];
                [[theValue([obj isKindOfClass:[NSManagedObjectID class]]) should] beYes];
            }];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(group);
        dispatch_release(queue);
#endif
        
    });
    it(@"Properly returns managed objects, sync method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[theValue([obj class] == [NSManagedObject class]) should] beYes];
        }];
        
    });
    it(@"Properly returns managed objects ids, sync method", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch returnManagedObjectIDs:YES error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[theValue([obj isTemporaryID]) should] beNo];
            [[theValue([obj isKindOfClass:[NSManagedObjectID class]]) should] beYes];
        }];
        
    });
});


describe(@"sending options with requests, saves", ^{
    __block SMTestProperties *testProperties = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [testProperties.moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
    });
    
    it(@"saveAndWait:options:, sending HTTPS", ^{
        
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         2 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
        
        //SM_CORE_DATA_DEBUG = YES;
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
#endif
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        if (!success) {
            NSLog(@"no success");
        }
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        error = nil;
        success = [testProperties.moc saveAndWait:&error options:options];
        if (!success) {
            NSLog(@"no success");
        }
        
        //SM_CORE_DATA_DEBUG = NO;
    });
    it(@"saveAndWait:options:, not sending HTTPS", ^{
        
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        if (!success) {
            [error shouldBeNil];
        }
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error options:options];
        if (!success) {
            [error shouldBeNil];
        }
    });
    
    it(@"saveOnSuccess, sending HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         2 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
#endif
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveWithSuccessCallbackQueue:dispatch_get_current_queue() failureCallbackQueue:dispatch_get_current_queue() options:options onSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
    });
    it(@"saveOnSuccess, not sending HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveWithSuccessCallbackQueue:dispatch_get_current_queue() failureCallbackQueue:dispatch_get_current_queue() options:options onSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
    });
    
});


describe(@"creating global request options, saves", ^{
    __block SMTestProperties *testProperties = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [testProperties.moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        sleep(SLEEP_TIME);
    });
    
    it(@"saveAndWait:options:, global request options have HTTPS", ^{
        /*
         First save (global secure):
         Create person
         
         0 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         Network available
         
         3 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:3];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
#endif
        [testProperties.cds setGlobalRequestOptions:[SMRequestOptions optionsWithHTTPS]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
    });
    it(@"saveAndWait:options:, global request options regular", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        [testProperties.cds setGlobalRequestOptions:[SMRequestOptions options]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
    });
    
    it(@"saveOnSuccess:options:, global request options have HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         0 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         3 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:3];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
#endif
        [testProperties.cds setGlobalRequestOptions:[SMRequestOptions optionsWithHTTPS]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user assignObjectId];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    it(@"saveOnSuccess:options:, global request options regular", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        [testProperties.cds setGlobalRequestOptions:[SMRequestOptions options]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [testProperties.moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    
});

describe(@"sending options with requests, fetches", ^{
    __block SMTestProperties *testProperties = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterAll(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [testProperties.moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
    });
    it(@"executeFetchRequestAndWait:error:, sending HTTPS", ^{
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
#endif
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchRequest returnManagedObjectIDs:NO options:options error:&error];
        
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        
        
    });
    
    it(@"executeFetchRequestAndWait:error:, not sending HTTPS", ^{
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchRequest returnManagedObjectIDs:NO options:options error:&error];
        
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        
    });
    
    it(@"executeFetchRequest:onSuccess, sending HTTPS", ^{
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
#endif
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:fetchRequest returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue options:options onSuccess:^(NSArray *results) {
            [[theValue([results count]) should] equal:theValue(1)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    it(@"executeFetchRequest:onSuccess, not sending HTTPS", ^{
#if CHECK_RECEIVE_SELECTORS
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Used to be 1, 3 because we added code to pull values on different threads
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:3];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
#endif
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        
        __block NSManagedObjectID *objectID = nil;
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:fetchRequest returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue options:options onSuccess:^(NSArray *results) {
            [[theValue([results count]) should] equal:theValue(1)];
            // Add code here to test threading
            
            NSManagedObject *object = [results objectAtIndex:0];
            NSString *first_name = [object valueForKey:@"first_name"];
            NSLog(@"first_name is %@", first_name);
            
            objectID = [object objectID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        NSManagedObject *bob = [testProperties.moc objectWithID:objectID];
        NSString *first_name = [bob valueForKey:@"first_name"];
        NSLog(@"outside of block, first_name is %@", first_name);
    });
});



/*
 describe(@"testing getting 500s", ^{
 __block SMClient *client = nil;
 __block SMCoreDataStore *cds = nil;
 __block NSManagedObjectContext *moc = nil;
 beforeAll(^{
 SM_CORE_DATA_DEBUG = YES;
 client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"d87cee00-c574-437d-a4cb-ab841e263b52"];
 NSBundle *bundle = [NSBundle bundleForClass:[self class]];
 NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
 cds = [client coreDataStoreWithManagedObjectModel:mom];
 moc = [cds contextForCurrentThread];
 });
 it(@"getting a 500:", ^{
 Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
 [person setPerson_id:[person assignObjectId]];
 [person setFirst_name:@"bob"];
 
 NSManagedObject *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
 [favorite setValue:[favorite assignObjectId] forKey:[favorite primaryKeyField]];
 [favorite setValue:@"fav" forKey:@"genre"];
 
 NSManagedObject *interest = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
 [interest setValue:[interest assignObjectId] forKey:[interest primaryKeyField]];
 [interest setValue:@"cool" forKey:@"name"];
 
 Superpower *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
 [superpower setSuperpower_id:[superpower assignObjectId]];
 [superpower setName:@"super"];
 
 [person setInterests:[NSSet setWithObject:interest]];
 [person setFavorites:[NSSet setWithObject:favorite]];
 [person setSuperpower:superpower];
 
 [superpower setPerson:person];
 //[interest setValue:person forKey:@"person"];
 
 
 NSError *error = nil;
 BOOL success = [moc saveAndWait:&error];
 [error shouldBeNil];
 
 });
 });
 */

/*
 describe(@"async save method tests", ^{
 __block SMClient *client = nil;
 __block SMCoreDataStore *cds = nil;
 __block NSManagedObjectContext *moc = nil;
 __block NSMutableArray *arrayOfObjects = nil;
 
 beforeAll(^{
 client = [SMIntegrationTestHelpers defaultClient];
 NSBundle *bundle = [NSBundle bundleForClass:[self class]];
 NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
 cds = [client coreDataStoreWithManagedObjectModel:mom];
 moc = [cds contextForCurrentThread];
 arrayOfObjects = [NSMutableArray array];
 for (int i=0; i < 30; i++) {
 NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
 [newManagedObject setValue:@"bob" forKey:@"title"];
 [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
 
 [arrayOfObjects addObject:newManagedObject];
 }
 });
 
 afterAll(^{
 __block BOOL saveSucess = NO;
 NSMutableArray *objectIDS = [NSMutableArray array];
 for (NSManagedObject *obj in arrayOfObjects) {
 [objectIDS addObject:[obj valueForKey:@"todoId"]];
 }
 
 for (NSString *objID in objectIDS) {
 syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
 [client.dataStore deleteObjectId:objID inSchema:@"todo" onSuccess:^(NSString *objectId, NSString *schema) {
 saveSucess = YES;
 syncReturn(semaphore);
 } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
 saveSucess = NO;
 syncReturn(semaphore);
 }];
 });
 [[theValue(saveSucess) should] beYes];
 }
 
 
 for (NSManagedObject *obj in arrayOfObjects) {
 [moc deleteObject:obj];
 }
 __block BOOL saveSuccess = NO;
 dispatch_group_enter(group);
 [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
 saveSuccess = YES;
 dispatch_group_leave(group);
 } onFailure:^(NSError *error) {
 dispatch_group_leave(group);
 }];
 
 dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
 
 [[theValue(saveSuccess) should] beYes];
 [arrayOfObjects removeAllObjects];
 
 
 });
 it(@"inserts without error", ^{
 __block BOOL saveSuccess = NO;
 dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
 dispatch_group_t group = dispatch_group_create();
 
 dispatch_group_enter(group);
 [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
 saveSuccess = YES;
 dispatch_group_leave(group);
 } onFailure:^(NSError *error) {
 dispatch_group_leave(group);
 }];
 
 
 dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
 
 
 syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
 [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
 saveSuccess = YES;
 syncReturn(semaphore);
 } onFailure:^(NSError *error) {
 syncReturn(semaphore);
 }];
 });
 
 
 [[theValue(saveSuccess) should] beYes];
 });
 
 });
 */


SPEC_END