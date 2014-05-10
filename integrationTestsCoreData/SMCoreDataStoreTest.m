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
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMCoreDataStoreTest)

describe(@"objects can be properly refreshed after save", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        NSFetchRequest *catfetch = [[NSFetchRequest alloc] initWithEntityName:@"Category"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:catfetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        NSFetchRequest *personfetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:personfetch error:&error];
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
    it(@"refreshes correctly with cache fetch", ^{
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todoObject setValue:@"title" forKey:@"title"];
        [todoObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
        [[[todoObject valueForKey:@"createddate"] should] beNil];
        [[[todoObject valueForKey:@"lastmoddate"] should] beNil];
        
        // Refresh Todo
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        SMRequestOptions *options = [SMRequestOptions optionsWithFetchPolicy:SMFetchPolicyCacheOnly];
        error = nil;
        
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch returnManagedObjectIDs:NO options:options error:&error];
        
        [[error should] beNil];
        [[results should] haveCountOf:1];
        
        NSManagedObject *todoFromFetch = [results lastObject];
        [[[todoFromFetch valueForKey:@"createddate"] shouldNot] beNil];
        [[[todoFromFetch valueForKey:@"lastmoddate"] shouldNot] beNil];
        
    });
    it(@"refreshes correctly with cache fetch and to-one relationship", ^{
        // Create Cat
        NSManagedObject *catObject = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:testProperties.moc];
        [catObject setValue:@"name" forKey:@"name"];
        [catObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
        // Create and relate todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todoObject setValue:@"title" forKey:@"title"];
        [todoObject assignObjectId];
        [todoObject setValue:catObject forKey:@"category"];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
        [[[todoObject valueForKey:@"createddate"] should] beNil];
        [[[todoObject valueForKey:@"lastmoddate"] should] beNil];
        [[[catObject valueForKey:@"createddate"] should] beNil];
        [[[catObject valueForKey:@"lastmoddate"] should] beNil];
        
        // Refresh Todo
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        SMRequestOptions *options = [SMRequestOptions optionsWithFetchPolicy:SMFetchPolicyCacheOnly];
        error = nil;
        
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch returnManagedObjectIDs:NO options:options error:&error];
        
        [[error should] beNil];
        [[results should] haveCountOf:1];
        
        NSManagedObject *todoFromFetch = [results lastObject];
        [[[todoFromFetch valueForKey:@"createddate"] shouldNot] beNil];
        [[[todoFromFetch valueForKey:@"lastmoddate"] shouldNot] beNil];
        
        // When you pull related object should be refreshed
        NSManagedObject *relatedCategory = [todoFromFetch valueForKey:@"category"];
        NSFetchRequest *categoryFetch = [[NSFetchRequest alloc] initWithEntityName:@"Category"];
        NSString *primaryKeyField = [relatedCategory primaryKeyField];
        [categoryFetch setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", primaryKeyField, [relatedCategory valueForKey:primaryKeyField]]];
        NSError *innerError = nil;
        SMRequestOptions *inneroptions = [SMRequestOptions optionsWithFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *innerResults = [testProperties.moc executeFetchRequestAndWait:todoFetch returnManagedObjectIDs:NO options:inneroptions error:&innerError];
        NSManagedObject *category = [innerResults lastObject];
        [[[category valueForKey:@"createddate"] shouldNot] beNil];
        [[[category valueForKey:@"lastmoddate"] shouldNot] beNil];
        
    });
    it(@"refreshes correctly with cache fetch and to-many relationship", ^{
        // Create Todos
        NSManagedObject *todoObject1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todoObject1 setValue:@"title1" forKey:@"title"];
        [todoObject1 assignObjectId];
        
        NSManagedObject *todoObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todoObject2 setValue:@"title2" forKey:@"title"];
        [todoObject2 assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
        // Create and relate todo
        NSManagedObject *personObject = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [personObject setValue:@"name" forKey:@"first_name"];
        [personObject assignObjectId];
        [personObject setValue:[NSSet setWithObjects:todoObject1, todoObject2, nil] forKey:@"todos"];
        
        error = nil;
        success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
        [[[todoObject1 valueForKey:@"createddate"] should] beNil];
        [[[todoObject1 valueForKey:@"lastmoddate"] should] beNil];
        [[[todoObject2 valueForKey:@"createddate"] should] beNil];
        [[[todoObject2 valueForKey:@"lastmoddate"] should] beNil];
        [[[personObject valueForKey:@"createddate"] should] beNil];
        [[[personObject valueForKey:@"lastmoddate"] should] beNil];
        
        // Refresh Todo
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        SMRequestOptions *options = [SMRequestOptions optionsWithFetchPolicy:SMFetchPolicyCacheOnly];
        error = nil;
        
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:personFetch returnManagedObjectIDs:NO options:options error:&error];
        
        [[error should] beNil];
        [[results should] haveCountOf:1];
        
        NSManagedObject *personFromFetch = [results lastObject];
        [[[personFromFetch valueForKey:@"createddate"] shouldNot] beNil];
        [[[personFromFetch valueForKey:@"lastmoddate"] shouldNot] beNil];
        
        // For now, to get refreshed related objects, fetch from the cache
        NSSet *relatedPeople = [personFromFetch valueForKey:@"todos"];
        [relatedPeople enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            NSString *primaryKeyField = [obj primaryKeyField];
            [todoFetch setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", primaryKeyField, [obj valueForKey:primaryKeyField]]];
            NSError *innerError = nil;
            SMRequestOptions *inneroptions = [SMRequestOptions optionsWithFetchPolicy:SMFetchPolicyCacheOnly];
            NSArray *innerResults = [testProperties.moc executeFetchRequestAndWait:todoFetch returnManagedObjectIDs:NO options:inneroptions error:&innerError];
            NSManagedObject *todo = [innerResults lastObject];
            [[[todo valueForKey:@"createddate"] shouldNot] beNil];
            [[[todo valueForKey:@"lastmoddate"] shouldNot] beNil];
        }];
        
    });
    
});

