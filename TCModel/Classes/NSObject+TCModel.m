//
//  NSObject+TCModel.m
//
//  Created by xtuck on 2020/6/4.
//  Copyright © 2020 TuCao. All rights reserved.
//


#import "NSObject+TCModel.h"
#import <objc/runtime.h>
#import "TCModelClassProperty.h"
#import "TCJSONValueTransformer.h"
#import <UIKit/UIResponder.h>

#pragma mark - associated objects names
static const char * kTCMapperObjectKey;
static const char * kTCClassPropertiesKey;

#pragma mark - class static variables
static NSArray* tcAllowedJSONTypes = nil;
static NSArray* tcAllowedPrimitiveTypes = nil;
static TCJSONValueTransformer* tcValueTransformer = nil;

#pragma mark - implementation
@implementation NSObject (TCModel)


#pragma mark - initialization methods

+(void)load
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // initialize all class static objects,
        // which are common for ALL TCModel subclasses

        @autoreleasepool {
            tcAllowedJSONTypes = @[
                [NSString class], [NSNumber class], [NSDecimalNumber class], [NSArray class], [NSDictionary class], [NSNull class], //immutable JSON classes
                [NSMutableString class], [NSMutableArray class], [NSMutableDictionary class] //mutable JSON classes
            ];

            tcAllowedPrimitiveTypes = @[
                @"BOOL", @"float", @"int", @"long", @"double", @"short",
                @"unsigned int", @"usigned long", @"long long", @"unsigned long long", @"unsigned short", @"char", @"unsigned char",
                //and some famous aliases
                @"NSInteger", @"NSUInteger",
                @"Block"
            ];

            tcValueTransformer = [[TCJSONValueTransformer alloc] init];
        }
    });
}

-(void)__tcSetup__
{
    //if first instance of this model, generate the property list
    if (!objc_getAssociatedObject(self.class, &kTCClassPropertiesKey)) {
        [self __tcInspectProperties];
    }

    //if there's a custom key mapper, store it in the associated object
    id mapper = [[self class] tc_keyMapper];
    if ( mapper && !objc_getAssociatedObject(self.class, &kTCMapperObjectKey) ) {
        objc_setAssociatedObject(self.class,&kTCMapperObjectKey,mapper,OBJC_ASSOCIATION_RETAIN);
    }
}

-(instancetype)initWithDataTC:(NSData *)data error:(NSError *__autoreleasing *)err
{
    //check for nil input
    if (!data) {
        if (err) *err = [TCModelError errorInputIsNil];
        return nil;
    }
    //read the json
    TCModelError* initError = nil;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&initError];
    if (initError) {
        if (err) *err = [TCModelError errorBadJSON];
        return nil;
    }

    //init with dictionary
    id objModel = [self initWithDictionaryTC:obj error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

-(id)initWithStringTC:(NSString*)string error:(TCModelError**)err
{
    TCModelError* initError = nil;
    id objModel = [self initWithStringTC:string usingEncoding:NSUTF8StringEncoding error:&initError];
    if (initError && err) *err = initError;
    return objModel;
}

-(id)initWithStringTC:(NSString *)string usingEncoding:(NSStringEncoding)encoding error:(TCModelError**)err
{
    //check for nil input
    if (!string) {
        if (err) *err = [TCModelError errorInputIsNil];
        return nil;
    }

    TCModelError* initError = nil;
    id objModel = [self initWithDataTC:[string dataUsingEncoding:encoding] error:&initError];
    if (initError && err) *err = initError;
    return objModel;

}

-(id)initWithDictionaryTC:(NSDictionary*)dict error:(NSError**)err
{
    //check for nil input
    if (!dict) {
        if (err) *err = [TCModelError errorInputIsNil];
        return nil;
    }

    //invalid input, just create empty instance
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (err) *err = [TCModelError errorInvalidDataWithMessage:@"Attempt to initialize JSONModel object using initWithDictionary:error: but the dictionary parameter was not an 'NSDictionary'."];
        return nil;
    }

    //create a class instance
    self = [self init];
    
    if (!self) {

        //super init didn't succeed
        if (err) *err = [TCModelError errorModelIsInvalid];
        return nil;
    }

    [self __tcSetup__];

    //import the data from a dictionary
    if (![self __tcImportDictionary:dict withKeyMapper:self.__tcKeyMapper validation:YES error:err]) {
        return nil;
    }

    //model is valid! yay!
    return self;
}

-(TCJSONKeyMapper*)__tcKeyMapper
{
    //get the model key mapper
    return objc_getAssociatedObject(self.class, &kTCMapperObjectKey);
}

