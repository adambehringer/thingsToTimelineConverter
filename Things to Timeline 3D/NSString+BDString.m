//
//  NSString+BDString.m
//  Things Timeline 3D Exporter
//
//  Created by Adam Behringer on 7/3/13.
//  Copyright (c) 2013 BEEDOCS, Inc. All rights reserved.
//

#import "NSString+BDString.h"

@implementation NSString (BDString)

- (NSString *)stringWithoutTabsAndReturns
{
	NSString *outputString = [self stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
	outputString = [outputString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
	outputString = [outputString stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
	
	return outputString;
}

@end
