package;

import backend.NoteTypesConfig;
import play.objects.SustainSplash;
import shaders.RGBPalette.RGBShaderReference;
import shaders.RGBPalette;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

@:structInit class PreloadedChartNote {
	public var strumTime:Float = 0;
	public var noteData:Int = 0;
	public var mustPress:Bool = false;
	public var oppNote:Bool = false;
	public var noteType:String = "";
	public var animSuffix:String = "";
	public var noteskin:Null<String> = null;
	public var texture:Null<String> = null;
	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var gfNote:Bool = false;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var sustainLength:Float = 0;
	public var parentST:Float = 0;
	public var parentSL:Float = 0;
	public var hitHealth:Float = 0;
	public var missHealth:Float = 0;
	public var hitCausesMiss:Bool = false;
	public var wasHit:Bool = false;
	public var multSpeed:Float = 1;
	public var multAlpha:Float = 1;
	public var noteDensity:Float = 1;
	public var ignoreNote:Bool = false;
	public var blockHit:Bool = false;
	public var lowPriority:Bool = false;

	public function dispose() {
		// will be cleared by the GC later
		for (field in Reflect.fields(this)) {
			Reflect.setField(this, field, null);
		}
	}
}


typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, //breaks r/g/b/a but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

/**
 * The note object used as a data structure to spawn and manage notes during gameplay.
 *
 * If you want to make a custom note type, you should search for: "function set_noteType"
**/

class Note extends FlxSprite
{
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var parentST:Float = 0;
	public var parentSL:Float = 0;
	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var doOppStuff:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var inKillQueue:Bool = false; // already waiting in PlayState.killNotes
	public var countsTowardLimit:Bool = false; // included in PlayState.limitNC
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false; //For Opponent notes

	public var blockHit:Bool = false; // only works for player

	public var noteDensity:Float = 1;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var isSustainEnd:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var rgbShader:RGBShaderReference;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var inEditor:Bool = Type.getClassName(Type.getClass(FlxG.state)) == 'editors.ChartingState';

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 0.5;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public static final SUSTAIN_SIZE:Int = 44;
	public static final swagWidth:Float = 160 * 0.7;

