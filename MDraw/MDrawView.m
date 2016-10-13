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

#import "MDrawView.h"
#import "MUndoManager.h"
#import "UIImage+Crop.h"

@implementation MDrawView
{
    NSMutableArray *_tools;
    Class _drawToolClass;
    MUndoManager *_undoManager;
    CGLayerRef drawingLayer,imageLayer;
    CGContextRef layerContext,imageLayerContext;
    BOOL _isMoved; // Is mouse or figure moved
    CGFloat _lineWidth;
    BOOL _enableGesture;
    BOOL _showMeasurement;
    NSString *_unit;
    UIImage *scaledImage;
}

@synthesize calibration = _calibration;
@synthesize isDirty = _isDirty;

-(void)setColor:(UIColor *)color {
    _color = color;
    _activeTool.color = _color;
    [self setNeedsDisplay];
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    if(self = [super initWithCoder:aDecoder])
    {
        // Initialization code
        _tools = [[NSMutableArray alloc] init];
        _undoManager = [[MUndoManager alloc] initWithTools:_tools];

        self.color = [UIColor redColor];
        self.backgroundColor = [UIColor clearColor];
        
        _lineWidth = 3;
        _calibration = 0;
        
        _enableGesture = YES;
        [self initGestures];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receivedRotate:) name:UIDeviceOrientationDidChangeNotification object:NULL];

    }
    
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if(drawingLayer)
        CGLayerRelease(drawingLayer);
    
    if(imageLayer)
        CGLayerRelease(imageLayer);
}

-(void) receivedRotate: (NSNotification*) notification {
    CGRect viewRect = AVMakeRectWithAspectRatioInsideRect(_image.size, self.superview.frame);
    self.frame = CGRectMake(viewRect.origin.x, viewRect.origin.y, ceil(viewRect.size.width), ceil(viewRect.size.height));
    for (MDrawTool *tool in _tools)
    {
        [tool convertPoints];
    }

    [self setNeedsDisplay];
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        _tools = [[NSMutableArray alloc] init];
        [self initGestures];
    }
    return self;
}

- (void)refreshCalibrations
{
    for (MDrawTool *tool in _tools)
    {
        tool.calibration = self.calibration;
        tool.unit = self.unit;
        tool.showMeasurement = self.showMeasurement;
    }
    
    [self setNeedsDisplay];
}

-(BOOL)hasTools
{
    return _tools.count > 0;
}

-(NSArray *)tools
{
    return _tools;
}

-(CGFloat)lineWidth
{
    return _lineWidth;
}

-(void)setLineWidth:(CGFloat)lineWidth
{
    if(_activeTool)
    {
        _activeTool.lineWidth = lineWidth;
        
        [self setNeedsDisplay];
    }
    
    _lineWidth = lineWidth;
}

-(BOOL)enableGesture
{
    return _enableGesture;
}

-(void)setEnableGesture:(BOOL)enableGesture
{
    _enableGesture = enableGesture;
    
    for (UIGestureRecognizer *g in self.gestureRecognizers) {
        g.enabled = _enableGesture;
    }
    
    self.multipleTouchEnabled = _enableGesture;
}

-(BOOL)showMeasurement
{
    return _showMeasurement;
}

-(void)setShowMeasurement:(BOOL)showMeasurement
{
    _showMeasurement = showMeasurement;
    
    for (MDrawTool *tool in _tools) {
        tool.showMeasurement = showMeasurement;
    }
    
    [self setNeedsDisplay];
    
}

- (CGFloat)calibration
{
    return _calibration;
}

- (void)setCalibration:(CGFloat)calibration
{
    _calibration = calibration;
    
    [self refreshCalibrations];
}

-(NSString *)unit
{
    if(_unit == Nil)
    {
        _unit = @"px";
    }
    
    return _unit;
}

-(void)setUnit:(NSString *)unit
{
    _unit = unit;
    
    [self refreshCalibrations];
}


-(BOOL)undo
{
    if([_undoManager undo])
    {
        [self setNeedsDisplay];
        [self.toolDelegate selectPreviousTool];
        return YES;
    }
    
    return NO;
}

-(BOOL)redo
{
    if([_undoManager redo])
    {
        [self setNeedsDisplay];
        return YES;
    }
    
    return NO;
}

