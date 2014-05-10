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

#import "SMIntegrationTestHelpers.h"

static NSMutableDictionary *_insertedObjects; 
// schema name -> array of dictionaries representing parsed objects, with uuid in schema_id field

/*
void synchronousQuery(SMDataStore *sm, SMQuery *query, SynchronousQueryBlock block) {    
    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [sm performQuery:query onSuccess:^(NSArray *results) {
            block(results, nil);
            syncReturn(semaphore);
        } onFailure:^(NSError *error) {
            block(nil, error);
            syncReturn(semaphore);
        }];
    });
}
 */

@implementation SMIntegrationTestHelpers

+ (SMClient *)defaultClient
{
    NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
    NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
    NSString *publicKey = [credentials objectForKey:@"PublicKey"];
    SMClient *aClient = [[SMClient alloc] initWithAPIVersion:SM_TEST_API_VERSION publicKey:publicKey];
    [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:@"api.stackmob.com"];
    return aClient;
}

+ (SMPushClient *)defaultPushClient
{
    NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
    NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
    NSString *publicKey = [credentials objectForKey:@"PublicKey"];
    NSString *privateKey = [credentials objectForKey:@"PrivateKey"];
    return [[SMPushClient alloc] initWithAPIVersion:SM_TEST_API_VERSION publicKey:publicKey privateKey:privateKey];
}

+ (SMDataStore *)dataStore {
    return [[SMIntegrationTestHelpers defaultClient] dataStore];
}

#pragma mark - Fixtures

+ (NSDictionary *)loadFixturesNamed:(NSArray *)fixtureNames {
    NSMutableDictionary *fixtures = [NSMutableDictionary dictionaryWithCapacity:[fixtureNames count]];
    
    [fixtureNames enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *fixtureName = (NSString *)obj;
        NSArray *fixture = [SMIntegrationTestHelpers loadFixture:fixtureName];
        [fixtures setValue:fixture forKey:fixtureName];
    }];
    return (NSDictionary *)fixtures;
}

+ (void)destroyAllForFixturesNamed:(NSArray *)fixtureNames {
    SMDataStore *sm = [SMIntegrationTestHelpers dataStore];
    
    [fixtureNames enumerateObjectsUsingBlock:^(id name, NSUInteger fixtureIdx, BOOL *stopFixEnum) {
        NSString *fixtureName = (NSString *)name;
        SMQuery *query = [[SMQuery alloc] initWithSchema:fixtureName];
        __block NSArray *smObjects;
        
        synchronousQuery(sm, query, ^(NSArray *results) {
            smObjects = results;
        }, ^(NSError *error) {
            
        });
        [smObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *uuid_field = [NSString stringWithFormat:@"%@_id", fixtureName];
            NSString *uuid = [(NSDictionary *)obj objectForKey:uuid_field];
            
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [sm deleteObjectId:uuid inSchema:fixtureName onSuccess:^(NSString *objectId, NSString *schema) {
                    NSLog(@"Deleted %@ from schema %@", objectId, schema);
                    syncReturn(semaphore);
                } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
                    NSLog(@"Failed to delete %@ from schema %@: %@", objectId, schema, error);
                    syncReturn(semaphore);  
                }];
            });
        }];
    }];    
}

+ (NSArray *)loadFixture:(NSString *)fixtureName {
    if (_insertedObjects == nil) {
        _insertedObjects = [NSMutableDictionary dictionary];
    }
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *fixtureFileURL = [bundle URLForResource:fixtureName withExtension:@"json"];
    NSData *fixtureData = [NSData dataWithContentsOfURL:fixtureFileURL];
    NSError *error = nil;
    
    NSArray *objToInsert = (NSArray *)[NSJSONSerialization JSONObjectWithData:fixtureData options:0 error:&error];
    
    SMDataStore *smClient = [SMIntegrationTestHelpers dataStore];
    __block NSMutableArray *insertedObjectsForFixture = [NSMutableArray array];
    
    dispatch_queue_t queue = dispatch_queue_create("fixtureQueue", NULL);
    dispatch_group_t group = dispatch_group_create();
    
    [objToInsert enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        [smClient createObject:(NSDictionary *)obj inSchema:fixtureName options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *object, NSString *schema) {
            NSLog(@"Created object in schema %@:\n%@", schema, object);
            [insertedObjectsForFixture addObject:object];
            dispatch_group_leave(group);
        } onFailure:^(NSError *anError, NSDictionary *object, NSString *schema) {
            NSLog(@"Failed to create a new %@: %@", schema, anError);
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(group);
    dispatch_release(queue);
#endif
    
    if ([_insertedObjects objectForKey:fixtureName] == nil) {
        [_insertedObjects setValue:[NSMutableArray array] forKey:fixtureName];
    }
    [[_insertedObjects objectForKey:fixtureName] addObjectsFromArray:insertedObjectsForFixture];
    
    return [_insertedObjects objectForKey:fixtureName];
}

+ (void)destroyFixture:(NSString *)fixtureName {
    SMDataStore *smClient = [SMIntegrationTestHelpers dataStore];
    NSString *idField = [NSString stringWithFormat:@"%@_id", fixtureName];

    dispatch_group_t group = dispatch_group_create();
    
    [[_insertedObjects objectForKey:fixtureName] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        NSString *uuid = [(NSDictionary *)obj objectForKey:idField];
        [smClient deleteObjectId:uuid inSchema:fixtureName onSuccess:^(NSString *objectId, NSString *schema) {
            NSLog(@"Deleted %@ from schema %@", objectId, schema);
            dispatch_group_leave(group);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            NSLog(@"Failed to delete %@ from schema %@: %@", objectId, schema, error);
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
#if !OS_OBJECT_USE_OBJC
    dispatch_release(group);
#endif
    
    [_insertedObjects removeObjectForKey:fixtureName];
}

+ (BOOL)createUser:(NSString *)username password:(NSString *)password dataStore:(SMDataStore *)dataStore
{
    __block BOOL createSuccess = NO;
    __block NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:username, @"username", password, @"password", @"value", @"randomfield", nil];
    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [dataStore createObject:createObjectDict inSchema:@"user" onSuccess:^(NSDictionary *object, NSString *schema) {
            createSuccess = YES;
            syncReturn(semaphore);
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            createSuccess = (error.code == 409);
            syncReturn(semaphore);
        }];
    });
    
    return createSuccess;
}

+ (BOOL)deleteUser:(NSString *)username dataStore:(SMDataStore *)dataStore
{
    __block BOOL deleteSuccess = NO;
    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [dataStore deleteObjectId:username inSchema:@"user" onSuccess:^(NSString *objectId, NSString *schema) {
            deleteSuccess = YES;
            syncReturn(semaphore);
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            deleteSuccess = NO;
            syncReturn(semaphore);
        }];
    });
    
    return deleteSuccess;
}

@end
