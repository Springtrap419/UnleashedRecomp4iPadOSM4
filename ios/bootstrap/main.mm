#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

static const char *kBootstrapShader = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct VSOut {
    float4 position [[position]];
    float2 uv;
};

struct Uniforms {
    float4 data0; // time, width, height, reserved
    float4 data1; // yaw, pitch, reserved, reserved
};

vertex VSOut vmain(uint vid [[vertex_id]]) {
    const float2 positions[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    VSOut out;
    float2 p = positions[vid];
    out.position = float4(p, 0.0, 1.0);
    out.uv = p * 0.5 + 0.5;
    return out;
}

float3 rotX(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

float3 rotY(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float sdSphere(float3 p, float r) {
    return length(p) - r;
}

float sdEllipsoid(float3 p, float3 r) {
    float k0 = length(p / r);
    float k1 = length(p / (r * r));
    return k0 * (k0 - 1.0) / max(k1, 1e-4);
}

float sdCapsule(float3 p, float3 a, float3 b, float r) {
    float3 pa = p - a;
    float3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float2 closer(float2 a, float2 b) {
    return (a.x < b.x) ? a : b;
}

float2 mapScene(float3 worldP, constant Uniforms &u) {
    const float time = u.data0.x;
    const float yaw = u.data1.x + time * 0.34;
    const float pitch = u.data1.y + sin(time * 0.73) * 0.035;

    float3 p = rotX(rotY(worldP, -yaw), -pitch);
    float2 hit = float2(1000.0, 0.0);

    // Body + head: legally-distinct, procedurally generated, deeply cursed hedgehog.
    hit = closer(hit, float2(sdEllipsoid(p - float3(0.0, -0.20, 0.0), float3(0.68, 0.92, 0.58)), 1.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3(0.0,  0.67, 0.0), float3(0.80, 0.74, 0.70)), 1.0));

    // Belly + muzzle.
    hit = closer(hit, float2(sdEllipsoid(p - float3(0.0, -0.18, 0.56), float3(0.37, 0.52, 0.10)), 2.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3(0.0,  0.50, 0.63), float3(0.48, 0.29, 0.23)), 2.0));

    // Eyes and pupils.
    hit = closer(hit, float2(sdEllipsoid(p - float3(-0.22, 0.84, 0.64), float3(0.19, 0.31, 0.10)), 3.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3( 0.22, 0.84, 0.64), float3(0.19, 0.31, 0.10)), 3.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3(-0.22, 0.83, 0.745), float3(0.065, 0.145, 0.045)), 4.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3( 0.22, 0.83, 0.745), float3(0.065, 0.145, 0.045)), 4.0));
    hit = closer(hit, float2(sdSphere(p - float3(0.0, 0.51, 0.86), 0.105), 4.0));

    // Arms, gloves, legs.
    hit = closer(hit, float2(sdCapsule(p, float3(-0.52, 0.18, 0.0), float3(-0.95, -0.18, 0.12), 0.13), 1.0));
    hit = closer(hit, float2(sdCapsule(p, float3( 0.52, 0.18, 0.0), float3( 0.95, -0.18, 0.12), 0.13), 1.0));
    hit = closer(hit, float2(sdSphere(p - float3(-1.02, -0.24, 0.14), 0.22), 3.0));
    hit = closer(hit, float2(sdSphere(p - float3( 1.02, -0.24, 0.14), 0.22), 3.0));
    hit = closer(hit, float2(sdCapsule(p, float3(-0.28, -0.78, 0.0), float3(-0.32, -1.13, 0.02), 0.16), 1.0));
    hit = closer(hit, float2(sdCapsule(p, float3( 0.28, -0.78, 0.0), float3( 0.32, -1.13, 0.02), 0.16), 1.0));

    // Shoes + ridiculous white straps.
    hit = closer(hit, float2(sdEllipsoid(p - float3(-0.35, -1.27, 0.20), float3(0.38, 0.20, 0.55)), 5.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3( 0.35, -1.27, 0.20), float3(0.38, 0.20, 0.55)), 5.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3(-0.35, -1.20, 0.32), float3(0.39, 0.055, 0.30)), 3.0));
    hit = closer(hit, float2(sdEllipsoid(p - float3( 0.35, -1.20, 0.32), float3(0.39, 0.055, 0.30)), 3.0));

    // Rear quills. They look increasingly questionable as he rotates.
    float3 q0 = rotX(p - float3(0.0, 1.02, -0.60), 0.40);
    float3 q1 = rotX(p - float3(0.0, 0.62, -0.72), 0.05);
    float3 q2 = rotX(p - float3(0.0, 0.18, -0.66), -0.38);
    float3 q3 = rotY(p - float3(-0.42, 0.72, -0.48), 0.30);
    float3 q4 = rotY(p - float3( 0.42, 0.72, -0.48), -0.30);
    hit = closer(hit, float2(sdEllipsoid(q0, float3(0.25, 0.24, 0.90)), 1.0));
    hit = closer(hit, float2(sdEllipsoid(q1, float3(0.27, 0.25, 1.00)), 1.0));
    hit = closer(hit, float2(sdEllipsoid(q2, float3(0.25, 0.24, 0.88)), 1.0));
    hit = closer(hit, float2(sdEllipsoid(q3, float3(0.25, 0.24, 0.78)), 1.0));
    hit = closer(hit, float2(sdEllipsoid(q4, float3(0.25, 0.24, 0.78)), 1.0));

    // Ground plane.
    hit = closer(hit, float2(worldP.y + 1.52, 8.0));
    return hit;
}