describe(@"can set a field to nil, string", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        
        testProperties = [[SMTestProperties alloc] init];
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todoObject setValue:@"title" forKey:@"title"];
        [todoObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
        
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"sets field to nil correctly", ^{
        
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"title"];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"title"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"title"] shouldBeNil];
        
    });
});

describe(@"can set a field to nil, date", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSDate *date = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        date = [NSDate date];
        [todoObject setValue:date forKey:@"time"];
        [todoObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"sets field to nil correctly", ^{
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        NSTimeInterval ti = [[[results objectAtIndex:0] valueForKey:@"time"] timeIntervalSince1970];
        [[theValue(ti - [date timeIntervalSince1970]) should] beLessThan:theValue(0.001)];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"time"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"time"] shouldBeNil];
    });
});

describe(@"can set a field to nil, int", ^{
    __block SMTestProperties *testProperties = nil;
    __block NSNumber *born = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        born = [NSNumber numberWithInt:1980];
        [todoObject setValue:born forKey:@"yearBorn"];
        [todoObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"sets field to nil correctly", ^{
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"yearBorn"] should] equal:[NSNumber numberWithInt:1980]];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"yearBorn"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"yearBorn"] shouldBeNil];
    });
});

describe(@"can set a field to nil, binary", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        NSError *error = nil;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString* pathToImageFile = [bundle pathForResource:@"goatPic" ofType:@"jpeg"];
        NSData *theData = [NSData dataWithContentsOfFile:pathToImageFile options:NSDataReadingMappedIfSafe error:&error];
        [error shouldBeNil];
        NSString *dataString = [SMBinaryDataConversion stringForBinaryData:theData name:@"whatever" contentType:@"image/jpeg"];
        [todoObject setValue:dataString forKey:@"pic"];
        [todoObject assignObjectId];
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"sets field to nil correctly", ^{
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldNotBeNil];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"pic"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldBeNil];
    });
});

describe(@"using the cache, binary field set to nil propogates, binary", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        [todoObject assignObjectId];
        NSError *error = nil;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString* pathToImageFile = [bundle pathForResource:@"goatPic" ofType:@"jpeg"];
        NSData *theData = [NSData dataWithContentsOfFile:pathToImageFile options:NSDataReadingMappedIfSafe error:&error];
        [error shouldBeNil];
        NSString *dataString = [SMBinaryDataConversion stringForBinaryData:theData name:@"whatever" contentType:@"image/jpeg"];
        [todoObject setValue:dataString forKey:@"pic"];
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
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
    it(@"sets field to nil correctly", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldNotBeNil];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"pic"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
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
            NSLog(@"FAILED UPDATE: %@", objects);
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            NSLog(@"FAILED INSERT: %@", objects);
            dispatch_group_leave(group);
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME_MIN);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldBeNil];
    });
});

describe(@"using the cache, binary field not set, doesn't propogates", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        NSError *error = nil;
        [todoObject setValue:@"cool" forKey:@"name"];
        [todoObject assignObjectId];
        
        error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
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
    it(@"sets field to nil correctly", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldBeNil];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:@"invisible" forKey:@"name"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
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
            NSLog(@"FAILED UPDATE: %@", objects);
            dispatch_group_leave(group);
        }];
        
        [testProperties.cds setSyncCallbackForFailedInserts:^(NSArray *objects) {
            NSLog(@"FAILED INSERT: %@", objects);
            dispatch_group_leave(group);
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        sleep(SLEEP_TIME_MIN);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"pic"] shouldBeNil];
    });
});

