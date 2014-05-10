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

#import "SMClient.h"
#import "SMDataStore.h"
#import "SMCoreDataStore.h"
#import "SMUserSession.h"
#import "SMOAuth2Client.h"
#import "AFHTTPClient.h"
#import "SMDataStore+Protected.h"
#import "SMRequestOptions.h"
#import "SMError.h"
#import "SMNetworkReachability.h"
#import "FileManagement.h"

#define FB_TOKEN_KEY @"fb_at"
#define TW_TOKEN_KEY @"tw_tk"
#define TW_SECRET_KEY @"tw_ts"
#define UUID_CHAR_NUM 36
#define HTTP @"http"
#define HTTPS @"https"

static SMClient *defaultClient = nil;

NSString *const SMDefaultHostsKey = @"SMDefaultHostsKey";
NSString *const SMRedirectedHostsKey = @"SMRedirectedHostsKey";


@interface SMClient ()

@property(nonatomic, readwrite, copy) NSString *publicKey;
@property(nonatomic, readwrite, strong) SMUserSession * session;
@property(nonatomic, readwrite, strong) SMCoreDataStore *coreDataStore;

@end

@implementation SMClient

@synthesize appAPIVersion = _SM_appAPIVersion;
@synthesize publicKey = _SM_publicKey;
@synthesize apiHost = _SM_APIHost;
@synthesize userSchema = _SM_userSchema;
@synthesize userPrimaryKeyField = _userPrimaryKeyField;
@synthesize userPasswordField = _SM_userPasswordField;

@synthesize session = _SM_session;
@synthesize coreDataStore = _SM_coreDataStore;

- (SMNetworkReachability *)networkMonitor
{
    return self.session.networkMonitor;
}

+ (void)setDefaultClient:(SMClient *)client
{
    defaultClient = client;
}

+ (SMClient *)defaultClient
{
    return defaultClient;
}

- (id)initWithAPIVersion:(NSString *)appAPIVersion publicKey:(NSString *)publicKey
{
    return [self initWithAPIVersion:appAPIVersion
                            apiHost:DEFAULT_API_HOST
                          publicKey:publicKey
                         userSchema:DEFAULT_USER_SCHEMA
                userPrimaryKeyField:DEFAULT_PRIMARY_KEY_FIELD_NAME
                  userPasswordField:DEFAULT_PASSWORD_FIELD_NAME];
}

- (id)initWithAPIVersion:(NSString *)appAPIVersion 
                 apiHost:(NSString *)apiHost 
               publicKey:(NSString *)publicKey 
              userSchema:(NSString *)userSchema
     userPrimaryKeyField:(NSString *)userPrimaryKeyField
       userPasswordField:(NSString *)userPasswordField
{
    return [self initWithAPIVersion:appAPIVersion httpHost:apiHost httpsHost:apiHost publicKey:publicKey userSchema:userSchema userPrimaryKeyField:userPrimaryKeyField userPasswordField:userPasswordField];
}

