//
//  BXMetalRenderingView.m
//  Boxer
//
//  Created by Stuart Carnie on 7/10/20.
//  
//

@import QuartzCore;
@import OpenEmuShaders;

#import "ADBGeometry.h"
#import "BXMetalRenderingView+Private.h"
#import "BXVideoFrame.h"
#import "BXMetalLayer.h"

/// Allow 2 frames in flight (double buffering) so that the
/// main thread isn't blocked waiting on GPU completion.
/// This keeps window dragging and UI responsive.
#define MAX_INFLIGHT 2

@interface BXMetalRenderingView() {
    
}

@property (nonatomic, readwrite) NSArray<OEShaderParamGroup *> *parameterGroups;

@end

@implementation BXMetalRenderingView {
    CAMetalLayer    *_videoLayer;
    OEFilterChain   *_filterChain;
    id<MTLTexture>  _texture;
    
    dispatch_semaphore_t    _inflightSemaphore;
    NSInteger               _skippedFrames;
    id<MTLDevice>           _device;
    id<MTLCommandQueue>     _commandQueue;
    MTLClearColor           _clearColor;
    
    id<MTLRenderPipelineState> _blitPipeline;
    id<MTLSamplerState>        _sampler;
    
    BOOL _inViewportAnimation;
    BOOL _managesViewport;
    NSSize _maxViewportSize;
    NSRect _viewportRect;
    NSRect _targetViewportRect;
    BXRenderingStyle _renderingStyle;
}

@synthesize currentFrame=_currentFrame;
@synthesize maxFrameSize=_maxFrameSize;

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder: coder]) {
        [self initDefaults];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    
    if (self = [super initWithFrame: frameRect device:device]) {
        [self initDefaults];
    }
    return self;
}

- (OEFilterChain *)filterChain {
    return _filterChain;
}

static NSString *const kBlitShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"struct VertexOut {\n"
"    float4 position [[position]];\n"
"    float2 texCoord;\n"
"};\n"
"vertex VertexOut blitVertex(uint vid [[vertex_id]]) {\n"
"    VertexOut out;\n"
"    out.texCoord = float2((vid << 1) & 2, vid & 2);\n"
"    out.position = float4(out.texCoord * float2(2, -2) + float2(-1, 1), 0, 1);\n"
"    return out;\n"
"}\n"
"fragment float4 blitFragment(VertexOut in [[stage_in]],\n"
"                              texture2d<float> tex [[texture(0)]],\n"
"                              sampler s [[sampler(0)]]) {\n"
"    return tex.sample(s, in.texCoord);\n"
"}\n";

- (void)initDefaults {
    _inflightSemaphore = dispatch_semaphore_create(MAX_INFLIGHT);
    // When loaded from a nib, MTKView has no device yet. Create one.
    if (!self.device) {
        self.device = MTLCreateSystemDefaultDevice();
    }
    _device = self.device;
    self.framebufferOnly = YES;
    self.presentsWithTransaction = YES;
    self.paused = NO;
    
    _commandQueue      = [_device newCommandQueue];
    _clearColor        = MTLClearColorMake(0, 0, 0, 1);
    _filterChain = [[OEFilterChain alloc] initWithDevice:_device];
    [_filterChain setDefaultFilteringLinear:NO];
    
    // some reasonable default
    [_filterChain setSourceRect:CGRectMake(0, 0, 648, 480) aspect:CGSizeMake(4, 3)];
    _renderingStyle = (BXRenderingStyle)-1; // Force the first setRenderingStyle: to actually load the shader
    self.renderingStyle = BXRenderingStyleNormal;
    
    // Build a simple fullscreen blit pipeline as fallback
    [self _buildBlitPipeline];
    
    self.wantsLayer = YES;
    
    _videoLayer = (CAMetalLayer *)self.layer;
    
    [self updateRenderState];
    
    _maxFrameSize = NSMakeSize(16384, 16384);
}