- (void)drawRect:(CGRect)rect {
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context)
        return;
    float scale = [UIScreen mainScreen].scale;
    CGRect bounds = CGRectMake(0, 0, rect.size.width *scale, rect.size.height *scale);
    
    if(drawingLayer)
        CGLayerRelease(drawingLayer);
    
    drawingLayer = CGLayerCreateWithContext(context, bounds.size, NULL);
    layerContext = CGLayerGetContext(drawingLayer);
    CGContextScaleCTM(layerContext, scale, scale);
    self.viewRect = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    
    if(imageLayer)
        CGLayerRelease(imageLayer);
    imageLayer = CGLayerCreateWithContext(context, bounds.size, NULL);
    imageLayerContext = CGLayerGetContext(imageLayer);

    UIGraphicsBeginImageContext (bounds.size);
    
    CGContextTranslateCTM(imageLayerContext, 0, bounds.size.height);
    CGContextScaleCTM(imageLayerContext, 1.0, -1.0);
    CGContextDrawImage(imageLayerContext, bounds, scaledImage.CGImage);
    UIGraphicsEndImageContext();
    
    CGContextRef ctx = CGLayerGetContext(drawingLayer);

    for (MDrawTool *tool in _tools)
    {
        [tool draw:ctx];
    }
    
    CGContextDrawLayerInRect(context, self.viewRect, imageLayer);
    CGContextDrawLayerInRect(context, self.viewRect, drawingLayer);

    UIGraphicsEndImageContext();

    if ([self.imageCreationDelegate respondsToSelector:@selector(imageCreateCompleted)])
        [self.imageCreationDelegate imageCreateCompleted];
}


-(void)beginDrawingForType:(Class)toolType
{
    if(toolType == Nil)
    {
        _drawToolClass = Nil;
        _drawing = NO;
        
        return;
    }
    
    if(_activeTool)
    {
        _activeTool.selected = NO;
        _activeTool = Nil;
        [self setNeedsDisplay];
    }
    
    _drawToolClass = toolType;
    _drawing = YES;
}

-(void)clearDragHandles:(Class)toolType {
    for (MDrawTool *tool in _tools)
    {
        tool.selected = NO;
        [self setNeedsDisplay];
    }
    _activeTool = Nil;
    _drawToolClass = toolType;

    _drawing = YES;
}

-(void)finalizeDrawing
{
    [_activeTool finalize];
    _drawing = NO;
    [self setNeedsDisplay];
}

-(void)deleteCurrentTool
{
    if(_activeTool)
    {
        [_undoManager removeTool:_activeTool];
        _activeTool = Nil;
        
        _isDirty = YES;
        
        [self setNeedsDisplay];
    }
}

-(void)clearTools
{
    [_tools removeAllObjects];
    [_undoManager reset];
    [self setNeedsDisplay];
}

-(void)selectNone
{
    if(_activeTool)
    {
        _activeTool.selected = NO;
        [self setNeedsDisplay];
    }
}

- (UIImage*) markedUpImage
{
    
    [self drawRect:self.frame];
    UIImage *markup = [self getDrawingImage];

    CGRect imageRect = CGRectMake(0, 0, ceil(_image.size.width), ceil(_image.size.height));
    UIGraphicsBeginImageContextWithOptions(_image.size, NO, [UIScreen mainScreen].scale);
    [_image drawInRect:imageRect];
    [markup drawInRect:imageRect];
    
    UIImage *editedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return editedImage;
}


- (UIImage*)getDrawingImage {


    UIGraphicsBeginImageContext (self.viewRect.size);

    CGContextRef ctx = UIGraphicsGetCurrentContext();

    for (MDrawTool *tool in _tools)
    {
        [tool draw:ctx];
    }

    UIImage *editedImage = UIGraphicsGetImageFromCurrentImageContext();

    UIGraphicsEndImageContext();


    return editedImage;
}

#pragma mark - private methods

-(void)initGestures
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    tapGesture.numberOfTouchesRequired = 1;
    tapGesture.delegate = self;
    [self addGestureRecognizer:tapGesture];
}