-(NSString*)__tcMapString:(NSString*)string withKeyMapper:(TCJSONKeyMapper*)keyMapper {
    if (keyMapper) {
        string = [keyMapper convertValue:string];
    }
    return string;
}

-(BOOL)__tcImportDictionary:(NSDictionary*)dict withKeyMapper:(TCJSONKeyMapper*)keyMapper validation:(BOOL)validation error:(NSError**)err
{
    //loop over the incoming keys and set self's properties
    for (TCModelClassProperty* property in [self __tcProperties__]) {

        //convert key name to model keys, if a mapper is provided
        NSString* jsonKeyPath = keyMapper ? [self __tcMapString:property.name withKeyMapper:keyMapper] : property.name;
        //JMLog(@"keyPath: %@", jsonKeyPath);

        //general check for data type compliance
        id jsonValue;
        @try {
            jsonValue = [dict valueForKeyPath: jsonKeyPath];
        }
        @catch (NSException *exception) {
            jsonValue = dict[jsonKeyPath];
        }

        //check for Optional properties
        if (isTCNull(jsonValue)) {
            //skip this property, continue with next property
            if (!property.isTCRequired || !validation) continue;

            if (err) {
                //null value for required property
                NSString* msg = [NSString stringWithFormat:@"Value of required model key %@ is null", property.name];
                TCModelError* dataErr = [TCModelError errorInvalidDataWithMessage:msg];
                *err = [dataErr errorByPrependingKeyPathComponent:property.name];
            }
            return NO;
        }

        Class jsonValueClass = [jsonValue class];
        BOOL isValueOfAllowedType = NO;

        for (Class allowedType in tcAllowedJSONTypes) {
            if ( [jsonValueClass isSubclassOfClass: allowedType] ) {
                isValueOfAllowedType = YES;
                break;
            }
        }

        if (isValueOfAllowedType==NO) {
            //type not allowed
            TCLog(@"Type %@ is not allowed in JSON.", NSStringFromClass(jsonValueClass));

            if (err) {
                NSString* msg = [NSString stringWithFormat:@"Type %@ is not allowed in JSON.", NSStringFromClass(jsonValueClass)];
                TCModelError* dataErr = [TCModelError errorInvalidDataWithMessage:msg];
                *err = [dataErr errorByPrependingKeyPathComponent:property.name];
            }
            return NO;
        }

        //check if there's matching property in the model
        if (property) {

            // check for custom setter, than the model doesn't need to do any guessing
            // how to read the property's value from JSON
            if (self.isUseCustomGetterOrSetters && [self __tcCustomSetValue:jsonValue forProperty:property]) {
                //skip to next JSON key
                continue;
            };

            // 0) handle primitives
            if (property.type == nil && property.structName==nil) {

                //generic setter
                if (jsonValue != [self valueForKey:property.name]) {
                    [self setValue:jsonValue forKey: property.name];
                }

                //skip directly to the next key
                continue;
            }

            // 0.5) handle nils
            if (isTCNull(jsonValue)) {
                if ([self valueForKey:property.name] != nil) {
                    [self setValue:nil forKey: property.name];
                }
                continue;
            }


            // 1) check if property is itself a custom Class
            if ([self __isCustomClass:property.type]) {

                //initialize the property's model, store it
                id value = [self valueForKey:property.name];
                TCModelError* initErr = nil;
                if (value && !validation) {
                    //这种情况是将字典合并到model中
                    [(NSObject *)value tc_mergeFromDictionary:jsonValue error:&initErr];
                } else {
                    value = [[property.type alloc] initWithDictionaryTC: jsonValue error:&initErr];
                }

                if (!value) {
                    //skip this property, continue with next property
                    if (!property.isTCRequired || !validation) continue;

                    // Propagate the error, including the property name as the key-path component
                    if((err != nil) && (initErr != nil))
                    {
                        *err = [initErr errorByPrependingKeyPathComponent:property.name];
                    }
                    return NO;
                }
                if (![value isEqual:[self valueForKey:property.name]]) {
                    [self setValue:value forKey: property.name];
                }

                //for clarity, does the same without continue
                continue;

            } else {

                // 2) check if there's a protocol to the property
                //  ) might or not be the case there's a built in transform for it
                if (property.protocol) {

                    //JMLog(@"proto: %@", p.protocol);
                    jsonValue = [self __tcTransform:jsonValue forProperty:property error:err];
                    if (!jsonValue) {
                        if ((err != nil) && (*err == nil)) {
                            NSString* msg = [NSString stringWithFormat:@"Failed to transform value, but no error was set during transformation. (%@)", property];
                            TCModelError* dataErr = [TCModelError errorInvalidDataWithMessage:msg];
                            *err = [dataErr errorByPrependingKeyPathComponent:property.name];
                        }
                        return NO;
                    }
                }

                // 3.1) handle matching standard JSON types
                if (property.isStandardJSONType && [jsonValue isKindOfClass: property.type]) {

                    //mutable properties
                    if (property.isMutable) {
                        jsonValue = [jsonValue mutableCopy];
                    }

                    //set the property value
                    if (![jsonValue isEqual:[self valueForKey:property.name]]) {
                        [self setValue:jsonValue forKey: property.name];
                    }
                    continue;
                }

                // 3.3) handle values to transform
                if (
                    (![jsonValue isKindOfClass:property.type] && !isTCNull(jsonValue))
                    ||
                    //the property is mutable
                    property.isMutable
                    ||
                    //custom struct property
                    property.structName
                    ) {

                    // searched around the web how to do this better
                    // but did not find any solution, maybe that's the best idea? (hardly)
                    Class sourceClass = [TCJSONValueTransformer classByResolvingClusterClasses:[jsonValue class]];

                    //JMLog(@"to type: [%@] from type: [%@] transformer: [%@]", p.type, sourceClass, selectorName);

                    //build a method selector for the property and json object classes
                    NSString* selectorName = [NSString stringWithFormat:@"%@From%@:",
                                              (property.structName? property.structName : property.type), //target name
                                              sourceClass]; //source name
                    SEL selector = NSSelectorFromString(selectorName);

                    //check for custom transformer
                    BOOL foundCustomTransformer = NO;
                    if ([tcValueTransformer respondsToSelector:selector]) {
                        foundCustomTransformer = YES;
                    } else {
                        //try for hidden custom transformer
                        selectorName = [NSString stringWithFormat:@"__%@",selectorName];
                        selector = NSSelectorFromString(selectorName);
                        if ([tcValueTransformer respondsToSelector:selector]) {
                            foundCustomTransformer = YES;
                        }
                    }

                    //check if there's a transformer with that name
                    if (foundCustomTransformer) {
                        IMP imp = [tcValueTransformer methodForSelector:selector];
                        id (*func)(id, SEL, id) = (void *)imp;
                        jsonValue = func(tcValueTransformer, selector, jsonValue);

                        if (![jsonValue isEqual:[self valueForKey:property.name]])
                            [self setValue:jsonValue forKey:property.name];
                    } else {
                        if (!property.isTCRequired) {
                            //存在了不支持的属性类型，但是忽略了
                            TCLog(@"%@ type not supported for %@.%@", property.type, [self class], property.name);
                            continue;
                        }
                        if (err) {
                            NSString* msg = [NSString stringWithFormat:@"%@ type not supported for %@.%@", property.type, [self class], property.name];
                            TCModelError* dataErr = [TCModelError errorInvalidDataWithTypeMismatch:msg];
                            *err = [dataErr errorByPrependingKeyPathComponent:property.name];
                        }
                        return NO;
                    }
                } else {
                    // 3.4) handle "all other" cases (if any)
                    if (![jsonValue isEqual:[self valueForKey:property.name]])
                        [self setValue:jsonValue forKey:property.name];
                }
            }
        }
    }

    return YES;
}

