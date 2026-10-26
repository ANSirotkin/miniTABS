shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    COLOR = vec4(flash_color.rgb, texture(TEXTURE, UV).a * COLOR.a);
}