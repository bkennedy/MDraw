//    The MIT License (MIT)
//
//    Copyright (c) 2013 xmkevin
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy of
//    this software and associated documentation files (the "Software"), to deal in
//    the Software without restriction, including without limitation the rights to
//    use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//    the Software, and to permit persons to whom the Software is furnished to do so,
//    subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//    FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//    COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//    IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//    CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "MDrawTool.h"
#import "MDrawMeasurementInfo.h"


@implementation MDrawTool
{
    UIColor *_handleFillColor;
    NSString *_unit;
    
    MDrawMeasurementInfo *_measurement;
}

@synthesize name;
@synthesize selected;
@synthesize finalized = _finalized;
@synthesize lineWidth;
@synthesize color;
@synthesize showMeasurement;
@synthesize calibration;
@synthesize measureText;
@synthesize originFrame;

-(id)init
{
    if(self = [super init])
    {
        _handleFillColor = [UIColor colorWithRed:1 green:1 blue:1 alpha:0.6];
        self.lineWidth = 3;
        self.calibration = 0;
        self.unit = @"px";
        _unitScale = 1;
        self.originFrame = CGRectZero;
    }
    
    return self;
}

-(id)initWithStartPoint:(CGPoint)startPoint
{
    if(self=[self init])
    {
        _startPoint = startPoint;
        _endPoint = startPoint;
    }
    
    return self;
}

-(NSString *)unit
{
    return [_unit copy];
}

-(void)setUnit:(NSString *)unit
{
    _unit = unit;
    _unitScale = 1;
    
    if([_unit isEqualToString:@"μm"] || [_unit isEqualToString:@"um"])
    {
        _unitScale = 1;
    }
    else if([_unit isEqualToString:@"mm"])
    {
        _unitScale = 1 / 1000.0;
    }
    else if([_unit isEqualToString:@"cm"])
    {
        _unitScale = 1 / 1000000.0;
    }
}

-(CGRect)frame
{
    return CGRectMake(MIN(_startPoint.x, _endPoint.x),
                      MIN(_startPoint.y, _endPoint.y),
                      fabs(_endPoint.x - _startPoint.x),
                      fabs(_endPoint.y - _startPoint.y));
}

-(void)drawDown:(CGPoint)point
{
}

-(void)drawMove:(CGPoint)point
{
}

-(void)drawUp:(CGPoint)point  frame:(CGRect)originFrame; {
    
}

-(void)recordOrigin
{
    self.originFrame = self.parentView.frame;
    _originStartPoint = _startPoint;
    _originEndPoint = _endPoint;
}

-(void)finalize:(CGPoint)point
{
    _endPoint = point;
}

-(BOOL)hitTest:(CGPoint)point
{
    return CGPointInRect(point, self.frame);
}

-(BOOL)hitOnHandle:(CGPoint)point
{
    return NO;
}

-(void)moveByOffset:(CGSize)offset
{
}

-(void)stopMoveHandle
{
}

-(void)draw:(CGContextRef)ctx
{
}


- (void)drawMeasurement:(CGContextRef)ctx
{
    BOOL needDraw = self.showMeasurement && self.finalized && !self.selected && self.measureText;
    if (!needDraw) {
        return;
    }
    
    if (!_measurement) {
        _measurement = [[MDrawMeasurementInfo alloc] initWithTool:self];
    }
    
    [_measurement draw:ctx];
}

#pragma mark - protected methods

-(void)drawHandle:(CGContextRef)ctx atPoint:(CGPoint)point
{
    CGContextSetFillColorWithColor(ctx, _handleFillColor.CGColor);
    CGContextSetStrokeColorWithColor(ctx, self.color.CGColor);
    CGRect handleRect = CGRectMake(point.x- HANDLE_SIZE /2, point.y- HANDLE_SIZE /2, HANDLE_SIZE, HANDLE_SIZE);
    CGContextSetLineWidth(ctx, 2);
    CGContextFillEllipseInRect(ctx, handleRect);
    CGContextStrokeEllipseInRect(ctx, handleRect);
}

-(BOOL)isPoint:(CGPoint)point onHandle:(CGPoint)handlePoint
{
    CGRect handleRect = CGRectMake(handlePoint.x- HANDLE_SIZE /2, handlePoint.y- HANDLE_SIZE /2, HANDLE_SIZE, HANDLE_SIZE);
    return CGPointInRect(point, handleRect);
}

-(CGFloat)unitConvert:(CGFloat)pixels isSquare:(BOOL)square
{
    if (self.calibration == 0) {
        return pixels;
    }
    
    CGFloat result = pixels * self.calibration * _unitScale;
    if(square)
    {
        result *= ( self.calibration * _unitScale );
    }
    
    return result;
}

-(CGPoint) convertPoint: (CGPoint) point fromRect: (CGRect) fromRect toRect: (CGRect) toRect {
    if (CGRectEqualToRect(fromRect, toRect)) {
        return point;
    }
    return (CGPoint){
        (toRect.size.width/fromRect.size.width) * point.x,
        (toRect.size.height/fromRect.size.height) * point.y
    };
}

-(void)convertFromScreenRect:(CGRect)fromRect toRect:(CGRect) toRect {
    _startPoint = [self convertPoint:_originStartPoint fromRect:self.frame toRect:toRect];
    _endPoint = [self convertPoint:_originEndPoint fromRect:self.frame toRect:toRect];

}

-(void)convertPoints {
    UIDeviceOrientation  orientation = [UIDevice currentDevice].orientation;
    if (orientation != UIDeviceOrientationPortraitUpsideDown) {
        if (!CGRectIsEmpty(self.originFrame) && !CGRectEqualToRect(self.originFrame,self.parentView.frame)) {
            _startPoint = [self convertPoint:_originStartPoint fromRect:self.originFrame toRect:self.parentView.frame];
            _endPoint = [self convertPoint:_originEndPoint fromRect:self.originFrame toRect:self.parentView.frame];
        } else {
            _startPoint = _originStartPoint;
            _endPoint = _originEndPoint;
        }
    }

}

//-(CGPoint)startPoint {
//    CGPoint sPoint =  _startPoint;
//    if (!CGRectIsEmpty(self.originFrame) && !CGRectEqualToRect(self.originFrame,self.parentView.frame)) {
//        sPoint = [self convertPoint:_startPoint fromRect:self.originFrame toRect:self.parentView.frame];
//    }
//    return sPoint;
//}
//
//-(CGPoint)endPoint {
//    CGPoint ePoint = _endPoint;
//    if (!CGRectIsEmpty(self.originFrame) && !CGRectEqualToRect(self.originFrame,self.parentView.frame)) {
//        ePoint = [self convertPoint:_endPoint fromRect:self.originFrame toRect:self.parentView.frame];
//    }
//    return ePoint;
//}

@end
