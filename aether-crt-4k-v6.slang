#version 450
// Aether CRT 4K v6: Razor scanlines + edge-aware AA + aspect controller (SDR output; not HDR10)

#pragma parameter RAZOR "Razor Scanline Definition" 0.72 0.0 1.0 0.02
#pragma parameter AA "Edge Antialiasing" 0.22 0.0 1.0 0.02
#pragma parameter SCANLINE "Scanline Darkness" 0.38 0.0 0.85 0.01
#pragma parameter BEAM "Scanline Beam Width" 1.45 0.65 3.0 0.05
#pragma parameter MASK "RGB Mask Strength" 0.10 0.0 0.35 0.01
#pragma parameter MASKTYPE "Mask Type (0 RGB, 1 Slot, 2 Off)" 0.0 0.0 2.0 1.0
#pragma parameter GLOW "Horizontal Glow" 0.10 0.0 0.40 0.01
#pragma parameter SHARPNESS "Pixel Edge Sharpness" 0.70 0.0 1.0 0.05
#pragma parameter VIBRANCE "Color Vibrance" 1.10 0.70 1.50 0.02
#pragma parameter HIGHLIGHTS "Highlight Pop" 0.20 0.0 0.60 0.02
#pragma parameter BLACKLEVEL "Black Level Lift" 0.00 0.0 0.12 0.01
#pragma parameter BLOOM "Phosphor Bloom" 0.12 0.0 0.40 0.01
#pragma parameter BLOOMRADIUS "Bloom Radius" 1.0 0.5 2.0 0.1
#pragma parameter BEAMRESPONSE "Bright Beam Expansion" 0.22 0.0 0.65 0.01
#pragma parameter MASKADAPT "Mask Highlight Protection" 0.50 0.0 1.0 0.05
#pragma parameter ASPECTMODE "Aspect Mode (0 Native, 1 4:3, 2 8:7, 3 16:9, 4 Custom, 5 Stretch)" 1.0 0.0 5.0 1.0
#pragma parameter CUSTOMASPECT "Custom Aspect Ratio (Width / Height)" 1.3333 0.75 2.40 0.01
#pragma parameter BRIGHTNESS "Brightness" 1.08 0.70 1.50 0.02

