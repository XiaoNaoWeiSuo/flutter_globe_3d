#version 460 core

precision highp float;

#include <flutter/runtime_effect.glsl>

// --- 标准 Uniform 协议 (完全保持不变) ---
uniform vec2 uResolution; // 屏幕尺寸
uniform vec2 uOffset;     // 交互偏移 -> 重新解释为：相机旋转角度 (x: Yaw, y: Pitch)
uniform float uZoom;      // 缩放 -> 重新解释为：相机距离 (值越大距离越近)
uniform float uTime;      // 时间

out vec4 fragColor;

const float PI = 3.14159265359;

// --- 3D 辅助函数 ---

// 2D 旋转矩阵
mat2 rotate2d(float a) {
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c);
}

// 不依赖 fwidth 的网格绘制函数 (兼容性更好)
// uv: 纹理坐标, width: 线条宽度
float gridTexture(vec2 uv, float width) {
    // fract 实现重复
    vec2 grid = abs(fract(uv - 0.5) - 0.5);
    // 取 x 和 y 中较小的值作为距离线条中心的距离
    float line = min(grid.x, grid.y);
    // 使用 smoothstep 画出抗锯齿线条
    return 1.0 - smoothstep(0.0, width, line);
}

void main() {
    // 1. 归一化坐标 (NDC)
    // 将原点移到屏幕中心，并修正宽高比
    vec2 pixelPos = FlutterFragCoord().xy;
    vec2 uv = (pixelPos - uResolution * 0.5) / uResolution.y;

    // --- 2. 相机设置 (3D 核心) ---
    
    // A. 距离控制
    // uZoom = 1.0 时距离为 5.0。zoom 越大，距离越近 (除法关系)
    float camDist = 5.0 / max(uZoom, 0.1);

    // B. 旋转控制 (Orbit Camera)
    // 将屏幕像素位移 uOffset 转换为弧度
    // x 控制水平旋转 (Yaw), y 控制垂直旋转 (Pitch)
    // 系数 200.0 决定旋转灵敏度
    float yaw = -uOffset.x / 200.0;
    float pitch = uOffset.y / 200.0;
    
    // 限制 Pitch 防止翻转 (上下 90 度内)
    pitch = clamp(pitch, -1.5, 1.5);

    // 计算相机位置 (RO - Ray Origin)
    // 初始位置在 Z 轴负方向
    vec3 ro = vec3(0.0, 0.0, -camDist);
    
    // 应用旋转 (先转 Pitch 再转 Yaw)
    ro.yz *= rotate2d(pitch);
    ro.xz *= rotate2d(yaw);
    
    // 相机目标点 (Look At Center)
    vec3 target = vec3(0.0, 0.0, 0.0);
    
    // 构建相机坐标系 (Forward, Right, Up)
    vec3 fwd = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), fwd)); // 假设 Y 轴向上
    vec3 up = cross(fwd, right);
    
    // 计算射线方向 (RD - Ray Direction)
    // 类似于透视投影
    vec3 rd = normalize(fwd + uv.x * right + uv.y * up);

    // --- 3. 场景渲染 (Ray Tracing) ---
    
    // 默认背景色 (带一点时间动态，证明 Shader 在运行)
    vec3 col = vec3(0.1, 0.1, 0.12) + 0.02 * sin(uTime);

    // --- 绘制地平面网格 (XZ Plane at Y = -1.0) ---
    float planeY = -1.0;
    
    // 射线与平面相交测试
    // ro.y + t * rd.y = planeY  =>  t = (planeY - ro.y) / rd.y
    if (abs(rd.y) > 0.001) {
        float t = (planeY - ro.y) / rd.y;
        
        // t > 0 表示击中点在相机前方
        if (t > 0.0) {
            vec3 p = ro + t * rd; // 击中点坐标
            
            // 绘制两层网格：粗网格和细网格
            // 使用 p.xz 作为纹理坐标
            float g1 = gridTexture(p.xz, 0.05);       // 1x1 粗网格
            float g2 = gridTexture(p.xz * 5.0, 0.02); // 0.2x0.2 细网格
            
            // 混合网格颜色 (黄色)
            vec3 gridColor = vec3(1.0, 0.9, 0.2) * (g1 * 0.8 + g2 * 0.4);
            
            // 距离雾 (Fog)
            // 让远处的网格淡出到背景色，增加深度感
            float fog = exp(-t * 0.1);
            
            // 混合背景色和网格色
            col = mix(col, gridColor, fog);
            
            // 绘制原点指示 (红色圆点)
            if (length(p.xz) < 0.1) {
                col = mix(col, vec3(1.0, 0.2, 0.2), fog);
            }
        }
    }
    
    // --- 绘制中心参考球体 (可选) ---
    // Ray-Sphere Intersection
    float sphereRadius = 0.5;
    vec3 oc = ro - target; // sphere at 0,0,0
    float b = dot(oc, rd);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float h = b*b - c;
    
    if (h > 0.0) {
        float tSphere = -b - sqrt(h);
        if (tSphere > 0.0) {
            vec3 p = ro + tSphere * rd;
            vec3 normal = normalize(p);
            
            // 简单光照
            vec3 lightDir = normalize(vec3(1.0, 1.0, -1.0));
            float diff = max(dot(normal, lightDir), 0.2);
            vec3 sphereCol = vec3(0.0, 0.5, 1.0) * diff; // 蓝色球体
            
            // 简单的边缘光 (Fresnel)
            float fresnel = pow(1.0 - max(dot(normal, -rd), 0.0), 3.0);
            sphereCol += vec3(0.5, 0.8, 1.0) * fresnel;

            col = sphereCol;
        }
    }

    fragColor = vec4(col, 1.0);
}