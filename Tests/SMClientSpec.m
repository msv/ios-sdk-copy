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

@interface SMClient ()

@property(nonatomic, readwrite, copy) NSString *publicKey;
@property(nonatomic, readwrite, strong) SMUserSession * session;
@property (nonatomic, readwrite) BOOL loggedIn;
@end

SPEC_BEGIN(SMClientSpec)


describe(@"+defaultClient", ^{
    context(@"when the default client has not been set", ^{
        beforeEach(^{
            [SMClient setDefaultClient:nil];
        });
        context(@"creating a new client instance", ^{
            __block SMClient *client = nil;
            beforeEach(^{
                client = [[SMClient alloc] initWithAPIVersion:@"1" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
            });
            it(@"should set the default client", ^{
                [[[SMClient defaultClient] should] equal:client];
            });
        });
    });
    context(@"when the default client has been set", ^{
        __block SMClient *originalDefaultClient = nil;
        beforeEach(^{
            originalDefaultClient = [SMClient mock];
            [SMClient setDefaultClient:originalDefaultClient];
        });
        context(@"setting the default client", ^{
            __block SMClient *client = nil;
            beforeEach(^{
                client = [[SMClient alloc] initWithAPIVersion:@"1" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
                [SMClient setDefaultClient:client];
            });
            it(@"should update the default client", ^{
                [[[SMClient defaultClient] should] equal:client];
            });
        });
        context(@"creating a new client instance", ^{
            __block SMClient *client = nil;
            beforeEach(^{
                client = [[SMClient alloc] initWithAPIVersion:@"1" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
            });
            it(@"should not change the default client", ^{
                [[[SMClient defaultClient] should] equal:originalDefaultClient];
            });
        });
    });
});

describe(@"simple configuration", ^{
    __block SMClient *client = nil;
    __block NSString *appAPIVersion = @"0";
    __block NSString *publicKey = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
    beforeEach(^{
        publicKey = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
        client = [[SMClient alloc] initWithAPIVersion:appAPIVersion publicKey:publicKey];
    });
    
    describe(@"app api version", ^{
        it(@"should set the client api version", ^{
            [[client.appAPIVersion should] equal:appAPIVersion];
        });
    });
    
    describe(@"API host", ^{
        it(@"should default to stackmob.com", ^{
            [[[[client session] getHttpHost] should] equal:DEFAULT_API_HOST];
            [[[[client session] getHttpsHost] should] equal:DEFAULT_API_HOST];
        });
    });
    
    describe(@"public key", ^{
        it(@"should set the client public key", ^{
            [[client.publicKey should] equal:publicKey];
        });
    });

    describe(@"user schema", ^{
        it(@"should default to user", ^{
            [[[client userSchema] should] equal:DEFAULT_USER_SCHEMA];
        });
        context(@"when I change the user object name", ^{
            beforeEach(^{
                [client setUserSchema:@"player"];
            });
            it(@"should now equal player", ^{
                [[[client userSchema] should] equal:@"player"];
            });
        });
    });
    
    
    describe(@"userId", ^{
        it(@"should default to username", ^{
            [[[client userPrimaryKeyField] should] equal:DEFAULT_PRIMARY_KEY_FIELD_NAME];
        });
    });
    
    
    describe(@"userPasswordField", ^{
        it(@"should default to password", ^{
            [[[client userPasswordField] should] equal:DEFAULT_PASSWORD_FIELD_NAME];
        });
    });
    
    
    describe(@"session", ^{
        it(@"should not be nil", ^{
            [[client session] shouldNotBeNil]; 
        });
        it(@"should have a regularOAuthClient", ^{
            [[[client session] regularOAuthClient] shouldNotBeNil];
        });
        it(@"should have a secureOAuthClient", ^{
            [[[client session] secureOAuthClient] shouldNotBeNil];
        });
    });
});

describe(@"complex configuration", ^{
    __block SMClient *client = nil;
    __block NSString *appAPIVersion = @"0";
    __block NSString *publicKey = nil;
    __block NSString *UDIDSalt = nil;
    __block NSString *apiHost = nil;
    __block NSString *userSchema = nil;
    __block NSString *userPrimaryKeyField = nil;
    __block NSString *userPasswordField = nil;


    
    beforeEach(^{
        publicKey = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
        UDIDSalt = @"foo";
        apiHost = @"bar";
        userSchema = @"qux";
        userPrimaryKeyField = @"hello";
        userPasswordField = @"world";
        client = [[SMClient alloc] initWithAPIVersion:appAPIVersion apiHost:apiHost publicKey:publicKey userSchema:userSchema userPrimaryKeyField:userPrimaryKeyField userPasswordField:userPasswordField];
    });
    
    describe(@"app api version", ^{
        it(@"should set the client api version", ^{
            [[client.appAPIVersion should] equal:appAPIVersion];
        });
    });
    
    
    describe(@"API host", ^{
        it(@"should be set", ^{
            [[[[client session] getHttpHost] should] equal:apiHost];
            [[[[client session] getHttpsHost] should] equal:apiHost];
        });
    });
    
    describe(@"public key", ^{
        it(@"should be set", ^{
            [[client.publicKey should] equal:publicKey];
        });
    });
    
    describe(@"StackMob user object name", ^{
        it(@"should be set", ^{
            [[[client userSchema] should] equal:userSchema];
        });
        context(@"when I change the user object name", ^{
            beforeEach(^{
                [client setUserSchema:@"player"];
            });
            it(@"should now equal player", ^{
                [[[client userSchema] should] equal:@"player"];
            });
        });
        context(@"when I change the user object name to include uppercase letters", ^{
            beforeEach(^{
                [client setUserSchema:@"Player"];
            });
            it(@"should now equal player", ^{
                [[[client userSchema] should] equal:@"player"];
            });
        });
    });
    
    describe(@"userPrimaryKeyField", ^{
        it(@"should be set", ^{
            [[[client userPrimaryKeyField] should] equal:userPrimaryKeyField];
        });
    });
    
    describe(@"userPasswordField", ^{
        it(@"should be set", ^{
            [[[client userPasswordField] should] equal:userPasswordField];
        });
    });

    describe(@"session", ^{
        it(@"should not be nil", ^{
            [[client session] shouldNotBeNil]; 
        });
        it(@"should have a regularOAuthClient", ^{
            [[[client session] regularOAuthClient] shouldNotBeNil];
        });
        it(@"should have a secureOAuthClient", ^{
            [[[client session] secureOAuthClient] shouldNotBeNil];
        });
    });
});

describe(@"-dataStore", ^{
    __block SMDataStore *dataStore = nil;
    __block SMClient *client = nil;
    __block NSString *publicKey = nil;
    __block NSString *APIVersion = @"0";
    beforeEach(^{
        publicKey = @"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
        client = [[SMClient alloc] initWithAPIVersion:APIVersion publicKey:publicKey];
        dataStore = [client dataStore];
    });
    it(@"it should return an SMDataStore instance", ^{
        [dataStore shouldNotBeNil];
    });
    it(@"the Datastore should have the client's configuration settings", ^{
        [[[dataStore apiVersion] should] equal:APIVersion];
    });
    it(@"datastore session should be the same as the clients", ^{
        [[[dataStore session] should] equal:[client session]];
    });
});


describe(@"login with SM username and password", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.tokenClient = [AFHTTPClient nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"username", @"1234", @"password", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
        [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"user/accessToken" parameters:dict];
        [client loginWithUsername:@"matt" password:@"1234" onSuccess:nil onFailure:nil];
    }); 
    
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema, user id, and password field", ^{
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"doggyname", @"1234", @"doggysecret", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
            [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"dog/accessToken" parameters:dict];
            [client loginWithUsername:@"matt" password:@"1234" onSuccess:nil onFailure:nil];
        }); 
    });
    

    it(@"should fail with nil username", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:nil password:@"1234"  onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });    
    
    it(@"should fail with nil password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:@"matt" password:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
});

