package;

import Song.SwagSong;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float=0;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	// credits to duskiewhy for making this
	public static var safeZoneOffset:Float = (ClientPrefs.safeFrames / 60) * 1000; // is calculated in create(), is safeFrames in milliseconds
	public static var timeScale:Float = Conductor.safeZoneOffset / 180; //max hit window should be 180 right?
	public static var ROWS_PER_BEAT = 48; // from Stepmania
	public static var BEATS_PER_MEASURE = 4; // TODO: time sigs
	public static var ROWS_PER_MEASURE = ROWS_PER_BEAT * BEATS_PER_MEASURE; // from Stepmania
	public static var MAX_NOTE_ROW = 1 << 30; // from Stepmania

	public inline static function beatToRow(beat:Float):Int
		return Math.round(beat * ROWS_PER_BEAT);

	public inline static function rowToBeat(row:Int):Float
		return row / ROWS_PER_BEAT;

	public inline static function secsToRow(sex:Float):Int
		return Math.round(getBeat(sex) * ROWS_PER_BEAT);

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];
	// Cached BPM-map cursors make the common forward-playback lookup O(1).
	// Binary search remains the fallback for seeks and out-of-order queries.
	private static var bpmTimeIndex:Int = -1;
	private static var bpmStepIndex:Int = -1;

	public function new()
	{
	}

	public static function recalculateTimings()
	{
		Conductor.safeZoneOffset = Math.floor((ClientPrefs.safeFrames / 60) * 1000);
		Conductor.timeScale = Conductor.safeZoneOffset / 180;
	}

	public static function judgeNote(note:Note, diff:Float=0, ?botplay:Bool = false, ?missedNote:Bool = false):Rating // die
	{
		if (botplay || missedNote) return PlayState.instance.ratingsData[0];
		var data:Array<Rating> = PlayState.instance.ratingsData; //shortening cuz fuck u
		for(i in 0...data.length-1) //skips last window (Shit)
		{
			if (diff <= data[i].hitWindow)
			{
				return data[i];
			}
		}
		return data[data.length - 1];
	}

	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	public static function getBPMFromSeconds(time:Float):BPMChangeEvent
	{
		final length:Int = bpmChangeMap.length;
		var index:Int = bpmTimeIndex;

		// Song playback normally moves forward. Reuse the active segment and
		// advance only across BPM changes crossed since the previous lookup.
		if (index >= 0 && index < length)
		{
			if (bpmChangeMap[index].songTime <= time)
			{
				while (index + 1 < length && bpmChangeMap[index + 1].songTime <= time) index++;
				if (index == length - 1 || bpmChangeMap[index + 1].songTime > time)
				{
					bpmTimeIndex = index;
					return bpmChangeMap[index];
				}
			}
		}

		// Seeks, rewinds and queries before the first change use binary search.
		var low:Int = 0;
		var high:Int = length - 1;
		var found:Int = -1;
		while (low <= high)
		{
			final mid:Int = low + ((high - low) >> 1);
			if (bpmChangeMap[mid].songTime <= time)
			{
				found = mid;
				low = mid + 1;
			}
			else high = mid - 1;
		}
		bpmTimeIndex = found;
		return found >= 0 ? bpmChangeMap[found] : {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		};
	}

	public static function getBPMFromStep(step:Float):BPMChangeEvent
	{
		final length:Int = bpmChangeMap.length;
		var index:Int = bpmStepIndex;

		if (index >= 0 && index < length)
		{
			if (bpmChangeMap[index].stepTime <= step)
			{
				while (index + 1 < length && bpmChangeMap[index + 1].stepTime <= step) index++;
				if (index == length - 1 || bpmChangeMap[index + 1].stepTime > step)
				{
					bpmStepIndex = index;
					return bpmChangeMap[index];
				}
			}
		}

		var low:Int = 0;
		var high:Int = length - 1;
		var found:Int = -1;
		while (low <= high)
		{
			final mid:Int = low + ((high - low) >> 1);
			if (bpmChangeMap[mid].stepTime <= step)
			{
				found = mid;
				low = mid + 1;
			}
			else high = mid - 1;
		}
		bpmStepIndex = found;
		return found >= 0 ? bpmChangeMap[found] : {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		};
	}

	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60)/4) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float){
		return getStep(time)/4;
	}

	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time)/4);
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];
		bpmTimeIndex = bpmStepIndex = -1;

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM)/4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		if (bpmChangeMap.length > 0)
			trace("new BPM map BUDDY " + bpmChangeMap);
	}

	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;

		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
	}
}

class Rating
{
	public var name:String = '';
	public var image:String = '';
	public var counter:String = '';
	public var hitWindow:Null<Float> = 0.0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 500;
	public var noteSplash:Bool = true;

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.counter = name + 's';
		this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		if(hitWindow == null)
		{
			hitWindow = 0;
		}
	}

	public static function loadDefault():Array<Rating>
	{
		var ratingsData:Array<Rating> = [];

		if (!ClientPrefs.noMarvJudge)
		{
			ratingsData.push(new Rating('perfect'));
		}

		var rating:Rating = new Rating('sick');
		rating.ratingMod = 1;
		rating.score = 350;
		rating.noteSplash = true;
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);
		return ratingsData;
	}
	
	public function increase(blah:Int = 1)
	{
		Reflect.setField(PlayState.instance, counter, Reflect.field(PlayState.instance, counter) + blah);
	}
}