- (void)_buildBlitPipeline {
    NSError *error = nil;
    id<MTLLibrary> library = [_device newLibraryWithSource:kBlitShaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"BXMetalRenderingView: Failed to compile blit shader: %@", error);
        return;
    }
    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"blitVertex"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"blitFragment"];
    
    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragmentFunc;
    // Match the layer's pixel format — MTKView defaults to BGRA8Unorm
    desc.colorAttachments[0].pixelFormat = ((CAMetalLayer *)self.layer).pixelFormat;
    NSLog(@"BXMetalRenderingView: Building blit pipeline for pixel format %lu", (unsigned long)((CAMetalLayer *)self.layer).pixelFormat);
    
    _blitPipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!_blitPipeline) {
        NSLog(@"BXMetalRenderingView: Failed to create blit pipeline: %@", error);
        return;
    }
    
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    _sampler = [_device newSamplerStateWithDescriptor:samplerDesc];
}

- (BOOL)supportsRenderingStyle:(BXRenderingStyle)style {
    return YES;
}

- (void)setRenderingStyle:(BXRenderingStyle)renderingStyle {
    if (renderingStyle == _renderingStyle)
    {
        return;
    }
    
    [self willChangeValueForKey:@"renderingStyle"];
    
    _renderingStyle = renderingStyle;
    
    switch (renderingStyle) {
    case BXRenderingStyleNormal:
        [self _loadShaderNamed:@"Pixellate" inSubdirectory:@"Shaders/Pixellate"];
        break;
    case BXRenderingStyleSmoothed:
        [self _loadShaderNamed:@"Smooth" inSubdirectory:@"Shaders/Smooth"];
        break;
    case BXRenderingStyleCRT:
        [self _loadShaderNamed:@"CRT Geom" inSubdirectory:@"Shaders/CRT Geom"];
        break;
    case BXRenderingStyleCRTDeluxe:
        [self _loadShaderNamed:@"CRT Geom Deluxe" inSubdirectory:@"Shaders/CRT Geom Deluxe"];
        break;
    case BXRenderingStyleCRTRoyale:
        [self _loadShaderNamed:@"CRT Royale Kurozumi" inSubdirectory:@"Shaders/CRT Royale Kurozumi"];
        break;
    case BXRenderingStyleNTSC:
        [self _loadShaderNamed:@"NTSC" inSubdirectory:@"Shaders/NTSC"];
        break;
    case BXRenderingStyleNTSCVCR:
        [self _loadShaderNamed:@"NTSC VCR" inSubdirectory:@"Shaders/NTSC VCR"];
        break;
    case BXRenderingStyleVHS:
        [self _loadShaderNamed:@"VHS" inSubdirectory:@"Shaders/VHS"];
        break;
    case BXRenderingStyleMAMEHLSL:
        [self _loadShaderNamed:@"MAME HLSL" inSubdirectory:@"Shaders/MAME HLSL"];
        break;
    case BXRenderingStyleLCDPSP:
        [self _loadShaderNamed:@"LCD PSP" inSubdirectory:@"Shaders/LCD PSP"];
        break;
    case BXRenderingStyleSABR:
        [self _loadShaderNamed:@"SABR" inSubdirectory:@"Shaders/SABR"];
        break;
    case BXRenderingStyleXBRZ:
        [self _loadShaderNamed:@"xBRZ Freescale" inSubdirectory:@"Shaders/xBRZ Freescale"];
        break;
    case BXRenderingStyleXBRZMultipass:
        [self _loadShaderNamed:@"xBRZ Multipass Freescale" inSubdirectory:@"Shaders/xBRZ Multipass Freescale"];
        break;
    case BXRenderingStyleNearestNeighbor:
        [self _loadShaderNamed:@"Nearest Neighbor" inSubdirectory:@"Shaders/Nearest Neighbor"];
        break;
    case BXRenderingStyleLinear:
        [self _loadShaderNamed:@"Linear" inSubdirectory:@"Shaders/Linear"];
        break;
    case BXRenderingStyleBlinky:
        [self _loadShaderNamed:@"Blinky" inSubdirectory:@"Shaders/Blinky"];
        break;
    case BXRenderingStyleDither:
        [self _loadShaderNamed:@"Dither" inSubdirectory:@"Shaders/Dither"];
        break;
    case BXRenderingStyleHalftone:
        [self _loadShaderNamed:@"Halftone" inSubdirectory:@"Shaders/Halftone"];
        break;
    case BXRenderingStyleMotionBlur:
        [self _loadShaderNamed:@"Motion Blur" inSubdirectory:@"Shaders/Motion Blur"];
        break;
    default:
        [self _loadShaderNamed:@"Pixellate" inSubdirectory:@"Shaders/Pixellate"];
        break;
    }
    
    [self didChangeValueForKey:@"renderingStyle"];
    
    self.parameterGroups = _filterChain.shader.parameterGroups;
}

