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

#import "NSObject+TCModel.h"
#import "TCJSONKeyMapper.h"
#import "TCJSONValueTransformer.h"
#import "TCModel.h"
#import "TCModelClassProperty.h"
#import "TCModelError.h"

FOUNDATION_EXPORT double TCModelVersionNumber;
FOUNDATION_EXPORT const unsigned char TCModelVersionString[];