describe(@"can set a field to nil, geopoint", ^{
    __block SMTestProperties *testProperties = nil;
    __block SMGeoPoint *geo = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        // Create todo
        NSManagedObject *todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        geo = [SMGeoPoint geoPointWithLatitude:[NSNumber numberWithDouble:30.5] longitude:[NSNumber numberWithDouble:30.5]];
        //geo = [SMGeoPoint geoPointWithLatitude:[NSNumber numberWithInt:30] longitude:[NSNumber numberWithInt:30]];
        [todoObject setValue:[NSKeyedArchiver archivedDataWithRootObject:geo] forKey:@"geopoint"];
        [todoObject assignObjectId];
        
        NSError *error = nil;
        BOOL success = [testProperties.moc saveAndWait:&error];
        
        [[theValue(success) should] beYes];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    it(@"sets field to nil correctly", ^{
        // Read Todo
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        NSData *data = [[results objectAtIndex:0] valueForKey:@"geopoint"];
        [data shouldNotBeNil];
        SMGeoPoint *geoPoint = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        [[geoPoint should] equal:geo];
        
        // Set to nil
        [[results objectAtIndex:0] setValue:nil forKey:@"geopoint"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Read todo
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch2 error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        
        [[[results objectAtIndex:0] valueForKey:@"geopoint"] shouldBeNil];
    });
});
 
describe(@"create an instance of SMCoreDataStore from SMClient", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    it(@"obtaining a managedObjectContext hooked to SM is not nil", ^{
        testProperties.moc = [testProperties.cds contextForCurrentThread];
        [testProperties.moc shouldNotBeNil];
    });
});
describe(@"with a managedObjectContext from SMCoreDataStore", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'the'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"a call to save should not fail", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [aPerson setValue:@"the" forKey:@"first_name"];
        [aPerson setValue:@"dude" forKey:@"last_name"];
        [aPerson assignObjectId];
        
        [[theValue([[testProperties.moc insertedObjects] count]) should] beGreaterThan:theValue(0)];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        [[theValue([[testProperties.moc insertedObjects] count]) should] equal:theValue(0)];
        
        sleep(SLEEP_TIME);
    });
});

describe(@"with a managedObjectContext from SMCoreDataStore", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
        
        NSManagedObject *aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [aPerson setValue:@"the" forKey:@"first_name"];
        [aPerson setValue:@"dude" forKey:@"last_name"];
        [aPerson assignObjectId];
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
    afterEach(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'the'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"reads the object", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"last_name = 'dude'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        NSManagedObject *theDude = [results objectAtIndex:0];
        [[[theDude valueForKey:@"first_name"] should] equal:@"the"];
    });
});

describe(@"with a managedObjectContext from SMCoreDataStore", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'matt'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"updates the object", ^{
        NSManagedObject *aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [aPerson setValue:@"the" forKey:@"first_name"];
        [aPerson setValue:@"dude" forKey:@"last_name"];
        [aPerson setValue:[aPerson assignObjectId] forKey:[aPerson primaryKeyField]];
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [aPerson setValue:@"matt" forKey:@"first_name"];
        [aPerson setValue:@"StackMob" forKey:@"company"];
        [[theValue([[testProperties.moc updatedObjects] count]) should] beGreaterThan:theValue(0)];
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
    });
});

describe(@"after sending a request for a field that doesn't exist", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    it(@"the fetch request should fail, and the error should contain the info", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"not_a_field = 'hello'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [error shouldNotBeNil];
        [results shouldBeNil];
    });
});

describe(@"after sending a request for a field that doesn't exist", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    it(@"a call to save: should fail, and the error should contain the info", ^{
        [[testProperties.client.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"fail" forKey:@"name"];
        [newManagedObject assignObjectId];
        
        __block BOOL saveSuccess = NO;
        
        NSError *anError = nil;
        saveSuccess = [testProperties.moc saveAndWait:&anError];
        [anError shouldNotBeNil];
        [[theValue(saveSuccess) should] beNo];
    });
});


describe(@"Writing Default Values Online, Strings", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"todoId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"Works when online", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"todoId == '1234'"]];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"What!"];
        }
        
    });
});
 
describe(@"Writing Default Values Online with Update, Integers", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"Works when online", ^{
        
        // Insert 
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSNumber numberWithInt:13] forKey:@"armor_class"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        }
        
        // Update
        
        NSManagedObject *fetchedTodo = [results objectAtIndex:0];
        [fetchedTodo setValue:@"bobby" forKey:@"first_name"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Fetch should still return original armor class, default value should not overwrite
        
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch2 setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        NSArray *results2 = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results2 should] haveCountOf:1];
        
        if ([results2 count] == 1) {
            [[[[results2 objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        }
        
    });
});

