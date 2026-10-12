precision highp float;

#include <flutter/runtime_effect.glsl>

// --- 标准 Uniform ---
uniform vec2 uResolution;
uniform vec2 uOffset;
uniform float uZoom;
uniform float uTime;

// --- 扩展 Uniform ---
uniform float uScale;
uniform vec3 uLightDir;
uniform float uHasNightTexture; // 0.0 = 无, 1.0 = 有

// Shared right-handed XYZ camera basis. The sphere is centered at the origin;
// +Z points toward the screen-facing surface and the default camera looks
// toward the origin along -Z.
uniform vec3 uCameraPosition;
uniform vec3 uCameraForward;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

uniform vec4 uGlowColor;
uniform float uGlowWidth;
uniform float uGlowIntensity;
uniform float uGlowAutomatic;

// Appended float uniforms 30–35 (keep the existing camera/glow ABI).
uniform float uDevicePixelRatio;
uniform float uSamplesPerAxis;
uniform vec2 uTextureSize;
uniform vec2 uNightTextureSize;

// Built-in Earth JPEG has a damaged final column and row. Crop those texels
// when sampling, without allocating another 8K image or changing custom maps.
uniform float uTrimEarthEdges;

// --- 纹理采样器 ---
uniform sampler2D uTexture;      // Index 0: 白天
uniform sampler2D uTextureNight; // Index 1: 夜晚

out vec4 fragColor;

const float PI = 3.14159265359;

// Flutter runtime effects use clamped samplers. Blend opposite edge texels
// at the longitude seam rather than clamping each half of the interpolation.
vec3 dayTexture(vec2 uv) {
    vec2 contentSize = uTextureSize - vec2(uTrimEarthEdges > 0.5 ? 1.0 : 0.0);
    vec2 contentExtent = contentSize / uTextureSize;
    float halfTexel = 0.5 / contentSize.x;
    float u = fract(uv.x);
    // Clamp to the valid last row even when using the longitude seam branch.
    float v = min(uv.y, 1.0 - 0.5 / contentSize.y);
    if (u < halfTexel || u > 1.0 - halfTexel) {
        float weight = (u < halfTexel ? u : u - 1.0) * contentSize.x + 0.5;
        return mix(texture(uTexture, vec2(1.0 - halfTexel, v) * contentExtent).rgb,
                   texture(uTexture, vec2(halfTexel, v) * contentExtent).rgb, weight);
    }
    // The south pole must clamp to the last valid texel center, rather than
    // interpolating with the damaged row just beyond the cropped region.
    return texture(uTexture, vec2(u, v) * contentExtent).rgb;
}

vec3 nightTexture(vec2 uv) {
    float halfTexel = 0.5 / uNightTextureSize.x;
    float u = fract(uv.x);
    if (u < halfTexel || u > 1.0 - halfTexel) {
        float weight = (u < halfTexel ? u : u - 1.0) * uNightTextureSize.x + 0.5;
        return mix(texture(uTextureNight, vec2(1.0 - halfTexel, uv.y)).rgb,
                   texture(uTextureNight, vec2(halfTexel, uv.y)).rgb, weight);
    }
    return texture(uTextureNight, vec2(u, uv.y)).rgb;
}

vec3 surfaceColor(vec3 normal, vec3 rd) {
    vec2 uv = vec2(0.5 + atan(normal.x, normal.z) / (2.0 * PI),
                   0.5 - asin(clamp(normal.y, -1.0, 1.0)) / PI);
    vec3 day = dayTexture(uv);
    float sunlight = dot(normal, uLightDir);
    float blend = smoothstep(-0.4, 0.4, sunlight);
    float sunIntensity = smoothstep(-0.1, 0.5, sunlight);
    vec3 night = day * 0.05;
    if (uHasNightTexture > 0.5 && sunlight < 0.45) {
        float visibility = 1.0 - smoothstep(-0.4, 0.2, sunlight);
        night += nightTexture(uv) * (1.5 * visibility);
    }
    vec3 color = mix(night, day * (sunIntensity + 0.05), blend);
    if (uGlowIntensity <= 0.0 || uGlowColor.a <= 0.0) return color;
    float rim = 1.0 - max(dot(normal, -rd), 0.0);
    float rimLighting = uGlowAutomatic > 0.5 ? mix(0.2, 1.0, blend) : 1.0;
    color += uGlowColor.rgb * uGlowColor.a * rim * rim * rim
        * uGlowIntensity * 0.625 * rimLighting;
    return color;
}

