package arm;

import iron.Trait;
import iron.system.Time;

class Zone extends Trait {
    var game: Game;

    public function new() {
        super();
        notifyOnInit(function() {
            game = Game.instance;
            game.zone = this;
            setRadius(game.zoneRadius);
        });
        notifyOnUpdate(update);
    }

    // Ring mesh has base major radius 1 -> scale to current radius
    public function setRadius(r: Float) {
        object.transform.scale.set(r, r, 1.0);
        object.transform.buildMatrix();
    }

    function update() {
        if (game.state != "fight") return;
        var dt = Time.delta;
        if (dt <= 0) return;
        var r = game.zoneRadius;
        for (f in game.fighters) {
            if (!f.alive) continue;
            var loc = f.object.transform.loc;
            if (Math.sqrt(loc.x * loc.x + loc.y * loc.y) > r) {
                f.damage(game.zoneDps * dt, null);
            }
        }
    }
}
