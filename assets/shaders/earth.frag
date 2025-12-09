#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// --- 标准 Uniform 协议 ---
uniform vec2 uResolution; // 屏幕尺寸
uniform vec2 uOffset;     // 交互偏移 (x: Yaw, y: Pitch)
uniform float uZoom;      // 缩放 (相机距离)
uniform float uTime;      // 时间

// --- 扩展 Uniform ---
uniform float uScale;       // 球体初始比例
// [修改] 不再接收角度，直接接收归一化的光照方向向量 (x, y, z)
uniform vec3 uLightDir;    
uniform sampler2D uTexture; // 地球纹理

out vec4 fragColor;

const float PI = 3.14159265359;

// 2D 旋转矩阵
mat2 rotate2d(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

void main() {
    // 1. 归一化坐标 (NDC)
    vec2 pixelPos = FlutterFragCoord().xy;
    vec2 uv = (pixelPos - uResolution * 0.5) / uResolution.y;

    // [关键修正] 翻转 Y 轴，匹配 Flutter 坐标系与 3D 逻辑
    uv.y = -uv.y;

    // --- 相机设置 ---
    float camDist = 5.0 / max(uZoom, 0.01);

    // 旋转逻辑 ( Pitch 无负号，符合上下手势 )
    float yaw = -uOffset.x / 200.0;
    float pitch = uOffset.y / 200.0;
    
    pitch = clamp(pitch, -1.5, 1.5);

    vec3 ro = vec3(0.0, 0.0, -camDist);
    ro.yz *= rotate2d(pitch);
    ro.xz *= rotate2d(yaw);
    
    vec3 target = vec3(0.0, 0.0, 0.0);
    
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
    vec3 up = cross(fwd, right);

    vec3 rd = normalize(fwd + uv.x * right + uv.y * up);

    // --- 场景渲染 ---
    
    // 计算球体半径
    float sphereRadius = uScale * 0.5;

    // 射线-球体相交测试
    vec3 oc = ro - target;
    float b = dot(oc, rd);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float h = b*b - c;

    // --- 1. 绘制地球本体 ---
    if (h > 0.0) {
        float t = -b - sqrt(h);
        
        // 只有当交点在相机前方时才渲染
        if (t > 0.0) {
            vec3 p = ro + t * rd;
            vec3 normal = normalize(p);
            
            // 纹理映射
            float u = 0.5 + atan(normal.z, normal.x) / (2.0 * PI);
            float v = 0.5 - asin(normal.y) / PI;
            
            vec3 texColor = texture(uTexture, vec2(u, v)).rgb;

            // [修改] 直接使用传入的光照方向
            vec3 lightDir = normalize(uLightDir);
            
            // 漫反射 (确保背面也有微弱亮度 0.02)
            float diff = max(dot(normal, lightDir), 0.02);

            // 菲涅尔边缘光 (Fresnel)
            float fresnel = pow(1.0 - max(dot(normal, -rd), 0.0), 3.0);
            
            vec3 atmosphereColor = vec3(0.4, 0.6, 1.0);
            
            vec3 col = texColor * diff;
            
            // 叠加大气层反光
            col += atmosphereColor * fresnel * 0.5;
            
            // 叠加环境光
            col += atmosphereColor * 0.1;
            
            fragColor = vec4(col, 1.0);
            return;
        }
    }
    
    // --- 2. 绘制外部光晕 (Atmosphere Halo) ---
    // (光晕代码保持不变)
    if (b > 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    float distToCenter = sqrt(sphereRadius * sphereRadius - h);
    float atmosphereWidth = 0.3 * uScale; 
    
    if (distToCenter < sphereRadius + atmosphereWidth) {
        float d = (distToCenter - sphereRadius) / atmosphereWidth;
        float glow = pow(1.0 - d, 4.0);
        vec3 haloColor = vec3(0.4, 0.6, 1.0);
        float alpha = glow * 0.8;
        fragColor = vec4(haloColor * alpha, alpha);
    } else {
        fragColor = vec4(0.0);
    }
}