#pragma mark - property inspection methods

///********* 提示 *********
///如果有特殊情况，可以复写此方法，要写在property的持有者的类中，或者写在自己的model基类中，或者直接hook(推荐)该方法。
///特殊情况:你直接用某个系统类作为你的model的属性，然后想要用该属性接收解析数据。（不推荐）
///如果需要使用系统类作为属性，但是不进行数据解析，可以加上<TCIgnore>进行修饰。
///判断class是否是自定义的类，用来过滤系统的类，提高解析效率
/// @param class 对应的是property的类型或者修饰(array和dictionary)的protocol对应的类型
-(BOOL)__isCustomClass:(Class)class {
    if ([tcAllowedJSONTypes containsObject:class]) {
        return NO;
    }
    if ([class isSubclassOfClass:NSDate.class]) {
        return NO;
    }
    if ([class isSubclassOfClass:NSValue.class]) {
        return NO;
    }
    if ([class isSubclassOfClass:NSURL.class]) {
        return NO;
    }
    if ([class isSubclassOfClass:NSSet.class]) {
        return NO;
    }
    if (class == NSObject.class) {
        return NO;
    }
    if ([class isSubclassOfClass:UIResponder.class]) {
        //UI和VC，不要用来作为model的属性，如有必要请加<TCIgnore>进行修饰
        return NO;
    }
//    NSBundle *bundle = [NSBundle bundleForClass:class];
//    if (!bundle.bundleIdentifier) {
//        //NSObject等其他类，在“usr/include”中，没有bundleId
//        return NO;;
//    }
//    //rangeOfString相对来说比较耗时，所以注释掉了
//    NSRange rang = [bundle.bundlePath rangeOfString:@"/System/Library/" options:NSBackwardsSearch];
//    //系统的类都在/RuntimeRoot/System/Library/中
//    if (rang.location != NSNotFound) {
//        return NO;
//    }
    return [class isSubclassOfClass:NSObject.class];
}


