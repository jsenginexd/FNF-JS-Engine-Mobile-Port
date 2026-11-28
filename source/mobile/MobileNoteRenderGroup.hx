package mobile;

import flixel.FlxCamera;
import flixel.group.FlxTypedGroup;

/**
 * Mobile-only note group with a compact indexed draw traversal.
 *
 * The loop preserves FlxTypedGroup's camera routing, member order and
 * exists/visible checks. Each note still runs its normal FlxSprite.draw()
 * path, including per-camera bounds checks, shaders and texture filtering.
 */
class MobileNoteRenderGroup extends FlxTypedGroup<Note>
{
	@:privateAccess
	override public function draw():Void
	{
		if (!ClientPrefs.fastMobileNoteRenderLoop)
		{
			super.draw();
			return;
		}

		final previousCameras:Array<FlxCamera> = FlxCamera._defaultCameras;
		final groupCameras:Array<FlxCamera> = cameras;
		if (groupCameras != null)
			FlxCamera._defaultCameras = groupCameras;

		final drawMembers:Array<Note> = members;
		final drawCount:Int = drawMembers.length;
		var index:Int = 0;
		while (index < drawCount)
		{
			final note:Note = drawMembers[index];
			if (note != null && note.exists && note.visible)
				note.draw();
			index++;
		}

		FlxCamera._defaultCameras = previousCameras;
	}
}
