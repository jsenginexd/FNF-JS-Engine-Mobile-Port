package options;

class OptimizationSubState extends BaseOptionsMenu
{
  public function new()
  {
    title = 'Optimization';
    rpcTitle = 'Optimization Settings Menu'; // for Discord Rich Presence

    // I'd suggest using "Chars & BG" as an example for making your own option since it is the simplest here
    final option:Option = new Option('Chars & BG', // Name
      'If unchecked, gameplay will only show the HUD.', // Description
      'charsAndBG', // Save data variable name
      'bool', // Variable type
      true); // Default value
    addOption(option);

    final option:Option = new Option('Enable GC',
      "If checked, then the game will be allowed to garbage collect, reducing RAM usage I suppose.\nIf you experience memory leaks, turn this on, and\nif you experience lag with it on then turn it off.",
      'enableGC', 'bool', true);
    addOption(option);

    final option:Option = new Option('Smooth Note Textures',
      'Uses linear GPU sampling for regular note skins and receptors while keeping the original full-resolution note atlas. Pixel-art stages stay crisp.',
      'smoothNotes', 'bool', true);
    addOption(option);

    final option:Option = new Option('Motion Blur Quality',
      'Performance uses 3 shader samples, Balanced uses 5, and Quality uses 9. Fewer samples reduce GPU work without disabling Motion Blur.',
      'motionBlurQuality', 'string', #if mobile 'Performance' #else 'Quality' #end,
      ['Performance', 'Balanced', 'Quality']);
    addOption(option);

    final option:Option = new Option('Stage Texture Saver',
      'Reduces selected stage, background and effect textures to 70% before GPU upload. Note skins remain full resolution. Restart or reload the stage after changing this.',
      'reduceBackgroundTextures', 'bool', #if mobile true #else false #end);
    addOption(option);

    final option:Option = new Option('Light Opponent Strums', "If this is unchecked, the Opponent strums won't light up when the Opponent hits a note.",
      'opponentLightStrum', 'bool', true);
    addOption(option);

    final option:Option = new Option('Light Botplay Strums', "If this is unchecked, the Player strums won't light when Botplay is active.", 'botLightStrum',
      'bool', true);
    addOption(option);

    final option:Option = new Option('Light Player Strums', "If this is unchecked, then uh.. the player strums won't light up.\nit's as simple as that.",
      'playerLightStrum', 'bool', true);
    addOption(option);

    final option:Option = new Option('Show Ratings', "If unchecked, the game will not show a rating sprite when hitting a note.", 'ratingPopups', 'bool', true);
    addOption(option);

    final option:Option = new Option('Show Combo Numbers', "If unchecked, the game will not show combo numbers when hitting a note.", 'comboPopups', 'bool',
      true);
    addOption(option);

    final option:Option = new Option('Show MS Popup', "If checked, hitting a note will also show how late/early you hit it.", 'showMS', 'bool', false);
    addOption(option);

    final option:Option = new Option('Disable onSpawnNote Lua Calls',
      "If checked, the game will not call onSpawnNote when a note is spawned.\nIf you have a script that uses that, maybe leave it on.", 'noSpawnFunc',
      'bool', false);
    addOption(option);

    final option:Option = new Option('Disable Hit Lua Calls', "If checked, the game will not call note hit functions when a note is hit.", 'noHitFuncs',
      'bool', false);
    addOption(option);

    final option:Option = new Option('Disable Skip Lua Calls', "If checked, the game will not call note hit functions for skipped notes.", 'noSkipFuncs',
      'bool', false);
    addOption(option);

    final option:Option = new Option('Even LESS Botplay Lag', "On mobile this is enabled by default. During BotPlay, keeps hit sounds, notes, receptors and character animations but skips rating popups, note splashes and hit-image overlays to reduce per-note visual allocations.", 'lessBotLag', 'bool', #if mobile true #else false #end);
    addOption(option);

    final option:Option = new Option('Max Rendered Notes: ', "The max amount of notes that the game can render onscreen.\nTo remove this limit, set it to 0.",
      'maxNotes', 'int', 0);
    addOption(option);

    option.scrollSpeed = 2000;
    option.minValue = 0;
    option.maxValue = 99999;
    option.displayFormat = '%v Notes';

    cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

    super();
  }
}
