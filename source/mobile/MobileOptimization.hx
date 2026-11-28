package mobile;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import openfl.display.BitmapData;
import openfl.geom.Matrix;

/**
 * Centralized mobile visual/performance policies.
 *
 * Keep pixel-art assets crisp. For non-pixel note atlases, enable texture
 * smoothing on mobile so scaled arrows and sustain edges do not look jagged.
 * Desktop continues to respect the user's global antialiasing preference.
 */
class MobileOptimization
{
	/** 85% linear resolution for note textures; displayed size is compensated. */
	public static inline var NOTE_TEXTURE_QUALITY:Float = 0.85;
	/** 70% linear resolution for stage backgrounds and non-note effects. */
	public static inline var BACKGROUND_TEXTURE_QUALITY:Float = 0.70;
	public static inline var NOTE_DISPLAY_COMPENSATION:Float = 1.0 / NOTE_TEXTURE_QUALITY;

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