	public static final colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteskins/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: (PlayState.SONG != null) ? (!PlayState.SONG.disableNoteRGB) : true,
		r: -1,
		g: -1,
		b: -1,
		a: 1
	};
	public var noteHoldSplash:SustainSplash;

	// Lua shit
	public var noteSplashDisabled:Bool = false;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed:Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyScaleX:Bool = true;
	public var copyScaleY:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var sustainScale:Float = 1.0;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	// Sustain notes keep the same hitbox dimensions for many frames. Avoid rebuilding
	// the Flixel hitbox unless the scale or current animation frame actually changes.
	private var hitboxCacheValid:Bool = false;
	private var hitboxScaleX:Float = 0;
	private var hitboxScaleY:Float = 0;
	private var hitboxFrameWidth:Float = 0;
	private var hitboxFrameHeight:Float = 0;

	// Sustain animations usually remain unchanged for hundreds of frames.
	// Cache the current animation object so we do not run endsWith() for every note every frame.
	private var cachedSustainAnim:Dynamic = null;
	private var cachedSustainIsEnd:Bool = false;

	// Cache the last clipping rectangle. Most sustain notes are not crossing a receptor,
	// so repeatedly clipping an unchanged full frame is wasted CPU work.
	private var clipCacheValid:Bool = false;
	private var clipCacheFrame:Dynamic = null;
	private var clipCacheX:Float = 0;
	private var clipCacheY:Float = 0;
	private var clipCacheWidth:Float = 0;
	private var clipCacheHeight:Float = 0;

	private inline function updateHitboxIfNeeded():Void
	{
		if (!hitboxCacheValid || hitboxScaleX != scale.x || hitboxScaleY != scale.y ||
			hitboxFrameWidth != frameWidth || hitboxFrameHeight != frameHeight)
		{
			updateHitbox();
			hitboxScaleX = scale.x;
			hitboxScaleY = scale.y;
			hitboxFrameWidth = frameWidth;
			hitboxFrameHeight = frameHeight;
			hitboxCacheValid = true;
		}
	}

	public var hitsoundDisabled:Bool = false;

	public var pixelNote:Bool = false;
	public var useRGBShader(default, set):Bool = true;

	private function set_useRGBShader(value:Bool):Bool {
		if (useRGBShader != value)
		{
			useRGBShader = value;
			if (rgbShader != null) rgbShader.enabled = value;
		}
		return value;
	}

	var changeSize:Bool = false;

	private function set_texture(value:String):String {
		if (value.length == 0) value = Paths.defaultSkin;
		if (!pixelNote && texture != value)
		{
			changeSize = false;
			if (!Paths.noteSkinFramesMap.exists(value)) Paths.initNote(value);
			if (frames != @:privateAccess Paths.noteSkinFramesMap.get(value)) frames = @:privateAccess Paths.noteSkinFramesMap.get(value);
			if (animation != @:privateAccess Paths.noteSkinAnimsMap.get(value)) animation.copyFrom(@:privateAccess Paths.noteSkinAnimsMap.get(value));

			antialiasing = ClientPrefs.globalAntialiasing;

			if (!changeSize)
			{
				changeSize = true;
				setGraphicSize(Std.int(width * 0.7));
				updateHitbox();
			}
			offsetX = 0;
		}
		else if (!pixelNote) return value;
		else if (pixelNote && inEditor) reloadNote(value);
		texture = value;
		return value;
	}

	var noteColor:Array<FlxColor>;
	public function defaultRGB()
	{
		noteColor = !PlayState.isPixelStage ? ClientPrefs.arrowRGB[noteData] : ClientPrefs.arrowRGBPixel[noteData];

		if (noteColor != null && noteData > -1 && noteData <= noteColor.length)
		{
			rgbShader.r = noteColor[0];
			rgbShader.g = noteColor[1];
			rgbShader.b = noteColor[2];
		}
	}

	private function set_noteType(value:String):String {
		noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes';
		if (ClientPrefs.noteColorStyle == 'Normal' && rgbShader != null && useRGBShader) defaultRGB();

		if(noteData > -1 && noteType != value) {
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			noteType = value;
		}
		return value;
	}

	public function toJson(){
		return Json.stringify({
			type:"Note",
			strumTime:strumTime,
			noteData:noteData,
			noteType:noteType,
			mustPress:mustPress
		});
	}
	public override function toString(){
		return Std.string({
			type:"Note",
			strumTime:strumTime,
			noteData:noteData,
			noteType:noteType,
			mustPress:mustPress
		});
	}

	public function new(?newStrumTime:Float, ?newNoteData:Int)
	{
		super();

		pixelNote = PlayState.isPixelStage;

		if (!Math.isNaN(newNoteData) && pixelNote) noteData = newNoteData;
		if (!Math.isNaN(newStrumTime)) strumTime = newStrumTime;

		y -= 2000;
		antialiasing = ClientPrefs.globalAntialiasing && !pixelNote;

		if(noteData > -1) {
			if (ClientPrefs.showNotes) texture = Paths.defaultSkin;

			if (ClientPrefs.enableColorShader)
			{
				try{ rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this)); }
				catch(e) {};
				if(PlayState.SONG != null && PlayState.SONG.disableNoteRGB) useRGBShader = false;
			}
			else useRGBShader = false;
		}
	}

	public static function initializeGlobalRGBShader(noteData:Int = 0, ?note:Note = null)
	{
		if (note == null)
		{
			if(globalRgbShaders[noteData] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[noteData] = newRGB;

				var arr:Array<FlxColor> = ClientPrefs.noteColorStyle != 'Quant-Based' ? (!PlayState.isPixelStage) ? ClientPrefs.arrowRGB[noteData] : ClientPrefs.arrowRGBPixel[noteData] : ClientPrefs.quantRGB[noteData];
				if (arr != null && noteData > -1 && noteData <= arr.length)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[noteData];
		}
		else switch(ClientPrefs.noteColorStyle)
		{
			case 'Quant-Based':
			if(globalRgbShaders[0] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[0] = newRGB;

				var arr:Array<FlxColor> = (!note.pixelNote) ? ClientPrefs.arrowRGB[3] : ClientPrefs.arrowRGBPixel[3];
				if (noteData > -1)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[0];
			case 'Grayscale', 'Rainbow', 'Char-Based':
			if(globalRgbShaders[0] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[0] = newRGB;

				if (noteData > -1)
				{
					newRGB.r = 0xFFA0A0A0;
					newRGB.g = FlxColor.WHITE;
					newRGB.b = 0xFF424242;
				}
			}
			return globalRgbShaders[0];
			default:
			if(globalRgbShaders[noteData] == null)
			{
				var newRGB:RGBPalette = new RGBPalette();
				globalRgbShaders[noteData] = newRGB;

				var arr:Array<FlxColor> = (!note.pixelNote) ? ClientPrefs.arrowRGB[noteData] : ClientPrefs.arrowRGBPixel[noteData];
				if (noteData > -1 && noteData <= arr.length)
				{
					newRGB.r = arr[0];
					newRGB.g = arr[1];
					newRGB.b = arr[2];
				}
			}
			return globalRgbShaders[noteData];
		}
	}

	var _lastNoteOffX:Float = 0;
	static var _lastValidChecked:String; //optimization
	public var originalHeight:Float = 6;
	private function reloadNote(?texture:String = '', ?postfix:String = '') {
		if(texture == null) texture = '';
		if(postfix == null) postfix = '';

		var skin:String = texture + postfix;
		if(texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if(skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var skinPixel:String = skin;
		var lastScaleY:Float = scale.y;
		var skinPostfix:String = getNoteSkinPostfix();
		var customSkin:String = skin + skinPostfix;
		var path:String = pixelNote ? 'pixelUI/' : '';
		if(customSkin == _lastValidChecked || Paths.fileExists('images/' + path + customSkin + '.png', IMAGE))
		{
			skin = customSkin;
			_lastValidChecked = customSkin;
		}
		else skinPostfix = '';

		if(pixelNote) {
			if(isSustainNote) {
				var graphic = Paths.image('pixelUI/' + skinPixel + 'ENDS' + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 2));
				originalHeight = graphic.height / 2;
			} else {
				var graphic = Paths.image('pixelUI/' + skinPixel + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			if(isSustainNote)
			{
				animation.add(colArray[noteData] + 'holdend', [noteData + 4], 24, true);
				animation.add(colArray[noteData] + 'hold', [noteData], 24, true);
			} else animation.add(colArray[noteData] + 'Scroll', [noteData + 4], 24, true);
			antialiasing = false;

			if(isSustainNote) {
				offsetX += _lastNoteOffX;
				_lastNoteOffX = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= _lastNoteOffX;
			}
		} else {
			frames = Paths.getSparrowAtlas(skin);
			animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');
			if (isSustainNote)
			{
				animation.addByPrefix('purpleholdend', 'pruple end hold'); // ?????
				animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end');
				animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece');
			}
			setGraphicSize(Std.int(width * 0.7));
			if(!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
			antialiasing = ClientPrefs.globalAntialiasing;
		}
		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);

		if(inEditor) {
			setGraphicSize(editors.ChartingState.GRID_SIZE, editors.ChartingState.GRID_SIZE);
			updateHitbox();
		}
	}

	public static function getNoteSkinPostfix()
	{
		var skin:String = '';
		if(ClientPrefs.noteSkin != 'Default')
			skin = '-' + ClientPrefs.noteSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	override function update(elapsed:Float)
	{
		#if !mobile
		// Non-mobile builds still use the generic group update path during BotPlay.
		// Mobile PlayState dispatches Note.update manually and skips that pass entirely
		// during BotPlay, so repeating these global state checks for every note is redundant.
		if (PlayState.instance != null && FlxG.state == PlayState.instance && PlayState.instance.cpuControlled) return;
		#end

		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit && !ignoreNote)
				tooLate = true;
			else tooLate = false;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if(strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	inline public function followStrum(strum:StrumNote, songSpeed:Float = 1):Void
	{
		if (isSustainNote)
		{
			if (flipY != strum.downScroll) flipY = strum.downScroll;

			final curAnim = animation == null ? null : animation.curAnim;
			if (cachedSustainAnim != curAnim)
			{
				cachedSustainAnim = curAnim;
				cachedSustainIsEnd = curAnim != null && curAnim.name.endsWith('end');
			}

			var sustainScaleY:Float = cachedSustainIsEnd ? 1 : Conductor.stepCrochet * 0.0105 * (songSpeed * multSpeed) * sustainScale;
			if (PlayState.isPixelStage) sustainScaleY *= PlayState.daPixelZoom * 1.20;

			// copyScaleX overwrites X below, so do not write a temporary 0.7 value.
			// Avoid dirtying the scale point when the sustain dimensions are unchanged.
			if (copyScaleX)
			{
				if (scale.y != sustainScaleY) scale.y = sustainScaleY;
			}
			else
			{
				final sustainScaleX:Float = PlayState.isPixelStage ? PlayState.daPixelZoom * 0.7 : 0.7;
				if (scale.x != sustainScaleX || scale.y != sustainScaleY)
					scale.set(sustainScaleX, sustainScaleY);
			}

			// copyScaleX refreshes the hitbox after applying the receptor scale below.
			// Avoid doing the same hitbox work twice for every sustain note each frame.
			if (!copyScaleX) updateHitboxIfNeeded();
		}

		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!ClientPrefs.downScroll) distance *= -1;

		if (copyAngle)
		{
			final targetAngle:Float = strum.direction - 90 + strum.angle + offsetAngle;
			if (angle != targetAngle) angle = targetAngle;
		}

		if (copyAlpha)
		{
			final targetAlpha:Float = strum.alpha * multAlpha;
			if (alpha != targetAlpha) alpha = targetAlpha;
		}

		if(copyX)
			x = strum.x + offsetX + strum.directionCos * distance;

		if(copyY)
		{
			y = strum.y + offsetY + (!isSustainNote || strum.downScroll ? 0 : 55) + strum.directionSin * distance;
			if(strum.downScroll && isSustainNote)
			{
				if(PlayState.isPixelStage)
				{
					y -= PlayState.daPixelZoom * 9.5;
				}
				y -= (frameHeight * scale.y) - (Note.swagWidth / 2);
			}
		}

		if (copyScaleX)
		{
			final targetScaleX:Float = strum.scale.x;
			if (scale.x != targetScaleX) scale.x = targetScaleX;
			if (isSustainNote) updateHitboxIfNeeded();
		}
		if (copyScaleY && !isSustainNote)
		{
			final targetScaleY:Float = strum.scale.y;
			if (scale.y != targetScaleY) scale.y = targetScaleY;
		}
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		if (!isSustainNote || (!mustPress && ignoreNote) ||
			(mustPress && !wasGoodHit && canBeHit)) return;

		final currentFrame:Dynamic = frame;
		if (currentFrame == null) return;
		@:privateAccess if (_frame == null) return;

		final center:Float = myStrum.y + offsetY + Note.swagWidth / 2;
		var clipX:Float = 0;
		var clipY:Float = 0;
		var clipWidth:Float = frameWidth;
		var clipHeight:Float = frameHeight;

		if (myStrum.downScroll)
		{
			if (y - offset.y * scale.y + height >= center)
			{
				clipHeight = (center - y) / scale.y;
				clipY = frameHeight - clipHeight;
			}
		}
		else if (y + offset.y * scale.y <= center)
		{
			clipY = (center - y) / scale.y;
			clipHeight = (height / scale.y) - clipY;
			clipWidth = width / scale.x;
		}

		// A sustain that has not reached the receptor needs no clipping at all.
		// Keep the full-frame state cached without allocating a FlxRect or clipped frame.
		if (clipRect == null && clipX == 0 && clipY == 0 &&
			clipWidth == frameWidth && clipHeight == frameHeight)
		{
			clipCacheFrame = currentFrame;
			clipCacheX = clipX;
			clipCacheY = clipY;
			clipCacheWidth = clipWidth;
			clipCacheHeight = clipHeight;
			clipCacheValid = true;
			return;
		}

		// frame.clipTo() is relatively expensive. Skip it when this sustain's
		// frame and effective clip rectangle are identical to the previous frame.
		if (clipCacheValid && clipCacheFrame == currentFrame && clipCacheX == clipX &&
			clipCacheY == clipY && clipCacheWidth == clipWidth && clipCacheHeight == clipHeight)
			return;

		if (clipRect == null)
		{
			@:bypassAccessor clipRect = FlxRect.get(clipX, clipY, clipWidth, clipHeight);
		}
		else
		{
			clipRect.x = clipX;
			clipRect.y = clipY;
			clipRect.width = clipWidth;
			clipRect.height = clipHeight;
		}

		final swagRect:FlxRect = clipRect;
		@:bypassAccessor clipRect = swagRect;
		@:privateAccess if (_frame != null)
			_frame = currentFrame.clipTo(swagRect, _frame);
		dirty = true;

		clipCacheFrame = currentFrame;
		clipCacheX = clipX;
		clipCacheY = clipY;
		clipCacheWidth = clipWidth;
		clipCacheHeight = clipHeight;
		clipCacheValid = true;
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect {
		clipCacheValid = false;
		@:bypassAccessor clipRect = rect;

		@:privateAccess if (frame != null) {
			if (rect != null && _frame != null)
				_frame = frame.clipTo(rect, _frame);
			else if (_frame != null)
				_frame = frame.copyTo(_frame);
			dirty = true;
		}
		
		return rect;
	}

	public override function destroy()
	{
		super.destroy();
		_lastValidChecked = '';
	}

	var superCoolColor = null;
	var arr:Array<Int> = [255, 255, 255];
	var rainbowTime = 0.0;
	public function updateRGBColors()
	{
		if (!useRGBShader) return;

		if (rgbShader == null) rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this));
		else switch(ClientPrefs.noteColorStyle)
		{
			case 'Rainbow':
			rainbowTime = (ClientPrefs.rainbowTime != 0 ? ClientPrefs.rainbowTime * 1000 : Conductor.crochet);
			superCoolColor = new FlxColor(0xFFFF0000);
			superCoolColor.hue = (strumTime / rainbowTime * 360) % 360;
			rgbShader.r = superCoolColor;
			rgbShader.g = FlxColor.WHITE;
			rgbShader.b = superCoolColor.getDarkened(0.7);

			case 'Quant-Based':
			CoolUtil.checkNoteQuant(this, (!isSustainNote ? strumTime : parentST), rgbShader);

			case 'Char-Based':
			if (PlayState.instance != null)
			{
				arr = CoolUtil.getHealthColors(doOppStuff ? PlayState.instance.dad : PlayState.instance.boyfriend);
				if (gfNote) arr = CoolUtil.getHealthColors(PlayState.instance.gf);
				if (noteData > -1)
				{
					rgbShader.r = FlxColor.fromRGB(arr[0], arr[1], arr[2]);
					rgbShader.g = FlxColor.WHITE;
					rgbShader.b = rgbShader.r;
					rgbShader.b = rgbShader.b.getDarkened(0.7);
				}
			}
			else defaultRGB();

			default:

		}
		if (noteType == 'Hurt Note' && rgbShader != null)
		{
			// note colors
			rgbShader.r = 0xFF101010;
			rgbShader.g = 0xFFFF0000;
			rgbShader.b = 0xFF990022;

			// splash data and colors
			noteSplashData.r = 0xFFFF0000;
			noteSplashData.g = 0xFF101010;
			noteSplashData.texture = 'noteSplashes/noteSplashes-electric';
		}
		else if (rgbShader != null)
		{
			noteSplashData.r = -1;
			noteSplashData.g = -1;
			noteSplashData.b = -1;
		}
	}

	// this is used for note recycling
	// or was before I removed the option, now it's just kept for reasons
	var firstOffX = false;
	var shouldCenterOffsets:Bool = true;
	public function setupNoteData(chartNoteData:PreloadedChartNote):Void
	{
		var ns = chartNoteData.noteskin ?? "";
		var tx = chartNoteData.texture ?? "";

		wasGoodHit = hitByOpponent = tooLate = canBeHit = false; // Don't make an update call of this for the note group

		if (ns.length > 0 && ns != texture) {
			texture = 'noteskins/' + ns;
			useRGBShader = false;
		}

		if (tx.length > 0 && tx != texture) {
			texture = tx;
			shouldCenterOffsets = false;
		}

		if (ns.length < 1 && tx.length < 1 && texture != Paths.defaultSkin) {
			texture = Paths.defaultSkin;
			useRGBShader = (ClientPrefs.enableColorShader && PlayState.SONG != null && !PlayState.SONG.disableNoteRGB);
			shouldCenterOffsets = useRGBShader;
		}

		strumTime = chartNoteData.strumTime;
		noteData = chartNoteData.noteData;
		noteType = chartNoteData.noteType;
		animSuffix = chartNoteData.animSuffix;
		noAnimation = noMissAnimation = chartNoteData.noAnimation;
		mustPress = chartNoteData.mustPress;
		doOppStuff = chartNoteData.oppNote;
		gfNote = chartNoteData.gfNote;
		isSustainNote = chartNoteData.isSustainNote;
		isSustainEnd = chartNoteData.isSustainEnd;
		lowPriority = chartNoteData.lowPriority;
		multAlpha = chartNoteData.multAlpha;
		if (isSustainNote) {
			parentST = chartNoteData.parentST;
			parentSL = chartNoteData.parentSL;
		}

		hitHealth = chartNoteData.hitHealth;
		missHealth = chartNoteData.missHealth;
		hitCausesMiss = chartNoteData.hitCausesMiss ?? false;
		ignoreNote = chartNoteData.ignoreNote;
		blockHit = chartNoteData.blockHit;
		multSpeed = chartNoteData.multSpeed;
		noteDensity = chartNoteData.noteDensity;

		if (ClientPrefs.enableColorShader && useRGBShader)
		{
			if (rgbShader == null) rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData, this));
			updateRGBColors();
		}

		if(!inEditor) strumTime += ClientPrefs.noteOffset;

		if (noteType == 'Hurt Note' && !ClientPrefs.enableColorShader)
		{
			texture = 'HURTNOTE_assets';
			noteSplashData.texture = 'noteSplashes/HURTnoteSplashes';
		}

		if (PlayState.isPixelStage)
		{
			@:privateAccess reloadNote(texture);
			if (isSustainNote && !firstOffX)
			{
				firstOffX = true;
				offsetX += 30;
			}
		}

		if (!changeSize && !PlayState.isPixelStage)
		{
			changeSize = true;
			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
		}

		if (isSustainNote) {
			offsetX += width / 2;
			copyAngle = false;
			animation.play(colArray[noteData] + (chartNoteData.isSustainEnd ? 'holdend' : 'hold'));
			updateHitbox();
			offsetX -= width / 2;

			if (!PlayState.isPixelStage)
				sustainScale = Note.SUSTAIN_SIZE / frameHeight;

			updateHitbox();
		}
		else {
			animation.play(colArray[noteData] + 'Scroll');
			if (!copyAngle) copyAngle = true;
			offsetX = 0; //Just in case we recycle a sustain note to a regular note
			if (useRGBShader && shouldCenterOffsets)
			{
				centerOffsets();
				centerOrigin();
			}
		}
		angle = 0;

		// the clipRect setter re-clips the frame every time; only pay for it when a previous sustain left a clip behind
		if (clipRect != null) clipRect = null;
		else clipCacheValid = false;
		if (!mustPress)
		{
			visible = ClientPrefs.opponentStrums;
			alpha = ClientPrefs.middleScroll ? ClientPrefs.oppNoteAlpha : 1;
		}
		else
		{
			if (!visible) visible = true;
			if (alpha != 1) alpha = 1; //if (multAlpha != 1) multAlpha = 1;
		}
		if (flipY) flipY = false;
	}
}
