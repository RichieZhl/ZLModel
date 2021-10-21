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

+ (NSArray *)basePropertyArray {
    static NSArray *basePropertyArray = nil;
    if (basePropertyArray == nil) {
        basePropertyArray = @[PropertyTypeInt, PropertyTypeUInt, PropertyTypeShort, PropertyTypeUShort, PropertyTypeFloat, PropertyTypeDouble, PropertyTypeLong, PropertyTypeLongLong, PropertyTypeULong, PropertyTypeULongLong, PropertyTypeBOOL1, PropertyTypeBOOL2, PropertyTypeCharPointer];
    }
    return basePropertyArray;
}

+ (NSArray *)defaultIgnorePropertyArray {
    static NSArray *defaultIgnorePropertyArray = nil;
    if (defaultIgnorePropertyArray == nil) {
        defaultIgnorePropertyArray = @[PropertyTypeIvar, PropertyTypeMethod, PropertyTypeStruct, PropertyTypeBlock, PropertyTypeClass, PropertyTypeSEL, PropertyTypeId];
    }
    return defaultIgnorePropertyArray;
}

+ (NSString *)propertyTypeEncoding:(objc_property_t)property {
    char attr[256] = { 0 };
    char *attributes = attr;
    memset(attributes, 0, sizeof(char) * 256);
    const char *attrs = property_getAttributes(property);
    strcpy(attributes, attrs);
    char *type = NULL;
    while (!((type = strsep(&attributes, ",")) != NULL && type != (void *)0 && type[0] == 'T'));
    return [NSString stringWithUTF8String:type + 1];
}

+ (BOOL)isFromFoundation:(NSString *)propertyType {
    if (([propertyType hasPrefix:@"@\"NS"] || [propertyType hasPrefix:@"@\"UI"] || [propertyType hasPrefix:@"@\"CG"]) && [propertyType hasSuffix:@"\""]) {
        return YES;
    }
    return NO;
}

+ (NSString *)classStringFromFoundationPropertyType:(NSString *)propertyType {
    if ([self isFromFoundation:propertyType]) {
        return [propertyType substringWithRange:NSMakeRange(2, propertyType.length - 3)];
    }
    return nil;
}

+ (NSDictionary *)zl_objectClassInArray {
    return @{@"": @""};
}

+ (NSString *)autoTransformation:(NSString *)origin {
    NSArray *needsAutoTransformationArray = @[@"ID", @"DESCRIPTION", @"HASH", @"DEBUGDESCRIPTION", @"SUPERCLASS", @"CLASS"];
    if ([needsAutoTransformationArray containsObject:origin]) {
        return [origin lowercaseString];
    }
    return origin;
}

