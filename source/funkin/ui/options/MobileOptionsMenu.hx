package funkin.ui.options;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import funkin.graphics.FunkinCamera;
import funkin.graphics.FunkinSprite;
import funkin.ui.AtlasText.AtlasFont;
import funkin.ui.FullScreenScaleMode;
import funkin.ui.Page;
import funkin.ui.TextMenuList;
import funkin.ui.options.items.CheckboxPreferenceItem;
#if mobile
import funkin.mobile.ui.FunkinBackButton;
import funkin.mobile.ui.options.ControlsSchemeMenu;
#end

class MobileOptionsMenu extends Page<OptionsState.OptionsMenuPageName>
{
  var items:TextMenuList;
  var preferenceItems:FlxTypedSpriteGroup<FlxSprite>;
  var preferenceDesc:Array<String> = [];
  var itemDesc:FlxText;
  var itemDescBox:FunkinSprite;
  var menuCamera:FlxCamera;
  var hudCamera:FlxCamera;
  var camFollow:FlxObject;

  public function new()
  {
    super();

    menuCamera = new FunkinCamera('mobileOptsMenu');
    FlxG.cameras.add(menuCamera, false);
    menuCamera.bgColor = 0x0;

    hudCamera = new FlxCamera();
    FlxG.cameras.add(hudCamera, false);
    hudCamera.bgColor = 0x0;

    camera = menuCamera;

    add(items = new TextMenuList());
    add(preferenceItems = new FlxTypedSpriteGroup<FlxSprite>());

    add(itemDescBox = new FunkinSprite());
    itemDescBox.cameras = [hudCamera];

    add(itemDesc = new FlxText(0, 0, 1180, null, 32));
    itemDesc.cameras = [hudCamera];

    createPrefItems();
    createPrefDescription();

    camFollow = new FlxObject(FlxG.width / 2, 0, 140, 70);

    menuCamera.follow(camFollow, null, 0.085);
    var margin = 160;
    menuCamera.deadzone.set(0, margin, menuCamera.width, menuCamera.height - margin * 2);
    menuCamera.minScrollY = 0;

    items.onChange.add(function(selected)
    {
      itemDesc.text = preferenceDesc[items.selectedIndex];
    });

    #if FEATURE_TOUCH_CONTROLS
    var backButton:FunkinBackButton = new FunkinBackButton(FlxG.width - 230, FlxG.height - 200, exit, 1.0);
    add(backButton);
    #end
  }

  function createPrefDescription():Void
  {
    itemDescBox.makeSolidColor(1, 1, FlxColor.BLACK);
    itemDescBox.alpha = 0.6;
    itemDesc.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    itemDesc.borderSize = 3;

    itemDesc.text = preferenceDesc[items.selectedIndex];
    itemDesc.screenCenter();
    itemDesc.y += 270;

    itemDescBox.setPosition(itemDesc.x - 10, itemDesc.y - 10);
    itemDescBox.setGraphicSize(Std.int(itemDesc.width + 20), Std.int(itemDesc.height + 25));
    itemDescBox.updateHitbox();
  }

  function createPrefItems():Void
  {
    createPrefItemCheckbox('Widescreen Mode', 'When enabled, stretches or adjusts the rendering scale to fit full widescreen display cutout edges.',
      function(value:Bool):Void
      {
        FullScreenScaleMode.enabled = value;
        Preferences.wideScreen = value;
      }, Preferences.wideScreen);

    #if mobile
    createPrefItemButton('Controls Scheme', 'Change touch overlay and control scheme options.', function()
    {
      FlxG.state.openSubState(new ControlsSchemeMenu());
    });
    #end
  }

  override function update(elapsed:Float):Void
  {
    super.update(elapsed);

    if (items != null) camFollow.y = items.selectedItem.y;

    items.forEach(function(daItem:TextMenuItem)
    {
      var thyOffset:Int = 0;
      if (items.selectedItem == daItem)
      {
        thyOffset = 150;
      }
      else
      {
        thyOffset = 120;
      }

      daItem.x = thyOffset + funkin.ui.FullScreenScaleMode.gameNotchSize.x;
    });
  }

  function createPrefItemCheckbox(prefName:String, prefDesc:String, onChange:Bool->Void, defaultValue:Bool, available:Bool = true):Void
  {
    var checkbox:CheckboxPreferenceItem = new CheckboxPreferenceItem(funkin.ui.FullScreenScaleMode.gameNotchSize.x, 120 * (items.length - 1 + 1),
      defaultValue, available);

    items.createItem(0, (120 * items.length) + 30, prefName, AtlasFont.BOLD, function()
    {
      var value = !checkbox.currentValue;
      onChange(value);
      checkbox.currentValue = value;
    }, false, available);

    preferenceItems.add(checkbox);
    preferenceDesc.push(prefDesc);
  }

  function createPrefItemButton(prefName:String, prefDesc:String, callback:Void->Void):Void
  {
    items.createItem(0, (120 * items.length) + 30, prefName, AtlasFont.BOLD, callback, false, true);
    preferenceDesc.push(prefDesc);
  }

  override function exit():Void
  {
    camFollow.setPosition(640, 30);
    menuCamera.snapToTarget();
    super.exit();
  }
}