layout(std140, set = 0, binding = 0) uniform UBO {
    mat4 MVP;
    vec4 OutputSize;
    vec4 OriginalSize;
    vec4 SourceSize;
    uint FrameCount;
    float RAZOR;
    float AA;
    float SCANLINE;
    float BEAM;
    float MASK;
    float MASKTYPE;
    float GLOW;
    float SHARPNESS;
    float BRIGHTNESS;
    float VIBRANCE;
    float HIGHLIGHTS;
    float BLACKLEVEL;
    float BLOOM;
    float BLOOMRADIUS;
    float BEAMRESPONSE;
    float MASKADAPT;
    float ASPECTMODE;
    float CUSTOMASPECT;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;
void main() {
    gl_Position = global.MVP * Position;
    vTexCoord = TexCoord;
}

#pragma stage fragment
layout(set = 0, binding = 1) uniform sampler2D Source;
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

vec3 samplePixel(vec2 pixel) {
    vec2 uv = (pixel + vec2(0.5)) * global.SourceSize.zw;
    return texture(Source, uv).rgb;
}

void main() {
    vec2 sourceSize = global.SourceSize.xy;
    vec2 outputSize = global.OutputSize.xy;
    // Letterbox/pillarbox within the shader viewport; preserve source proportions.
    // This cannot change the host application's window or physical viewport.
    vec2 uv = vTexCoord;
    if (global.ASPECTMODE > 0.5 && global.ASPECTMODE < 5.5) {
        float targetAspect = sourceSize.x / max(sourceSize.y, 1.0);
        if (global.ASPECTMODE < 1.5) targetAspect = 4.0 / 3.0;
        else if (global.ASPECTMODE < 2.5) targetAspect = 8.0 / 7.0;
        else if (global.ASPECTMODE < 3.5) targetAspect = 16.0 / 9.0;
        else if (global.ASPECTMODE < 4.5) targetAspect = global.CUSTOMASPECT;
        // Mode 5 intentionally stretches to the host viewport.
        if (global.ASPECTMODE < 5.0) {
            float viewportAspect = outputSize.x / max(outputSize.y, 1.0);
            vec2 activeArea = vec2(1.0);
            if (viewportAspect > targetAspect)
                activeArea.x = targetAspect / viewportAspect;
            else
                activeArea.y = viewportAspect / targetAspect;
            uv = (vTexCoord - vec2(0.5)) / activeArea + vec2(0.5);
            if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
                FragColor = vec4(0.0, 0.0, 0.0, 1.0);
                return;
            }
        }
    }
    vec2 p = uv * sourceSize - vec2(0.5);
    vec2 base = floor(p);
    vec2 f = fract(p);

    // Controllable edge smoothing, preserving original pixel colors.
    vec2 blend = mix(smoothstep(vec2(0.0), vec2(1.0), f), f, 1.0 - global.SHARPNESS);
    vec3 a = mix(samplePixel(base), samplePixel(base + vec2(1.0, 0.0)), blend.x);
    vec3 b = mix(samplePixel(base + vec2(0.0, 1.0)), samplePixel(base + vec2(1.0, 1.0)), blend.x);
    vec3 color = mix(a, b, blend.y);

    // Contrast-aware subpixel smoothing: affects sprite edges, not scanline shape.
    // Operates only on existing source pixels; avoids full-frame blur.
    vec3 centerPixel = samplePixel(base);
    vec3 edgeRight = samplePixel(base + vec2(1.0, 0.0));
    vec3 edgeDown = samplePixel(base + vec2(0.0, 1.0));
    float contrastX = max(max(abs(centerPixel.r-edgeRight.r), abs(centerPixel.g-edgeRight.g)), abs(centerPixel.b-edgeRight.b));
    float contrastY = max(max(abs(centerPixel.r-edgeDown.r), abs(centerPixel.g-edgeDown.g)), abs(centerPixel.b-edgeDown.b));
    float edgeStrength = clamp(max(contrastX, contrastY) * 3.0, 0.0, 1.0);
    // Gentle four-neighbor average only near high-contrast pixel boundaries.
    vec3 aaSample = (centerPixel + edgeRight + edgeDown + samplePixel(base + vec2(1.0, 1.0))) * 0.25;
    float boundary = max(1.0 - abs(f.x - 0.5) * 2.0, 1.0 - abs(f.y - 0.5) * 2.0);
    color = mix(color, aaSample, global.AA * edgeStrength * boundary * 0.35);

    // Restrained horizontal halation, strongest near bright source pixels.
    vec3 left = samplePixel(base + vec2(-1.0, 0.0));
    vec3 right = samplePixel(base + vec2(1.0, 0.0));
    vec3 halo = max(color, 0.5 * (left + right));
    color = mix(color, halo, global.GLOW);

    // Soft phosphor bloom: sample neighboring source texels, without temporal persistence.
    // Restrict bloom to bright source details so dark pixels retain contrast.
    vec2 r = vec2(global.BLOOMRADIUS, 0.0);
    vec3 neighborhood = (samplePixel(base - r) + samplePixel(base + r)
                       + samplePixel(base + r.yx) + samplePixel(base - r.yx)) * 0.25;
    vec3 luminous = max(neighborhood - vec3(0.50), vec3(0.0)) * 2.0;
    color += luminous * global.BLOOM * (vec3(1.0) - min(color, vec3(1.0)));

    // Scanline beam centered on each source pixel row.
    float phase = fract(uv.y * sourceSize.y);
    float beamBase = max(sin(3.14159265 * phase), 0.0);
    // Narrower phosphor beam with crisp dark gaps at high Razor settings.
    float beamExponent = mix(global.BEAM, global.BEAM * 4.0, global.RAZOR);
    float beam = pow(beamBase, beamExponent);
    float beamLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float expandedBeam = mix(beam, sqrt(max(beam, 0.0)),
                             clamp(beamLuma * global.BEAMRESPONSE, 0.0, 1.0));
    color *= 1.0 - global.SCANLINE * (1.0 - expandedBeam);

    // Output-pixel RGB mask; optional staggered slot mask.
    if (global.MASKTYPE < 1.5) {
        vec2 frag = floor(vTexCoord * outputSize);
        float shift = global.MASKTYPE > 0.5 ? mod(floor(frag.y / 2.0), 2.0) : 0.0;
        float subpixel = mod(frag.x + shift, 3.0);
        float maskLuma = dot(color, vec3(0.2126, 0.7152, 0.0722));
        float maskStrength = global.MASK * (1.0 - global.MASKADAPT * smoothstep(0.55, 1.0, maskLuma));
        vec3 mask = vec3(1.0 - maskStrength);
        if (subpixel < 1.0) mask.r = 1.0;
        else if (subpixel < 2.0) mask.g = 1.0;
        else mask.b = 1.0;
        color *= mask;
    }

    // SDR highlight expansion: add sparkle to bright details, not HDR metadata.
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    float highlight = smoothstep(0.45, 0.95, luma);
    color += color * highlight * global.HIGHLIGHTS * (1.0 - color);

    // Gently boost muted colors while protecting already saturated colors.
    float sat = max(max(color.r, color.g), color.b) - min(min(color.r, color.g), color.b);
    float gray = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(gray), color, 1.0 + (global.VIBRANCE - 1.0) * (1.0 - sat));
    color = max(color, vec3(0.0));
    color = color * global.BRIGHTNESS + vec3(global.BLACKLEVEL);
    FragColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}