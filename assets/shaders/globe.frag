#include <flutter/runtime_effect.glsl>

precision highp float;

// [0, 1] 组件的逻辑尺寸 (width, height)
uniform vec2 uLogicalSize;

// [2] 设备像素比  
uniform float uPixelRatio;

// [3] 时间
uniform float iTime;

// [4-12] 旋转矩阵 (3x3)
uniform vec3 uRotCol0; 
uniform vec3 uRotCol1;
uniform vec3 uRotCol2;

// [13] 缩放
uniform float iZoom;

uniform sampler2D iChannel0;

#define PI 3.14159265359
#define R_EARTH 0.5
#define BASE_CAMERA_DIST 1.4

out vec4 fragColor;

vec3 getRayDirection(vec2 uv, float currentDist) {
    vec2 p = uv * 2.0 - 1.0;
    
    float aspect = uLogicalSize.x / uLogicalSize.y;
    if (aspect > 1.0) {
        p.x *= aspect;
    } else {
        p.y /= aspect;
    }
    
    return normalize(vec3(p.x, -p.y, -currentDist));
}

float intersectSphere(vec3 ro, vec3 rd, float r) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - r * r;
    float h = b * b - c;
    if (h < 0.0) return -1.0;
    return -b - sqrt(h);
}

void main() {
    // 🔧 完全重写坐标计算逻辑
    // 直接使用 FlutterFragCoord 但强制标准化处理
    vec2 rawCoord = FlutterFragCoord().xy;
    
    // 🔧 关键修复：使用 fract 确保坐标被"包裹"回正确范围
    // 这解决了全局坐标导致的问题
    vec2 normalizedCoord = fract(rawCoord / uLogicalSize);
    
    // 如果 fract 导致反向，修正它
    vec2 uv = normalizedCoord;
    
    // 🔧 另一个方法：直接重新映射
    // 确保 UV 始终在 [0, 1] 范围内
    uv = clamp(rawCoord / uLogicalSize, 0.0, 1.0);

    float currentCameraDist = BASE_CAMERA_DIST / max(0.1, iZoom);
    vec3 ro = vec3(0.0, 0.0, currentCameraDist);
    vec3 rd = getRayDirection(uv, currentCameraDist);

    float t = intersectSphere(ro, rd, R_EARTH);

    if (t < 0.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 0.0);
        return;
    }

    vec3 p_world = ro + t * rd;

    mat3 rotMatrix = mat3(uRotCol0, uRotCol1, uRotCol2);
    vec3 p_local = transpose(rotMatrix) * p_world;

    float lat = asin(clamp(p_local.y / R_EARTH, -1.0, 1.0));
    float lon = atan(p_local.x, p_local.z); 
    
    float u = lon / (2.0 * PI) + 0.5;
    float v = lat / PI + 0.5;
    
    u = fract(u); 
    v = 1.0 - v; 

    vec4 col = texture(iChannel0, vec2(u, v));

    vec3 normal = normalize(p_world);
    vec3 lightDir = normalize(vec3(0.5, 0.5, 1.0));
    
    float diff = max(0.1, dot(normal, lightDir));
    float rim = 1.0 - max(0.0, dot(normal, vec3(0.0, 0.0, 1.0)));
    rim = pow(rim, 4.0) * 0.6;

    fragColor = vec4(col.rgb * diff + vec3(0.4, 0.6, 1.0) * rim, 1.0);
}