- (void)_loadShaderNamed:(NSString *)name inSubdirectory:(NSString *)subdirectory {
    NSURL *path = [NSBundle.mainBundle URLForResource:name withExtension:@"slangp" subdirectory:subdirectory];
    if (!path) {
        NSLog(@"BXMetalRenderingView: Shader not found: %@/%@.slangp", subdirectory, name);
        return;
    }
    NSError *error = nil;
    if (![_filterChain setShaderFromURL:path error:&error]) {
        NSLog(@"BXMetalRenderingView: Failed to load shader %@: %@", name, error);
    }
}

- (void)updateWithFrame:(BXVideoFrame *)frame {
    if (frame == nil) {
        _currentFrame = nil;
        _texture      = nil;
        return;
    }
    
    CGRect sourceRect = CGRectMake(0, 0, frame.size.width, frame.size.height);
    [_filterChain setSourceRect:sourceRect aspect:frame.scaledSize];
    
    if (frame != _currentFrame) {
        if (NSIsEmptyRect(self.viewportRect)) {
            NSRect viewportRect = [self viewportForFrame:frame];
            [self setViewportRect:viewportRect animated:NO];
        }
        
        // new buffer
        _currentFrame = frame;
        MTLTextureDescriptor *td =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                                           width:frame.size.width
                                                          height:frame.size.height
                                                       mipmapped:NO];
        _texture = [_device newTextureWithDescriptor:td];
        [_filterChain setSourceTexture:_texture];
    }
    
    [_texture replaceRegion:MTLRegionMake2D(0, 0, sourceRect.size.width, sourceRect.size.height)
                mipmapLevel:0
                  withBytes:frame.bytes
                bytesPerRow:frame.pitch];
    
    // If the frame changes size or aspect ratio, and we're responsible for the viewport ourselves,
    // then smoothly animate the transition to the new size.
    if (self.managesViewport)
    {
        [self setViewportRect:[self viewportForFrame:frame] animated:YES];
    }
    
    // When the emulator runs on the main thread, MTKView's internal display
    // link can't fire because the run loop is owned by the DOSBox loop.
    // Trigger an immediate draw so the frame is presented.
    [self draw];
}

- (void)drawRect:(NSRect)dirtyRect {
    if (_texture == nil) {
        return;
    }
    
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    
    @autoreleasepool {
        id<CAMetalDrawable> drawable = metalLayer.nextDrawable;
        if (drawable == nil) {
            return;
        }
        
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        
        MTLRenderPassDescriptor *rpd = [MTLRenderPassDescriptor new];
        rpd.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
        rpd.colorAttachments[0].loadAction = MTLLoadActionClear;
        rpd.colorAttachments[0].texture    = drawable.texture;
        
        if (_filterChain.shader) {
            // Use OEFilterChain for shader-based rendering (CRT, smoothing, etc.)
            [_filterChain renderWithCommandBuffer:commandBuffer renderPassDescriptor:rpd];
        } else if (_blitPipeline) {
            // Fallback to simple blit when no shader is loaded
            id<MTLRenderCommandEncoder> rce = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
            [rce setRenderPipelineState:_blitPipeline];
            [rce setFragmentTexture:_texture atIndex:0];
            [rce setFragmentSamplerState:_sampler atIndex:0];
            [rce drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
            [rce endEncoding];
        } else {
            return;
        }
        
        // With presentsWithTransaction=YES, we commit first, wait for the
        // command buffer to be scheduled on the GPU (very fast — microseconds),
        // then present the drawable in sync with the Core Animation transaction.
        // This keeps the layer content synchronized with the window position
        // during drags and resizes.
        [commandBuffer commit];
        [commandBuffer waitUntilScheduled];
        [drawable present];
    }
}

#pragma mark - Viewport / Bounds

- (void)updateRenderState {
    [_videoLayer setBounds:self.bounds];
    NSRect rect = [self convertRectToBacking:self.bounds];
    _videoLayer.drawableSize = NSSizeToCGSize(rect.size);
    [_filterChain setDrawableSize:_videoLayer.drawableSize];
    if (self.currentFrame) {
        [self setViewportRect:[self viewportForFrame:self.currentFrame] animated:NO];
    }
}

- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    if (!self.inLiveResize) {
        [self updateRenderState];
    }
}

