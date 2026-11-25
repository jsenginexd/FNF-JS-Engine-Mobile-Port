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
	 * Apply the correct filtering policy to note and receptor sprites.
	 * This does not change sprite dimensions, note count, animation frames,
	 * hitboxes, timing, or sustain geometry.
	 */
	public static inline function applyNoteSmoothing(sprite:FlxSprite, pixelArt:Bool):Void
	{
		#if mobile
		// Mobile note atlases are rendered with linear smoothing even when a
		// stage advertises pixel UI. This affects notes/receptors only, not the
		// stage art, and avoids forcing their edges onto whole display pixels.
		sprite.antialiasing = true;
		sprite.pixelPerfectRender = false;
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
