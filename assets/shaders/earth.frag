#version 460 core

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

// --- 纹理采样器 ---
uniform sampler2D uTexture;      // Index 0: 白天
uniform sampler2D uTextureNight; // Index 1: 夜晚

out vec4 fragColor;

const float PI = 3.14159265359;
const vec3 ATMOSPHERE_COLOR = vec3(0.4, 0.6, 1.0);

mat2 rotate2d(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

void main() {
    vec2 pixelPos = FlutterFragCoord().xy;
    vec2 uv = (pixelPos - uResolution * 0.5) / uResolution.y;
    uv.y = -uv.y;

    float camDist = 5.0 / max(uZoom, 0.01);
    float yaw = -uOffset.x / 200.0;
    float pitch = clamp(uOffset.y / 200.0, -1.5, 1.5);

    // 旋转矩阵
    mat2 rotY = rotate2d(pitch);
    mat2 rotX = rotate2d(yaw);

    vec3 ro = vec3(0.0, 0.0, -camDist);
    ro.yz *= rotY;
    ro.xz *= rotX;
    
    vec3 target = vec3(0.0, 0.0, 0.0);
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
    vec3 up = cross(fwd, right);
    vec3 rd = normalize(fwd + uv.x * right + uv.y * up);

    float sphereRadius = uScale * 0.5;
    vec3 oc = ro - target;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float h = b*b - c;

    // --- 1. 绘制地球本体 ---
    if (h > 0.0) {
        float t = -b - sqrt(h);
        if (t > 0.0) {
            vec3 p = ro + t * rd;
            vec3 normal = normalize(p);
            
            // UV 映射
            float u = 0.5 + atan(normal.z, normal.x) / (2.0 * PI);
            float v = 0.5 - asin(normal.y) / PI;
            
            // 1. 采样白天纹理 (必须采样，作为基础)
            vec3 dayTexColor = texture(uTexture, vec2(u, v)).rgb;
            
            // 2. 光照计算
            vec3 lightDir = normalize(uLightDir);
            float NdotL = dot(normal, lightDir);
            
            // [优化] 过渡因子
            float blendFactor = smoothstep(-0.4, 0.4, NdotL);
            
            // [优化] 阳光强度
            float sunIntensity = smoothstep(-0.1, 0.5, NdotL);

            // 3. 计算暗部 (Night Side)
            vec3 nightSideColor;
            
            // [性能优化核心] 动态分支
            // 只有当 (有夜景贴图) 且 (处于黑暗或晨昏线区域 NdotL < 0.45) 时，才采样夜景纹理。
            // 这里的 0.45 略大于 smoothstep 的右边界 0.4，确保过渡区也能采到样。
            // 在向阳面 (NdotL > 0.45)，我们直接跳过昂贵的纹理采样，显存带宽减半。
            if (uHasNightTexture > 0.5 && NdotL < 0.45) {
                vec3 nightTex = texture(uTextureNight, vec2(u, v)).rgb;
                
                // 城市灯光自然淡出逻辑
                float cityLightVisibility = 1.0 - smoothstep(-0.4, 0.2, NdotL);
                
                nightTex *= 1.5 * cityLightVisibility;
                nightSideColor = nightTex + dayTexColor * 0.05;
            } else {
                // 白天区域或无夜景贴图，仅使用微弱环境光
                nightSideColor = dayTexColor * 0.05; 
            }

            // 4. 计算亮部 (Day Side)
            vec3 daySideColor = dayTexColor * (sunIntensity + 0.05);

            // 5. 最终混合
            vec3 finalColor = mix(nightSideColor, daySideColor, blendFactor);

            // 6. 菲涅尔边缘光 (大气感)
            // [性能优化] 将 pow(x, 3.0) 替换为简单的乘法
            float fresnelBase = 1.0 - max(dot(normal, -rd), 0.0);
            float fresnel = fresnelBase * fresnelBase * fresnelBase;
            
            finalColor += ATMOSPHERE_COLOR * fresnel * 0.5;
            
            fragColor = vec4(finalColor, 1.0);
            return;
        }
    }
    
    // --- 2. 绘制大气光晕 ---
    if (b > 0.0) { fragColor = vec4(0.0); return; }
    
    float distToCenter = sqrt(sphereRadius * sphereRadius - h);
    float atmosphereWidth = 0.3 * uScale; 
    
    if (distToCenter < sphereRadius + atmosphereWidth) {
        float d = (distToCenter - sphereRadius) / atmosphereWidth;
        // [性能优化] 替换 pow(x, 3.0)
        float glowBase = 1.0 - d;
        float glow = glowBase * glowBase * glowBase;
        
        fragColor = vec4(ATMOSPHERE_COLOR * glow * 0.8, glow * 0.8);
    } else {
        fragColor = vec4(0.0);
    }
}