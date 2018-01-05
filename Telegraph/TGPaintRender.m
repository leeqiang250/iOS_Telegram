#import "TGPaintRender.h"

#include <OpenGLES/ES2/gl.h>

#import "TGPaintBrush.h"
#import "TGPaintPath.h"
#import "TGPaintUtils.h"

const NSInteger TGPaintRenderStateDefaultSize = 256;

@interface TGPaintRenderState ()
{
    NSUInteger _allocatedCount;
}

@property (nonatomic, assign) CGFloat brushWeight;
@property (nonatomic, assign) CGFloat spacing;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) CGFloat angle;
@property (nonatomic, assign) CGFloat scale;

@property (nonatomic, readonly) CGFloat *values;
@property (nonatomic, readonly) NSUInteger count;

@property (nonatomic, assign) CGFloat remainder;

- (void)reset;

@end

@implementation TGPaintRenderState

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        _values = NULL;
    }
    return self;
}

- (void)dealloc
{
    if (_values != NULL)
    {
        free(_values);
        _values = NULL;
    }
}

- (void)prepare
{
    if (_values != NULL)
    {
        free(_values);
        _values = NULL;
    }
    
    _count = 0;
    _allocatedCount = TGPaintRenderStateDefaultSize;
    _values = malloc(sizeof(CGFloat) * TGPaintRenderStateDefaultSize * 5);
}

- (void)appendValuesCount:(NSUInteger)count
{
    NSUInteger newTotalCount = _count + count;
    
    if (newTotalCount > _allocatedCount || _values == NULL)
    {
        if (_values != NULL)
        {
            free(_values);
            _values = NULL;
        }
        
        NSInteger newCount = MAX(_allocatedCount * 2, TGPaintRenderStateDefaultSize);
        _values = malloc(sizeof(CGFloat) * newCount * 5);
        _allocatedCount = newCount;
    }
    
    _count = newTotalCount;
}

- (void)addPoint:(CGPoint)point size:(CGFloat)size angle:(CGFloat)angle alpha:(CGFloat)alpha index:(NSInteger)index
{
    NSInteger column = index * 5;
    _values[column] = point.x;
    _values[column + 1] = point.y;
    _values[column + 2] = size;
    _values[column + 3] = angle;
    _values[column + 4] = alpha;
}

- (void)reset
{
    _count = 0;
    _allocatedCount = 0;
    if (_values != NULL)
    {
        free(_values);
        _values = NULL;
    }
    
    _remainder = 0;
}

@end

@implementation TGPaintRender

typedef struct
{
    GLfloat x;
    GLfloat y;
    GLfloat s;
    GLfloat t;
    GLfloat a;
} vertexData;

+ (void)_paintStamp:(TGPaintPoint *)point state:(TGPaintRenderState *)state
{
    CGFloat weight = state.brushWeight;
    
    CGPoint start = point.CGPoint;
    
    CGFloat brushSize = weight;
    CGFloat rotationalScatter = 0.0f;
    CGFloat angleOffset = fabs(state.angle) > FLT_EPSILON ? state.angle : 0.0f;
    CGFloat alpha = MIN(1.0f, state.alpha * 1.55f);
    
    [state prepare];
    [state appendValuesCount:1];
    [state addPoint:start size:brushSize angle:rotationalScatter + angleOffset alpha:alpha index:0];
}

+ (void)_paintFromPoint:(TGPaintPoint *)lastLocation toPoint:(TGPaintPoint *)location state:(TGPaintRenderState *)state
{
    CGFloat f, distance = TGPaintDistance(lastLocation.CGPoint, location.CGPoint);
    CGPoint vector = TGPaintSubtractPoints(location.CGPoint, lastLocation.CGPoint);
    CGPoint unitVector = CGPointMake(1.0f, 1.0f);
    CGFloat vectorAngle = fabs(state.angle) > FLT_EPSILON ? state.angle : atan2(vector.y, vector.x);
    
    CGFloat brushWeight = state.brushWeight * state.scale;
    CGFloat step = MAX(1.0f, state.spacing * brushWeight);
    
    if (distance > 0.0f)
        unitVector = TGPaintMultiplyPoint(vector, 1.0f / distance);
    
    CGPoint start = TGPaintAddPoints(lastLocation.CGPoint, TGPaintMultiplyPoint(unitVector, state.remainder));
    
    NSInteger i = state.count;
    NSInteger count = (NSInteger)(ceil((distance - state.remainder) / step));
    
    CGFloat boldenedAlpha = MIN(1.0f, state.alpha * 1.15f);
    bool boldenFirst = lastLocation.edge;
    bool boldenLast = location.edge;
    
    [state appendValuesCount:count];
    
    for (f = state.remainder; f <= distance; f += step)
    {
        CGFloat alpha = boldenFirst ? boldenedAlpha : state.alpha;
        [state addPoint:start size:brushWeight angle:vectorAngle alpha:alpha index:i];
        
        start = TGPaintAddPoints(start, TGPaintMultiplyPoint(unitVector, step));
        
        i++;
        
        boldenFirst = false;
    }
    
    if (boldenLast)
    {
        [state appendValuesCount:1];
        [state addPoint:location.CGPoint size:brushWeight angle:vectorAngle alpha:boldenedAlpha index:i];
    }
    
    state.remainder = f - distance;
}

