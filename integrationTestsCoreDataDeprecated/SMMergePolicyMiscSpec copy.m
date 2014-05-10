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

SPEC_BEGIN(SMMergePolicyMiscSpec)


describe(@"many-to-many relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
        
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForFavorite = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForFavorite error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-many relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *favID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        personID = [person valueForKey:[person primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:testProperties.moc];
        [favorite assignObjectId];
        [favorite setValue:[NSSet setWithObject:person] forKey:@"persons"];
        
        favID = [favorite valueForKey:[favorite primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *favRelation = [[[results objectAtIndex:0] valueForKey:@"favorites"] anyObject];
        [favRelation shouldNotBeNil];
        
        
        NSFetchRequest *favFetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:favFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[[results objectAtIndex:0] valueForKey:@"persons"] anyObject];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *favRelation2 = [[[results objectAtIndex:0] valueForKey:@"favorites"] anyObject];
        [favRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *favFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:favFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[[results objectAtIndex:0] valueForKey:@"persons"] anyObject];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"person" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *favorites = [object objectForKey:@"favorites"];
            [[favorites should] haveCountOf:1];
            [[[favorites objectAtIndex:0] should] equal:favID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:favID inSchema:@"favorite" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *persons = [object objectForKey:@"persons"];
            [[persons should] haveCountOf:1];
            [[[persons objectAtIndex:0] should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"many-to-one relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForInterest = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForInterest error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-many and to-one relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *interestID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        personID = [person valueForKey:[person primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *interest = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:testProperties.moc];
        [interest assignObjectId];
        [interest setValue:person forKey:@"person"];
        
        interestID = [interest valueForKey:[interest primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *interestRelation = [[[results objectAtIndex:0] valueForKey:@"interests"] anyObject];
        [interestRelation shouldNotBeNil];
        
        
        NSFetchRequest *interestFetch = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:interestFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[results objectAtIndex:0] valueForKey:@"person"];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *interestRelation2 = [[[results objectAtIndex:0] valueForKey:@"interests"] anyObject];
        [interestRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *interestFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:interestFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[results objectAtIndex:0] valueForKey:@"person"];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"person" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *interests = [object objectForKey:@"interests"];
            [[interests should] haveCountOf:1];
            [[[interests objectAtIndex:0] should] equal:interestID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:interestID inSchema:@"interest" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *personString = [object objectForKey:@"person"];
            [[personString should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"one-to-one relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForSuperpower = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForSuperpower error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-one relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *superpowerID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [person assignObjectId];
        personID = [person valueForKey:[person primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        [superpower assignObjectId];
        [superpower setValue:person forKey:@"person"];
        
        superpowerID = [superpower valueForKey:[superpower primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *superpowerRelation = [[results objectAtIndex:0] valueForKey:@"superpower"];
        [superpowerRelation shouldNotBeNil];
        
        
        NSFetchRequest *superpowerFetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:superpowerFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[results objectAtIndex:0] valueForKey:@"person"];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *superpowerRelation2 = [[results objectAtIndex:0] valueForKey:@"superpower"];
        [superpowerRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *superpowerFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:superpowerFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[results objectAtIndex:0] valueForKey:@"person"];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"person" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *interestString = [object objectForKey:@"superpower"];
            [[interestString should] equal:superpowerID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:superpowerID inSchema:@"superpower" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *personString = [object objectForKey:@"person"];
            [[personString should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});


describe(@"With User Object: many-to-many relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForFavorite = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForFavorite error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-many relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *favID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        User3 *person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        personID = [NSString stringWithFormat:@"bob%d", arc4random() / 100000];
        [person setUsername:personID];
        [person setPassword:@"1234"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:testProperties.moc];
        [favorite assignObjectId];
        [favorite setValue:[NSSet setWithObject:person] forKey:@"user3s"];
        
        favID = [favorite valueForKey:[favorite primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *favRelation = [[[results objectAtIndex:0] valueForKey:@"favorites"] anyObject];
        [favRelation shouldNotBeNil];
        
        
        NSFetchRequest *favFetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:favFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[[results objectAtIndex:0] valueForKey:@"user3s"] anyObject];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *favRelation2 = [[[results objectAtIndex:0] valueForKey:@"favorites"] anyObject];
        [favRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *favFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:favFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[[results objectAtIndex:0] valueForKey:@"user3s"] anyObject];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"user3" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *favorites = [object objectForKey:@"favorites"];
            [[favorites should] haveCountOf:1];
            [[[favorites objectAtIndex:0] should] equal:favID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:favID inSchema:@"favorite" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *persons = [object objectForKey:@"user3s"];
            [[persons should] haveCountOf:1];
            [[[persons objectAtIndex:0] should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"With User Object: many-to-one relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForInterest = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForInterest error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-many and to-one relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *interestID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        User3 *person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        personID = [NSString stringWithFormat:@"bob%d", arc4random() / 100000];
        [person setUsername:personID];
        [person setPassword:@"1234"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *interest = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:testProperties.moc];
        [interest assignObjectId];
        [interest setValue:person forKey:@"user3"];
        
        interestID = [interest valueForKey:[interest primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *interestRelation = [[[results objectAtIndex:0] valueForKey:@"interests"] anyObject];
        [interestRelation shouldNotBeNil];
        
        
        NSFetchRequest *interestFetch = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:interestFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[results objectAtIndex:0] valueForKey:@"user3"];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *interestRelation2 = [[[results objectAtIndex:0] valueForKey:@"interests"] anyObject];
        [interestRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *interestFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Interest"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:interestFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[results objectAtIndex:0] valueForKey:@"user3"];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"user3" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSArray *interests = [object objectForKey:@"interests"];
            [[interests should] haveCountOf:1];
            [[[interests objectAtIndex:0] should] equal:interestID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:interestID inSchema:@"interest" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *personString = [object objectForKey:@"user3"];
            [[personString should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"With User Object: one-to-one relationships being serialized correctly on sync", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"user3"];
    });
    afterEach(^{
        NSError *error = nil;
        NSFetchRequest *fetchForPerson = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetchForPerson error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        NSFetchRequest *fetchForSuperpower = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        results = [testProperties.moc executeFetchRequestAndWait:fetchForSuperpower error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"serialized the to-one relationships to their correct IDs when syncing", ^{
        
        __block NSString *personID = nil;
        __block NSString *superpowerID = nil;
        
        // Create Person with 1-N on Superpower, Online
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        User3 *person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:testProperties.moc];
        personID = [NSString stringWithFormat:@"bob%d", arc4random() / 100000];
        [person setUsername:personID];
        [person setPassword:@"1234"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Create Superpower, Offline
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        [superpower assignObjectId];
        [superpower setValue:person forKey:@"user3"];
        
        superpowerID = [superpower valueForKey:[superpower primaryKeyField]];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read from and check the cache
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *superpowerRelation = [[results objectAtIndex:0] valueForKey:@"superpower"];
        [superpowerRelation shouldNotBeNil];
        
        
        NSFetchRequest *superpowerFetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:superpowerFetch returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation = [[results objectAtIndex:0] valueForKey:@"user3"];
        [personRelation shouldNotBeNil];
        
        // Sync
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed update"];
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [NSException raise:@"Something Wrong" format:@"Failed insert"];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Relationships should be all good
        NSFetchRequest *personFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *superpowerRelation2 = [[results objectAtIndex:0] valueForKey:@"superpower"];
        [superpowerRelation2 shouldNotBeNil];
        
        
        NSFetchRequest *superpowerFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:superpowerFetch2 returnManagedObjectIDs:NO options:[SMRequestOptions optionsWithCachePolicy:SMCachePolicyTryCacheOnly] error:&error];
        
        [error shouldBeNil];
        NSManagedObject *personRelation2 = [[results objectAtIndex:0] valueForKey:@"user3"];
        [personRelation2 shouldNotBeNil];
        
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:personID inSchema:@"user3" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *interestString = [object objectForKey:@"superpower"];
            [[interestString should] equal:superpowerID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        [[[SMClient defaultClient] dataStore] readObjectWithId:superpowerID inSchema:@"superpower" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSString *personString = [object objectForKey:@"user3"];
            [[personString should] equal:personID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *objectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});


describe(@"Sync Errors, Inserting offline to a forbidden schema with POST perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
    });
    it(@"Error callback should get called", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermspost" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermspostId"];
        [object setValue:@"post perms" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});

describe(@"Sync Errors, Inserting offline to a forbidden schema with GET perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
    });
    it(@"Error callback should get called", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsget" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsgetId"];
        [object setValue:@"get perms" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
            
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});

describe(@"Insert 5 Online, Go offline and delete 5, T2 update 2 Online", ^{
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
    it(@"Server Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Delete 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
    });
    
    it(@"Last Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME_MIN);
        
        // Update 2 Online at T2
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
    it(@"Client wins, 5 should delete from server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
});


describe(@"Insert 5 Online, Update 2 Online T1, Go offline and delete 5 T2", ^{
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
    it(@"Server Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Delete 5 offline at T2
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
    });
    
    it(@"Last Mod wins, should delete 5 from the server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Delete 5 offline at T2
        [NSThread sleepForTimeInterval:0.5];
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
    it(@"Client wins, 5 should delete from server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Delete 5 offline at T2
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:5];
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
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
});




describe(@"Sync Errors, Updating offline to a forbidden schema with PUT perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
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
    it(@"Error callback should get called", ^{
        // Insert online
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsput" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsputId"];
        [object setValue:@"original title" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [object setValue:@"put perms" forKey:@"title"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:1];
            if ([results count] == 1) {
                [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"original title"];
            }
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 error:&saveError];
            [[results should] haveCountOf:1];
            if ([results count] == 1) {
                [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"original title"];
            }
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});
describe(@"Sync Errors, Updating offline to a forbidden schema with GET perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"offlinepermsget" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *objectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Error callback should get called", ^{
        // Insert online
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsget" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsgetId"];
        [object setValue:@"original title" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Update offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [object setValue:@"get perms" forKey:@"title"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setSyncCallbackForFailedUpdates:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsget"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});

describe(@"Sync Global request options with HTTPS", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        
    });
    it(@"Only makes HTTPS calls", ^{
        
        testProperties.cds.globalRequestOptions = [SMRequestOptions optionsWithHTTPS];
#if CHECK_RECEIVE_SELECTORS
        [[testProperties.cds.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) withCount:0];
        [[testProperties.cds.session.secureOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) withCount:5];
#endif
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"todoId"];
        [object setValue:@"only https" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
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
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
});


describe(@"Syncing with user objects, Inserts", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
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
    it(@"Succeeds without error", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"username"] should] equal:@"Bob"];
        }
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"username"] should] equal:@"Bob"];
        }
    });
});

describe(@"Syncing with user objects, Updates", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
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
    it(@"Succeeds without error", ^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [user setEmail:@"bob@bob.com"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"email"] should] equal:@"bob@bob.com"];
        }
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"email"] should] equal:@"bob@bob.com"];
        }
    });
});

describe(@"Syncing with user objects, Deletes", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        SM_CACHE_ENABLED = NO;
    });
    it(@"Succeeds without error", ^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:user];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
});

describe(@"syncInProgress", ^{
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
    it(@"works properly", ^{
        
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
#if CHECK_RECEIVE_SELECTORS
        [[store should] receive:@selector(syncWithServer) withCount:1];
#endif
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
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
    });
    
    it(@"second test properly", ^{
        
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
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
#if CHECK_RECEIVE_SELECTORS
        [[store should] receive:@selector(syncWithServer) withCount:2];
#endif
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
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
    });
});


SPEC_END