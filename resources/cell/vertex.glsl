#version 330 core
layout (location = 0) in vec2 aPosition;
uniform float ZoomLevel;
uniform mat4 Projection;
uniform mat4 View;

void main() {
    gl_Position = Projection * View * vec4(aPosition * ZoomLevel, 0.0, 1.0);
}