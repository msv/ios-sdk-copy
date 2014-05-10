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
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMSavePolicySpec)

describe(@"Save policy works with syncing", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        [testProperties.cds setSavePolicy:SMSavePolicyNetworkOnly];
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Can save locally a few times, sync, and all is well", ^{
        
        //[[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[SMClient defaultClient] coreDataStore] setSavePolicy:SMSavePolicyCacheOnly];
        [[[SMClient defaultClient] coreDataStore] setFetchPolicy:SMFetchPolicyCacheOnly];
        
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"second new todo" forKey:@"title"];
        }
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        // Updated 5 of the todos
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == 'new todo'"]];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated todo" forKey:@"title"];
        }];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        [[[SMClient defaultClient] coreDataStore] setFetchPolicy:SMFetchPolicyNetworkOnly];
        
        // At this point there should be nothing on the server
        error = nil;
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSUInteger count = [testProperties.moc countForFetchRequestAndWait:todoFetch error:&error];
        
        [error shouldBeNil];
        [[theValue(count) should] equal:theValue(0)];
        
        // Now sync
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:10];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        
        // Now there should be 10 objects on StackMob
        error = nil;
        NSFetchRequest *todoFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSUInteger count2 = [testProperties.moc countForFetchRequestAndWait:todoFetch2 error:&error];
        
        [error shouldBeNil];
        [[theValue(count2) should] equal:theValue(10)];
        
    });
    
});

describe(@"SMSavePolicy, default networkThenCache", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Saves in both places on create", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves in both places on update", ^{
        
        dispatch_queue_t queue = dispatch_queue_create("createQueue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        // Create 5 new objects
        NSMutableArray *theObjects = [NSMutableArray array];
        for (int i=0; i < 5; i++) {
            [theObjects addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil]];
        }
        
        dispatch_group_enter(group);
        [[testProperties.client dataStore] createObjects:theObjects inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            [[succeeded should] haveCountOf:5];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Pull down objects
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves in both places on create and update", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
});

describe(@"SMSavePolicy, explicitly setting networkThenCache", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setSavePolicy:SMSavePolicyNetworkThenCache];
    });
    afterEach(^{
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Saves in both places on create", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves in both places on update", ^{
        
        dispatch_queue_t queue = dispatch_queue_create("createQueue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        // Create 5 new objects
        NSMutableArray *theObjects = [NSMutableArray array];
        for (int i=0; i < 5; i++) {
            [theObjects addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil]];
        }
        
        dispatch_group_enter(group);
        [[testProperties.client dataStore] createObjects:theObjects inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            [[succeeded should] haveCountOf:5];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Pull down objects
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves in both places on create and update", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
});

describe(@"SMSavePolicy, setting networkOnly", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setSavePolicy:SMSavePolicyNetworkOnly];
    });
    afterEach(^{
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Saves on the network only on create", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves on network only for update", ^{
        
        dispatch_queue_t queue = dispatch_queue_create("createQueue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        // Create 5 new objects
        NSMutableArray *theObjects = [NSMutableArray array];
        for (int i=0; i < 5; i++) {
            [theObjects addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"new todo", @"title", nil]];
        }
        
        dispatch_group_enter(group);
        [[testProperties.client dataStore] createObjects:theObjects inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *succeeded, NSArray *failed, NSString *schema) {
            [[succeeded should] haveCountOf:5];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSArray *objects, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Pull down objects
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        [testProperties.cds purgeCacheOfObjectsWithEntityName:@"Todo"];
        
        sleep(SLEEP_TIME_MIN);
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
    
    it(@"Saves on network only on create and update", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        [testProperties.cds purgeCacheOfObjectsWithEntityName:@"Todo"];
        
        sleep(SLEEP_TIME_MIN);
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
    });
});

describe(@"SMSavePolicy, setting cacheOnly", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setSavePolicy:SMSavePolicyCacheOnly];
    });
    afterEach(^{
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Saves on the network only on create", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
    });
    
    it(@"Saves on network only on create and update", ^{
        
        // Create 5 new objects
        for (int i=0; i < 5; i++) {
            NSManagedObject *newTodo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [newTodo assignObjectId];
            [newTodo setValue:@"new todo" forKey:@"title"];
        }
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj setValue:@"updated title" forKey:@"title"];
        }];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(testProperties.cds.globalRequestOptions.cacheResults) should] beYes];
        
        [[theValue(success) should] beYes];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 returnManagedObjectIDs:NO error:&error];
        
        [[results should] haveCountOf:5];
        [error shouldBeNil];
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *networkFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:networkFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCacheResults:NO] error:&error];
        
        [[results should] haveCountOf:0];
        [error shouldBeNil];
        
    });
});


describe(@"Per Request Save Policy", ^{
    __block SMTestProperties *testProperties;
    beforeAll(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterAll(^{
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        [testProperties.cds setSavePolicy:SMSavePolicyNetworkThenCache];
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *error = nil;
        NSArray *array = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        
        [error shouldBeNil];
        [array enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        if ([testProperties.moc hasChanges]) {
            error = nil;
            [testProperties.moc saveAndWait:&error];
            [error shouldBeNil];
        }
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"not setting policy works, sync", ^{
        
        //[[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [testProperties.cds setSavePolicy:SMSavePolicyCacheOnly];
        
        for (int i=0; i < 10; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo assignObjectId];
        }
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        [error shouldBeNil];
    });
    it(@"setting request policy works, sync", ^{
        
        [testProperties.cds setSavePolicy:SMSavePolicyNetworkOnly];
        
        //[[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithSavePolicy:SMSavePolicyCacheOnly];
        [[theValue(options.savePolicySet) should] beYes];
        for (int i=0; i < 10; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo assignObjectId];
        }
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error options:options];
        [[theValue(success) should] beYes];
        [error shouldBeNil];
    });
    it(@"setting request policy works, sync, reverse works", ^{
        
        [testProperties.cds setSavePolicy:SMSavePolicyCacheOnly];
        
        //[[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithSavePolicy:SMSavePolicyNetworkOnly];
        [[theValue(options.savePolicySet) should] beYes];
        for (int i=0; i < 10; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo assignObjectId];
        }
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error options:options];
        [[theValue(success) should] beYes];
        [error shouldBeNil];
    });
    /*
    it(@"not setting policy works, async", ^{
        
        dispatch_queue_t queue = dispatch_queue_create("aQueue", NULL);
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [testProperties.cds setSavePolicy:SMSavePolicyCacheOnly];
        
        for (int i=0; i < 10; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo assignObjectId];
        }
        
        __block NSError *anError = [NSError errorWithDomain:@"error" code:400 userInfo:nil];
        [testProperties.moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
            NSLog(@"here");
            anError = nil;
        } onFailure:^(NSError *error) {
            anError = error;
        }];
        
        sleep(2);
        
        [anError shouldBeNil];
                        
    });
    it(@"setting request policy works, async", ^{
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        SMRequestOptions *options = [SMRequestOptions options];
        options.cachePolicy = SMFetchPolicyCacheOnly;
        [[theValue(options.fetchPolicySet) should] beYes];
        
        dispatch_group_enter(group);
        [testProperties.moc executeFetchRequest:request returnManagedObjectIDs:YES successCallbackQueue:queue failureCallbackQueue:queue options:options onSuccess:^(NSArray *results) {
            [[results should] haveCountOf:10];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    });
     */
});



SPEC_END