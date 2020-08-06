//
//  JSONModelError.m
//  JSONModel
//

#import "TCJSONModelError.h"

NSString* const TCJSONModelErrorDomain = @"TCJSONModelErrorDomain";
NSString* const kTCJSONModelMissingKeys = @"kTCJSONModelMissingKeys";
NSString* const kTCJSONModelTypeMismatch = @"kTCJSONModelTypeMismatch";
NSString* const kTCJSONModelKeyPath = @"kTCJSONModelKeyPath";

@implementation TCJSONModelError

+(id)errorInvalidDataWithMessage:(NSString*)message
{
    message = [NSString stringWithFormat:@"Invalid JSON data: %@", message];
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:message}];
}

+(id)errorInvalidDataWithMissingKeys:(NSSet *)keys
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON data. Required JSON keys are missing from the input. Check the error user information.",kTCJSONModelMissingKeys:[keys allObjects]}];
}

+(id)errorInvalidDataWithTypeMismatch:(NSString*)mismatchDescription
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON data. The JSON type mismatches the expected type. Check the error user information.",kTCJSONModelTypeMismatch:mismatchDescription}];
}

+(id)errorBadResponse
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorBadResponse
                                  userInfo:@{NSLocalizedDescriptionKey:@"Bad network response. Probably the JSON URL is unreachable."}];
}

+(id)errorBadJSON
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorBadJSON
                                  userInfo:@{NSLocalizedDescriptionKey:@"Malformed JSON. Check the JSONModel data input."}];
}

+(id)errorModelIsInvalid
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorModelIsInvalid
                                  userInfo:@{NSLocalizedDescriptionKey:@"Model does not validate. The custom validation for the input data failed."}];
}

+(id)errorInputIsNil
{
    return [TCJSONModelError errorWithDomain:TCJSONModelErrorDomain
                                      code:kTCJSONModelErrorNilInput
                                  userInfo:@{NSLocalizedDescriptionKey:@"Initializing model with nil input object."}];
}

- (instancetype)errorByPrependingKeyPathComponent:(NSString*)component
{
    // Create a mutable  copy of the user info so that we can add to it and update it
    NSMutableDictionary* userInfo = [self.userInfo mutableCopy];

    // Create or update the key-path
    NSString* existingPath = userInfo[kTCJSONModelKeyPath];
    NSString* separator = [existingPath hasPrefix:@"["] ? @"" : @".";
    NSString* updatedPath = (existingPath == nil) ? component : [component stringByAppendingFormat:@"%@%@", separator, existingPath];
    userInfo[kTCJSONModelKeyPath] = updatedPath;

    // Create the new error
    return [TCJSONModelError errorWithDomain:self.domain
                                      code:self.code
                                  userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
}

@end
