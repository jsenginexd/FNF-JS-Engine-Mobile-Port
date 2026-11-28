package mobile;

import flixel.system.FlxAssets.FlxShader;

/**
 * Screen-space directional motion blur for gameplay.
 *
 * The quality selector chooses 3, 5, or 9 texture samples. Uniform arrays are
 * updated in place to avoid creating new arrays on every gameplay frame.
 */
class MotionBlurShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec2 uDirection;
		uniform float uBlurPixels;
		uniform float uTapMode;

		vec4 motionSample(vec2 uv, float amount)
		{
			vec2 halfTexel = vec2(0.5) / openfl_TextureSize;
			vec2 sampleUV = uv + (uDirection * (uBlurPixels * amount)) / openfl_TextureSize;
			sampleUV = clamp(sampleUV, halfTexel, vec2(1.0) - halfTexel);
			return flixel_texture2D(bitmap, sampleUV);
		}

		void main()
		{
			vec2 uv = openfl_TextureCoordv;

			if (uBlurPixels < 0.05)
			{
				gl_FragColor = flixel_texture2D(bitmap, uv);
				return;
			}

			vec4 color;
			// Uniform branches let mobile GPUs skip the unused quality path.
			if (uTapMode < 0.5)
			{
				// Performance: three taps.
				color = motionSample(uv, -1.00) * 0.22;
				color += flixel_texture2D(bitmap, uv) * 0.56;
				color += motionSample(uv, 1.00) * 0.22;
			}
			else if (uTapMode < 1.5)
			{
				// Balanced: five taps.
				color = motionSample(uv, -1.00) * 0.12;
				color += motionSample(uv, -0.50) * 0.20;
				color += flixel_texture2D(bitmap, uv) * 0.36;
				color += motionSample(uv, 0.50) * 0.20;
				color += motionSample(uv, 1.00) * 0.12;
			}
			else
			{
				// Quality: original nine-tap kernel.
				color = motionSample(uv, -1.00) * 0.05;
				color += motionSample(uv, -0.75) * 0.09;
				color += motionSample(uv, -0.50) * 0.12;
				color += motionSample(uv, -0.25) * 0.16;
				color += flixel_texture2D(bitmap, uv) * 0.16;
				color += motionSample(uv, 0.25) * 0.16;
				color += motionSample(uv, 0.50) * 0.12;
				color += motionSample(uv, 0.75) * 0.09;
				color += motionSample(uv, 1.00) * 0.05;
			}

			gl_FragColor = color;
		}
	')

	private var lastTapMode:Float = -1.0;

	public function new()
	{
		super();
		uDirection.value = [0.0, 1.0];
		uBlurPixels.value = [0.0];
		uTapMode.value = [0.0];
	}

	/**
	 * Set the screen-space movement vector and blur strength (0..12).
	 * Returns true when a visible blur pass should be attached to the camera.
	 */
	public function setMotion(pixelX:Float, pixelY:Float, strength:Float, quality:String):Bool
	{
		final safeStrength:Float = Math.max(0.0, Math.min(12.0, strength));
		final mode:Float = switch (quality)
		{
			case 'Balanced': 1.0;
			case 'Quality': 2.0;
			default: 0.0;
		};
		if (mode != lastTapMode)
		{
			uTapMode.value[0] = mode;
			lastTapMode = mode;
		}

		final magnitude:Float = Math.sqrt(pixelX * pixelX + pixelY * pixelY);
		if (safeStrength <= 0.0 || magnitude < 0.05)
		{
			uDirection.value[0] = 0.0;
			uDirection.value[1] = 1.0;
			uBlurPixels.value[0] = 0.0;
			return false;
		}

		uDirection.value[0] = pixelX / magnitude;
		uDirection.value[1] = pixelY / magnitude;
		// Keep a strong but bounded streak; lower quality changes sample count,
		// not the visual radius.
		final radius:Float = Math.min(28.0, magnitude * (safeStrength / 12.0) * 2.4);
		uBlurPixels.value[0] = radius;
		return radius >= 0.05;
	}
}