-(void)handleTapGesture:(UITapGestureRecognizer *)gesture
{
    CGPoint point = [gesture locationInView:self];
    if(_drawing)
    {
        [self drawUp:point];
        [self setNeedsDisplay];
    }
    else
    {
        if (![self selectTool:point])
            [self.toolDelegate selectPreviousTool];
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint point = [touch locationInView:self];
    
    [self drawDown:point];
    
    
    [self.nextResponder touchesBegan:touches withEvent:event];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint prePoint = [touch previousLocationInView:self];
    CGPoint point = [touch locationInView:self];
    
    [self drawMoveFromPoint:prePoint toPoint:point];
    
    [self.nextResponder touchesMoved:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint point = [touch locationInView:self];
    
    [self drawUp:point];
    
    [self.nextResponder touchesEnded:touches withEvent:event];
}

#pragma mark - draw

-(void)drawDown:(CGPoint)point
{
    _isMoved = NO;
    
    if(self.drawing)
    {
        if(_activeTool && !_activeTool.finalized && _drawing)
        {
            [_activeTool drawDown:point];
        }
        else
        {
            _activeTool = [[_drawToolClass alloc] initWithStartPoint:point];
            _activeTool.color = self.color;
            _activeTool.lineWidth = self.lineWidth;
            _activeTool.showMeasurement = self.showMeasurement;
            _activeTool.unit = self.unit;
            _activeTool.calibration = self.calibration;
            _activeTool.parentView = self;
            //Comment tool is special, it should interate with alert views.
            if([_activeTool isKindOfClass:[MDrawComment class]])
            {
                MDrawComment *comment = (MDrawComment *)_activeTool;
                comment.delegate = self;
            }
            
            [_undoManager addTool:_activeTool];
            
            _isDirty = YES;
        }
        
        [self setNeedsDisplay];
    }
    else
    {
        [self.activeTool hitOnHandle:point];
    }
}

-(void)drawMoveFromPoint:(CGPoint)srcPoint toPoint:(CGPoint)point
{
    _isMoved = YES;
    _isDirty = YES;
    
    if(self.drawing)
    {
        [self.activeTool drawMove:point];
    }
    else
    {
        CGSize offset = CGPointOffset(srcPoint, point);
        [self.activeTool moveByOffset:offset];
    }
    
    [self setNeedsDisplay];
}

-(void)drawUp:(CGPoint)point
{
    if(self.drawing)
    {
        if(_isMoved){
            [self.activeTool drawUp:point frame:self.frame];
        
            if(self.activeTool.finalized){
                _drawing = NO;
            }
        } else {
            if (![self selectTool:point])
                [self.toolDelegate selectPreviousTool];
        }
    }
    else
    {
        if(_isMoved)
        {
            [self.activeTool stopMoveHandle];
        }
        else
        {
            //Click or tap
            if (![self selectTool:point])
                [self.toolDelegate selectPreviousTool];
        }
        
    }
    
    [self setNeedsDisplay];
    
    _isMoved = NO;
}

#pragma mark - hit tests

-(BOOL)selectTool:(CGPoint)point
{
    BOOL hasSelected = NO;
    _activeTool = Nil;
    _drawing = YES;

    for (NSInteger i = _tools.count -1; i >= 0; i--)
    {
        MDrawTool *tool = [_tools objectAtIndex:i];
        
        if([tool hitTest:point] && !hasSelected)
        {
            hasSelected = YES;
            
            tool.selected = YES;
            _activeTool = tool;
            _drawing = NO;
        }
        else
        {
            tool.selected = NO;
            
        }
    }
    
    [self setNeedsDisplay];
    return hasSelected;
}

#pragma mark - draw comment protocol

-(void)drawTool:(MDrawTool *)tool isAdded:(BOOL)added
{
    if(added)
    {
        [self setNeedsDisplay];
    }
    else
    {
        [self deleteCurrentTool];
    }
}

//-(void)rotateImage {
//    [self setImage:_image];
//}

- (void) setImage:(UIImage*)sketch
{
    CGRect imageRect = AVMakeRectWithAspectRatioInsideRect(sketch.size, self.superview.frame);
    imageRect = CGRectMake(imageRect.origin.x, imageRect.origin.y, ceil(imageRect.size.width), ceil(imageRect.size.height));
    
    self.frame = imageRect;
    _image = [sketch rotateUIImage];
    
    
    UIImageView* imageView = [[UIImageView alloc] initWithFrame:imageRect];
    imageView.contentMode = self.contentMode;
    imageView.image = _image;
    imageView.backgroundColor = [UIColor clearColor];
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0);
    [imageView.layer renderInContext:UIGraphicsGetCurrentContext()];
    scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

}


@end
