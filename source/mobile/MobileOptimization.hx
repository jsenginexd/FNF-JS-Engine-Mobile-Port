package mobile;

import flixel.FlxG;
import flixel.FlxSprite;
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
	/** 85% source resolution for note textures; the displayed size is compensated. */
	public static inline var NOTE_TEXTURE_QUALITY:Float = 0.85;
	/** 70% source resolution for selected stage backgrounds and effects. */
	public static inline var BACKGROUND_TEXTURE_QUALITY:Float = 0.70;
	public static inline var NOTE_DISPLAY_COMPENSATION:Float = 1.0 / NOTE_TEXTURE_QUALITY;

	/** Choose a resolution tier by asset path. UI, characters and pixel art stay untouched. */
	public static function imageQualityForPath(path:String):Float
	{
		#if mobile
		if (path == null) return 1.0;
		final normalized:String = path.toLowerCase();
		if (normalized.indexOf("noteskins/") >= 0 && normalized.indexOf("pixelui/") < 0)
			return NOTE_TEXTURE_QUALITY;

		if (normalized.indexOf("images/stages/") >= 0 || normalized.indexOf("images/backgrounds/") >= 0 ||
			normalized.indexOf("images/effects/") >= 0 || normalized.indexOf("images/particles/") >= 0 ||
			normalized.indexOf("images/stageback.") >= 0 || normalized.indexOf("images/stagefront.") >= 0 ||
			normalized.indexOf("images/stagecurtains.") >= 0 || normalized.indexOf("images/stage_light.") >= 0)
			return BACKGROUND_TEXTURE_QUALITY;
		#end
		return 1.0;
	}

	/** Downsample before GPU upload, preserving alpha and the original aspect ratio. */
	public static function downsampleBitmap(bitmap:BitmapData, quality:Float):BitmapData
	{
		if (bitmap == null || quality >= 0.999 || quality <= 0.0) return bitmap;
		final width:Int = Std.int(Math.max(1, Math.round(bitmap.width * quality)));
		final height:Int = Std.int(Math.max(1, Math.round(bitmap.height * quality)));
		if (width == bitmap.width && height == bitmap.height) return bitmap;

		final reduced:BitmapData = new BitmapData(width, height, true, 0x00000000);
		final matrix:Matrix = new Matrix();
		matrix.scale(width / bitmap.width, height / bitmap.height);
		reduced.draw(bitmap, matrix, null, null, null, true);
		return reduced;
	}

	/** Scale Sparrow SubTexture coordinates to match a reduced source bitmap. */
	public static function scaleSparrowXml(xmlText:String, quality:Float):String
	{
		if (xmlText == null || quality >= 0.999 || quality <= 0.0) return xmlText;
		try
		{
			final document:Xml = Xml.parse(xmlText);
			final root:Xml = document.firstElement();
			if (root == null) return xmlText;
			final attributes:Array<String> = ["x", "y", "width", "height", "frameX", "frameY", "frameWidth", "frameHeight"];
			for (subTexture in root.elements())
			{
				for (attribute in attributes)
				{
					if (subTexture.exists(attribute))
					{
						final original:Float = Std.parseFloat(subTexture.get(attribute));
						if (!Math.isNaN(original))
							subTexture.set(attribute, Std.string(Math.round(original * quality)));
					}
				}
			}
			return document.toString();
		}
		catch (e:Dynamic)
		{
			FlxG.log.warn("Could not scale mobile Sparrow atlas metadata: " + e);
			return xmlText;
		}
	}

	/** Preserve the original on-screen arrow dimensions after reducing source pixels. */
	public static inline function noteDisplayScale(baseScale:Float):Float
	{
		#if mobile
		return baseScale * NOTE_DISPLAY_COMPENSATION;
		#else
		return baseScale;
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