describe(@"login with SM username, temporary password, and new password", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.tokenClient = [AFHTTPClient nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"username", @"1234", @"password", @"12345", @"new_password", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
        [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"user/accessToken" parameters:dict];
        [client loginWithUsername:@"matt" temporaryPassword:@"1234" settingNewPassword:@"12345" onSuccess:nil onFailure:nil];
    });   
    
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema, user id, and password field", ^{
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"doggyname", @"1234", @"doggysecret", @"12345", @"new_password", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
            [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"dog/accessToken" parameters:dict];
            [client loginWithUsername:@"matt" temporaryPassword:@"1234" settingNewPassword:@"12345" onSuccess:nil onFailure:nil];
        }); 
    });
    
    
    it(@"should fail with nil username", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:nil temporaryPassword:@"1234" settingNewPassword:@"12345"  onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });    
    
    it(@"should fail with nil password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:@"matt" temporaryPassword:nil settingNewPassword:@"12345"  onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
    
    it(@"should fail with nil new password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:@"matt" temporaryPassword:@"1234" settingNewPassword:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
});

describe(@"loggedInUser", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.regularOAuthClient = [SMOAuth2Client nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"GET" path:@"user/loggedInUser" parameters:nil];
        [client getLoggedInUserOnSuccess:nil onFailure:nil];
    });   
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema", ^{
            [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"GET" path:@"dog/loggedInUser" parameters:nil];
            [client getLoggedInUserOnSuccess:nil onFailure:nil];
        }); 
    });
});