- (id)initWithAPIVersion:(NSString *)appAPIVersion
                httpHost:(NSString *)httpHost
               httpsHost:(NSString *)httpsHost
               publicKey:(NSString *)publicKey
              userSchema:(NSString *)userSchema
     userPrimaryKeyField:(NSString *)userPrimaryKeyField
       userPasswordField:(NSString *)userPasswordField
{
    self = [super init];
    if (self)
    {
        self.appAPIVersion = appAPIVersion;
        self.publicKey = publicKey;
        self.userSchema = [userSchema lowercaseString];
        self.userPrimaryKeyField = userPrimaryKeyField;
        self.userPasswordField = userPasswordField;
        
        // Throw an exception if apiVersion is nil or incorrectly formatted
        NSCharacterSet* notDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        
        if (self.appAPIVersion == nil || [self.appAPIVersion rangeOfCharacterFromSet:notDigits].location != NSNotFound) {
            [NSException raise:@"SMClientInitializationException" format:@"Incorrect API Version provided.  API Version must be an integer and cannot be nil.  Pass @\"0\" for Development and @\"1\" or greater for Production, depending on which version of your application you are developing for."];
        }
        
        // Throw an excpetion if publicKey is nil or incorrectly formatted
        if (self.publicKey == nil || [self.publicKey length] != UUID_CHAR_NUM) {
            [NSException raise:@"SMClientInitializationException" format:@"Incorrect Public Key format provided.  Please check your public key to make sure you are passing the correct one, and that you are not passing nil."];
        }
        
        // Pull host data from user defaults
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        
        NSString *defaultHostsPath = nil;
        if (applicationName != nil) {
            defaultHostsPath = [NSString stringWithFormat:@"%@-%@-%@", applicationName, publicKey, SMDefaultHostsKey];
        } else {
            defaultHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMDefaultHostsKey];
        }
        
        NSString *redirectedHostsPath = nil;
        if (applicationName != nil) {
            redirectedHostsPath = [NSString stringWithFormat:@"%@-%@-%@", applicationName, publicKey, SMRedirectedHostsKey];
        } else {
            redirectedHostsPath = [NSString stringWithFormat:@"%@-%@", publicKey, SMRedirectedHostsKey];
        }
        
        NSDictionary *defaultHosts = [[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath];
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath];
        
        
        // Check defaults
        NSString *hostToUseHTTP = nil;
        NSString *hostToUseHTTPS = nil;
        if (defaultHosts) {
            
            hostToUseHTTP = [self SM_getHostToUseForScheme:HTTP currentHosts:[NSDictionary dictionaryWithObjectsAndKeys:httpHost, HTTP, httpsHost, HTTPS, nil] defaultHosts:defaultHosts defaultPath:defaultHostsPath redirectedHosts:redirectedHosts redirectPath:redirectedHostsPath];
            
            hostToUseHTTPS = [self SM_getHostToUseForScheme:HTTPS currentHosts:[NSDictionary dictionaryWithObjectsAndKeys:httpHost, HTTP, httpsHost, HTTPS, nil] defaultHosts:[[NSUserDefaults standardUserDefaults] objectForKey:defaultHostsPath] defaultPath:defaultHostsPath redirectedHosts:[[NSUserDefaults standardUserDefaults] objectForKey:redirectedHostsPath] redirectPath:redirectedHostsPath];
            
        } else {
            // Never saved current host/port to defaults
            hostToUseHTTP = httpHost;
            hostToUseHTTPS = httpsHost;
            NSDictionary *defaultHostsToPersist = [NSDictionary dictionaryWithObjectsAndKeys:httpHost, HTTP, httpsHost, HTTPS, nil];
            [[NSUserDefaults standardUserDefaults] setObject:defaultHostsToPersist forKey:defaultHostsPath];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        self.session = [[SMUserSession alloc] initWithAPIVersion:appAPIVersion httpHost:hostToUseHTTP httpsHost:hostToUseHTTPS publicKey:publicKey userSchema:userSchema userPrimaryKeyField:userPrimaryKeyField userPasswordField:userPasswordField];
        
        // Assign for deprecated purposes
        _SM_APIHost = hostToUseHTTP;
        
        self.coreDataStore = nil;
        
        
        if ([SMClient defaultClient] == nil) {
            [SMClient setDefaultClient:self];
        }
    }
    
    return self;
}

/*
 current/default/redirected hosts all in the form
 {
    "http" : "<host>:<port>",
    "https" : "<host>:<port>"
 }
 
 Current and default will always have both schemes, redirected may have only one.
 Port only attached to scheme if not 80/443.
 
 */