float3 normalAt(float3 p, constant Uniforms &u) {
    const float e = 0.0025;
    float d = mapScene(p, u).x;
    return normalize(float3(
        mapScene(p + float3(e, 0.0, 0.0), u).x - d,
        mapScene(p + float3(0.0, e, 0.0), u).x - d,
        mapScene(p + float3(0.0, 0.0, e), u).x - d
    ));
}

float3 materialColor(float mat, float3 p) {
    if (mat < 1.5) return float3(0.015, 0.22, 0.95); // blue
    if (mat < 2.5) return float3(0.93, 0.62, 0.36);  // muzzle/belly
    if (mat < 3.5) return float3(0.97, 0.98, 1.00);  // gloves/eyes/straps
    if (mat < 4.5) return float3(0.015, 0.018, 0.025); // pupils/nose
    if (mat < 5.5) return float3(0.92, 0.035, 0.045); // shoes

    float checker = fmod(floor(p.x * 2.2) + floor(p.z * 2.2), 2.0);
    return mix(float3(0.055, 0.065, 0.085), float3(0.09, 0.11, 0.14), checker);
}

fragment float4 fmain(VSOut in [[stage_in]], constant Uniforms &u [[buffer(0)]]) {
    float2 resolution = max(u.data0.yz, float2(1.0));
    float2 q = in.uv * 2.0 - 1.0;
    q.y = -q.y;
    q.x *= resolution.x / resolution.y;

    float3 ro = float3(0.0, 0.02, 5.15);
    float3 rd = normalize(float3(q.x, q.y, -2.25));

    float t = 0.0;
    float mat = 0.0;
    bool found = false;

    for (uint i = 0; i < 72; ++i) {
        float3 p = ro + rd * t;
        float2 h = mapScene(p, u);
        if (h.x < 0.0018) {
            mat = h.y;
            found = true;
            break;
        }
        t += max(h.x * 0.78, 0.0025);
        if (t > 12.0) break;
    }

    float horizon = clamp(in.uv.y, 0.0, 1.0);
    float3 bg = mix(float3(0.025, 0.035, 0.065), float3(0.10, 0.18, 0.29), horizon);
    bg += 0.025 * sin(float3(1.0, 1.7, 2.3) + u.data0.x * 0.25);

    if (!found) return float4(bg, 1.0);

    float3 p = ro + rd * t;
    float3 n = normalAt(p, u);
    float3 lightDir = normalize(float3(-0.55, 0.85, 0.70));
    float diff = max(dot(n, lightDir), 0.0);
    float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 48.0);

    float3 base = materialColor(mat, p);
    float3 color = base * (0.22 + 0.88 * diff) + rim * float3(0.12, 0.22, 0.42) + spec * 0.30;

    // Cheap fog keeps the stress-test mascot from looking too dignified.
    float fog = smoothstep(5.5, 10.0, t);
    color = mix(color, bg, fog * 0.45);
    return float4(pow(max(color, 0.0), float3(1.0 / 2.2)), 1.0);
}
)METAL";

typedef struct BootstrapUniforms {
    vector_float4 data0;
    vector_float4 data1;
} BootstrapUniforms;

@interface BootstrapRenderer : NSObject <MTKViewDelegate>
@property(nonatomic, weak) UILabel *statusLabel;
@property(nonatomic) float yaw;
@property(nonatomic) float pitch;
- (instancetype)initWithView:(MTKView *)view;
@end

@implementation BootstrapRenderer {
    id<MTLCommandQueue> _queue;
    id<MTLRenderPipelineState> _pipeline;
    CFTimeInterval _startTime;
    CFTimeInterval _fpsWindowStart;
    NSUInteger _fpsFrames;
    NSString *_pipelineError;
}

- (instancetype)initWithView:(MTKView *)view {
    self = [super init];
    if (!self) return nil;

    _queue = [view.device newCommandQueue];
    _startTime = CACurrentMediaTime();
    _fpsWindowStart = _startTime;
    _fpsFrames = 0;
    _yaw = 0.0f;
    _pitch = 0.0f;

    NSError *error = nil;
    NSString *source = [NSString stringWithUTF8String:kBootstrapShader];
    id<MTLLibrary> library = [view.device newLibraryWithSource:source options:nil error:&error];
    if (!library) {
        _pipelineError = [NSString stringWithFormat:@"Metal shader compile failed: %@", error.localizedDescription ?: @"unknown error"];
        NSLog(@"%@", _pipelineError);
        return self;
    }

    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.label = @"Budget Hedgehog Raymarch Pipeline";
    desc.vertexFunction = [library newFunctionWithName:@"vmain"];
    desc.fragmentFunction = [library newFunctionWithName:@"fmain"];
    desc.colorAttachments[0].pixelFormat = view.colorPixelFormat;

    _pipeline = [view.device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!_pipeline) {
        _pipelineError = [NSString stringWithFormat:@"Metal pipeline creation failed: %@", error.localizedDescription ?: @"unknown error"];
        NSLog(@"%@", _pipelineError);
    }

    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    NSLog(@"Bootstrap drawable: %.0fx%.0f", size.width, size.height);
}