+ (instancetype)zl_objectFromDictionary:(NSDictionary *)dic {
    id object = [[[self class] alloc] init];
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [NSString stringWithUTF8String:property_getName(property)];
        id value = [dic objectForKey:[self autoTransformation:key]];
        if (value == nil) {
            continue;
        }
        NSString *propertyType = [self propertyTypeEncoding:property];
        if ([[self defaultIgnorePropertyArray] containsObject:propertyType]) {
            continue;
        }
        NSString *methodName = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString, [key substringFromIndex:1]];
        SEL setter = sel_registerName(methodName.UTF8String);
        if ([object respondsToSelector:setter]) {
            if ([[self basePropertyArray] containsObject:propertyType]) {
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
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, BOOL)) objc_msgSend)(object, setter, [(NSString *)value boolValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, BOOL)) objc_msgSend)(object, setter, [(NSNumber *)value boolValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    if ([value isKindOfClass:[NSString class]]) {
                        ((void (*) (id, SEL, bool)) objc_msgSend)(object, setter, (bool)[(NSString *)value boolValue]);
                    } else if ([value isKindOfClass:[NSNumber class]]) {
                        ((void (*) (id, SEL, bool)) objc_msgSend)(object, setter, (bool)[(NSNumber *)value boolValue]);
                    }
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    ((void (*) (id, SEL, const char *)) objc_msgSend)(object, setter, [(NSString *)value UTF8String]);
                }
            } else if ([self isFromFoundation:propertyType]) {
                NSString *string = [self classStringFromFoundationPropertyType:propertyType];
                if (string == nil) {
                    continue;
                }
                NSString *className = [[self zl_objectClassInArray] objectForKey:key];
                if (className != nil && ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"])) {
                    NSMutableArray *array = [NSMutableArray array];
                    for (NSDictionary *dic in (NSArray *)value) {
                        [array addObject:[NSClassFromString(className) zl_objectFromDictionary:dic]];
                    }
                    ((void (*) (id, SEL, id)) objc_msgSend)(object, setter, array);
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
                    NSDateFormatter *dateFromatter = self.zl_dateFormatter;
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
    id object = [self valueWithJsonString:string];
    if (object == nil) {
        return nil;
    }
    Class cls = [self class];
    if ([object isKindOfClass:[NSDictionary class]]) {
        return [cls zl_objectFromDictionary:object];
    }
    
    return [cls zl_objectArrayFromArray:object];
}

+ (id)valueWithJsonString:(NSString *)string {
    NSError *error = nil;
    id object = [NSJSONSerialization JSONObjectWithData:[string dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&error];
    return object;
}

- (NSMutableArray *)zl_arrayWithObjectArray:(NSArray *)objectArray {
    NSMutableArray *array = [NSMutableArray array];
    for (id object in objectArray) {
        [array addObject:[object zl_toDictionary]];
    }
    return array;
}

- (NSDictionary *)zl_toDictionary {
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &outCount);
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        NSString *key = [NSString stringWithUTF8String:propertyName];
        NSString *propertyType = [[self class] propertyTypeEncoding:property];
        if ([[[self class] defaultIgnorePropertyArray] containsObject:propertyType]) {
            continue;
        }
        if ([self respondsToSelector:getter]) {
            if ([[[self class] basePropertyArray] containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    int value = ((int (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    short value = ((short (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    unsigned int value = ((unsigned int (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    unsigned short value = ((unsigned short (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    float value = ((float (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    double value = ((double (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    long value = ((long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    long long value = ((long long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    unsigned long value = ((unsigned long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    unsigned long long value = ((unsigned long long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    BOOL value = ((BOOL (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    bool value = ((bool (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    char *value = ((char * (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                }
            } else if ([[self class] isFromFoundation:propertyType]) {
                NSString *string = [[self class] classStringFromFoundationPropertyType:propertyType];
                if (string == nil) {
                    continue;
                }
                NSString *className = [[[self class] zl_objectClassInArray] objectForKey:key];
                if (className != nil && ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"])) {
                    NSArray *value = ((NSArray * (*) (id, SEL)) objc_msgSend) (self, getter);
                    NSMutableArray *array = [NSMutableArray array];
                    for (NSObject *o in value) {
                        [array addObject:o.zl_toDictionary];
                    }
                    [dict setObject:array forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    CGRect value = ((CGRect (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:NSStringFromCGRect(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    CGSize value = ((CGSize (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:NSStringFromCGSize(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    CGPoint value = ((CGPoint (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:NSStringFromCGPoint(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSInteger"]) {
                    NSInteger value = ((NSInteger (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    NSUInteger value = ((NSUInteger (*) (id, SEL)) objc_msgSend) (self, getter);
                    [dict setObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDate *value = ((NSDate * (*) (id, SEL)) objc_msgSend) (self, getter);
                    NSDateFormatter *dateFromatter = [self class].zl_dateFormatter;
                    if (dateFromatter == nil) {
                        [dict setObject:@([value timeIntervalSince1970]) forKey:[[self class] autoTransformation:key]];
                    } else {
                        [dict setObject:[dateFromatter stringFromDate:value] forKey:[[self class] autoTransformation:key]];
                    }
                } else {
                    id value = ((id (*) (id,SEL)) objc_msgSend) (self, getter);
                    if (value) {
                        [dict setObject:value forKey:[[self class] autoTransformation:key]];
                    }
                }
            } else {
                id value = ((id (*) (id,SEL)) objc_msgSend) (self, getter);
                if (value) {
                    [dict setObject:[value zl_toDictionary] forKey:[[self class] autoTransformation:key]];
                }
            }
        }
    }
    free(propertyList);
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
    unsigned int outCount = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &outCount);
    for (int i = 0; i < outCount; i ++) {
        objc_property_t property = propertyList[i];
        
        const char *propertyName = property_getName(property);
        SEL getter = sel_registerName(propertyName);
        NSString *key = [NSString stringWithUTF8String:propertyName];
        NSString *propertyType = [[self class] propertyTypeEncoding:property];
        if ([[[self class] defaultIgnorePropertyArray] containsObject:propertyType]) {
            continue;
        }
        if ([self respondsToSelector:getter]) {
            if ([[[self class] basePropertyArray] containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    int value = ((int (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    short value = ((short (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    unsigned int value = ((unsigned int (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    unsigned short value = ((unsigned short (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    float value = ((float (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    double value = ((double (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    long value = ((long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    long long value = ((long long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    unsigned long value = ((unsigned long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    unsigned long long value = ((unsigned long long (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    BOOL value = ((BOOL (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    bool value = ((bool (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    char *value = ((char * (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                }
            } else if ([[self class] isFromFoundation:propertyType]) {
                NSString *string = [[self class] classStringFromFoundationPropertyType:propertyType];
                if (string == nil) {
                    continue;
                }
                if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    CGRect value = ((CGRect (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeCGRect:value forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    CGSize value = ((CGSize (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeCGSize:value forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    CGPoint value = ((CGPoint (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeCGPoint:value forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSInteger"]) {
                    NSInteger value = ((NSInteger (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    NSUInteger value = ((NSUInteger (*) (id, SEL)) objc_msgSend) (self, getter);
                    [aCoder encodeObject:@(value) forKey:[[self class] autoTransformation:key]];
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDate *date = ((NSDate * (*) (id, SEL)) objc_msgSend) (self, getter);
                    NSDateFormatter *dateFromatter = [self class].zl_dateFormatter;
                    if (dateFromatter == nil) {
                        [aCoder encodeObject:@([date timeIntervalSince1970]) forKey:[[self class] autoTransformation:key]];
                    } else {
                        [aCoder encodeObject:[dateFromatter stringFromDate:date] forKey:[[self class] autoTransformation:key]];
                    }
                    
                } else {
                    id value = ((id (*) (id,SEL)) objc_msgSend) (self, getter);
                    if (value) {
                        [aCoder encodeObject:value forKey:[[self class] autoTransformation:key]];
                    }
                }
            } else {
                NSObject *value = ((NSObject * (*) (id,SEL)) objc_msgSend) (self, getter);
                if (value) {
                    [aCoder encodeObject:value.zl_toJSONString forKey:[[self class] autoTransformation:key]];
                }
            }
        }
    }
    free(propertyList);
}

- (void)zl_coderDecode:(NSCoder *)aCoder {
    unsigned int outCount, i;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *key = [NSString stringWithUTF8String:property_getName(property)];
        NSString *propertyType = [[self class] propertyTypeEncoding:property];
        if ([[[self class] defaultIgnorePropertyArray] containsObject:propertyType]) {
            continue;
        }
        NSString *methodName = [NSString stringWithFormat:@"set%@%@:",[key substringToIndex:1].uppercaseString,[key substringFromIndex:1]];
        SEL setter = sel_registerName(methodName.UTF8String);
        if ([self respondsToSelector:setter]) {
            if ([[[self class] basePropertyArray] containsObject:propertyType]) {
                if ([propertyType isEqualToString:PropertyTypeInt]) {
                    ((void (*) (id, SEL, int)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeShort]) {
                    ((void (*) (id, SEL, short)) objc_msgSend)(self, setter, (short)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeUInt]) {
                    ((void (*) (id, SEL, unsigned int)) objc_msgSend)(self, setter, (unsigned int)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeUShort]) {
                    ((void (*) (id, SEL, unsigned short)) objc_msgSend)(self, setter, (unsigned short)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).intValue);
                } else if ([propertyType isEqualToString:PropertyTypeFloat]) {
                    ((void (*) (id, SEL, float)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).floatValue);
                } else if ([propertyType isEqualToString:PropertyTypeDouble]) {
                    ((void (*) (id, SEL, double)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).doubleValue);
                } else if ([propertyType isEqualToString:PropertyTypeLong]) {
                    ((void (*) (id, SEL, long)) objc_msgSend)(self, setter, (long)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).longLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeLongLong]) {
                    ((void (*) (id, SEL, long long)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).longLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeULong]) {
                    ((void (*) (id, SEL, unsigned long)) objc_msgSend)(self, setter, (unsigned long)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).unsignedLongLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeULongLong]) {
                    ((void (*) (id, SEL, unsigned long long)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).unsignedLongLongValue);
                } else if ([propertyType isEqualToString:PropertyTypeBOOL1]) {
                    ((void (*) (id, SEL, BOOL)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).boolValue);
                } else if ([propertyType isEqualToString:PropertyTypeBOOL2]) {
                    ((void (*) (id, SEL, bool)) objc_msgSend)(self, setter, (bool)((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).boolValue);
                } else if ([propertyType isEqualToString:PropertyTypeCharPointer]) {
                    ((void (*) (id, SEL, const char *)) objc_msgSend)(self, setter, [(NSString *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]] UTF8String]);
                }
            } else if ([[self class] isFromFoundation:propertyType]) {
                NSString *string = [[self class] classStringFromFoundationPropertyType:propertyType];
                if (string == nil) {
                    continue;
                }
                NSString *className = [[[self class] zl_objectClassInArray] objectForKey:key];
                if (className != nil && ([string isEqualToString:@"NSArray"] || [string isEqualToString:@"NSMutableArray"])) {
                    NSArray *value = [aCoder decodeObjectForKey:[[self class] autoTransformation:key]];
                    NSMutableArray *array = [NSMutableArray array];
                    for (NSDictionary *dic in value) {
                        [array addObject:[NSClassFromString(className) zl_objectFromDictionary:dic]];
                    }
                    ((void (*) (id, SEL, id)) objc_msgSend)(self, setter, array);
                } else if ([string isEqualToString:@"CGRect"] || [string isEqualToString:@"NSRect"]) {
                    ((void (*) (id, SEL, CGRect)) objc_msgSend)(self, setter, [aCoder decodeCGRectForKey:[[self class] autoTransformation:key]]);
                } else if ([string isEqualToString:@"CGSize"] || [string isEqualToString:@"NSSize"]) {
                    ((void (*) (id, SEL, CGSize)) objc_msgSend)(self, setter, [aCoder decodeCGSizeForKey:[[self class] autoTransformation:key]]);
                } else if ([string isEqualToString:@"CGPoint"] || [string isEqualToString:@"NSPoint"]) {
                    ((void (*) (id, SEL, CGPoint)) objc_msgSend)(self, setter, [aCoder decodeCGPointForKey:[[self class] autoTransformation:key]]);
                } else if ([string isEqualToString:@"NSInteger"]) {
                    ((void (*) (id, SEL, NSInteger)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).integerValue);
                } else if ([string isEqualToString:@"NSUInteger"]) {
                    ((void (*) (id, SEL, NSUInteger)) objc_msgSend)(self, setter, ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).unsignedIntegerValue);
                } else if ([string isEqualToString:@"NSDate"]) {
                    NSDateFormatter *dateFromatter = [self class].zl_dateFormatter;
                    if (dateFromatter == nil) {
                        double timeInterval = ((NSNumber *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]).doubleValue;
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(self, setter, [NSDate dateWithTimeIntervalSince1970:timeInterval]);
                    } else {
                        ((void (*) (id, SEL, NSDate *)) objc_msgSend)(self, setter, [dateFromatter dateFromString:[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]]);
                    }
                } else {
                    ((void (*) (id, SEL, id)) objc_msgSend)(self, setter, [aCoder decodeObjectForKey:[[self class] autoTransformation:key]]);
                }
            } else {
                id v = [NSClassFromString([propertyType substringWithRange:NSMakeRange(2, propertyType.length - 3)]) zl_objectFromJsonString:(NSString *)[aCoder decodeObjectForKey:[[self class] autoTransformation:key]]];
                ((void (*) (id, SEL, id)) objc_msgSend)(self, setter, v);
            }
        }
    }
    free(properties);
}

@end
