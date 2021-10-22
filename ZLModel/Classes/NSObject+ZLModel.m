//
//  NSObject+ZLModel.m
//  ZLModel
//
//  Created by richiezhl on 10/21/2021.
//  Copyright (c) 2021 richiezhl. All rights reserved.
//

#import "NSObject+ZLModel.h"
#include <stdlib.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const PropertyTypeInt = @"i";
static NSString *const PropertyTypeUInt = @"I";
static NSString *const PropertyTypeShort = @"s";
static NSString *const PropertyTypeUShort = @"S";
static NSString *const PropertyTypeFloat = @"f";
static NSString *const PropertyTypeDouble = @"d";
static NSString *const PropertyTypeLong = @"l";
static NSString *const PropertyTypeLongLong = @"q";
static NSString *const PropertyTypeULong = @"L";
static NSString *const PropertyTypeULongLong = @"Q";
static NSString *const PropertyTypeBOOL1 = @"c";
static NSString *const PropertyTypeBOOL2 = @"b";
static NSString *const PropertyTypeBOOL3 = @"B";
static NSString *const PropertyTypeCharPointer = @"^*";

static NSString *const PropertyTypeIvar = @"^^{objc_ivar=}";
static NSString *const PropertyTypeMethod = @"^^{objc_method=}";
static NSString *const PropertyTypeStruct = @"{Struct=*^v}";
static NSString *const PropertyTypeBlock = @"@?";
static NSString *const PropertyTypeClass = @"#";
static NSString *const PropertyTypeSEL = @":";
static NSString *const PropertyTypeId = @"@";

static const void *DateFormatString = "DateFormatString";
static const void *NSDateFormatterString = "NSDateFormatterString";

static inline NSArray *zlmodel_basePropertyArray(void) {
    static NSArray *basePropertyArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        basePropertyArray = @[PropertyTypeInt, PropertyTypeUInt, PropertyTypeShort, PropertyTypeUShort, PropertyTypeFloat, PropertyTypeDouble, PropertyTypeLong, PropertyTypeLongLong, PropertyTypeULong, PropertyTypeULongLong, PropertyTypeBOOL1, PropertyTypeBOOL2, PropertyTypeBOOL3, PropertyTypeCharPointer];
    });
    return basePropertyArray;
}

static inline NSArray *zlmodel_defaultIgnorePropertyArray(void) {
    static NSArray *defaultIgnorePropertyArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultIgnorePropertyArray = @[PropertyTypeIvar, PropertyTypeMethod, PropertyTypeStruct, PropertyTypeBlock, PropertyTypeClass, PropertyTypeSEL, PropertyTypeId];
    });
    return defaultIgnorePropertyArray;
}

static inline NSString *zlmodel_propertyTypeEncoding(objc_property_t property) {
    char attr[256] = { 0 };
    char *attributes = attr;
    memset(attributes, 0, sizeof(char) * 256);
    const char *attrs = property_getAttributes(property);
    strcpy(attributes, attrs);
    char *type = NULL;
    while (!((type = strsep(&attributes, ",")) != NULL && type != (void *)0 && type[0] == 'T'));
    return [NSString stringWithUTF8String:type + 1];
}

static inline BOOL zlmodel_isFromFoundation(NSString *propertyType) {
    if (([propertyType hasPrefix:@"@\"NS"] || [propertyType hasPrefix:@"@\"UI"] || [propertyType hasPrefix:@"@\"CG"]) && [propertyType hasSuffix:@"\""]) {
        return YES;
    }
    return NO;
}

static inline NSString *zlmodel_classStringFromFoundationPropertyType(NSString *propertyType) {
    if (zlmodel_isFromFoundation(propertyType)) {
        return [propertyType substringWithRange:NSMakeRange(2, propertyType.length - 3)];
    }
    return nil;
}

static inline NSString *zlmodel_autoTransformation(NSString *origin) {
    static NSArray *needsAutoTransformationArray = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        needsAutoTransformationArray = @[@"ID", @"DESCRIPTION", @"HASH", @"DEBUGDESCRIPTION", @"SUPERCLASS", @"CLASS"];
    });
    if ([needsAutoTransformationArray containsObject:origin]) {
        return [origin lowercaseString];
    }
    return origin;
}