// Returns premultiplied RGBA. The ray's closest distance to the sphere is a
// signed distance; its analytic screen gradient supplies coverage without
// dFdx/fwidth, which are not portable across Flutter runtime-effect backends.
vec4 renderSample(vec2 pixel, float subpixelWidth) {
    vec2 uv = (pixel - uResolution * 0.5) / uResolution.y;
    uv.y = -uv.y;
    vec3 ro = uCameraPosition;
    vec3 right = uCameraRight;
    vec3 up = uCameraUp;
    vec3 ray = uCameraForward + uv.x * right + uv.y * up;
    float rayLength = length(ray);
    vec3 rd = ray / rayLength;
    float radius = uScale * 0.5;
    float b = dot(ro, rd);
    if (b >= 0.0) return vec4(0.0);
    float closest = length(ro - b * rd);
    float distance = radius - closest;
    float maxFootprint = length(ro) * subpixelWidth / (rayLength * uResolution.y);
    float coverage = 0.0;
    if (distance >= maxFootprint) {
        coverage = 1.0;
    } else if (distance > -maxFootprint) {
        vec3 dx = (right - rd * dot(rd, right)) / rayLength;
        vec3 dy = (up - rd * dot(rd, up)) / rayLength;
        vec2 gradient = b * vec2(dot(ro, dx), dot(ro, dy)) / max(closest, 0.000001);
        float footprint = max(length(gradient) * subpixelWidth / uResolution.y, 0.000001);
        coverage = smoothstep(-0.5 * footprint, 0.5 * footprint, distance);
    }

    vec4 atmosphere = vec4(0.0);
    float glowWidth = uGlowWidth * radius;
    if (coverage < 1.0 && glowWidth > 0.0 && uGlowIntensity > 0.0 && uGlowColor.a > 0.0) {
        float d = clamp((closest - radius) / glowWidth, 0.0, 1.0);
        float glow = 1.0 - d;
        float light = 1.0;
        if (uGlowAutomatic > 0.5) {
            vec3 limb = normalize(ro - b * rd);
            light = mix(0.2, 1.0, smoothstep(-0.4, 0.4, dot(limb, uLightDir)));
        }
        float alpha = glow * glow * glow * uGlowIntensity * uGlowColor.a * light;
        atmosphere = vec4(uGlowColor.rgb * alpha, alpha);
    }
    if (coverage <= 0.0) return atmosphere;
    float h = radius * radius - closest * closest;
    float t = -b - sqrt(max(h, 0.0));
    if (t <= 0.0) return atmosphere;
    // For partial coverage just outside the sphere, shade the tangent point.
    vec3 normal = normalize(ro + t * rd);
    vec3 color = surfaceColor(normal, rd);
    return vec4(color * coverage, coverage) + atmosphere * (1.0 - coverage);
}

void main() {
    vec2 pixel = FlutterFragCoord().xy;
    const float axis = float(SPHERE_SAMPLE_AXIS);
    float physicalPixel = 1.0 / max(uDevicePixelRatio, 1.0);
    // Uniform camera basis is normalized on the CPU. Reject the whole pixel
    // before supersampling when its rays cannot reach the sphere or glow.
    vec2 centerUV = (pixel - uResolution * 0.5) / uResolution.y;
    centerUV.y = -centerUV.y;
    vec3 centerRay = uCameraForward + centerUV.x * uCameraRight + centerUV.y * uCameraUp;
    vec3 centerDir = normalize(centerRay);
    float centerB = dot(uCameraPosition, centerDir);
    float radius = uScale * 0.5;
    float glowExtent = uGlowIntensity > 0.0 && uGlowColor.a > 0.0 ? uGlowWidth * radius : 0.0;
    float margin = length(uCameraPosition) * physicalPixel / uResolution.y;
    if (centerB >= margin || length(uCameraPosition - centerB * centerDir) > radius + glowExtent + margin) {
        fragColor = vec4(0.0);
        return;
    }
#if SPHERE_SAMPLE_AXIS == 1
    // Single sample already has analytic silhouette coverage. No loop,
    // accumulator, unpremultiplication or gamma conversion round-trip.
    vec4 color = renderSample(pixel, physicalPixel);
    fragColor = vec4(min(color.rgb, vec3(color.a)), color.a);
#else
    vec4 sum = vec4(0.0);
    for (int y = 0; y < SPHERE_SAMPLE_AXIS; y++) {
        for (int x = 0; x < SPHERE_SAMPLE_AXIS; x++) {
            vec2 offset = (vec2(float(x), float(y)) + 0.5) / axis - 0.5;
            vec4 color = renderSample(pixel + offset * physicalPixel, physicalPixel / axis);
            vec3 straight = color.rgb / max(color.a, 0.000001);
            sum += vec4(pow(clamp(straight, vec3(0.0), vec3(1.0)), vec3(2.2)) * color.a, color.a);
        }
    }
    vec4 average = sum / (axis * axis);
    vec3 straight = average.rgb / max(average.a, 0.000001);
    fragColor = vec4(pow(max(straight, vec3(0.0)), vec3(1.0 / 2.2)) * average.a, average.a);
#endif
}
