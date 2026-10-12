#version 460 core

// Shared surface sampling includes longitude wrapping and Earth border repair.

#define SPHERE_SAMPLE_AXIS 4
#include "sphere_common.glsl"