describe(@"refreshLogin", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.tokenClient = [AFHTTPClient nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"username", @"1234", @"password", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
        [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"user/accessToken" parameters:dict];
        [client loginWithUsername:@"matt" password:@"1234" onSuccess:nil onFailure:nil];
    }); 
    
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema, user id, and password field", ^{
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"doggyname", @"1234", @"doggysecret", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
            [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"dog/accessToken" parameters:dict];
            [client loginWithUsername:@"matt" password:@"1234" onSuccess:nil onFailure:nil];
        }); 
    });
    
    
    it(@"should fail with nil username", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:nil password:@"1234"  onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });    
    
    it(@"should fail with nil password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithUsername:@"matt" password:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  

});



describe(@"logout", ^{
    
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.regularOAuthClient = [SMOAuth2Client nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"GET" path:@"user/logout" parameters:nil];
        [client logoutOnSuccess:nil onFailure:nil];
    });   
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema", ^{
            [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"GET" path:@"dog/logout" parameters:nil];
            [client logoutOnSuccess:nil onFailure:nil];
        }); 
    });
});


#pragma mark Reset Password

describe(@"forgot password", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.regularOAuthClient = [SMOAuth2Client nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"username", nil];
        [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"POST" path:@"user/forgotPassword" parameters:dict];
        [client sendForgotPaswordEmailForUser:@"matt" onSuccess:nil onFailure:nil];
    });   
    
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should keep username but replace user schema", ^{
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"matt", @"username", nil];
            [[[client.session.regularOAuthClient should] receive] requestWithMethod:@"POST" path:@"dog/forgotPassword" parameters:dict];
            [client sendForgotPaswordEmailForUser:@"matt" onSuccess:nil onFailure:nil];
        }); 
    });

    
    it(@"should fail with nil username", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client sendForgotPaswordEmailForUser:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });    
});

