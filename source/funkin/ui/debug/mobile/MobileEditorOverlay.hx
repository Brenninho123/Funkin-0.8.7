package funkin.ui.debug.mobile;

#if (mobile && FEATURE_HAXEUI)
import haxe.ui.RuntimeComponentBuilder;
import haxe.ui.components.Button;
import haxe.ui.core.Component;
import haxe.ui.core.Screen;
import haxe.ui.events.MouseEvent as HaxeUIMouseEvent;
import openfl.events.KeyboardEvent;
import openfl.events.MouseEvent;
import openfl.ui.Keyboard;

/**
 * A touch-friendly on-screen control pad for the debug editors (Chart Editor, Stage Editor, Animation Editor).
 *
 * The editors were written for mouse and keyboard. Rather than rewriting every one of them, this overlay
 * injects the missing inputs (arrow keys, Space, Escape, Ctrl/Shift modifiers, Undo/Redo/Save, mouse wheel
 * and right click) at the stage level so that every existing editor shortcut keeps working on a phone.
 *
 * Because the pad is made of HaxeUI components, the editors' own "is the cursor over the UI" checks
 * already prevent taps on the pad from also interacting with the editor underneath.
 */
@:nullSafety
class MobileEditorOverlay
{
  /**
   * The HaxeUI scale applied to the whole editor UI on mobile so that controls are big enough to hit with a finger.
   */
  public static final MOBILE_UI_SCALE:Float = 1.5;

  /**
   * How long (in ms) a synthetic key stays held, so that Flixel registers a `justPressed` for at least one frame.
   */
  static final KEY_HOLD_MS:Int = 90;

  static final PAD_XML:String = '
<vbox style="background-color: #000000; background-opacity: 0.55; border-radius: 8px; padding: 6px; spacing: 4px;">
  <hbox>
    <button id="btnToggle" text="Controls [-]" />
  </hbox>
  <vbox id="padBody" style="spacing: 4px;">
    <hbox>
      <button id="btnBack" text="Esc" />
      <button id="btnSpace" text="Space" />
      <button id="btnUndo" text="Undo" />
      <button id="btnRedo" text="Redo" />
      <button id="btnSave" text="Save" />
    </hbox>
    <hbox>
      <button id="btnCtrl" text="Ctrl" toggle="true" />
      <button id="btnShift" text="Shift" toggle="true" />
      <button id="btnRmb" text="Right-Click" toggle="true" />
      <button id="btnDel" text="Del" />
      <button id="btnEnter" text="Enter" />
    </hbox>
    <hbox>
      <button id="btnLeft" text="&lt;" repeater="true" />
      <button id="btnUp" text="^" repeater="true" />
      <button id="btnDown" text="v" repeater="true" />
      <button id="btnRight" text="&gt;" repeater="true" />
      <button id="btnWheelUp" text="Scroll+" repeater="true" />
      <button id="btnWheelDown" text="Scroll-" repeater="true" />
    </hbox>
  </vbox>
</vbox>
';

  static var current:Null<MobileEditorOverlay> = null;

  var pad:Null<Component> = null;
  var ctrlHeld:Bool = false;
  var shiftHeld:Bool = false;
  var rightClickArmed:Bool = false;
  var collapsed:Bool = false;

  function new() {}

  /**
   * Attach the control pad to the current editor state.
   * Safe to call multiple times; the previous pad is removed first.
   */
  public static function attach():Void
  {
    detach();
    current = new MobileEditorOverlay();
    current.build();
  }

  /**
   * Remove the control pad and release any held modifiers.
   * Call this when leaving an editor.
   */
  public static function detach():Void
  {
    if (current == null) return;
    current.destroy();
    current = null;
  }

  function build():Void
  {
    var component:Null<Component> = RuntimeComponentBuilder.fromString(PAD_XML, "xml");
    if (component == null) return;
    pad = component;

    bindKey("btnBack", Keyboard.ESCAPE);
    bindKey("btnSpace", Keyboard.SPACE);
    bindKey("btnDel", Keyboard.DELETE);
    bindKey("btnEnter", Keyboard.ENTER);
    bindKey("btnLeft", Keyboard.LEFT);
    bindKey("btnUp", Keyboard.UP);
    bindKey("btnDown", Keyboard.DOWN);
    bindKey("btnRight", Keyboard.RIGHT);

    bindCombo("btnUndo", [Keyboard.CONTROL, Keyboard.Z]);
    bindCombo("btnRedo", [Keyboard.CONTROL, Keyboard.Y]);
    bindCombo("btnSave", [Keyboard.CONTROL, Keyboard.S]);

    bindWheel("btnWheelUp", 3);
    bindWheel("btnWheelDown", -3);

    bindToggle("btnCtrl", function(on:Bool):Void
    {
      ctrlHeld = on;
      sendKey(Keyboard.CONTROL, on);
    });
    bindToggle("btnShift", function(on:Bool):Void
    {
      shiftHeld = on;
      sendKey(Keyboard.SHIFT, on);
    });
    bindToggle("btnRmb", function(on:Bool):Void
    {
      rightClickArmed = on;
      updateRightClickInterceptor();
    });

    var toggle:Null<Button> = pad.findComponent("btnToggle", Button);
    var body:Null<Component> = pad.findComponent("padBody", Component);
    if (toggle != null && body != null)
    {
      toggle.onClick = function(_:HaxeUIMouseEvent):Void
      {
        collapsed = !collapsed;
        body.hidden = collapsed;
        toggle.text = collapsed ? "Controls [+]" : "Controls [-]";
      };
    }

    // Anchor to the bottom-left corner, out of the way of the editors' menus and toolboxes.
    pad.left = 8;
    pad.top = Screen.instance.height - 200;
    Screen.instance.addComponent(pad);
    Screen.instance.registerEvent(haxe.ui.events.UIEvent.RESIZE, onScreenResize);
    reposition();
  }

