#include <flutter/runtime_effect.glsl>

precision highp float;

// 0,1: 逻辑分辨率
uniform vec2 uLogicalRes;
// 2: 设备像素比
uniform float uPixelRatio;
// 3: 时间
uniform float iTime;

// 旋转矩阵
uniform vec3 uRotCol0; 
uniform vec3 uRotCol1;
uniform vec3 uRotCol2;

// 13: 缩放
uniform float iZoom;

// [新增] 14-17: 逆变换矩阵的 4 个列向量 (用于将全局坐标还原为局部坐标)
uniform vec4 uInvCol0;
uniform vec4 uInvCol1;
uniform vec4 uInvCol2;
uniform vec4 uInvCol3;

uniform sampler2D iChannel0;

#define PI 3.14159265359
#define R_EARTH 0.5
#define BASE_CAMERA_DIST 1.4

out vec4 fragColor;

vec3 getRayDirection(vec2 fragCoord, float currentDist) {
    vec2 p = (2.0 * fragCoord - uLogicalRes) / min(uLogicalRes.x, uLogicalRes.y);

    // Y-Up 修正
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
    float currentCameraDist = BASE_CAMERA_DIST / max(0.1, iZoom);
    vec3 ro = vec3(0.0, 0.0, currentCameraDist);
    
    // 1. 获取屏幕物理坐标 (FlutterFragCoord 保证了跨平台原点一致性)
    vec2 screenPos = FlutterFragCoord().xy;
    
    // 2. 重组逆矩阵 (Global Physical -> Local Logical)
    mat4 globalToLocal = mat4(uInvCol0, uInvCol1, uInvCol2, uInvCol3);
    
    // 3. 乘以逆矩阵，直接还原出当前像素在组件内的逻辑坐标
    // 这一步自动处理了 Offset(滚动位置)、Scale(DPR)、甚至 Rotation
    vec4 localPos = globalToLocal * vec4(screenPos, 0.0, 1.0);
    vec2 fragCoord = localPos.xy;

    vec3 rd = getRayDirection(fragCoord, currentCameraDist);

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