//returns a list of the model's properties
-(NSArray*)__tcProperties__
{
    //fetch the associated object
    NSDictionary* classProperties = objc_getAssociatedObject(self.class, &kTCClassPropertiesKey);
    if (classProperties) return [classProperties allValues];

    //if here, the class needs to inspect itself
    [self __tcSetup__];

    //return the property list
    classProperties = objc_getAssociatedObject(self.class, &kTCClassPropertiesKey);
    return [classProperties allValues];
}

//inspects the class, get's a list of the class properties
-(void)__tcInspectProperties
{
    //JMLog(@"Inspect class: %@", [self class]);

    NSMutableDictionary* propertyIndex = [NSMutableDictionary dictionary];

    //temp variables for the loops
    Class class = [self class];
    NSScanner* scanner = nil;
    NSString* propertyType = nil;

    // inspect inherited properties up to the NSObject class
    while (class != [NSObject class]) {
        //JMLog(@"inspecting: %@", NSStringFromClass(class));

        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);

        //loop over the class properties
        for (unsigned int i = 0; i < propertyCount; i++) {

            TCModelClassProperty* p = [[TCModelClassProperty alloc] init];

            //get property name
            objc_property_t property = properties[i];
            const char *propertyName = property_getName(property);
            p.name = @(propertyName);

            //JMLog(@"property: %@", p.name);

            //get property attributes
            const char *attrs = property_getAttributes(property);
            NSString* propertyAttributes = @(attrs);
            NSArray* attributeItems = [propertyAttributes componentsSeparatedByString:@","];

            //ignore read-only properties
            if ([attributeItems containsObject:@"R"]) {
                continue; //to next property
            }

            scanner = [NSScanner scannerWithString: propertyAttributes];

            //JMLog(@"attr: %@", [NSString stringWithCString:attrs encoding:NSUTF8StringEncoding]);
            [scanner scanUpToString:@"T" intoString: nil];
            [scanner scanString:@"T" intoString:nil];

            //check if the property is an instance of a class
            if ([scanner scanString:@"@\"" intoString: &propertyType]) {

                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                        intoString:&propertyType];

                //JMLog(@"type: %@", propertyClassName);
                p.type = NSClassFromString(propertyType);
                p.isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
                p.isStandardJSONType = [tcAllowedJSONTypes containsObject:p.type];

                //read through the property protocols
                while ([scanner scanString:@"<" intoString:NULL]) {

                    NSString* protocolName = nil;

                    [scanner scanUpToString:@">" intoString: &protocolName];

                    if ([protocolName isEqualToString:@"TCRequired"]) {
                        p.isTCRequired = YES;
                    } else if([protocolName isEqualToString:@"TCIgnore"]) {
                        p = nil;
                    } else {
                        p.protocol = protocolName; //对应类名称
                    }

                    [scanner scanString:@">" intoString:NULL];
                }

            }
            //check if the property is a structure
            else if ([scanner scanString:@"{" intoString: &propertyType]) {
                [scanner scanCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]
                                    intoString:&propertyType];

                p.isStandardJSONType = NO;
                p.structName = propertyType;

            }
            //the property must be a primitive
            else {

                //the property contains a primitive data type
                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                        intoString:&propertyType];

                //get the full name of the primitive type
                propertyType = tcValueTransformer.primitivesNames[propertyType];

                if (![tcAllowedPrimitiveTypes containsObject:propertyType]) {

                    //type not allowed - programmer mistaken -> exception
                    @throw [NSException exceptionWithName:@"JSONModelProperty type not allowed"
                                                   reason:[NSString stringWithFormat:@"Property type of %@.%@ is not supported by JSONModel.", self.class, p.name]
                                                 userInfo:nil];
                }

            }

            //few cases where JSONModel will ignore properties automatically
            if ([propertyType isEqualToString:@"Block"]) {
                p = nil;
            }

            //add the property object to the temp index
            if (p && ![propertyIndex objectForKey:p.name]) {
                [propertyIndex setValue:p forKey:p.name];
            }

            // generate custom setters and getter //下面的自定义get和set，基本用不到
            if (p && self.isUseCustomGetterOrSetters)
            {
                NSString *name = [p.name stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[p.name substringToIndex:1].uppercaseString];

                // getter
                SEL getter = NSSelectorFromString([NSString stringWithFormat:@"JSONObjectFor%@", name]);

                if ([self respondsToSelector:getter])
                    p.customGetter = getter;

                // setters
                p.customSetters = [NSMutableDictionary new];

                SEL genericSetter = NSSelectorFromString([NSString stringWithFormat:@"set%@WithJSONObject:", name]);

                if ([self respondsToSelector:genericSetter])
                    p.customSetters[@"generic"] = [NSValue valueWithBytes:&genericSetter objCType:@encode(SEL)];

                for (Class type in tcAllowedJSONTypes)
                {
                    NSString *class = NSStringFromClass([TCJSONValueTransformer classByResolvingClusterClasses:type]);

                    if (p.customSetters[class])
                        continue;

                    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@With%@:", name, class]);

                    if ([self respondsToSelector:setter])
                        p.customSetters[class] = [NSValue valueWithBytes:&setter objCType:@encode(SEL)];
                }
            }
        }

        free(properties);

        //ascend to the super of the class
        //(will do that until it reaches the root class - JSONModel)
        class = [class superclass];
    }

    //finally store the property index in the static property index
    objc_setAssociatedObject(
                             self.class,
                             &kTCClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN // This is atomic
                             );
}