+ (CGRect)_drawWithState:(TGPaintRenderState *)state
{
    vertexData *vertexD = calloc(sizeof(vertexData), state.count * 4 + (state.count - 1) * 2);
    CGRect dataBounds = CGRectZero;
    
    int n = 0;
    for (NSUInteger i = 0; i < state.count; i++)
    {
        NSInteger column = i * 5;
        
        CGPoint result = CGPointMake(state.values[column], state.values[column + 1]);
        CGFloat size = state.values[column + 2] / 2;
        CGFloat angle = state.values[column + 3];
        CGFloat alpha = state.values[column + 4];
        
        CGRect rect = CGRectMake(result.x - size, result.y - size, size*2, size*2);
        CGPoint a = CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect));
        CGPoint b = CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect));
        CGPoint c = CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect));
        CGPoint d = CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect));
        
        CGPoint center = TGPaintCenterOfRect(rect);
        CGAffineTransform t = CGAffineTransformMakeTranslation(center.x, center.y);
        t = CGAffineTransformRotate(t, angle);
        t = CGAffineTransformTranslate(t, -center.x, -center.y);
        
        a = CGPointApplyAffineTransform(a, t);
        b = CGPointApplyAffineTransform(b, t);
        c = CGPointApplyAffineTransform(c, t);
        d = CGPointApplyAffineTransform(d, t);
        
        CGRect boxBounds = CGRectApplyAffineTransform(rect, t);
        dataBounds = TGPaintUnionRect(dataBounds, CGRectIntegral(boxBounds));
        
        if (n != 0)
        {
            vertexD[n].x = (GLfloat)a.x;
            vertexD[n].y = (GLfloat)a.y;
            vertexD[n].s = (GLfloat)0;
            vertexD[n].t = (GLfloat)0;
            vertexD[n].a = (GLfloat)alpha;
            n++;
        }
        
        vertexD[n].x = (GLfloat)a.x;
        vertexD[n].y = (GLfloat)a.y;
        vertexD[n].s = (GLfloat)0;
        vertexD[n].t = (GLfloat)0;
        vertexD[n].a = (GLfloat)alpha;
        n++;
        
        vertexD[n].x = (GLfloat)b.x;
        vertexD[n].y = (GLfloat)b.y;
        vertexD[n].s = (GLfloat)1;
        vertexD[n].t = (GLfloat)0;
        vertexD[n].a = (GLfloat)alpha;
        n++;
        
        vertexD[n].x = (GLfloat)c.x;
        vertexD[n].y = (GLfloat)c.y;
        vertexD[n].s = (GLfloat)0;
        vertexD[n].t = (GLfloat)1;
        vertexD[n].a = (GLfloat)alpha;
        n++;
        
        vertexD[n].x = (GLfloat)d.x;
        vertexD[n].y = (GLfloat)d.y;
        vertexD[n].s = (GLfloat)1;
        vertexD[n].t = (GLfloat)1;
        vertexD[n].a = (GLfloat)alpha;
        n++;
        
        if (i != (state.count - 1))
        {
            vertexD[n].x = (GLfloat)d.x;
            vertexD[n].y = (GLfloat)d.y;
            vertexD[n].s = (GLfloat)1;
            vertexD[n].t = (GLfloat)1;
            vertexD[n].a = (GLfloat)alpha;
            n++;
        }
    }
    
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(vertexData), &vertexD[0].x);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_TRUE, sizeof(vertexData), &vertexD[0].s);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(2, 1, GL_FLOAT, GL_TRUE, sizeof(vertexData), &vertexD[0].a);
    glEnableVertexAttribArray(2);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, n);
    
    free(vertexD);
    TGPaintHasGLError();
    
    return dataBounds;
}

+ (CGRect)renderPath:(TGPaintPath *)path renderState:(TGPaintRenderState *)renderState
{
    renderState.brushWeight = path.baseWeight;
    renderState.spacing = path.brush.spacing;
    renderState.alpha = path.brush.alpha;
    renderState.angle = path.brush.angle;
    renderState.scale = path.brush.scale;
    
    if (path.points.count == 1)
    {
        [self _paintStamp:path.points.lastObject state:renderState];
    }
    else
    {
        NSArray *points = path.points;
        [renderState prepare];
        
        for (NSUInteger i = 0; i < points.count - 1; i++)
        {
            [self _paintFromPoint:points[i] toPoint:points[i + 1] state:renderState];
        }
    }
    
    path.remainder = renderState.remainder;
    
    return [self _drawWithState:renderState];
}

@end
