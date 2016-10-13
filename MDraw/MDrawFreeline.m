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

#import "MDrawFreeline.h"

@implementation MDrawFreeline
{
    NSMutableArray *_points;
}

-(id)init
{
    if(self = [super init])
    {
        _points = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(id)initWithStartPoint:(CGPoint)startPoint
{
    self = [super initWithStartPoint:startPoint];
    if(self)
    {
        _points = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(CGRect)frame
{
    CGPoint tl, rb;
    
    if(_points.count > 0 )
    {
        CGPoint firstPoint = [[_points objectAtIndex:0] CGPointValue];
        tl = firstPoint;
        rb = firstPoint;
    }
    
    for (NSValue *pValue in _points)
    {
        CGPoint p = [pValue CGPointValue];
        
        tl.x = MIN(tl.x, p.x);
        tl.y = MIN(tl.y, p.y);
        rb.x = MAX(rb.x, p.x);
        rb.y = MAX(rb.y, p.y);
    }
    
    return CGRectMake(tl.x,
                      tl.y,
                      fabs(rb.x - tl.x),
                      fabs(rb.y - tl.y));
    
    
}

-(void)drawMove:(CGPoint)point
{
    [_points addObject:[NSValue valueWithCGPoint:point]];
}

-(void)recordOrigin
{
    self.originFrame = self.parentView.frame;
    self.originPoints = [NSArray arrayWithArray:_points];
}


-(void)drawUp:(CGPoint)point frame:(CGRect)originFrame
{
    [self recordOrigin];
    [_points addObject:[NSValue valueWithCGPoint:point]];
    [self finalize];
}

-(void)finalize
{
    _finalized = YES;
    self.selected = YES;
}

-(BOOL)hitOnHandle:(CGPoint)point
{
    _moveDirection = MDrawMoveDirectionNone;
    
    CGRect frame = self.frame;
    
    if(CGPointInRect(point, frame))
    {
        _moveDirection = MDrawMoveDirectionWhole;
        return YES;
    }
    
    return NO;
}

-(void)moveByOffset:(CGSize)offset
{
    if(_moveDirection == MDrawMoveDirectionWhole)
    {
        for (int i = 0; i < _points.count; i++) {
            CGPoint p = [[_points objectAtIndex:i] CGPointValue];
            p.x += offset.width;
            p.y += offset.height;
            
            [_points replaceObjectAtIndex:i withObject:[NSValue valueWithCGPoint:p]];
        }
    }
    [self recordOrigin];
}

-(void)draw:(CGContextRef)ctx
{
    CGContextSetStrokeColorWithColor(ctx, self.color.CGColor);
    CGContextSetLineWidth(ctx, self.lineWidth);
    
    CGContextBeginPath(ctx);
    if(_points.count > 0 )
    {
        CGPoint p = [[_points objectAtIndex:0] CGPointValue];
        CGContextMoveToPoint(ctx, p.x, p.y);
        
        for (int i = 1; i < _points.count; i++)
        {
            CGPoint p = [[_points objectAtIndex:i] CGPointValue];
            CGContextAddLineToPoint(ctx, p.x, p.y);
        }
        
    }
    
    CGContextStrokePath(ctx);
    
    if (self.selected)
    {
        [self drawHandle:ctx atPoint:CGRectMid(self.frame)];
        
    }

}

-(NSString *)measureText
{
    static NSString *lengthString;
    if(!lengthString)
    {
        lengthString = NSLocalizedString(@"Length", Nil);
    }
    
    CGFloat length = CGPolygonLength(_points);
    
    return [NSString stringWithFormat:@"%@: %0.2f %@",
            lengthString,
            [self unitConvert:length isSquare:NO],
            self.unit];
}

-(void)convertPoints {
    UIDeviceOrientation  orientation = [UIDevice currentDevice].orientation;
    if (orientation != UIDeviceOrientationPortraitUpsideDown) {
        if (!CGRectIsEmpty(self.originFrame) && !CGRectEqualToRect(self.originFrame,self.parentView.frame)) {
            [_points removeAllObjects];
            for (NSValue *pointValue in self.originPoints) {
                CGPoint point = [pointValue CGPointValue];
                CGPoint newPoint = [self convertPoint:point fromRect:self.originFrame toRect:self.parentView.frame];
                [_points addObject:[NSValue valueWithCGPoint:newPoint]];
            }
        } else {
            _points = [NSMutableArray arrayWithArray:self.originPoints];
        }
    }
    
    if (_points.count <= 1)
        _points = [NSMutableArray arrayWithArray:_originPoints];
    
}


@end
