package mobile;

import flixel.system.FlxAssets.FlxShader;

/**
 * Screen-space directional motion blur for gameplay.
 *
 * The blur vector is supplied in game pixels per frame by PlayState, combining
 * note travel and camera movement. This is a single-pass shader; it does not
 * allocate a history framebuffer or duplicate sprites.
 */
class MotionBlurShader extends FlxShader
{
	@:glFragmentSource('
		#pragma header

		uniform vec2 uDirection;
		uniform float uBlurPixels;

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

			// Nine weighted taps keep the streak smooth without an excessive
			// full-screen sampling cost on mobile GPUs.
			vec4 color = motionSample(uv, -1.00) * 0.05;
			color += motionSample(uv, -0.75) * 0.09;
			color += motionSample(uv, -0.50) * 0.12;
			color += motionSample(uv, -0.25) * 0.16;
			color += motionSample(uv,  0.00) * 0.16;
			color += motionSample(uv,  0.25) * 0.16;
			color += motionSample(uv,  0.50) * 0.12;
			color += motionSample(uv,  0.75) * 0.09;
			color += motionSample(uv,  1.00) * 0.05;

			gl_FragColor = color;
		}
	')

	public function new()
	{
		super();
		uDirection.value = [0.0, 1.0];
		uBlurPixels.value = [0.0];
	}

	/**
	 * Set the screen-space movement vector and blur strength (0..12).
	 * Returns true when a visible blur pass should be attached to the camera.
	 */
	public function setMotion(pixelX:Float, pixelY:Float, strength:Float):Bool
	{
		final safeStrength:Float = Math.max(0.0, Math.min(12.0, strength));
		final magnitude:Float = Math.sqrt(pixelX * pixelX + pixelY * pixelY);
		if (safeStrength <= 0.0 || magnitude < 0.05)
		{
			uDirection.value = [0.0, 1.0];
			uBlurPixels.value = [0.0];
			return false;
		}

		uDirection.value = [pixelX / magnitude, pixelY / magnitude];
		// At strength 12, blur extends about 2.4 frames of measured movement.
		// Clamp extreme camera jumps so a cutscene transition cannot smear the
		// entire screen into an unreadable image.
		final radius:Float = Math.min(28.0, magnitude * (safeStrength / 12.0) * 2.4);
		uBlurPixels.value = [radius];
		return radius >= 0.05;
	}
}