  function onScreenResize(_:Dynamic):Void
  {
    reposition();
  }

  function reposition():Void
  {
    if (pad == null) return;
    pad.validateNow();
    pad.left = 8;
    pad.top = Math.max(0, Screen.instance.height - pad.height - 8);
  }

  function destroy():Void
  {
    // Release anything we are still "holding".
    if (ctrlHeld) sendKey(Keyboard.CONTROL, false);
    if (shiftHeld) sendKey(Keyboard.SHIFT, false);
    ctrlHeld = false;
    shiftHeld = false;
    rightClickArmed = false;
    updateRightClickInterceptor();

    if (pad != null)
    {
      Screen.instance.removeComponent(pad);
      pad = null;
    }
  }

  // --- Binding helpers --------------------------------------------------------------------------

  function bindKey(id:String, keyCode:Int):Void
  {
    var button:Null<Button> = pad?.findComponent(id, Button);
    if (button == null) return;
    button.onClick = function(_:HaxeUIMouseEvent):Void tapKey(keyCode);
  }

  function bindCombo(id:String, keyCodes:Array<Int>):Void
  {
    var button:Null<Button> = pad?.findComponent(id, Button);
    if (button == null) return;
    button.onClick = function(_:HaxeUIMouseEvent):Void tapCombo(keyCodes);
  }

  function bindWheel(id:String, delta:Int):Void
  {
    var button:Null<Button> = pad?.findComponent(id, Button);
    if (button == null) return;
    button.onClick = function(_:HaxeUIMouseEvent):Void sendWheel(delta);
  }

  function bindToggle(id:String, callback:Bool->Void):Void
  {
    var button:Null<Button> = pad?.findComponent(id, Button);
    if (button == null) return;
    button.onClick = function(_:HaxeUIMouseEvent):Void callback(button.selected);
  }

  // --- Input injection --------------------------------------------------------------------------

  static function sendKey(keyCode:Int, down:Bool):Void
  {
    if (FlxG.stage == null) return;
    var event:KeyboardEvent = new KeyboardEvent(down ? KeyboardEvent.KEY_DOWN : KeyboardEvent.KEY_UP, true, false, 0, keyCode);
    FlxG.stage.dispatchEvent(event);
  }

  /**
   * Press and release a single key.
   */
  static function tapKey(keyCode:Int):Void
  {
    sendKey(keyCode, true);
    haxe.Timer.delay(function():Void sendKey(keyCode, false), KEY_HOLD_MS);
  }

  /**
   * Press all keys in order (e.g. Ctrl, Z) then release them in reverse order.
   */
  static function tapCombo(keyCodes:Array<Int>):Void
  {
    for (code in keyCodes)
      sendKey(code, true);
    haxe.Timer.delay(function():Void
    {
      var reversed:Array<Int> = keyCodes.copy();
      reversed.reverse();
      for (code in reversed)
        sendKey(code, false);
    }, KEY_HOLD_MS);
  }

  function sendWheel(delta:Int):Void
  {
    if (FlxG.stage == null) return;
    var x:Float = FlxG.stage.mouseX;
    var y:Float = FlxG.stage.mouseY;
    FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_WHEEL, true, false, x, y, null, ctrlHeld, false, shiftHeld, false, delta));
  }

  // --- Right click emulation --------------------------------------------------------------------

  var interceptorActive:Bool = false;

  /**
   * While "Right-Click" is armed, the next tap is turned into a right click instead of a left click.
   * This is done by swallowing the left-click in the capture phase and re-dispatching right-click events.
   */
  function updateRightClickInterceptor():Void
  {
    if (FlxG.stage == null) return;

    if (rightClickArmed && !interceptorActive)
    {
      FlxG.stage.addEventListener(MouseEvent.MOUSE_DOWN, onInterceptDown, true, 1000);
      FlxG.stage.addEventListener(MouseEvent.MOUSE_UP, onInterceptUp, true, 1000);
      interceptorActive = true;
    }
    else if (!rightClickArmed && interceptorActive)
    {
      FlxG.stage.removeEventListener(MouseEvent.MOUSE_DOWN, onInterceptDown, true);
      FlxG.stage.removeEventListener(MouseEvent.MOUSE_UP, onInterceptUp, true);
      interceptorActive = false;
    }
  }

  function overPad(stageX:Float, stageY:Float):Bool
  {
    if (pad == null) return false;
    // Let taps on the control pad itself through so it can be used while armed.
    var bounds = pad.screenLeft <= stageX && stageX <= pad.screenLeft + pad.width && pad.screenTop <= stageY && stageY <= pad.screenTop + pad.height;
    return bounds;
  }

  function onInterceptDown(event:MouseEvent):Void
  {
    if (overPad(event.stageX, event.stageY)) return;

    event.stopImmediatePropagation();
    FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_DOWN, true, false, event.stageX, event.stageY));
  }

  function onInterceptUp(event:MouseEvent):Void
  {
    if (overPad(event.stageX, event.stageY)) return;

    event.stopImmediatePropagation();
    FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_MOUSE_UP, true, false, event.stageX, event.stageY));
    FlxG.stage.dispatchEvent(new MouseEvent(MouseEvent.RIGHT_CLICK, true, false, event.stageX, event.stageY));
  }
}
#else
/**
 * Stub for platforms that do not need the on-screen editor controls.
 */
class MobileEditorOverlay
{
  public static final MOBILE_UI_SCALE:Float = 1.0;

  public static inline function attach():Void {}

  public static inline function detach():Void {}
}
#end