- (NSString *)SM_getHostToUseForScheme:(NSString *)scheme currentHosts:(NSDictionary *)currentHosts defaultHosts:(NSDictionary *)defaultHosts defaultPath:(NSString *)defaultPath redirectedHosts:(NSDictionary *)redirectedHosts redirectPath:(NSString *)redirectPath
{
    NSString *currentHost = [currentHosts objectForKey:scheme];
    NSString *defaultHost = [defaultHosts objectForKey:scheme];
    NSString *redirectedHost = [redirectedHosts objectForKey:scheme];
    
    if (![currentHost isEqualToString:defaultHost]) {
        // Initializing with a new default, use it and clear any redirects
        
        NSMutableDictionary *defaultValuesCopy = [defaultHosts mutableCopy];
        [defaultValuesCopy setObject:currentHost forKey:scheme];
        [[NSUserDefaults standardUserDefaults] setObject:defaultValuesCopy forKey:defaultPath];
        
        NSMutableDictionary *redirectedValuesCopy = [redirectedHosts mutableCopy];
        [redirectedValuesCopy removeObjectForKey:scheme];
        [redirectedValuesCopy count] == 0 ? [[NSUserDefaults standardUserDefaults] removeObjectForKey:redirectPath] : [[NSUserDefaults standardUserDefaults] setObject:redirectedValuesCopy forKey:redirectPath];
        
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        return currentHost;
        
    } else {
        
        // Check redirect flag
        if (redirectedHost) {
            // Use this value as the host for this scheme
            return redirectedHost;
        } else {
            // Use currentHost for this scheme
            return currentHost;
        }
    }
    
    return nil;
}

- (SMDataStore *)dataStore
{
    return [[SMDataStore alloc] initWithAPIVersion:self.appAPIVersion session:self.session];
}

- (SMCoreDataStore *)coreDataStore
{
    return _SM_coreDataStore;
}

- (SMCoreDataStore *)coreDataStoreWithManagedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    if (self.coreDataStore == nil) {
        self.coreDataStore = [[SMCoreDataStore alloc] initWithAPIVersion:self.appAPIVersion session:self.session managedObjectModel:managedObjectModel];
    }
    
    return self.coreDataStore;
}

- (void)setUserSchema:(NSString *)userSchema
{
    if (![_SM_userSchema isEqualToString:userSchema]) {
        _SM_userSchema = [userSchema lowercaseString];
        [self.session setUserSchema:_SM_userSchema];
    }
}

- (void)setUserPrimaryKeyField:(NSString *)userPrimaryKeyField
{
    if (![_userPrimaryKeyField isEqualToString:userPrimaryKeyField]) {
        _userPrimaryKeyField = userPrimaryKeyField;
        [self.session setUserPrimaryKeyField:userPrimaryKeyField];
    }
}

- (void)setUserPasswordField:(NSString *)userPasswordField
{
    if (![_SM_userPasswordField isEqualToString:userPasswordField]) {
        _SM_userPasswordField = userPasswordField;
        [self.session setUserPasswordField:userPasswordField];
    }
}

- (void)setRedirectedAPIHost:(NSString *)apiHost port:(NSNumber *)port scheme:(NSString *)scheme permanent:(BOOL)permanent
{
    
    [self.session setNewAPIHost:apiHost port:port scheme:scheme];
    
    if (permanent) {
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        
        NSString *baseRedirectKey = nil;
        if (applicationName != nil) {
            baseRedirectKey = [NSString stringWithFormat:@"%@-%@-", applicationName, self.publicKey];
        } else {
            baseRedirectKey = [NSString stringWithFormat:@"%@-", self.publicKey];
        }
        
        NSString *hostRedirectKey = [NSString stringWithFormat:@"%@%@", baseRedirectKey, SMRedirectedHostsKey];
        
        NSString *fullHostString = port ? [NSString stringWithFormat:@"%@:%@", apiHost, port] : apiHost;
        
        NSDictionary *redirectedHosts = [[NSUserDefaults standardUserDefaults] objectForKey:hostRedirectKey];
        
        if (redirectedHosts) {
            // Update existing
            NSMutableDictionary *redirectedHostsCopy = [redirectedHosts mutableCopy];
            [redirectedHostsCopy setObject:fullHostString forKey:scheme];
            [[NSUserDefaults standardUserDefaults] setObject:redirectedHostsCopy forKey:hostRedirectKey];
        } else {
            NSDictionary *redirectedHostDict = [NSDictionary dictionaryWithObjectsAndKeys:fullHostString, scheme, nil];
            [[NSUserDefaults standardUserDefaults] setObject:redirectedHostDict forKey:hostRedirectKey];
        }
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithUsername:username password:password options:[SMRequestOptions options] onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
              options:(SMRequestOptions *)options
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithUsername:username password:password options:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
                  options:(SMRequestOptions *)options
     successCallbackQueue:(dispatch_queue_t)successCallbackQueue
     failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    if (username == nil || password == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:username, self.userPrimaryKeyField, password, self.userPasswordField, nil];
        [self.session doTokenRequestWithEndpoint:@"accessToken" credentials:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
    }
}

- (void)loginWithUsername:(NSString *)username
        temporaryPassword:(NSString *)tempPassword
       settingNewPassword:(NSString *)newPassword
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithUsername:username temporaryPassword:tempPassword settingNewPassword:newPassword options:[SMRequestOptions options] onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithUsername:(NSString *)username
        temporaryPassword:(NSString *)tempPassword
       settingNewPassword:(NSString *)newPassword
              options:(SMRequestOptions *)options
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithUsername:username temporaryPassword:tempPassword settingNewPassword:newPassword options:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithUsername:(NSString *)username
        temporaryPassword:(NSString *)tempPassword
       settingNewPassword:(NSString *)newPassword
                  options:(SMRequestOptions *)options
     successCallbackQueue:(dispatch_queue_t)successCallbackQueue
     failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    if (username == nil || tempPassword == nil || newPassword == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:username, self.userPrimaryKeyField,
                              tempPassword, self.userPasswordField,
                              newPassword, @"new_password", nil];
        [self.session doTokenRequestWithEndpoint:@"accessToken" credentials:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
    }
}

