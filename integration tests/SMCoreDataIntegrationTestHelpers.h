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

#import <CoreData/CoreData.h>
#import "StackMob.h"
#import "NSManagedObject+StackMobSerialization.h"

#define SLEEP_TIME 3
#define SLEEP_TIME_MIN 1

typedef void (^SynchronousFetchBlock)(NSArray *results, NSError *error);
typedef void (^SynchronousErrorBlock)(NSError *error);

@interface SMCoreDataIntegrationTestHelpers : NSObject

@property (readonly, strong, nonatomic) NSManagedObjectModel *stackMobMOM;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *stackMobPSC;
@property (readonly, strong, nonatomic) NSManagedObjectContext *stackMobMOC;
@property (nonatomic, strong) SMClient *client;

+ (NSManagedObjectContext *)moc;
+ (NSEntityDescription *)entityForName:(NSString *)entityName;
+ (NSFetchRequest *)makePersonFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc;
+ (NSFetchRequest *)makeSuperpowerFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc;;
+ (NSFetchRequest *)makeFavoriteFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc;;
+ (NSFetchRequest *)makeInterestFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc;;
+ (void)executeSynchronousFetch:(NSManagedObjectContext *)moc withRequest:(NSFetchRequest *)fetchRequest andBlock:(SynchronousFetchBlock)block;
+ (void)executeSynchronousSave:(NSManagedObjectContext *)moc withBlock:(SynchronousErrorBlock)block;
+ (void)executeSynchronousUpdate:(NSManagedObjectContext *)moc withObject:(NSManagedObjectID *)objectID andBlock:(SynchronousErrorBlock)block;
+ (void)executeSynchronousDelete:(NSManagedObjectContext *)moc withObject:(NSManagedObjectID *)objectID andBlock:(SynchronousErrorBlock)block;
+ (void)registerForMOCNotificationsWithContext:(NSManagedObjectContext *)context;
+ (void)removeObserversrForMOCNotificationsWithContext:(NSManagedObjectContext *)context;
+ (void)MOCDidChange:(NSNotification *)notification;
+ (void)MOCDidSave:(NSNotification *)notification;
+ (void)MOCWillSave:(NSNotification *)notification;
+ (void)removeSQLiteDatabaseAndMapsWithPublicKey:(NSString *)publicKey;
+ (NSURL *)SM_getStoreURLForCacheMapTableWithPublicKey:(NSString *)publicKey;
+ (NSURL *)SM_getStoreURLForDirtyQueueTableWithPublicKey:(NSString *)publicKey;
+ (NSDictionary *)getContentsOfFileAtPath:(NSString *)path;

@end

