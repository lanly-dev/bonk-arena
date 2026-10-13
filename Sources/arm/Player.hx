package arm;

import iron.Trait;
import iron.Scene;
import iron.math.Ray;
import iron.math.RayCaster;
import iron.math.Vec4;
import iron.system.Input;
import iron.system.Time;
import kha.input.Surface;

class Player extends Trait {
    var fighter: Fighter;
    var game: Game;
    var groundPlane = new Plane();
    var kb: iron.system.Input.Keyboard;
    var mouse: iron.system.Input.Mouse;
    var lastTap = -10.0;

    // Real touch state via kha.input.Surface. iron's Input.getSurface() is
    // typedef'd to Mouse ("Map to mouse for now..") so surface.down("tip")
    // was literally the left mouse button — holding click to fire also
    // drove touch movement. Real touch events only fire here.
    // Track whichever finger goes down first (touch ids are not guaranteed
    // to start at 0 on every platform; iOS remaps them, others may not).
    var touch: Surface;
    var touchId = -1;
    var touchActive = false;
    var touchX = 0.0;
    var touchY = 0.0;

    public function new() {
        super();
        notifyOnInit(init);
        notifyOnUpdate(update);
    }

    function init() {
        fighter = object.getTrait(Fighter);
        fighter.isPlayer = true;
        game = Game.instance;
        kb = Input.getKeyboard();
        mouse = Input.getMouse();
        groundPlane.set(new Vec4(0, 0, 1), new Vec4(0, 0, 1.0));
        touch = Surface.get();
        if (touch != null) touch.notify(onTouchStart, onTouchEnd, onTouchMove);
    }

    function onTouchStart(id: Int, x: Int, y: Int) {
        if (touchId != -1) return; // already tracking a finger
        touchId = id;
        touchActive = true;
        touchX = x; touchY = y;
        // Double-tap = dash toward aim
        var now = Time.realTime();
        if (now - lastTap < 0.35) fighter.tryDash(fighter.aimX, fighter.aimY);
        lastTap = now;
    }

    function onTouchEnd(id: Int, x: Int, y: Int) {
        if (id == touchId) { touchId = -1; touchActive = false; }
    }

    function onTouchMove(id: Int, x: Int, y: Int) {
        if (id != touchId) return;
        touchX = x; touchY = y;
    }

    function update() {
        if (game.state == "draft") {
            if (kb.started("1")) game.chooseDraft(0);
            else if (kb.started("2")) game.chooseDraft(1);
            else if (kb.started("3")) game.chooseDraft(2);
            if (mouse.started("left")) game.clickDraft(mouse.x, mouse.y);
            return;
        }
        if (game.state == "over") {
            if (mouse.started("left")) game.rematch();
            return;
        }
        if (game.state != "fight") return;

        var x = 0.0, y = 0.0;
        if (kb.down("a") || kb.down("left")) x -= 1;
        if (kb.down("d") || kb.down("right")) x += 1;
        if (kb.down("w") || kb.down("up")) y += 1;
        if (kb.down("s") || kb.down("down")) y -= 1;

        if (touchActive) {
            // Touch: one finger = move toward finger, aim & fire at finger.
            // Kha reports touch in canvas pixels, same space as mouse.x/y.
            aimFromScreen(touchX, touchY);
            var fx0 = fighter.object.transform.loc.x;
            var fy0 = fighter.object.transform.loc.y;
            var tdx = aimWorldX - fx0, tdy = aimWorldY - fy0;
            var tdl = Math.sqrt(tdx * tdx + tdy * tdy);
            if (tdl > 2.0) { x = tdx / tdl; y = tdy / tdl; }
        }
        else {
            // Desktop: aim from mouse; mouse fire can no longer leak into the touch path
            aimFromScreen(mouse.x, mouse.y);
        }

        var l = Math.sqrt(x * x + y * y);
        if (l > 0) { x /= l; y /= l; }
        fighter.moveX = x;
        fighter.moveY = y;

        if (mouse.down("left") || touchActive) fighter.tryFire();
        if (mouse.started("right") || kb.started("shift")) fighter.tryDash(x, y);
    }

    var aimWorldX = 0.0;
    var aimWorldY = 0.0;

    function aimFromScreen(sx: Float, sy: Float) {
        var cam = Scene.active.camera;
        if (cam == null) return;
        var ray = RayCaster.getRay(sx, sy, cam);
        var p = ray.intersectPlane(groundPlane);
        if (p == null) return;
        aimWorldX = p.x; aimWorldY = p.y;
        var fx = fighter.object.transform.loc.x;
        var fy = fighter.object.transform.loc.y;
        var dx = p.x - fx, dy = p.y - fy;
        var dl = Math.sqrt(dx * dx + dy * dy);
        if (dl > 0.05) { fighter.aimX = dx / dl; fighter.aimY = dy / dl; }
    }
}
