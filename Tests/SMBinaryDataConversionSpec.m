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
#import "SMBinaryDataConversion.h"

SPEC_BEGIN(SMBinaryDataConversionSpec)

describe(@"SMBinaryDataConversion init", ^{
    __block NSData *theData = nil;
    beforeEach(^{
        NSError *error = nil;
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString* pathToImageFile = [bundle pathForResource:@"goatPic" ofType:@"jpeg"];
        theData = [NSData dataWithContentsOfFile:pathToImageFile options:NSDataReadingMappedIfSafe error:&error];
        [error shouldBeNil];
    });
    it(@"the data should not be nil", ^{
        [theData shouldNotBeNil];
    });
    describe(@"return a StackMob string version for NSData", ^{
        __block NSString *fieldValueForBinaryData = nil;
        beforeEach(^{
            fieldValueForBinaryData = [SMBinaryDataConversion stringForBinaryData:theData name:@"goatPic.jpeg" contentType:@"image/jpeg"]; 
        });
        it(@"data should not be nil", ^{
            [fieldValueForBinaryData shouldNotBeNil];
        });
    });
});

SPEC_END