#pragma mark - built-in transformer methods

- (BOOL)isEmptyValue:(id)value {
    if ([[value class] isSubclassOfClass:[NSDictionary class]]) {
        return [value count]==0;
    } else if ([[value class] isSubclassOfClass:[NSString class]]) {
        return [value length]==0;
    } else if ([[value class] isSubclassOfClass:[NSNumber class]]) {
        id num = value;
        return [num isKindOfClass:[NSNull class]];
    }
    return NO;
}

//few built-in transformations
-(id)__tcTransform:(id)value forProperty:(TCModelClassProperty*)property error:(NSError**)err
{
    Class protocolClass = NSClassFromString(property.protocol);
    if (!protocolClass) {

        //no other protocols on arrays and dictionaries
        //except JSONModel classes
        if ([value isKindOfClass:[NSArray class]]) {
            @throw [NSException exceptionWithName:@"Bad property protocol declaration"
                                           reason:[NSString stringWithFormat:@"<%@> is not allowed JSONModel property protocol, and not a JSONModel class.", property.protocol]
                                         userInfo:nil];
        }
        return value;
    }

    //if the protocol is actually a custom class
    if ([self __isCustomClass:protocolClass]) {

        //check if it's a list of models
        if ([property.type isSubclassOfClass:[NSArray class]]) {

            // Expecting an array, make sure 'value' is an array
            if(![[value class] isSubclassOfClass:[NSArray class]])
            {
                //接口返回数据类型错误，已做兼容处理
                if ([self isEmptyValue:value]) {
                    value = @[];
                } else {
                    value = [NSArray arrayWithObject:value];
                }
                TCLog(@"接口返回数据 %@ 类型错误，该数据类型应为数组，已做兼容处理",property.name);
            }

            //one shot conversion
            TCModelError* arrayErr = nil;
            value = [[protocolClass class] tc_arrayOfModelsFromDictionaries:value error:&arrayErr];
            if((err != nil) && (arrayErr != nil))
            {
                *err = [arrayErr errorByPrependingKeyPathComponent:property.name];
                return nil;
            }
        }

        //check if it's a dictionary of models
        if ([property.type isSubclassOfClass:[NSDictionary class]]) {

            // Expecting a dictionary, make sure 'value' is a dictionary
            if(![[value class] isSubclassOfClass:[NSDictionary class]])
            {
                if(err != nil)
                {
                    NSString* mismatch = [NSString stringWithFormat:@"Property '%@' is declared as NSDictionary<%@>* but the corresponding JSON value is not a JSON Object.", property.name, property.protocol];
                    TCModelError* typeErr = [TCModelError errorInvalidDataWithTypeMismatch:mismatch];
                    *err = [typeErr errorByPrependingKeyPathComponent:property.name];
                }
                return nil;
            }

            NSMutableDictionary* res = [NSMutableDictionary dictionary];

            for (NSString* key in [value allKeys]) {
                TCModelError* initErr = nil;
                id obj = [[[protocolClass class] alloc] initWithDictionaryTC:value[key] error:&initErr];
                if (obj == nil)
                {
                    // Propagate the error, including the property name as the key-path component
                    if((err != nil) && (initErr != nil))
                    {
                        initErr = [initErr errorByPrependingKeyPathComponent:key];
                        *err = [initErr errorByPrependingKeyPathComponent:property.name];
                    }
                    return nil;
                }
                [res setValue:obj forKey:key];
            }
            value = [NSDictionary dictionaryWithDictionary:res];
        }
    }

    return value;
}