static inline void inline_objectWithClassFromDictionary(id object, Class cls, NSDictionary *dic) {
    if (![dic isKindOfClass:[NSDictionary class]]) {
        return;
    }
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [NSString stringWithUTF8String:property_getName(property)];
        id value = [dic objectForKey:zlmodel_autoTransformation(key)];
        if (value == nil) {
            continue;
        }
        NSString *propertyType = zlmodel_propertyTypeEncoding(property);
        if ([zlmodel_defaultIgnorePropertyArray() containsObject:propertyType]) {
            continue;
        }
        NSString *methodName = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString, [key substringFromIndex:1]];
        SEL setter = sel_registerName(methodName.UTF8String);
        if ([object respondsToSelector:setter]) {
            if ([zlmodel_basePropertyArray() containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, int)) objc_msgSend)(object, setter, [(NSString *)value intValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, int)) objc_msgSend)(object, setter, [(NSNumber *)value intValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, short)) objc_msgSend)(object, setter, (short)[(NSString *)value intValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, short)) objc_msgSend)(object, setter, (short)[(NSNumber *)value intValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, unsigned int)) objc_msgSend)(object, setter, [(NSString *)value intValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, unsigned int)) objc_msgSend)(object, setter, [(NSNumber *)value unsignedIntValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, unsigned short)) objc_msgSend)(object, setter, [(NSString *)value intValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, unsigned short)) objc_msgSend)(object, setter, (unsigned short)[(NSNumber *)value intValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, float)) objc_msgSend)(object, setter, [(NSString *)value floatValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, float)) objc_msgSend)(object, setter, [(NSNumber *)value floatValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, double)) objc_msgSend)(object, setter, [(NSString *)value doubleValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, double)) objc_msgSend)(object, setter, [(NSNumber *)value doubleValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, long)) objc_msgSend)(object, setter, (long)[(NSString *)value longLongValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, long)) objc_msgSend)(object, setter, [(NSNumber *)value longValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, long)) objc_msgSend)(object, setter, (long)[(NSString *)value longLongValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, long)) objc_msgSend)(object, setter, [(NSNumber *)value longLongValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, unsigned long)) objc_msgSend)(object, setter, (unsigned long)[(NSString *)value longLongValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, unsigned long)) objc_msgSend)(object, setter, [(NSNumber *)value unsignedLongValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, unsigned long long)) objc_msgSend)(object, setter, (unsigned long long)[(NSString *)value longLongValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, unsigned long long)) objc_msgSend)(object, setter, [(NSNumber *)value unsignedLongLongValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1] || [propertyType isEqualToString:PropertyTypeBOOL2] || [propertyType isEqualToString:PropertyTypeBOOL3]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, BOOL)) objc_msgSend)(object, setter, [(NSString *)value boolValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, BOOL)) objc_msgSend)(object, setter, [(NSNumber *)value boolValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    ((void (*) (id, SEL, const char *)) objc_msgSend)(object, setter, [(NSString *)value UTF8String]);
                }
            } else if (zlmodel_isFromFoundation(propertyType)) {
                NSString *string = zlmodel_classStringFromFoundationPropertyType(propertyType);
                if (string == nil) {
                    continue;
                }
                
                if ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    if (className) {
                        NSMutableArray *array = [NSMutableArray array];
                        Class cls = NSClassFromString(className);
                        if (cls) {
                            for (NSDictionary *dic in (NSArray *)value) {
                                [array addObject:[cls zl_objectFromDictionary:dic]];
                            }
                        }
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, array);
                    } else {
                        if ([string isEqualToString:@"NSMutableArray"]) {
                            if ([value isKindOfClass:[NSMutableArray class]]) {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                            } else {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [value mutableCopy]);
                            }
                        } else {
                            ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                        }
                    }
                } else if ([string isEqualToString:@"NSMutableDictionary"]) {
                    if ([value isKindOfClass:[NSMutableDictionary class]]) {
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                    } else {
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [value mutableCopy]);
                    }
                }  else if ([string isEqualToString:@"NSSet"] || [string isEqualToString:@"NSMutableSet"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    if (className) {
                        NSMutableSet *array = [NSMutableSet set];
                        Class cls = NSClassFromString(className);
                        if (cls) {
                            for (NSDictionary *dic in (NSSet *)value) {
                                [array addObject:[cls zl_objectFromDictionary:dic]];
                            }
                        }
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, array);
                    } else {
                        if ([string isEqualToString:@"NSMutableSet"]) {
                            if ([value isKindOfClass:[NSMutableSet class]]) {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                            } else {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [value mutableCopy]);
                            }
                        } else {
                            ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                        }
                    }
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    ((void (*) (id, SEL, CGRect)) objc_msgSend)(object, setter, CGRectFromString(value));
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    ((void (*) (id, SEL, CGSize)) objc_msgSend)(object, setter, CGSizeFromString(value));
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    ((void (*) (id, SEL, CGPoint)) objc_msgSend)(object, setter, CGPointFromString(value));
                } else if ([string isEqualToString:@"NSInteger"]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, NSInteger)) objc_msgSend)(object, setter, [(NSString *)value integerValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, NSInteger)) objc_msgSend)(object, setter, [(NSNumber *)value integerValue]);
                    }
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, NSUInteger)) objc_msgSend)(object, setter, (NSUInteger)[(NSString *)value integerValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, NSUInteger)) objc_msgSend)(object, setter, [(NSNumber *)value unsignedIntegerValue]);
                    }
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDateFormatter *dateFromatter = [cls zl_dateFormatter];
                    if (dateFromatter == nil) {
                        double timeInterval = 0;
                        if ([value isKindOfClass:[NSString class]]) {
                            timeInterval = [(NSString *)value doubleValue];
                        } else if ([value isKindOfClass:[NSNumber class]]) {
                            timeInterval = [(NSNumber *)value doubleValue];
                        }
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(object, setter, [NSDate dateWithTimeIntervalSince1970:timeInterval]);
                    } else {
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(object, setter, [dateFromatter dateFromString:value]);
                    }
                } else {
                    ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                }
            } else {
                id v = [NSClassFromString([propertyType substringWithRange:NSMakeRange(2, propertyType.length - 3)]) zl_objectFromDictionary:(NSDictionary *)value];
                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, v);
            }
        }
    }
    free(properties);
    
    Class superClass = class_getSuperclass(cls);
    if (superClass && ![NSStringFromClass(superClass) isEqualToString:@"NSObject"]) {
        inline_objectWithClassFromDictionary(object, superClass, dic);
    }
}