- (void) viewDidEndLiveResize
{
    [self updateRenderState];
}

- (void) windowDidChangeBackingProperties: (NSNotification *)notification
{
    //[self _applyViewportToRenderer];
}

#pragma mark - Animation

+ (id) defaultAnimationForKey: (NSString *)key
{
    if ([key isEqualToString: @"viewportRect"])
    {
        CABasicAnimation *animation = [CABasicAnimation animation];
        animation.duration = 0.2;
        animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionEaseIn];
        return animation;
    }
    else
    {
        return [super defaultAnimationForKey:key];
    }
}

- (void)animationDidStart:(CAAnimation *)anim
{
    _inViewportAnimation = YES;
}

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    _inViewportAnimation = NO;
    anim.delegate = nil;
}

//Returns the rectangular region of the view into which the specified frame should be drawn.
- (NSRect)viewportForFrame:(BXVideoFrame *)frame
{
    if (frame != nil && self.managesViewport)
    {
        NSSize frameSize = frame.scaledSize;
        NSRect frameRect = NSMakeRect(0.0f, 0.0f, frameSize.width, frameSize.height);
        
        NSRect canvasRect = self.bounds;
        NSRect maxViewportRect = canvasRect;
        
        //If we have a maximum viewport size, fit the frame within that; otherwise, just fill the canvas as best we can.
        if (!NSEqualSizes(self.maxViewportSize, NSZeroSize) && sizeFitsWithinSize(self.maxViewportSize, canvasRect.size))
        {
            maxViewportRect = resizeRectFromPoint(canvasRect, self.maxViewportSize, NSMakePoint(0.5f, 0.5f));
        }
        
        NSRect fittedViewportRect = fitInRect(frameRect, maxViewportRect, NSMakePoint(0.5f, 0.5f));
        
        return fittedViewportRect;
    }
    else
    {
        return self.bounds;
    }
}

- (void) setManagesViewport:(BOOL)enabled
{
    if (_managesViewport != enabled)
    {
        _managesViewport = enabled;
        
        // Update our viewport immediately to compensate for the change
        [self setViewportRect:[self viewportForFrame:self.currentFrame]
                     animated:NO];
    }
}

- (void)setViewportRect:(NSRect)newRect
{
    if (!NSEqualRects(newRect, _viewportRect))
    {
        _viewportRect = newRect;
        [self setNeedsDisplay:YES];
    }
}

- (void)setViewportRect:(NSRect)newRect animated:(BOOL)animated
{
    if (!NSEqualRects(_targetViewportRect, newRect))
    {
        //If our viewport is zero (i.e. we haven't received a frame until now)
        //then just replace the viewport with the new one instead of animating to it.
        if (!animated || NSIsEmptyRect(_viewportRect))
        {
            _targetViewportRect = newRect;
            self.viewportRect = newRect;
        }
        else
        {
            _targetViewportRect = newRect;
            
            [NSAnimationContext beginGrouping]; {
                NSAnimationContext.currentContext.duration = 0.2;
                [self.animator setViewportRect:_targetViewportRect];
                [NSAnimationContext endGrouping];
            }
        }
    }
}


@end
