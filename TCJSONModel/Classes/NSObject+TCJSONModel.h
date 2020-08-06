//
//  NSObject+TCJSONModel.h
//
//  Created by xtuck on 2020/6/4.
//  Copyright © 2020 TuCao. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TCJSONModelError.h"
#import "TCJSONKeyMapper.h"

/////////////////////////////////////////////////////////////////////////////////////////////
#if TARGET_IPHONE_SIMULATOR
#define TCLog( s, ... ) NSLog( @"[%@:%d] %@", [[NSString stringWithUTF8String:__FILE__] \
lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define TCLog( s, ... )
#endif
/////////////////////////////////////////////////////////////////////////////////////////////


@protocol TCIgnore
@end
@protocol TCRequired
@end

@interface NSObject (TCJSONModel)<TCIgnore,TCRequired>


/// 类方法转化model
/// @param keyValues 可以是：NSDictionary，NSData，NSString
+ (instancetype)tc_modelFromKeyValues:(id)keyValues;
+ (instancetype)tc_modelFromKeyValues:(id)keyValues error:(NSError **)err;


- (NSDictionary *)tc_toDictionary;
- (NSString *)tc_toJSONString;
- (NSData *)tc_toJSONData;

- (NSDictionary *)tc_toDictionaryWithKeys:(NSArray <NSString *> *)propertyNames;
- (NSString *)tc_toJSONStringWithKeys:(NSArray <NSString *> *)propertyNames;
- (NSData *)tc_toJSONDataWithKeys:(NSArray <NSString *> *)propertyNames;


/// 字典转成model数组
/// @param keyValues 可以是：NSDictionary，NSData，NSString
+ (NSMutableArray *)tc_arrayOfModelsFromKeyValues:(id)keyValues;
+ (NSMutableArray *)tc_arrayOfModelsFromKeyValues:(id)keyValues error:(NSError **)err;


//纯字典转成字典中value为model的字典
+ (NSMutableDictionary *)tc_dictionaryOfModelsFromDictionary:(NSDictionary *)dictionary error:(NSError **)err;
+ (NSMutableDictionary *)tc_dictionaryOfModelsFromData:(NSData *)data error:(NSError **)err;
+ (NSMutableDictionary *)tc_dictionaryOfModelsFromString:(NSString *)string error:(NSError **)err;

//把model数组转化成字典数组
+ (NSMutableArray *)tc_arrayOfDictionariesFromModels:(NSArray *)array;
//把字典中的键和model组成的字典转换成纯字典
+ (NSMutableDictionary *)tc_dictionaryOfDictionariesFromModels:(NSDictionary *)dictionary;

/** @name Key mapping */
/**
 * Overwrite in your models if your property names don't match your JSON key names.
 * Lookup JSONKeyMapper docs for more details.
 */
+ (TCJSONKeyMapper *)tc_keyMapper;

/// 左边是obj对象属性名。右边是字典中的key
+ (NSDictionary *)tc_propertyNameDictionaryKey;


/**
 * Merges values from the given dictionary into the model instance.
 * @param dict dictionary with values
 */
- (BOOL)tc_mergeFromDictionary:(NSDictionary *)dict error:(NSError **)error;


/// 伪copy，返回一个一模一样实例对象
- (instancetype)tc_copy;
- (instancetype)tc_copy:(NSError **)error;

/// 归档解档
- (instancetype)tc_coder:(NSCoder *)decoder;
- (void)tc_encodeCoder:(NSCoder *)encoder;


#pragma mark --提高解析效率

/// 默认不使用自定义get和set，需要按规则使用自定义set和get时，请在model中复写此方法，返回yes
+ (BOOL)tc_supportCustomGetterAndSetters;


@end


//MARK: - 在model类中的.m实现文件中加入TCJSONModelSynthCoder宏，来实现归档解档
#define TCJSONModelSynthCoder \
- (void)encodeWithCoder:(NSCoder *)aCoder { [self tc_encodeCoder:aCoder]; } \
- (id)initWithCoder:(NSCoder *)aDecoder { return [self tc_coder:aDecoder]; } \
+ (BOOL)supportsSecureCoding { return YES; }
