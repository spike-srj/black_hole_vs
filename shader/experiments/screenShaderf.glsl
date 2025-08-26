#version 330 core
out vec4 FragColor;

in vec2 outUV;
in vec3 outFragPos;

uniform sampler2D  ourTexture;
//锐化卷积核
float kernelSharp[9] = float[](
	-1.0, -1.0, -1.0,
	-1.0,  9.0, -1.0,
	-1.0, -1.0, -1.0
);
//模糊卷积核
float kernelBlur[9] = float[](
	1.0 / 16, 2.0 / 16, 1.0 / 16,
	2.0 / 16, 4.0 / 16, 2.0 / 16,
	1.0 / 16, 2.0 / 16, 1.0 / 16
);

void main()
{

	const float yOffset = 1.0 / 600.0;
	const float xOffset = 1.0 / 800.0;
	vec2 offset[9] = vec2[](
		vec2(-xOffset, yOffset),  // top-left
		vec2(0.0f, yOffset),  // top-center
		vec2(xOffset, yOffset),  // top-right
		vec2(-xOffset, 0.0f),  // center-left
		vec2(0.0f, 0.0f),  // center-center
		vec2(xOffset, 0.0f),  // center-right
		vec2(-xOffset, -yOffset),  // bottom-left
		vec2(0.0f, -yOffset),  // bottom-center
		vec2(xOffset, -yOffset)   // bottom-right	
	);

	vec3 sampleTex[9];
	for(int i = 0; i < 9; i++)
	{
		sampleTex[i] = vec3(texture(ourTexture, outUV + offset[i]));
	}
	vec3 col = vec3(0.0);
	for(int i = 0; i < 9; i++)
	{
		col += sampleTex[i] * kernelSharp[i];
	}

    FragColor = vec4(col, 1.0);
};