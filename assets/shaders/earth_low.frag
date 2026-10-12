#version 460 core

// Shared surface sampling includes longitude wrapping and Earth border repair.

#define SPHERE_SAMPLE_AXIS 1
#include "sphere_common.glsl"
