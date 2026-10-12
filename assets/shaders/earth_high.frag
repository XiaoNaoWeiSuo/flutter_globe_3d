#version 460 core

// Shared surface sampling includes longitude wrapping and Earth border repair.

#define SPHERE_SAMPLE_AXIS 3
#include "sphere_common.glsl"