//built-in reverse transformations (export to JSON compliant objects)
-(id)__tcReverseTransform:(id)value forProperty:(TCModelClassProperty*)property
{
    Class protocolClass = NSClassFromString(property.protocol);
    if (!protocolClass) return value;

    //if the protocol is actually a CustomModel class
    if ([self __isCustomClass:protocolClass]) {

        //check if should export list of dictionaries
        if (property.type == [NSArray class] || property.type == [NSMutableArray class]) {
            NSMutableArray* tempArray = [NSMutableArray arrayWithCapacity: [(NSArray*)value count] ];
            for (NSObject *model in (NSArray*)value) {
                if ([model respondsToSelector:@selector(tc_toDictionary)]) {
                    [tempArray addObject: [model tc_toDictionary]];
                } else
                    [tempArray addObject: model];
            }
            return [tempArray copy];
        }

        //check if should export dictionary of dictionaries
        if (property.type == [NSDictionary class] || property.type == [NSMutableDictionary class]) {
            NSMutableDictionary* res = [NSMutableDictionary dictionary];
            for (NSString* key in [(NSDictionary*)value allKeys]) {
                id model = value[key];
                [res setValue: [model tc_toDictionary] forKey: key];
            }
            return [NSDictionary dictionaryWithDictionary:res];
        }
    }

    return value;
}

#pragma mark - custom transformations

- (BOOL)__tcCustomSetValue:(id <NSObject>)value forProperty:(TCModelClassProperty *)property
{
    NSString *class = NSStringFromClass([TCJSONValueTransformer classByResolvingClusterClasses:[value class]]);

    SEL setter = nil;
    [property.customSetters[class] getValue:&setter];

    if (!setter)
        [property.customSetters[@"generic"] getValue:&setter];

    if (!setter)
        return NO;

    IMP imp = [self methodForSelector:setter];
    void (*func)(id, SEL, id <NSObject>) = (void *)imp;
    func(self, setter, value);

    return YES;
}

- (BOOL)__tcCustomGetValue:(id *)value forProperty:(TCModelClassProperty *)property
{
    SEL getter = property.customGetter;

    if (!getter)
        return NO;

    IMP imp = [self methodForSelector:getter];
    id (*func)(id, SEL) = (void *)imp;
    *value = func(self, getter);

    return YES;
}

- (BOOL)isUseCustomGetterOrSetters {
    return NO;
}


#pragma mark - persistance
-(void)__tcCreateDictionariesForKeyPath:(NSString*)keyPath inDictionary:(NSMutableDictionary**)dict
{
    //find if there's a dot left in the keyPath
    NSUInteger dotLocation = [keyPath rangeOfString:@"."].location;
    if (dotLocation==NSNotFound) return;

    //inspect next level
    NSString* nextHierarchyLevelKeyName = [keyPath substringToIndex: dotLocation];
    NSDictionary* nextLevelDictionary = (*dict)[nextHierarchyLevelKeyName];

    if (nextLevelDictionary==nil) {
        //create non-existing next level here
        nextLevelDictionary = [NSMutableDictionary dictionary];
    }

    //recurse levels
    [self __tcCreateDictionariesForKeyPath:[keyPath substringFromIndex: dotLocation+1]
                            inDictionary:&nextLevelDictionary ];

    //create the hierarchy level
    [*dict setValue:nextLevelDictionary  forKeyPath: nextHierarchyLevelKeyName];
}

-(NSDictionary*)tc_toDictionary
{
    return [self tc_toDictionaryWithKeys:nil];
}

-(NSString*)tc_toJSONString
{
    return [self tc_toJSONStringWithKeys:nil];
}

-(NSData*)tc_toJSONData
{
    return [self tc_toJSONDataWithKeys:nil];
}

