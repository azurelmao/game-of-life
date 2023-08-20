#version 330 core
layout (location = 0) in vec2 aPosition;
layout (location = 1) in vec2 aTexCoord;
out vec2 TexCoord;
uniform float ZoomLevel;
uniform mat4 Projection;
uniform mat4 View;

void main() {
    gl_Position = Projection * View * vec4(aPosition * ZoomLevel, 0.0, 1.0);
    TexCoord = aTexCoord;
}