static inline void inline_objectToDictionaryWithClassAndDictionary(id object, Class cls, NSMutableDictionary *dict) {
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(cls, &outCount);
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        NSString *key = [NSString stringWithUTF8String:propertyName];
        NSString *propertyType = zlmodel_propertyTypeEncoding(property);
        if ([zlmodel_defaultIgnorePropertyArray() containsObject:propertyType]) {
            continue;
        }
        if ([object respondsToSelector:getter]) {
            if ([zlmodel_basePropertyArray() containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    int value = ((int (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    short value = ((short (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    unsigned int value = ((unsigned int (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    unsigned short value = ((unsigned short (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    float value = ((float (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    double value = ((double (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    long value = ((long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    long long value = ((long long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    unsigned long value = ((unsigned long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    unsigned long long value = ((unsigned long long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1] || [propertyType isEqualToString:PropertyTypeBOOL2] || [propertyType isEqualToString:PropertyTypeBOOL3]) {
                    BOOL value = ((BOOL (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    char *value = ((char * (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                }
            } else if (zlmodel_isFromFoundation(propertyType)) {
                NSString *string = zlmodel_classStringFromFoundationPropertyType(propertyType);
                if (string == nil) {
                    continue;
                }
                
                if ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    NSArray *value = ((NSArray * (*) (id, SEL)) objc_msgSend) (object, getter);
                    if (className != nil) {
                        NSMutableArray *array = [NSMutableArray array];
                        for (NSObject *o in value) {
                            [array addObject:o.zl_toDictionary];
                        }
                        [dict setObject:array forKey:zlmodel_autoTransformation(key)];
                    } else if (value) {
                        [dict setObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                } else if ([string isEqualToString:@"NSSet"] || [string isEqualToString:@"NSMutableSet"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    NSSet *value = ((NSSet * (*) (id, SEL)) objc_msgSend) (object, getter);
                    if (className != nil) {
                        NSMutableSet *array = [NSMutableSet set];
                        for (NSObject *o in value) {
                            [array addObject:o.zl_toDictionary];
                        }
                        [dict setObject:array forKey:zlmodel_autoTransformation(key)];
                    } else if (value) {
                        [dict setObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    CGRect value = ((CGRect (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:NSStringFromCGRect(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    CGSize value = ((CGSize (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:NSStringFromCGSize(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    CGPoint value = ((CGPoint (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:NSStringFromCGPoint(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSInteger"]) {
                    NSInteger value = ((NSInteger (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    NSUInteger value = ((NSUInteger (*) (id, SEL)) objc_msgSend) (object, getter);
                    [dict setObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDate *value = ((NSDate * (*) (id, SEL)) objc_msgSend) (object, getter);
                    NSDateFormatter *dateFromatter = [cls zl_dateFormatter];
                    if (dateFromatter == nil) {
                        [dict setObject:@([value timeIntervalSince1970]) forKey:zlmodel_autoTransformation(key)];
                    } else {
                        [dict setObject:[dateFromatter stringFromDate:value] forKey:zlmodel_autoTransformation(key)];
                    }
                } else {
                    id value = ((id (*) (id,SEL)) objc_msgSend) (object, getter);
                    if (value) {
                        [dict setObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                }
            } else {
                id value = ((id (*) (id,SEL)) objc_msgSend) (object, getter);
                if (value) {
                    [dict setObject:[value zl_toDictionary] forKey:zlmodel_autoTransformation(key)];
                }
            }
        }
    }
    free(propertyList);
    
    Class superClass = class_getSuperclass(cls);
    if (superClass && ![NSStringFromClass(superClass) isEqualToString:@"NSObject"]) {
        inline_objectToDictionaryWithClassAndDictionary(object, superClass, dict);
    }
}

static inline void inline_objectWithClassInEncode(id object, Class cls, NSCoder *aCoder) {
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(cls, &outCount);
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        NSString *key = [NSString stringWithUTF8String:propertyName];
        NSString *propertyType = zlmodel_propertyTypeEncoding(property);
        if ([zlmodel_defaultIgnorePropertyArray() containsObject:propertyType]) {
            continue;
        }
        if ([object respondsToSelector:getter]) {
            if ([zlmodel_basePropertyArray() containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    int value = ((int (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    short value = ((short (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    unsigned int value = ((unsigned int (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    unsigned short value = ((unsigned short (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    float value = ((float (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    double value = ((double (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    long value = ((long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    long long value = ((long long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    unsigned long value = ((unsigned long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    unsigned long long value = ((unsigned long long (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    BOOL value = ((BOOL (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    bool value = ((bool (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    char *value = ((char * (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                }
            } else if (zlmodel_isFromFoundation(propertyType)) {
                NSString *string = zlmodel_classStringFromFoundationPropertyType(propertyType);
                if (string == nil) {
                    continue;
                }
                
                if ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"]) {
                    NSArray *value = ((NSArray * (*) (id, SEL)) objc_msgSend) (object, getter);
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    if (className != nil) {
                        NSMutableArray *array = [NSMutableArray array];
                        for (NSObject *o in value) {
                            [array addObject:o.zl_toDictionary];
                        }
                        [aCoder encodeObject:array forKey:zlmodel_autoTransformation(key)];
                    } else if (value) {
                        [aCoder encodeObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                } else if ([string isEqualToString:@"NSSet"] || [string isEqualToString:@"NSMutableSet"]) {
                    NSSet *value = ((NSSet * (*) (id, SEL)) objc_msgSend) (object, getter);
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    if (className != nil) {
                        NSMutableSet *array = [NSMutableSet set];
                        for (NSObject *o in value) {
                            [array addObject:o.zl_toDictionary];
                        }
                        [aCoder encodeObject:array forKey:zlmodel_autoTransformation(key)];
                    } else if (value) {
                        [aCoder encodeObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    CGRect value = ((CGRect (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeCGRect:value forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    CGSize value = ((CGSize (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeCGSize:value forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    CGPoint value = ((CGPoint (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeCGPoint:value forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSInteger"]) {
                    NSInteger value = ((NSInteger (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    NSUInteger value = ((NSUInteger (*) (id, SEL)) objc_msgSend) (object, getter);
                    [aCoder encodeObject:@(value) forKey:zlmodel_autoTransformation(key)];
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDate *date = ((NSDate * (*) (id, SEL)) objc_msgSend) (object, getter);
                    NSDateFormatter *dateFromatter = [cls zl_dateFormatter];
                    if (dateFromatter == nil) {
                        [aCoder encodeObject:@([date timeIntervalSince1970]) forKey:zlmodel_autoTransformation(key)];
                    } else {
                        [aCoder encodeObject:[dateFromatter stringFromDate:date] forKey:zlmodel_autoTransformation(key)];
                    }
                    
                } else {
                    id value = ((id (*) (id,SEL)) objc_msgSend) (object, getter);
                    if (value) {
                        [aCoder encodeObject:value forKey:zlmodel_autoTransformation(key)];
                    }
                }
            } else {
                NSObject *value = ((NSObject * (*) (id,SEL)) objc_msgSend) (object, getter);
                if (value) {
                    [aCoder encodeObject:value.zl_toJSONString forKey:zlmodel_autoTransformation(key)];
                }
            }
        }
    }
    free(propertyList);
    
    Class superClass = class_getSuperclass(cls);
    if (superClass && ![NSStringFromClass(superClass) isEqualToString:@"NSObject"]) {
        inline_objectWithClassInEncode(object, superClass, aCoder);
    }
}

static inline void inline_objectWithClassInDecode(id object, Class cls, NSCoder *aCoder) {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList(cls, &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [NSString stringWithUTF8String:property_getName(property)];
        NSString *propertyType = zlmodel_propertyTypeEncoding(property);
        if ([zlmodel_defaultIgnorePropertyArray() containsObject:propertyType]) {
            continue;
        }
        NSString *methodName = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString,[key substringFromIndex:1]];
        SEL setter = sel_registerName(methodName.UTF8String);
        if ([object respondsToSelector:setter]) {
            if ([zlmodel_basePropertyArray() containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    ((void (*) (id, SEL, int)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    ((void (*) (id, SEL, short)) objc_msgSend)(object, setter, (short)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    ((void (*) (id, SEL, unsigned int)) objc_msgSend)(object, setter, (unsigned int)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    ((void (*) (id, SEL, unsigned short)) objc_msgSend)(object, setter, (unsigned short)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    ((void (*) (id, SEL, float)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).floatValue);
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    ((void (*) (id, SEL, double)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).doubleValue);
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    ((void (*) (id, SEL, long)) objc_msgSend)(object, setter, (long)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).longLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    ((void (*) (id, SEL, long long)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).longLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    ((void (*) (id, SEL, unsigned long)) objc_msgSend)(object, setter, (unsigned long)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).unsignedLongLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    ((void (*) (id, SEL, unsigned long long)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).unsignedLongLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    ((void (*) (id, SEL, BOOL)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).boolValue);
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    ((void (*) (id, SEL, bool)) objc_msgSend)(object, setter, (bool)((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).boolValue);
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    ((void (*) (id, SEL, const char *)) objc_msgSend)(object, setter, [(NSString *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)] UTF8String]);
                }
            } else if (zlmodel_isFromFoundation(propertyType)) {
                NSString *string = zlmodel_classStringFromFoundationPropertyType(propertyType);
                if (string == nil) {
                    continue;
                }
                
                if ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    NSArray *value = [aCoder decodeObjectForKey:zlmodel_autoTransformation(key)];
                    if (className != nil) {
                        NSMutableArray *array = [NSMutableArray array];
                        for (NSDictionary *dic in value) {
                            [array addObject:[NSClassFromString(className) zl_objectFromDictionary:dic]];
                        }
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, array);
                    } else {
                        if ([string isEqualToString:@"NSArray"]) {
                            ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                        } else {
                            if ([value isKindOfClass:[NSMutableArray class]]) {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                            } else {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [value mutableCopy]);
                            }
                        }
                    }
                } else if ([string isEqualToString:@"NSSet"] || [string isEqualToString:@"NSMutableSet"]) {
                    NSString *className = [[cls zl_objectClassInArray] objectForKey:key];
                    NSArray *value = [aCoder decodeObjectForKey:zlmodel_autoTransformation(key)];
                    if (className != nil) {
                        NSMutableSet *array = [NSMutableSet set];
                        for (NSDictionary *dic in value) {
                            [array addObject:[NSClassFromString(className) zl_objectFromDictionary:dic]];
                        }
                        ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, array);
                    } else {
                        if ([string isEqualToString:@"NSSet"]) {
                            ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                        } else {
                            if ([value isKindOfClass:[NSMutableSet class]]) {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, value);
                            } else {
                                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [value mutableCopy]);
                            }
                        }
                    }
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    ((void (*) (id, SEL, CGRect)) objc_msgSend)(object, setter, [aCoder decodeCGRectForKey:zlmodel_autoTransformation(key)]);
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    ((void (*) (id, SEL, CGSize)) objc_msgSend)(object, setter, [aCoder decodeCGSizeForKey:zlmodel_autoTransformation(key)]);
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    ((void (*) (id, SEL, CGPoint)) objc_msgSend)(object, setter, [aCoder decodeCGPointForKey:zlmodel_autoTransformation(key)]);
                } else if ([string isEqualToString:@"NSInteger"]) {
                    ((void (*) (id, SEL, NSInteger)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).integerValue);
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    ((void (*) (id, SEL, NSUInteger)) objc_msgSend)(object, setter, ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).unsignedIntegerValue);
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDateFormatter *dateFromatter = [cls zl_dateFormatter];
                    if (dateFromatter == nil) {
                        double timeInterval = ((NSNumber *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]).doubleValue;
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(object, setter, [NSDate dateWithTimeIntervalSince1970:timeInterval]);
                    } else {
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(object, setter, [dateFromatter dateFromString:[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]]);
                    }
                } else {
                    ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, [aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]);
                }
            } else {
                id v = [NSClassFromString([propertyType substringWithRange:NSMakeRange(2, propertyType.length - 3)]) zl_objectFromJsonString:(NSString *)[aCoder decodeObjectForKey:zlmodel_autoTransformation(key)]];
                ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, v);
            }
        }
    }
    free(properties);
    
    Class superClass = class_getSuperclass(cls);
    if (superClass && ![NSStringFromClass(superClass) isEqualToString:@"NSObject"]) {
        inline_objectWithClassInDecode(object, superClass, aCoder);
    }
}

@implementation NSObject (ZLModel)

+ (void)zl_swizzleSelector:(SEL)originalSelector withAnotherSelector:(SEL)swizzledSelector {
    Class aClass = [self class];
    
    Method originalMethod = class_getInstanceMethod(aClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector);
    
    BOOL didAddMethod =
        class_addMethod(aClass,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(aClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

+ (NSDateFormatter *)zl_dateFormatter {
    NSDateFormatter *formatter = objc_getAssociatedObject(self, NSDateFormatterString);
    NSString *dateFormatterString = [self zl_dateFormatString];
    if (formatter == nil) {
        if (dateFormatterString != nil && ![dateFormatterString isEqualToString:@""]) {
            formatter = [[NSDateFormatter alloc] init];
            formatter.timeZone = [NSTimeZone systemTimeZone];
            formatter.dateFormat = dateFormatterString;
            objc_setAssociatedObject(self, NSDateFormatterString, formatter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } else if (dateFormatterString == nil || [dateFormatterString isEqualToString:@""]) {
        objc_setAssociatedObject(self, NSDateFormatterString, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        formatter.dateFormat = dateFormatterString;
        formatter.timeZone = [NSTimeZone systemTimeZone];
        objc_setAssociatedObject(self, NSDateFormatterString, formatter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return formatter;
}

+ (void)zl_setDateFormatString:(NSString *)string {
    [self willChangeValueForKey:@"zl_dateFormatString"];
    objc_setAssociatedObject(self, DateFormatString, string, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self didChangeValueForKey:@"zl_dateFormatString"];
}

+ (NSString *)zl_dateFormatString {
    return objc_getAssociatedObject(self, DateFormatString);
}

+ (NSDictionary *)zl_objectClassInArray {
    return @{@"": @""};
}

+ (instancetype)zl_objectFromDictionary:(NSDictionary *)dic {
    id object = [[[self class] alloc] init];
    inline_objectWithClassFromDictionary(object, [self class], dic);
    return object;
}

+ (NSMutableArray *)zl_objectArrayFromArray:(NSArray *)objectArray {
    NSMutableArray *array = [NSMutableArray array];
    for (NSDictionary *dic in objectArray) {
        [array addObject:[[self class] zl_objectFromDictionary:dic]];
    }
    return array;
}

+ (instancetype)zl_objectFromJsonString:(NSString *)string {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
    if (object == nil) {
        return nil;
    }
    Class cls = [self class];
    if ([object isKindOfClass:[NSDictionary class]]) {
        return [cls zl_objectFromDictionary:object];
    }
    
    return [cls zl_objectArrayFromArray:object];
}

- (NSMutableArray *)zl_arrayWithObjectArray:(NSArray *)objectArray {
    NSMutableArray *array = [NSMutableArray array];
    for (id object in objectArray) {
        [array addObject:[object zl_toDictionary]];
    }
    return array;
}

- (NSDictionary *)zl_toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    inline_objectToDictionaryWithClassAndDictionary(self, [self class], dict);
    return dict;
}

- (NSData *)zl_toJSONData {
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self zl_toDictionary] options:0 error:&error];
    return data;
}

- (NSString *)zl_toJSONString {
    NSData *data = [self zl_toJSONData];
    if (data == nil) {
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (void)zl_coderEncode:(NSCoder *)aCoder {
    inline_objectWithClassInEncode(self, [self class], aCoder);
}

- (void)zl_coderDecode:(NSCoder *)aCoder {
    inline_objectWithClassInDecode(self, [self class], aCoder);
}

@end
