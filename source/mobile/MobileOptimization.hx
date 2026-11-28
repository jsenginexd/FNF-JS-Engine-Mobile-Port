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

	static var scaledNoteAtlases:Map<String, FlxAtlasFrames> = new Map();
	static var scaledOtherAtlases:Map<String, FlxAtlasFrames> = new Map();

	/**
	 * Return a texture resolution scale for selected mobile assets.
	 * Note skins keep 85%; backgrounds and stage effects use 70%.
	 */
	public static function imageQualityForPath(path:String):Float
	{
		#if mobile
		if (path == null) return 1.0;
		final normalized:String = path.toLowerCase();
		if (normalized.indexOf("noteskins/") >= 0 && normalized.indexOf("pixelui/") < 0)
			return NOTE_TEXTURE_QUALITY;

		if (normalized.indexOf("images/stages/") >= 0 || normalized.indexOf("images/backgrounds/") >= 0 ||
			normalized.indexOf("images/effects/") >= 0 || normalized.indexOf("images/particles/") >= 0 ||
			normalized.indexOf("stageback") >= 0 || normalized.indexOf("stagefront") >= 0 ||
			normalized.indexOf("stagecurtains") >= 0 || normalized.indexOf("stage_light") >= 0)
			return BACKGROUND_TEXTURE_QUALITY;
		#end
		return 1.0;
	}

	/** Downsample once before GPU upload, preserving alpha and aspect ratio. */
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

	/** Scale Sparrow atlas coordinates to match a downsampled source bitmap. */
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

	/** Cached 85% note atlas with every frame, name, offset and duration preserved. */
	public static function scaleNoteAtlas(source:FlxAtlasFrames):FlxAtlasFrames
	{
		#if mobile
		return scaleAtlas(source, NOTE_TEXTURE_QUALITY, scaledNoteAtlases);
		#else
		return source;
		#end
	}

	/** Cached 70% atlas for stage backgrounds/effects; no frames are dropped. */
	public static function scaleBackgroundAtlas(source:FlxAtlasFrames):FlxAtlasFrames
	{
		#if mobile
		return scaleAtlas(source, BACKGROUND_TEXTURE_QUALITY, scaledOtherAtlases);
		#else
		return source;
		#end
	}

	static function scaleAtlas(source:FlxAtlasFrames, quality:Float, cache:Map<String, FlxAtlasFrames>):FlxAtlasFrames
	{
		if (source == null || source.parent == null || source.parent.bitmap == null) return source;
		final cacheKey:String = source.parent.key + "@" + quality;
		if (cache.exists(cacheKey)) return cache.get(cacheKey);

		final original:BitmapData = source.parent.bitmap;
		final reduced:BitmapData = downsampleBitmap(original, quality);
		if (reduced == original) return source;
		final graphic:FlxGraphic = FlxG.bitmap.add(reduced, false, "mobile-quality-" + cacheKey);
		graphic.persist = true;
		graphic.destroyOnNoUse = false;
		final result:FlxAtlasFrames = new FlxAtlasFrames(graphic);
		for (frame in source.frames)
		{
			final left:Int = Math.round(frame.frame.x * quality);
			final top:Int = Math.round(frame.frame.y * quality);
			final right:Int = Math.round((frame.frame.x + frame.frame.width) * quality);
			final bottom:Int = Math.round((frame.frame.y + frame.frame.height) * quality);
			final rect:FlxRect = FlxRect.get(left, top, Math.max(1, right - left), Math.max(1, bottom - top));
			final sourceSize:FlxPoint = FlxPoint.get(
				Math.max(1, Math.round(frame.sourceSize.x * quality)),
				Math.max(1, Math.round(frame.sourceSize.y * quality))
			);
			final offset:FlxPoint = FlxPoint.get(
				Math.round(frame.offset.x * quality),
				Math.round(frame.offset.y * quality)
			);
			result.addAtlasFrame(rect, sourceSize, offset, frame.name, frame.angle, frame.flipX, frame.flipY, frame.duration);
		}
		cache.set(cacheKey, result);
		return result;
	}
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