- (void)drawInMTKView:(MTKView *)view {
    @autoreleasepool {
        if (!_pipeline || !_queue) {
            if (self.statusLabel && _pipelineError) {
                self.statusLabel.text = [NSString stringWithFormat:@"UNLEASHED RECOMP iPAD BOOTSTRAP\n\n%@", _pipelineError];
            }
            return;
        }

        MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
        id<CAMetalDrawable> drawable = view.currentDrawable;
        if (!pass || !drawable) return;

        CFTimeInterval now = CACurrentMediaTime();
        BootstrapUniforms uniforms;
        uniforms.data0 = (vector_float4){
            (float)(now - _startTime),
            (float)view.drawableSize.width,
            (float)view.drawableSize.height,
            0.0f
        };
        uniforms.data1 = (vector_float4){self.yaw, self.pitch, 0.0f, 0.0f};

        id<MTLCommandBuffer> commandBuffer = [_queue commandBuffer];
        commandBuffer.label = @"Budget Hedgehog Frame";
        id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:pass];
        [encoder setRenderPipelineState:_pipeline];
        [encoder setFragmentBytes:&uniforms length:sizeof(uniforms) atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [commandBuffer presentDrawable:drawable];
        [commandBuffer commit];

        _fpsFrames++;
        CFTimeInterval elapsed = now - _fpsWindowStart;
        if (elapsed >= 0.50) {
            double fps = (double)_fpsFrames / elapsed;
            _fpsFrames = 0;
            _fpsWindowStart = now;

            NSString *gpu = view.device.name ?: @"Apple GPU";
            NSInteger target = view.preferredFramesPerSecond;
            NSString *text = [NSString stringWithFormat:
                @"UNLEASHED RECOMP — iPAD BOOTSTRAP\n"
                 "GPU: %@  |  Metal: ONLINE\n"
                 "Drawable: %.0f × %.0f  |  Target: %ld Hz  |  FPS: %.1f\n\n"
                 "HE HAS ESCAPED THE XBOX 360\n"
                 "Drag to rotate the budget hedgehog.",
                gpu,
                view.drawableSize.width,
                view.drawableSize.height,
                (long)target,
                fps];

            dispatch_async(dispatch_get_main_queue(), ^{
                self.statusLabel.text = text;
            });
        }
    }
}

@end

@interface BootstrapViewController : UIViewController
@property(nonatomic, strong) BootstrapRenderer *renderer;
@end

@implementation BootstrapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) {
        self.view.backgroundColor = UIColor.redColor;
        return;
    }

    MTKView *metalView = [[MTKView alloc] initWithFrame:self.view.bounds device:device];
    metalView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm_sRGB;
    metalView.clearColor = MTLClearColorMake(0.02, 0.025, 0.045, 1.0);
    metalView.framebufferOnly = YES;
    metalView.enableSetNeedsDisplay = NO;
    metalView.paused = NO;
    metalView.preferredFramesPerSecond = UIScreen.mainScreen.maximumFramesPerSecond;
    self.view = metalView;

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.46];
    label.layer.cornerRadius = 12.0;
    label.layer.masksToBounds = YES;
    label.font = [UIFont monospacedSystemFontOfSize:14.0 weight:UIFontWeightSemibold];
    label.text = @"UNLEASHED RECOMP — iPAD BOOTSTRAP\nWaking the budget hedgehog…";
    [metalView addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:metalView.safeAreaLayoutGuide.leadingAnchor constant:18.0],
        [label.topAnchor constraintEqualToAnchor:metalView.safeAreaLayoutGuide.topAnchor constant:18.0],
        [label.widthAnchor constraintLessThanOrEqualToConstant:620.0]
    ]];

    self.renderer = [[BootstrapRenderer alloc] initWithView:metalView];
    self.renderer.statusLabel = label;
    metalView.delegate = self.renderer;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [metalView addGestureRecognizer:pan];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:gesture.view];
    self.renderer.yaw += (float)delta.x * 0.005f;
    self.renderer.pitch = fmaxf(-0.75f, fminf(0.75f, self.renderer.pitch + (float)delta.y * 0.005f));
    [gesture setTranslation:CGPointZero inView:gesture.view];
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskLandscape;
}

@end

@interface BootstrapAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation BootstrapAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [BootstrapViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    return UIInterfaceOrientationMaskLandscape;
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(BootstrapAppDelegate.class));
    }
}