//exports the model as a dictionary of JSON compliant objects
- (NSDictionary *)tc_toDictionaryWithKeys:(NSArray <NSString *> *)propertyNames
{
    NSArray* properties = [self __tcProperties__];
    NSMutableDictionary* tempDictionary = [NSMutableDictionary dictionaryWithCapacity:properties.count];

    id value;

    //loop over all properties
    for (TCModelClassProperty* p in properties) {

        //skip if unwanted
        if (propertyNames != nil && ![propertyNames containsObject:p.name])
            continue;

        //fetch key and value
        NSString* keyPath = self.__tcKeyMapper ? [self __tcMapString:p.name withKeyMapper:self.__tcKeyMapper] : p.name;
        value = [self valueForKey: p.name];

        //JMLog(@"toDictionary[%@]->[%@] = '%@'", p.name, keyPath, value);

        if ([keyPath rangeOfString:@"."].location != NSNotFound) {
            //there are sub-keys, introduce dictionaries for them
            [self __tcCreateDictionariesForKeyPath:keyPath inDictionary:&tempDictionary];
        }

        //check for custom getter
        if ([self __tcCustomGetValue:&value forProperty:p]) {
            //custom getter, all done
            [tempDictionary setValue:value forKeyPath:keyPath];
            continue;
        }

        //export nil when they are not optional values as JSON null, so that the structure of the exported data
        //is still valid if it's to be imported as a model again
        if (isTCNull(value)) {

            if (value == nil)
            {
                [tempDictionary removeObjectForKey:keyPath];
            }
            else
            {
                [tempDictionary setValue:[NSNull null] forKeyPath:keyPath];
            }
            continue;
        }

        //check if the property is another model
        if ([self __isCustomClass:p.type]) {

            //recurse models
            value = [(NSObject*)value tc_toDictionary];
            [tempDictionary setValue:value forKeyPath: keyPath];

            //for clarity
            continue;

        } else {

            // 1) check for built-in transformation
            if (p.protocol) {
                value = [self __tcReverseTransform:value forProperty:p];
            }

            // 2) check for standard types OR 2.1) primitives
            if (p.structName==nil && (p.isStandardJSONType || p.type==nil)) {

                //generic get value
                [tempDictionary setValue:value forKeyPath: keyPath];

                continue;
            }

            // 3) try to apply a value transformer
            if (YES) {
                //非基本数据类型，非自定义的class,需要通过扩展transformer转换方法进行处理，通过创建TCJSONValueTransformer的分类进行扩展
                //create selector from the property's class name
                NSString* selectorName = [NSString stringWithFormat:@"%@From%@:", @"JSONObject", p.type?p.type:p.structName];
                SEL selector = NSSelectorFromString(selectorName);

                BOOL foundCustomTransformer = NO;
                if ([tcValueTransformer respondsToSelector:selector]) {
                    foundCustomTransformer = YES;
                } else {
                    //try for hidden transformer
                    selectorName = [NSString stringWithFormat:@"__%@",selectorName];
                    selector = NSSelectorFromString(selectorName);
                    if ([tcValueTransformer respondsToSelector:selector]) {
                        foundCustomTransformer = YES;
                    }
                }

                //check if there's a transformer declared
                if (foundCustomTransformer) {
                    IMP imp = [tcValueTransformer methodForSelector:selector];
                    id (*func)(id, SEL, id) = (void *)imp;
                    value = func(tcValueTransformer, selector, value);

                    [tempDictionary setValue:value forKeyPath:keyPath];
                } else {
                    //in this case most probably a custom property was defined in a model
                    //but no default reverse transformer for it
                    @throw [NSException exceptionWithName:@"Value transformer not found"
                                                   reason:[NSString stringWithFormat:@"[JSONValueTransformer %@] not found", selectorName]
                                                 userInfo:nil];
                    return nil;
                }
            }
        }
    }

    return [tempDictionary copy];
}

//exports model to a dictionary and then to a JSON string
- (NSData *)tc_toJSONDataWithKeys:(NSArray <NSString *> *)propertyNames
{
    NSData* jsonData = nil;
    NSError* jsonError = nil;

    @try {
        NSDictionary* dict = [self tc_toDictionaryWithKeys:propertyNames];
        jsonData = [NSJSONSerialization dataWithJSONObject:dict options:kNilOptions error:&jsonError];
    }
    @catch (NSException *exception) {
        //this should not happen in properly design JSONModel
        //usually means there was no reverse transformer for a custom property
        TCLog(@"EXCEPTION: %@", exception.description);
        return nil;
    }

    return jsonData;
}

- (NSString *)tc_toJSONStringWithKeys:(NSArray <NSString *> *)propertyNames
{
    return [[NSString alloc] initWithData: [self tc_toJSONDataWithKeys: propertyNames]
                                 encoding: NSUTF8StringEncoding];
}

#pragma mark - import/export of lists
//loop over an NSArray of JSON objects and turn them into models
+(NSMutableArray*)tc_arrayOfModelsFromDictionaries:(NSArray*)array
{
    return [self tc_arrayOfModelsFromDictionaries:array error:nil];
}

+ (NSMutableArray *)tc_arrayOfModelsFromData:(NSData *)data error:(NSError **)err
{
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:err];
    if (!json || ![json isKindOfClass:[NSArray class]]) return nil;

    return [self tc_arrayOfModelsFromDictionaries:json error:err];
}

+ (NSMutableArray *)tc_arrayOfModelsFromString:(NSString *)string error:(NSError **)err
{
    return [self tc_arrayOfModelsFromData:[string dataUsingEncoding:NSUTF8StringEncoding] error:err];
}