describe(@"reset password", ^{
    
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.secureOAuthClient = [SMOAuth2Client nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *old = [NSDictionary dictionaryWithObject:@"foo" forKey:@"password"];
        NSDictionary *new = [NSDictionary dictionaryWithObject:@"bar" forKey:@"password"];
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:old, @"old", new, @"new", nil];
        [[[client.session.secureOAuthClient should] receive] requestWithMethod:@"POST" path:@"user/resetPassword" parameters:dict];
        [client changeLoggedInUserPasswordFrom:@"foo" to:@"bar" onSuccess:nil onFailure:nil];
    });   
    
    context(@"when alternate values are specified in client ctor", ^{
        beforeEach(^{
            client = [[SMClient alloc] initWithAPIVersion:@"0" apiHost:DEFAULT_API_HOST publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX" userSchema:@"dog" userPrimaryKeyField:@"doggyname" userPasswordField:@"doggysecret"];
        });
        it(@"should pick up the user schema", ^{
            NSDictionary *old = [NSDictionary dictionaryWithObject:@"foo" forKey:@"password"];
            NSDictionary *new = [NSDictionary dictionaryWithObject:@"bar" forKey:@"password"];
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:old, @"old", new, @"new", nil];
            [[[client.session.secureOAuthClient should] receive] requestWithMethod:@"POST" path:@"dog/resetPassword" parameters:dict];
            [client changeLoggedInUserPasswordFrom:@"foo" to:@"bar" onSuccess:nil onFailure:nil];
        }); 
    });
    
    
    it(@"should fail with nil old password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client changeLoggedInUserPasswordFrom:nil to:@"bar" onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });    
    
    it(@"should fail with nil new password", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client changeLoggedInUserPasswordFrom:@"foo" to:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
});

#pragma mark Facebook Auth

describe(@"loginWithFacebook", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        client.session.tokenClient = [AFHTTPClient nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"foo", @"fb_at", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
        [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"user/facebookAccessToken" parameters:dict];
        [client loginWithFacebookToken:@"foo" onSuccess:nil onFailure:nil];
    });  
    it(@"should fail with nil token", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithFacebookToken:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
});

         /*
describe(@"createWithFacebook", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"foo"];
        client.session.secureOAuthClient = [SMOAuth2Client nullMock];
    });
    
    it(@"should create the appropriate request", ^{
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"foo", @"fb_at", @"mac", @"token_type", @"hmac-sha-1", @"mac_algorithm", nil];
        [[[client.session.tokenClient should] receive] requestWithMethod:@"POST" path:@"user/facebookAccessToken" parameters:dict];
        [client loginWithFacebookToken:@"foo" onSuccess:nil onFailure:nil];
    });  
    it(@"should fail with nil token", ^{
        __block int failureBlockCalled = 0;
        __block int successBlockCalled = 0;
        [client loginWithFacebookToken:nil onSuccess:^(NSDictionary *responseObject){
            successBlockCalled = 1;
        } onFailure:^(NSError *error) {
            [error shouldNotBeNil];
            [[error.domain should] equal:SMErrorDomain];
            [[theValue(error.code) should] equal:theValue(SMErrorInvalidArguments)];
            failureBlockCalled = 1;
        }];
        [[theValue(successBlockCalled) should] equal:theValue(0)];
        [[theValue(failureBlockCalled) should] equal:theValue(1)];
    });  
});

- (void)createUserWithFacebookToken:(NSString *)fbToken
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)createUserWithFacebookToken:(NSString *)fbToken
username:(NSString *)username
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)linkLoggedInUserWithFacebookToken:(NSString *)fbToken
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)loginWithFacebookToken:(NSString *)fbToken
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)updateFacebookStatusWithMessage:(NSString *)message
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)getLoggedInUserFacebookInfoWithOnSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;


#pragma mark Twitter Auth

- (void)createUserWithTwitterToken:(NSString *)twitterToken
twitterSecret:(NSString *)twitterSecret
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)createUserWithTwitterToken:(NSString *)twitterToken
twitterSecret:(NSString *)twitterSecret
username:(NSString *)username
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)linkLoggedInUserWithTwitterToken:(NSString *)twitterToken
twitterSecret:(NSString *)twitterSecret
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;


- (void)loginWithTwitterToken:(NSString *)twitterToken
twitterSecret:(NSString *)twitterSecret
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)updateTwitterStatusWithMessage:(NSString *)message
onSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;

- (void)getLoggedInUserTwitterInfoWithOnSuccess:(SMResultSuccessBlock)successBlock
onFailure:(SMFailureBlock)failureBlock;
          */


SPEC_END
