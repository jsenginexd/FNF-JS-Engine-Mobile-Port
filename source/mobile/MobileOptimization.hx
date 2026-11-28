package mobile;

import flixel.FlxSprite;

/**
 * Centralized mobile visual/performance policies.
 *
 * Keep pixel-art assets crisp. For non-pixel note atlases, enable texture
 * smoothing on mobile so scaled arrows and sustain edges do not look jagged.
 * Desktop continues to respect the user's global antialiasing preference.
 */
class MobileOptimization
{
	/**
	 * On Android, do not upscale the tiny 60x40 pixelUI arrow atlas.
	 * The shared note atlas contains the full-resolution art and is filtered
	 * smoothly; pixel styling remains available on desktop pixel stages.
	 */
	public static inline function usePixelNoteSkin(pixelStage:Bool):Bool
	{
		#if mobile
		return false;
		#else
		return pixelStage;
		#end
	}
	/**
	 * Apply the correct filtering policy to note and receptor sprites.
	 * This does not change sprite dimensions, note count, animation frames,
	 * hitboxes, timing, or sustain geometry.
	 */
	public static inline function applyNoteSmoothing(sprite:FlxSprite, pixelArt:Bool):Void
	{
		#if mobile
		// Keep the two visual modes separate: pixel skins stay crisp and snapped;
		// regular atlases are smoothly sampled and may move at sub-pixel positions.
		sprite.antialiasing = !pixelArt;
		sprite.pixelPerfectRender = pixelArt;
		sprite.pixelPerfectPosition = pixelArt;
		#else
		sprite.antialiasing = ClientPrefs.globalAntialiasing && !pixelArt;
		#end
	}

	/** Small overlap hides seams between independently rendered sustain pieces. */
	public static inline var SUSTAIN_TEXTURE_OVERLAP:Float = 1.025;

	/**
	 * Use compact mobile note iteration only when script hooks cannot observe
	 * skipped group updates. Lua/modchart paths must keep the compatibility path.
	 */
	public static inline function canUseCompactNoteUpdates(hasLua:Bool, hasModchart:Bool):Bool
	{
		#if mobile
		return !hasLua && !hasModchart;
		#else
		return false;
		#end
	}
}