// Same as above, but with error reporting
+(NSMutableArray*)tc_arrayOfModelsFromDictionaries:(NSArray*)array error:(NSError**)err
{
    //bail early
    if (isTCNull(array)) return nil;

    //parse dictionaries to objects
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];

    for (id d in array)
    {
        if ([d isKindOfClass:NSDictionary.class])
        {
            TCModelError* initErr = nil;
            id obj = [[self alloc] initWithDictionaryTC:d error:&initErr];
            if (obj == nil)
            {
                // Propagate the error, including the array index as the key-path component
                if((err != nil) && (initErr != nil))
                {
                    NSString* path = [NSString stringWithFormat:@"[%lu]", (unsigned long)list.count];
                    *err = [initErr errorByPrependingKeyPathComponent:path];
                }
                return nil;
            }

            [list addObject: obj];
        } else if ([d isKindOfClass:NSArray.class])
        {
            [list addObjectsFromArray:[self tc_arrayOfModelsFromDictionaries:d error:err]];
        } else
        {
            // This is very bad
        }

    }

    return list;
}

+ (NSMutableDictionary *)tc_dictionaryOfModelsFromString:(NSString *)string error:(NSError **)err
{
    return [self tc_dictionaryOfModelsFromData:[string dataUsingEncoding:NSUTF8StringEncoding] error:err];
}

+ (NSMutableDictionary *)tc_dictionaryOfModelsFromData:(NSData *)data error:(NSError **)err
{
    id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:err];
    if (!json || ![json isKindOfClass:[NSDictionary class]]) return nil;

    return [self tc_dictionaryOfModelsFromDictionary:json error:err];
}

+ (NSMutableDictionary *)tc_dictionaryOfModelsFromDictionary:(NSDictionary *)dictionary error:(NSError **)err
{
    NSMutableDictionary *output = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in dictionary.allKeys)
    {
        id object = dictionary[key];

        if ([object isKindOfClass:NSDictionary.class])
        {
            id obj = [[self alloc] initWithDictionaryTC:object error:err];
            if (obj == nil) return nil;
            output[key] = obj;
        }
        else if ([object isKindOfClass:NSArray.class])
        {
            id obj = [self tc_arrayOfModelsFromDictionaries:object error:err];
            if (obj == nil) return nil;
            output[key] = obj;
        }
        else
        {
            if (err) {
                *err = [TCModelError errorInvalidDataWithTypeMismatch:@"Only dictionaries and arrays are supported"];
            }
            return nil;
        }
    }

    return output;
}

//loop over NSArray of models and export them to JSON objects
+(NSMutableArray*)tc_arrayOfDictionariesFromModels:(NSArray*)array
{
    //bail early
    if (isTCNull(array)) return nil;

    //convert to dictionaries
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];

    for (id object in array) {

        id obj = [object tc_toDictionary];
        if (!obj) return nil;

        [list addObject: obj];
    }
    return list;
}

//loop over NSArray of models and export them to JSON objects with specific properties
+(NSMutableArray*)tc_arrayOfDictionariesFromModels:(NSArray*)array propertyNamesToExport:(NSArray*)propertyNamesToExport;
{
    //bail early
    if (isTCNull(array)) return nil;

    //convert to dictionaries
    NSMutableArray* list = [NSMutableArray arrayWithCapacity: [array count]];

    for (id object in array) {

        id obj = [object tc_toDictionaryWithKeys:propertyNamesToExport];
        if (!obj) return nil;

        [list addObject: obj];
    }
    return list;
}

+(NSMutableDictionary *)tc_dictionaryOfDictionariesFromModels:(NSDictionary *)dictionary
{
    //bail early
    if (isTCNull(dictionary)) return nil;

    NSMutableDictionary *output = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];

    for (NSString *key in dictionary.allKeys) {
        id object = dictionary[key];
        id obj = [object tc_toDictionary];
        if (!obj) return nil;
        output[key] = obj;
    }

    return output;
}


#pragma mark - key mapping
+(TCJSONKeyMapper*)tc_keyMapper
{
    return nil;
}


#pragma mark - working with incomplete models
- (void)tc_mergeFromDictionary:(NSDictionary *)dict
{
    [self tc_mergeFromDictionary:dict error:nil];
}

- (BOOL)tc_mergeFromDictionary:(NSDictionary *)dict error:(NSError **)error
{
    return [self __tcImportDictionary:dict withKeyMapper:self.__tcKeyMapper validation:NO error:error];
}


- (instancetype)copyJM:(NSError **)error {
    return [[self.class alloc] initWithDictionaryTC:self.tc_toDictionary error:error];
}

@end