- (void)getLoggedInUserOnSuccess:(SMResultSuccessBlock)successBlock
                       onFailure:(SMFailureBlock)failureBlock
{
    [self getLoggedInUserWithOptions:[SMRequestOptions options] onSuccess:successBlock onFailure:failureBlock];
}

- (void)getLoggedInUserWithOptions:(SMRequestOptions *)options
                         onSuccess:(SMResultSuccessBlock)successBlock
                         onFailure:(SMFailureBlock)failureBlock
{
    [self getLoggedInUserWithOptions:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)getLoggedInUserWithOptions:(SMRequestOptions *)options
              successCallbackQueue:(dispatch_queue_t)successCallbackQueue
              failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                         onSuccess:(SMResultSuccessBlock)successBlock
                         onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore readObjectWithId:@"loggedInUser" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *object, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)refreshLoginWithOnSuccess:(SMResultSuccessBlock)successBlock
                        onFailure:(SMFailureBlock)failureBlock
{
    [[self session] refreshTokenOnSuccess:successBlock onFailure:failureBlock];
}

- (void)setTokenRefreshFailureBlock:(void (^)(NSError *error, SMFailureBlock originalFailureBlock))block
{
    [[self session] setTokenRefreshFailureBlock:block];
}

- (void)sendForgotPaswordEmailForUser:(NSString *)username
                            onSuccess:(SMResultSuccessBlock)successBlock
                            onFailure:(SMFailureBlock)failureBlock
{
    if (username == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObject:username forKey:DEFAULT_PRIMARY_KEY_FIELD_NAME];
        [self.dataStore createObject:args inSchema:[self.userSchema stringByAppendingPathComponent:@"forgotPassword"] onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)changeLoggedInUserPasswordFrom:(NSString *)oldPassword
                                     to:(NSString *)newPassword
                              onSuccess:(SMResultSuccessBlock)successBlock
                              onFailure:(SMFailureBlock)failureBlock
{
    if (oldPassword == nil || newPassword == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *old = [NSDictionary dictionaryWithObject:oldPassword forKey:@"password"];
        NSDictionary *new = [NSDictionary dictionaryWithObject:newPassword forKey:@"password"];
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:old, @"old", new, @"new", nil];
        SMRequestOptions *options = [SMRequestOptions options];
        options.isSecure = YES;
        [self.dataStore createObject:args inSchema:[self.userSchema stringByAppendingPathComponent:@"resetPassword"] options:options onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)logoutOnSuccess:(SMResultSuccessBlock)successBlock
                  onFailure:(SMFailureBlock)failureBlock
{
    [self logoutWithOptions:[SMRequestOptions options] onSuccess:successBlock onFailure:failureBlock];
}

- (void)logoutWithOptions:(SMRequestOptions *)options
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self logoutWithOptions:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)logoutWithOptions:(SMRequestOptions *)options
     successCallbackQueue:(dispatch_queue_t)successCallbackQueue
     failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                onSuccess:(SMResultSuccessBlock)successBlock
                onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore readObjectWithId:@"logout" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        [[self session] clearSessionInfo];
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *object, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (BOOL)isLoggedIn
{
    return [self.session refreshToken] != nil || ![self.session accessTokenHasExpired];
}

- (BOOL)isLoggedOut
{
    return ![self isLoggedIn];
}

- (void)addAcceptableContentTypes:(NSSet *)contentTypes
{
    
}

# pragma mark Facebook

- (void)createUserWithFacebookToken:(NSString *)fbToken
                          onSuccess:(SMResultSuccessBlock)successBlock
                          onFailure:(SMFailureBlock)failureBlock
{
    [self createUserWithFacebookToken:fbToken username:nil onSuccess:successBlock onFailure:failureBlock];
}

- (void)createUserWithFacebookToken:(NSString *)fbToken
                           username:(NSString *)username
                          onSuccess:(SMResultSuccessBlock)successBlock
                          onFailure:(SMFailureBlock)failureBlock
{
    [self createUserWithFacebookToken:fbToken username:username options:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)createUserWithFacebookToken:(NSString *)fbToken
                           username:(NSString *)username
                            options:(SMRequestOptions *)options
               successCallbackQueue:(dispatch_queue_t)successCallbackQueue
               failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                          onSuccess:(SMResultSuccessBlock)successBlock
                          onFailure:(SMFailureBlock)failureBlock
{
    if (fbToken == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSMutableDictionary *args = [[NSDictionary dictionaryWithObject:fbToken forKey:FB_TOKEN_KEY] mutableCopy];
        if (username != nil) {
            [args setValue:username forKey:self.userPrimaryKeyField];
        }
        [self.dataStore createObject:args inSchema:[NSString stringWithFormat:@"%@/createUserWithFacebook", self.userSchema] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)linkLoggedInUserWithFacebookToken:(NSString *)fbToken
                                onSuccess:(SMResultSuccessBlock)successBlock
                                onFailure:(SMFailureBlock)failureBlock
{
    [self linkLoggedInUserWithFacebookToken:fbToken options:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)linkLoggedInUserWithFacebookToken:(NSString *)fbToken
                                  options:(SMRequestOptions *)options
                     successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                     failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                onSuccess:(SMResultSuccessBlock)successBlock
                                onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:fbToken, FB_TOKEN_KEY, nil];
    [self.dataStore readObjectWithId:@"linkUserWithFacebook" inSchema:self.userSchema parameters:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)unlinkLoggedInUserFromFacebookOnSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self unlinkLoggedInUserFromFacebookWithOptions:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)unlinkLoggedInUserFromFacebookWithOptions:(SMRequestOptions *)options
                             successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                             failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                        onSuccess:(SMSuccessBlock)successBlock
                                        onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore deleteObjectId:@"unlinkUserFromFacebook" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSString *objectId, NSString *schema) {
        if (successBlock) {
            successBlock();
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)loginWithFacebookToken:(NSString *)fbToken
                     onSuccess:(SMResultSuccessBlock)successBlock
                     onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithFacebookToken:fbToken createUserIfNeeded:NO usernameForCreate:nil onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithFacebookToken:(NSString *)fbToken createUserIfNeeded:(BOOL)createUser usernameForCreate:(NSString *)username onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithFacebookToken:fbToken createUserIfNeeded:createUser usernameForCreate:username options:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

// Deprecated
- (void)loginWithFacebookToken:(NSString *)fbToken
                   options:(SMRequestOptions *)options
                     onSuccess:(SMResultSuccessBlock)successBlock
                     onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithFacebookToken:fbToken createUserIfNeeded:NO usernameForCreate:nil options:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithFacebookToken:(NSString *)fbToken
            createUserIfNeeded:(BOOL)createUser
             usernameForCreate:(NSString *)username
                       options:(SMRequestOptions *)options
          successCallbackQueue:(dispatch_queue_t)successCallbackQueue
          failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                     onSuccess:(SMResultSuccessBlock)successBlock
                     onFailure:(SMFailureBlock)failureBlock
{
    if (fbToken == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSMutableDictionary *args = [NSMutableDictionary dictionaryWithObjectsAndKeys:fbToken, FB_TOKEN_KEY, nil];
        NSString *endpoint = @"facebookAccessToken";
        if (createUser) {
            endpoint = [endpoint stringByAppendingString:@"WithCreate"];
            if (username != nil) {
                [args setObject:username forKey:@"username"];
            }
        }
        [self.session doTokenRequestWithEndpoint:endpoint credentials:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
    }
}

- (void)updateFacebookStatusWithMessage:(NSString *)message
                              onSuccess:(SMResultSuccessBlock)successBlock
                              onFailure:(SMFailureBlock)failureBlock
{
    [self updateFacebookStatusWithMessage:message options:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)updateFacebookStatusWithMessage:(NSString *)message
                                options:(SMRequestOptions *)options
                   successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                   failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                              onSuccess:(SMResultSuccessBlock)successBlock
                              onFailure:(SMFailureBlock)failureBlock
{
    if (message == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObject:message forKey:@"message"];
        
        [self.dataStore readObjectWithId:@"postFacebookMessage" inSchema:self.userSchema parameters:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)getLoggedInUserFacebookInfoWithOnSuccess:(SMResultSuccessBlock)successBlock
                                       onFailure:(SMFailureBlock)failureBlock
{ 
    [self getLoggedInUserFacebookInfoWithOptions:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)getLoggedInUserFacebookInfoWithOptions:(SMRequestOptions *)options
                          successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                          failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                     onSuccess:(SMResultSuccessBlock)successBlock
                                     onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore readObjectWithId:@"getFacebookUserInfo" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

# pragma mark Twitter

- (void)createUserWithTwitterToken:(NSString *)twitterToken
                     twitterSecret:(NSString *)twitterSecret
                         onSuccess:(SMResultSuccessBlock)successBlock
                         onFailure:(SMFailureBlock)failureBlock
{
    [self createUserWithTwitterToken:twitterToken twitterSecret:twitterSecret username:nil onSuccess:successBlock onFailure:failureBlock];
}


- (void)createUserWithTwitterToken:(NSString *)twitterToken
                     twitterSecret:(NSString *)twitterSecret
                          username:(NSString *)username
                         onSuccess:(SMResultSuccessBlock)successBlock
                         onFailure:(SMFailureBlock)failureBlock
{
    [self createUserWithTwitterToken:twitterToken twitterSecret:twitterSecret username:username options:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)createUserWithTwitterToken:(NSString *)twitterToken
                     twitterSecret:(NSString *)twitterSecret
                          username:(NSString *)username
                           options:(SMRequestOptions *)options
              successCallbackQueue:(dispatch_queue_t)successCallbackQueue
              failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                         onSuccess:(SMResultSuccessBlock)successBlock
                         onFailure:(SMFailureBlock)failureBlock
{
    if (twitterToken == nil || twitterSecret == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSMutableDictionary *args = [[NSDictionary dictionaryWithObjectsAndKeys:twitterToken, TW_TOKEN_KEY, twitterSecret, TW_SECRET_KEY, nil] mutableCopy];
        if (username != nil) {
            [args setValue:username forKey:self.userPrimaryKeyField];
        }
        [self.dataStore readObjectWithId:@"createUserWithTwitter" inSchema:self.userSchema parameters:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)linkLoggedInUserWithTwitterToken:(NSString *)twitterToken
                           twitterSecret:(NSString *)twitterSecret
                               onSuccess:(SMResultSuccessBlock)successBlock
                               onFailure:(SMFailureBlock)failureBlock
{
    [self linkLoggedInUserWithTwitterToken:twitterToken twitterSecret:twitterSecret options:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)linkLoggedInUserWithTwitterToken:(NSString *)twitterToken
                           twitterSecret:(NSString *)twitterSecret
                                 options:(SMRequestOptions *)options
                    successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                    failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                               onSuccess:(SMResultSuccessBlock)successBlock
                               onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:twitterToken, TW_TOKEN_KEY, twitterSecret, TW_SECRET_KEY, nil];
    [self.dataStore readObjectWithId:@"linkUserWithTwitter" inSchema:self.userSchema parameters:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)unlinkLoggedInUserFromTwitterOnSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self unlinkLoggedInUserFromTwitterWithOptions:[SMRequestOptions optionsWithHTTPS] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)unlinkLoggedInUserFromTwitterWithOptions:(SMRequestOptions *)options
                             successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                             failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                        onSuccess:(SMSuccessBlock)successBlock
                                        onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore deleteObjectId:@"unlinkUserFromTwitter" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSString *objectId, NSString *schema) {
        if (successBlock) {
            successBlock();
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)loginWithTwitterToken:(NSString *)twitterToken
                twitterSecret:(NSString *)twitterSecret
                    onSuccess:(SMResultSuccessBlock)successBlock
                    onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithTwitterToken:twitterToken twitterSecret:twitterSecret createUserIfNeeded:NO usernameForCreate:nil onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithTwitterToken:(NSString *)twitterToken
                twitterSecret:(NSString *)twitterSecret
           createUserIfNeeded:(BOOL)createUser
            usernameForCreate:(NSString *)username
                    onSuccess:(SMResultSuccessBlock)successBlock
                    onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithTwitterToken:twitterToken twitterSecret:twitterSecret createUserIfNeeded:createUser usernameForCreate:username options:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

// Deprecated
- (void)loginWithTwitterToken:(NSString *)twitterToken
                twitterSecret:(NSString *)twitterSecret
                  options:(SMRequestOptions *)options
                    onSuccess:(SMResultSuccessBlock)successBlock
                    onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithTwitterToken:twitterToken twitterSecret:twitterSecret createUserIfNeeded:NO usernameForCreate:nil options:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithTwitterToken:(NSString *)twitterToken
                twitterSecret:(NSString *)twitterSecret
           createUserIfNeeded:(BOOL)createUser
            usernameForCreate:(NSString *)username
                      options:(SMRequestOptions *)options
         successCallbackQueue:(dispatch_queue_t)successCallbackQueue
         failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                    onSuccess:(SMResultSuccessBlock)successBlock
                    onFailure:(SMFailureBlock)failureBlock
{
    if (twitterToken == nil || twitterSecret == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSMutableDictionary *args = [NSMutableDictionary dictionaryWithObjectsAndKeys:twitterToken, TW_TOKEN_KEY, twitterSecret, TW_SECRET_KEY, nil];
        NSString *endpoint = @"twitterAccessToken";
        if (createUser) {
            endpoint = [endpoint stringByAppendingString:@"WithCreate"];
            if (username != nil) {
                [args setObject:username forKey:@"username"];
            }
        }
        [self.session doTokenRequestWithEndpoint:endpoint credentials:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
    }
}

- (void)updateTwitterStatusWithMessage:(NSString *)message
                             onSuccess:(SMResultSuccessBlock)successBlock
                             onFailure:(SMFailureBlock)failureBlock
{
    [self updateTwitterStatusWithMessage:message options:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)updateTwitterStatusWithMessage:(NSString *)message
                               options:(SMRequestOptions *)options
                  successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                  failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                             onSuccess:(SMResultSuccessBlock)successBlock
                             onFailure:(SMFailureBlock)failureBlock
{
    if (message == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObject:message forKey:@"tw_st"];
        
        [self.dataStore readObjectWithId:@"twitterStatusUpdate" inSchema:self.userSchema parameters:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
            if (successBlock) {
                successBlock(object);
            }
        } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
            if (failureBlock) {
                failureBlock(error);
            }
        }];
    }
}

- (void)getLoggedInUserTwitterInfoOnSuccess:(SMResultSuccessBlock)successBlock
                                      onFailure:(SMFailureBlock)failureBlock
{
    [self getLoggedInUserTwitterInfoWithOptions:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)getLoggedInUserTwitterInfoWithOptions:(SMRequestOptions *)options
                         successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                         failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                    onSuccess:(SMResultSuccessBlock)successBlock
                                    onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore readObjectWithId:@"getTwitterUserInfo" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

# pragma mark Gigya

- (void)linkLoggedInUserWithGigyaUserDictionary:(NSDictionary *)gsUser
                                           onSuccess:(SMResultSuccessBlock)successBlock
                                           onFailure:(SMFailureBlock)failureBlock
{
    NSString *uid = [gsUser objectForKey:@"UID"];
    NSString *uidSignature = [gsUser objectForKey:@"UIDSignature"];
    NSString *timestamp = [gsUser objectForKey:@"signatureTimestamp"];
    [self linkLoggedInUserWithGigyaUID:uid uidSignature:uidSignature signatureTimestamp:timestamp onSuccess:successBlock onFailure:failureBlock];
}

- (void)linkLoggedInUserWithGigyaUID:(NSString *)uid uidSignature:(NSString *)uidSignature signatureTimestamp:(NSString *)signatureTimestamp onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self linkLoggedInUserWithGigyaUID:uid uidSignature:uidSignature signatureTimestamp:signatureTimestamp options:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)linkLoggedInUserWithGigyaUID:(NSString *)uid uidSignature:(NSString *)uidSignature signatureTimestamp:(NSString *)signatureTimestamp options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:uid, @"gigya_uid", uidSignature, @"gigya_sig", signatureTimestamp, @"gigya_ts", nil];
    [self.dataStore createObject:args inSchema:[NSString stringWithFormat:@"%@/linkUserWithGigya", self.userSchema] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSDictionary *object, NSString *schema) {
        if (successBlock) {
            successBlock(object);
        }
    } onFailure:^(NSError *error, NSDictionary *object, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)unlinkLoggedInUserFromGigyaOnSuccess:(SMSuccessBlock)successBlock
                                   onFailure:(SMFailureBlock)failureBlock
{
    [self unlinkLoggedInUserFromGigyaWithOptions:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)unlinkLoggedInUserFromGigyaWithOptions:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self.dataStore deleteObjectId:@"unlinkUserFromGigya" inSchema:self.userSchema options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:^(NSString *objectId, NSString *schema) {
        if (successBlock) {
            successBlock();
        }
    } onFailure:^(NSError *error, NSString *objectId, NSString *schema) {
        if (failureBlock) {
            failureBlock(error);
        }
    }];
}

- (void)loginWithGigyaUserDictionary:(NSDictionary *)gsUser onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSString *uid = [gsUser objectForKey:@"UID"];
    NSString *uidSignature = [gsUser objectForKey:@"UIDSignature"];
    NSString *timestamp = [gsUser objectForKey:@"signatureTimestamp"];
    [self loginWithGigyaUID:uid uidSignature:uidSignature signatureTimestamp:timestamp onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithGigyaUID:(NSString *)uid uidSignature:(NSString *)uidSignature signatureTimestamp:(NSString *)signatureTimestamp onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithGigyaUID:uid uidSignature:uidSignature signatureTimestamp:signatureTimestamp options:[SMRequestOptions options] successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

// Deprecated 1.4.0
- (void)loginWithGigyaUID:(NSString *)uid uidSignature:(NSString *)uidSignature signatureTimestamp:(NSString *)signatureTimestamp options:(SMRequestOptions *)options onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self loginWithGigyaUID:uid uidSignature:uidSignature signatureTimestamp:signatureTimestamp options:options successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)loginWithGigyaUID:(NSString *)uid uidSignature:(NSString *)uidSignature signatureTimestamp:(NSString *)signatureTimestamp options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    
    if (uid == nil || uidSignature == nil || signatureTimestamp == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Nil argument(s) provided.", NSLocalizedDescriptionKey, nil]];
            failureBlock(error);
        }
    } else {
        NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:uid, @"gigya_uid", uidSignature, @"gigya_sig", signatureTimestamp, @"gigya_ts", nil];
        [self.session doTokenRequestWithEndpoint:@"gigyaAccessToken" credentials:args options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
    }
}

@end
