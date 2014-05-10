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

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "StackMob.h"

@class Superpower;

@interface User3 : SMUserManagedObject

@property (nonatomic, retain) NSString * email;
@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSSet *todos;
@property (nonatomic, retain) NSSet *favorites;
@property (nonatomic, retain) NSSet *interests;
@property (nonatomic, retain) Superpower *superpower;
@end

@interface User3 (CoreDataGeneratedAccessors)

- (void)addTodosObject:(NSManagedObject *)value;
- (void)removeTodosObject:(NSManagedObject *)value;
- (void)addTodos:(NSSet *)values;
- (void)removeTodos:(NSSet *)values;
- (void)addFavoritesObject:(NSManagedObject *)value;
- (void)removeFavoritesObject:(NSManagedObject *)value;
- (void)addFavorites:(NSSet *)values;
- (void)removeFavorites:(NSSet *)values;
- (void)addInterestsObject:(NSManagedObject *)value;
- (void)removeInterestsObject:(NSManagedObject *)value;
- (void)addInterests:(NSSet *)values;
- (void)removeInterests:(NSSet *)values;
@end
