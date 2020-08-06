#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "NSObject+TCJSONModel.h"
#import "TCJSONKeyMapper.h"
#import "TCJSONModel.h"
#import "TCJSONModelClassProperty.h"
#import "TCJSONModelError.h"
#import "TCJSONValueTransformer.h"

FOUNDATION_EXPORT double TCJSONModelVersionNumber;
FOUNDATION_EXPORT const unsigned char TCJSONModelVersionString[];

