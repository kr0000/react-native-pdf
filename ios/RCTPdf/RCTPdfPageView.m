/**
 * Copyright (c) 2017-present, Wonday (@wonday.org)
 * All rights reserved.
 *
 * This source code is licensed under the MIT-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "PdfManager.h"
#import "RCTPdfPageView.h"



#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

#if __has_include(<React/RCTAssert.h>)
#import <React/RCTBridgeModule.h>
#import <React/RCTEventDispatcher.h>
#import <React/UIView+React.h>
#import <React/RCTLog.h>
#else
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"
#import "UIView+React.h"
#import "RCTLog.h"
#endif

#ifndef __OPTIMIZE__
// only output log when debug
#define DLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DLog( s, ... )
#endif

// output log both debug and release
#define RLog( s, ... ) NSLog( @"<%p %@:(%d)> %@", self, [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )

@implementation RCTPdfPageView {

   
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.backgroundColor = UIColor.whiteColor;
        CATiledLayer *tiledLayer = (CATiledLayer *)[self layer];
        
    }
    
    return self;
}

// The layer's class should be CATiledLayer.
+ (Class)layerClass
{
    return [CATiledLayer class];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps
{
    long int count = [changedProps count];
    for (int i = 0 ; i < count; i++) {
        
        if ([[changedProps objectAtIndex:i] isEqualToString:@"page"]) {
            [self setNeedsDisplay];
        }

    }
    
    [self setNeedsDisplay];
}


- (void)reactSetFrame:(CGRect)frame
{
    [super reactSetFrame:frame];
}

+ (void) renderPage: (CGPDFPageRef) page inContext: (CGContextRef) context atPoint: (CGPoint) point withZoom: (float) zoom{
    
    CGRect cropBox = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    int rotate = CGPDFPageGetRotationAngle(page);
    
    CGContextSaveGState(context);
    
    // Setup the coordinate system.
    // Top left corner of the displayed page must be located at the point specified by the 'point' parameter.
    CGContextTranslateCTM(context, point.x, point.y);
    
    // Scale the page to desired zoom level.
    CGContextScaleCTM(context, zoom / 100, zoom / 100);
    
    // The coordinate system must be set to match the PDF coordinate system.
    switch (rotate) {
        case 0:
            CGContextTranslateCTM(context, 0, cropBox.size.height);
            CGContextScaleCTM(context, 1, -1);
            break;
        case 90:
            CGContextScaleCTM(context, 1, -1);
            CGContextRotateCTM(context, -M_PI / 2);
            break;
        case 180:
        case -180:
            CGContextScaleCTM(context, 1, -1);
            CGContextTranslateCTM(context, cropBox.size.width, 0);
            CGContextRotateCTM(context, M_PI);
            break;
        case 270:
        case -90:
            CGContextTranslateCTM(context, cropBox.size.height, cropBox.size.width);
            CGContextRotateCTM(context, M_PI / 2);
            CGContextScaleCTM(context, -1, 1);
            break;
    }
    
    // The CropBox defines the page visible area, clip everything outside it.
    CGRect clipRect = CGRectMake(0, 0, cropBox.size.width, cropBox.size.height);
    CGContextAddRect(context, clipRect);
    CGContextClip(context);
    
    CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
    CGContextFillRect(context, clipRect);
    
    CGContextTranslateCTM(context, -cropBox.origin.x, -cropBox.origin.y);
    
    CGContextDrawPDFPage(context, page);
    
    CGContextRestoreGState(context);
}

CGRect AspectFitRectInRect(CGRect rfit, CGRect rtarget)
{
    CGFloat scale = 1;
    //default values to the target
    CGFloat w = CGRectGetWidth(rtarget);
    CGFloat h = CGRectGetHeight(rtarget);
    
    CGFloat s = CGRectGetWidth(rtarget) / CGRectGetWidth(rfit);
    // The greatest dim was preset, compute the lesser one
    if (CGRectGetHeight(rfit) * s <= CGRectGetHeight(rtarget))
    {
        scale = s;
        h = CGRectGetHeight(rfit) * scale;
    } else {
        scale = CGRectGetHeight(rtarget) / CGRectGetHeight(rfit);
        w = CGRectGetWidth(rfit) * scale;
    }
    
    // Center the resulting rect in the target
    CGFloat x = CGRectGetMidX(rtarget) - w / 2;
    CGFloat y = CGRectGetMidY(rtarget) - h / 2;
    return CGRectMake(x, y, w, h);
}

-(void)drawLayer:(CALayer*)layer inContext:(CGContextRef)context
{
    CGPDFDocumentRef pdfRef= [PdfManager getPdf:_fileNo];
    CGPDFPageRef page = CGPDFDocumentGetPage(pdfRef, _page);
    CGRect cropBox = CGPDFPageGetBoxRect(page, kCGPDFCropBox);
    CGRect mediaBox = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
    RLog(@"self box size %f ", self.bounds.size.height);
    RLog(@"crop box size %f ", cropBox.size.height);
    RLog(@"media box size %f ", mediaBox.size.height);
    
    CGRect displayRectangle = CGRectMake(-((self.bounds.size.width-cropBox.size.width)/2), 100, self.bounds.size.height, self.bounds.size.width);
    if ((displayRectangle.size.width == 0) || (displayRectangle.size.height == 0)) {
        return;
    }

    int pageRotation = CGPDFPageGetRotationAngle(page);
    
    CGSize pageVisibleSize = CGSizeMake(cropBox.size.width, cropBox.size.height);
    if ((pageRotation == 90) || (pageRotation == 270) ||(pageRotation == -90)) {
        pageVisibleSize = CGSizeMake(cropBox.size.height, cropBox.size.width);
    }
    
    float scaleX = displayRectangle.size.width / pageVisibleSize.width;
    float scaleY = displayRectangle.size.height / pageVisibleSize.height;
    float scale = scaleX < scaleY ? scaleX : scaleY;
    
    // Offset relative to top left corner of rectangle where the page will be displayed
    float offsetX = 0;
    float offsetY = 0;
    
    float rectangleAspectRatio = displayRectangle.size.width / displayRectangle.size.height;
    float pageAspectRatio = pageVisibleSize.width / pageVisibleSize.height;
    
    if (pageAspectRatio < rectangleAspectRatio) {
        // The page is narrower than the rectangle, we place it at center on the horizontal
        offsetX = (displayRectangle.size.width - pageVisibleSize.width * scale) / 2;
    }
    else {
        // The page is wider than the rectangle, we place it at center on the vertical
        offsetY = (displayRectangle.size.height - pageVisibleSize.height * scale) / 2;
    }
    
    CGPoint topLeftPage = CGPointMake(displayRectangle.origin.x + offsetX, displayRectangle.origin.y + offsetY);
    
    [RCTPdfPageView renderPage:page inContext:context atPoint:topLeftPage withZoom:scale * 100];

    
    
//    // PDF page drawing expects a Lower-Left coordinate system, so we flip the coordinate system before drawing.
//    CGContextScaleCTM(context, 1.0, -1.0);
//
//    CGPDFDocumentRef pdfRef= [PdfManager getPdf:_fileNo];
//    if (pdfRef!=NULL)
//    {
//
//        CGPDFPageRef pdfPage = CGPDFDocumentGetPage(pdfRef, _page);
//
//        if (pdfPage != NULL) {
//
//            CGContextSaveGState(context);
//            CGRect pageBounds;
//                pageBounds = CGRectMake(0,
//                                        -self.bounds.size.height,
//                                        self.bounds.size.width,
//                                        self.bounds.size.height);
//
//            // Fill the background with white.
//            CGContextSetRGBFillColor(context, 1.0,1.0,1.0,1.0);
//            CGContextFillRect(context, pageBounds);
//
//            CGAffineTransform pageTransform = CGPDFPageGetDrawingTransform(pdfPage, kCGPDFCropBox, pageBounds, 0, true);
//            CGContextConcatCTM(context, pageTransform);
//
//            CGContextDrawPDFPage(context, pdfPage);
//            CGContextRestoreGState(context);
//
//            RLog(@"drawpage %d", _page);
//        }
//
//    }
}

@end
