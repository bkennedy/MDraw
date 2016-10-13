#import "MDrawBezierFreeline.h"

static CGPoint midpoint(CGPoint p0, CGPoint p1) {
    return (CGPoint) {
        (p0.x + p1.x) / 2.0,
        (p0.y + p1.y) / 2.0
    };
}

@implementation MDrawBezierFreeline
{
    CGPoint _previousPoint;
}

-(id)init
{
    if(self = [super init])
    {
        _path = [UIBezierPath bezierPath];
        _points = [NSMutableArray array];
    }
    
    return self;
}

-(void)recordOrigin
{
    self.originFrame = self.parentView.frame;
    self.originPoints = [NSArray arrayWithArray:_points];
}


-(id)initWithStartPoint:(CGPoint)startPoint
{
    self = [super initWithStartPoint:startPoint];
    if(self)
    {
        _path = [UIBezierPath bezierPath];
        [_path moveToPoint:startPoint];
        [_points addObject:[NSValue valueWithCGPoint:startPoint]];
    }
    
    return self;
}

-(BOOL)hitTest:(CGPoint)point
{
    return CGPointInRect(point, self.frame);
}

-(CGRect)frame
{
    return _path.bounds;
}


-(void)drawMove:(CGPoint)point
{
    CGPoint midPoint = midpoint([[_points lastObject] CGPointValue], point);
    [_path addQuadCurveToPoint:midPoint controlPoint:[[_points lastObject] CGPointValue]];
    [_points addObject:[NSValue valueWithCGPoint:point]];
//    _previousPoint = point;
}

-(void)drawUp:(CGPoint)point  frame:(CGRect)originFrame
{
    CGPoint midPoint = midpoint([[_points lastObject] CGPointValue], point);
    [_path addQuadCurveToPoint:midPoint controlPoint:[[_points lastObject] CGPointValue]];
    
    [_points addObject:[NSValue valueWithCGPoint:point]];
    [self finalize];
}

-(void)finalize
{
    _originPoints = [NSArray arrayWithArray:_points];
    [self recordOrigin];
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
        [_path applyTransform:CGAffineTransformMakeTranslation(offset.width,
                                                              offset.height)];
    }
    
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
    UIGraphicsPushContext(ctx);
    
    [self.color setStroke];
    _path.lineWidth = self.lineWidth;
    [_path stroke];
    
    UIGraphicsPopContext();
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
    
    CGFloat length = _path.bounds.size.width;
    
    return [NSString stringWithFormat:@"%@: %0.2f %@",
            lengthString,
            [self unitConvert:length isSquare:NO],
            self.unit];
}

-(void)convertPoints {
    if (_originPoints.count == 0) return;
    
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
    
    if (_points.count <= 1)
        return;
    
    _path = [UIBezierPath bezierPath];
    
    [_path moveToPoint:[_points[0] CGPointValue]];
    for (int i=1;i<_points.count;i++) {
        CGPoint midPoint = midpoint([_points[i-1] CGPointValue], [_points[i] CGPointValue]);
        [_path addQuadCurveToPoint:midPoint controlPoint:[_points[i-1] CGPointValue]];
    }
    
}


@end