describe(@"Writing Default Values Online with Update, Boolean", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"Works when online", ^{
        
        // Insert
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSNumber numberWithBool:YES] forKey:@"done"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        }
        
        // Update
        
        NSManagedObject *fetchedTodo = [results objectAtIndex:0];
        [fetchedTodo setValue:@"bobby" forKey:@"name"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        // Fetch should still return original done value, default value should not overwrite
        
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch2 setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        NSArray *results2 = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results2 should] haveCountOf:1];
        
        if ([results2 count] == 1) {
            [[[[results2 objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        }
        
    });
});

describe(@"Writing Default Values Online, Integers", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"Works when online", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(1)];
        }
        
    });
});

describe(@"Writing Default Values Online, Boolean", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        
        sleep(SLEEP_TIME);
    });
    it(@"Works when online", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        sleep(SLEEP_TIME);
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(NO)];
        }
        
    });
});

describe(@"Writing Default Values Offline, Strings", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"todoId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Works before and after sync", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
                
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"todoId == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"What!"];
        }
        
        // Sync
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
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
        
        sleep(SLEEP_TIME_MIN);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"What!"];
        
        // Check server
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"What!"];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
    });
});

describe(@"Writing Default Values Offline, Integer", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Works before and after sync", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
                
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(1)];
        }
        
        // Sync
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
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
        
        sleep(SLEEP_TIME_MIN);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(1)];
        
        // Check server
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(1)];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
    });
});

describe(@"Writing Default Values Offline with Update, Integer", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Works before and after sync", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSNumber numberWithInt:13] forKey:@"armor_class"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        }
        
        // Update
        NSManagedObject *person = [results objectAtIndex:0];
        [person setValue:@"bobby" forKey:@"first_name"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
                
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch2 setPredicate:[NSPredicate predicateWithFormat:@"person_id == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results2 = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results2 should] haveCountOf:1];
        
        if ([results2 count] == 1) {
            [[[[results2 objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        }
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        
        // Sync
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
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
        
        sleep(SLEEP_TIME_MIN);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        
        // Check server
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"armor_class"] should] equal:theValue(13)];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
    });
});

describe(@"Writing Default Values Offline, Boolean", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Works before and after sync", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
                
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(NO)];
        }
        
        // Sync
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
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
        
        sleep(SLEEP_TIME_MIN);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(NO)];
        
        // Check server
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(NO)];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
    });
});

describe(@"Writing Default Values Offline with Udpate, Boolean", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [testProperties.moc deleteObject:[results objectAtIndex:0]];
            error = nil;
            [testProperties.moc saveAndWait:&error];
        }
        SM_CACHE_ENABLED = NO;
        
        sleep(SLEEP_TIME);
    });
    it(@"Works before and after sync", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:[NSNumber numberWithBool:YES] forKey:@"done"];
        
        NSError *error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        }
        
        // Update
        
        NSManagedObject *random = [results objectAtIndex:0];
        [random setValue:@"bobby" forKey:@"name"];
        
        error = nil;
        [testProperties.moc saveAndWait:&error];
        [error shouldBeNil];
        
        [[theValue([testProperties.cds isDirtyObject:[todo objectID]]) should] beYes];
        
        NSFetchRequest *fetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        [fetch2 setPredicate:[NSPredicate predicateWithFormat:@"randomId == '1234'"]];
        error = nil;
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSArray *results2 = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        [[results2 should] haveCountOf:1];
        
        if ([results count] == 1) {
            [[[[results2 objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        }
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Sync
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setSyncCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
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
        
        sleep(SLEEP_TIME_MIN);
        
        // Check cache
        [testProperties.cds setFetchPolicy:SMFetchPolicyCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        
        // Check server
        [testProperties.cds setFetchPolicy:SMFetchPolicyNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Random"];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:theValue(YES)];
        
        [[theValue([testProperties.cds isDirtyObject:[[results objectAtIndex:0] objectID]]) should] beNo];
    });
});

describe(@"inserting to a schema with permission Allow any logged in user when we are not logged in", ^{
    __block NSManagedObject *newManagedObject = nil;
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        testProperties = [[SMTestProperties alloc] init];
    });
    it(@"a call to save: should fail, and the error should contain the info", ^{
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:testProperties.moc];
        [newManagedObject setValue:@"fail" forKey:@"name"];
        [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
        
        __block BOOL saveSuccess = NO;
        NSError *anError = nil;
        saveSuccess = [testProperties.moc saveAndWait:&anError];
        [anError shouldNotBeNil];
        [[theValue(saveSuccess) should] beNo];
    });
});

SPEC_END
