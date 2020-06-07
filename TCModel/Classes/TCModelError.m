//
//  JSONModelError.m
//  JSONModel
//

#import "TCModelError.h"

NSString* const TCModelErrorDomain = @"TCModelErrorDomain";
NSString* const kTCModelMissingKeys = @"kTCModelMissingKeys";
NSString* const kTCModelTypeMismatch = @"kTCModelTypeMismatch";
NSString* const kTCModelKeyPath = @"kTCModelKeyPath";

@implementation TCModelError

+(id)errorInvalidDataWithMessage:(NSString*)message
{
    message = [NSString stringWithFormat:@"Invalid JSON data: %@", message];
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:message}];
}

+(id)errorInvalidDataWithMissingKeys:(NSSet *)keys
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON data. Required JSON keys are missing from the input. Check the error user information.",kTCModelMissingKeys:[keys allObjects]}];
}

+(id)errorInvalidDataWithTypeMismatch:(NSString*)mismatchDescription
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorInvalidData
                                  userInfo:@{NSLocalizedDescriptionKey:@"Invalid JSON data. The JSON type mismatches the expected type. Check the error user information.",kTCModelTypeMismatch:mismatchDescription}];
}

+(id)errorBadResponse
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorBadResponse
                                  userInfo:@{NSLocalizedDescriptionKey:@"Bad network response. Probably the JSON URL is unreachable."}];
}

+(id)errorBadJSON
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorBadJSON
                                  userInfo:@{NSLocalizedDescriptionKey:@"Malformed JSON. Check the JSONModel data input."}];
}

+(id)errorModelIsInvalid
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorModelIsInvalid
                                  userInfo:@{NSLocalizedDescriptionKey:@"Model does not validate. The custom validation for the input data failed."}];
}

+(id)errorInputIsNil
{
    return [TCModelError errorWithDomain:TCModelErrorDomain
                                      code:kTCModelErrorNilInput
                                  userInfo:@{NSLocalizedDescriptionKey:@"Initializing model with nil input object."}];
}

- (instancetype)errorByPrependingKeyPathComponent:(NSString*)component
{
    // Create a mutable  copy of the user info so that we can add to it and update it
    NSMutableDictionary* userInfo = [self.userInfo mutableCopy];

    // Create or update the key-path
    NSString* existingPath = userInfo[kTCModelKeyPath];
    NSString* separator = [existingPath hasPrefix:@"["] ? @"" : @".";
    NSString* updatedPath = (existingPath == nil) ? component : [component stringByAppendingFormat:@"%@%@", separator, existingPath];
    userInfo[kTCModelKeyPath] = updatedPath;

    // Create the new error
    return [TCModelError errorWithDomain:self.domain
                                      code:self.code
                                  userInfo:[NSDictionary dictionaryWithDictionary:userInfo]];
}

@end
