shader_type canvas_item;

uniform float transparency : hint_range(0, 1) = 1.0;

// Cloud colors (with better defaults)
uniform vec4 color0 : source_color = vec4(0.3, 0.4, 0.6, 0.0);    // Sky (transparent)
uniform vec4 color1 : source_color = vec4(0.5, 0.6, 0.8, 0.4);    // Light cloud shadow
uniform vec4 color2 : source_color = vec4(0.8, 0.85, 0.9, 0.7);   // Cloud body
uniform vec4 color3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);    // Cloud highlights

uniform vec2 Direction = vec2(1, 1); 
uniform float Speed = 1.00;

// Smoother threshold controls
uniform float threshold1 : hint_range(0.0, 1.0) = 0.3;
uniform float threshold2 : hint_range(0.0, 1.0) = 0.5;
uniform float threshold3 : hint_range(0.0, 1.0) = 0.7;

// Smoothness controls
uniform float edge_smoothness : hint_range(0.01, 0.2) = 0.05;
uniform float color_blend : hint_range(0.0, 1.0) = 0.3;

uniform int OCTAVE = 4;  // Reduced for smoother clouds
uniform int pixel_size = 32;
uniform float dithering = 1.8;  // Less harsh

vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
    return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
}

float noise(vec2 uv) {
    vec2 uv_index = floor(uv);
    vec2 uv_fract = fract(uv);
    vec2 blur = smoothstep(0.0, 1.0, uv_fract);
    return mix( mix( dot( random(uv_index + vec2(0.0,0.0) ), uv_fract - vec2(0.0,0.0) ),
                     dot( random(uv_index + vec2(1.0,0.0) ), uv_fract - vec2(1.0,0.0) ), blur.x),
                mix( dot( random(uv_index + vec2(0.0,1.0) ), uv_fract - vec2(0.0,1.0) ),
                     dot( random(uv_index + vec2(1.0,1.0) ), uv_fract - vec2(1.0,1.0) ), blur.x), blur.y) + 0.5;
}

float fbm(vec2 input){
	float value = 0.0;
	float scale = 0.5;  // Increased base scale for smoother base
	
	input *= TIME/5000.0 + 1.0;  // Slower movement
	
	for(int i = 0; i < OCTAVE; i++){
		value += noise(input) * scale;
		input *= dithering;
		scale *= 0.5;  // Reduce each octave's influence more
	}
	
	return clamp(value, 0.0, 1.0);
}

float get_pixelated_moving_colors(vec2 uv, vec2 direction, float speed) {
	speed = speed / 1000.0;
	direction *= -1.0;
	vec2 moving_uv = uv + (direction * TIME * speed) + vec2(0.5/float(pixel_size));
	vec2 pixel_uv = round((moving_uv) * float(pixel_size)) / float(pixel_size);
	float pixelated_color = fbm(pixel_uv);
	return pixelated_color;
}

// NEW: Smooth color blending instead of hard thresholds
vec4 smooth_cloud_colors(float density) {
	// Use smoothstep for gradual transitions
	float t1 = smoothstep(threshold1 - edge_smoothness, threshold1 + edge_smoothness, density);
	float t2 = smoothstep(threshold2 - edge_smoothness, threshold2 + edge_smoothness, density);
	float t3 = smoothstep(threshold3 - edge_smoothness, threshold3 + edge_smoothness, density);
	
	// Blend between colors smoothly
	vec4 result = color0;
	result = mix(result, color1, t1);
	result = mix(result, color2, t2);
	result = mix(result, color3, t3);
	
	// Optional: Add some color variation based on density
	if (color_blend > 0.0) {
		float variation = sin(density * 10.0) * 0.1 + cos(density * 7.0) * 0.05;
		result.rgb += variation * color_blend;
		result.rgb = clamp(result.rgb, 0.0, 1.0);
	}
	
	return result;
}

// NEW: Add secondary noise layer for more organic shapes
float add_detail_noise(vec2 uv) {
	vec2 detail_uv = uv * 3.0 + TIME * 0.02;
	return noise(detail_uv) * 0.2;  // Subtle detail layer
}

void fragment(){
	float base_density = get_pixelated_moving_colors(UV, Direction, Speed);
	
	// Add detail layer for more organic look
	float detail = add_detail_noise(UV);
	float final_density = base_density + detail;
	final_density = clamp(final_density, 0.0, 1.0);
	
	// Use smooth color blending
	vec4 smoothed_color = smooth_cloud_colors(final_density);
	
	COLOR = vec4(smoothed_color.rgb, smoothed_color.a * transparency);
}