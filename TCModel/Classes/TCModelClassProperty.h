//
//  TCModelClassProperty.h
//  TCModel
//

#import <Foundation/Foundation.h>


@interface TCModelClassProperty : NSObject

/** The name of the declared property (not the ivar name) */
@property (copy, nonatomic) NSString *name;

/** A property class type  */
@property (assign, nonatomic) Class type;

/** Struct name if a struct */
@property (strong, nonatomic) NSString *structName;

/** The name of the protocol the property conforms to (or nil) */
@property (copy, nonatomic) NSString *protocol;

/** If YES, it can't be missing in the input data, and the input would be invalid */
@property (assign, nonatomic) BOOL isTCRequired;

/** If YES - don't call any transformers on this property's value */
@property (assign, nonatomic) BOOL isStandardJSONType;

/** If YES - create a mutable object for the value of the property */
@property (assign, nonatomic) BOOL isMutable;

/** a custom getter for this property, found in the owning model */
@property (assign, nonatomic) SEL customGetter;

/** custom setters for this property, found in the owning model */
@property (strong, nonatomic) NSMutableDictionary *customSetters;

@end
