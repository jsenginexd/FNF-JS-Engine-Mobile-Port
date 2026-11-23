package mobile;

/**
 * Small native math kernels for the HXCPP build.
 *
 * These methods deliberately accept primitive values only: no Haxe arrays,
 * Dynamic values, sprite objects, or allocations cross the native boundary.
 * Non-C++ targets keep an equivalent Haxe implementation.
 */
class NativeNoteMath
{
	#if cpp
	@:functionCode("return (0.45 * (songPosition - strumTime) * songSpeed * multSpeed) * (downScroll ? -1.0 : 1.0);")
	#end
	public static function noteDistance(songPosition:Float, strumTime:Float,
		songSpeed:Float, multSpeed:Float, downScroll:Bool):Float
	{
		var result:Float = 0.45 * (songPosition - strumTime) * songSpeed * multSpeed;
		return downScroll ? result : -result;
	}

	#if cpp
	@:functionCode("if (isEnd) return 1.0; double value = stepCrochet * 0.0105 * (songSpeed * multSpeed) * sustainScale * (pixelStage ? 1.0 : overlap); if (pixelStage) value *= pixelZoom * 1.20; return value;")
	#end
	public static function sustainScale(stepCrochet:Float, songSpeed:Float,
		multSpeed:Float, sustainScale:Float, pixelStage:Bool,
		overlap:Float, pixelZoom:Float, isEnd:Bool):Float
	{
		if (isEnd) return 1;
		var value:Float = stepCrochet * 0.0105 * (songSpeed * multSpeed) *
			sustainScale * (pixelStage ? 1 : overlap);
		if (pixelStage) value *= pixelZoom * 1.20;
		return value;
	}
}
