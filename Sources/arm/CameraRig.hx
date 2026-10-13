package arm;

import iron.Trait;
import iron.system.Time;

class CameraRig extends Trait {
    public var trauma = 0.0;

    var baseX = 0.0;
    var baseY = 0.0;
    var baseZ = 0.0;

    public function new() {
        super();
        notifyOnInit(function() {
            var loc = object.transform.loc;
            baseX = loc.x; baseY = loc.y; baseZ = loc.z;
            Game.instance.cameraRig = this;
        });
        notifyOnUpdate(update);
    }

    public function shake(amount: Float) {
        trauma = Math.min(1.0, trauma + amount);
    }

    function update() {
        var dt = Time.delta;
        if (trauma <= 0) return;
        trauma = Math.max(0, trauma - dt * 1.6);
        var s = trauma * trauma * 1.1;
        object.transform.loc.set(
            baseX + (Math.random() * 2 - 1) * s,
            baseY + (Math.random() * 2 - 1) * s,
            baseZ + (Math.random() * 2 - 1) * s * 0.5
        );
        if (trauma == 0) object.transform.loc.set(baseX, baseY, baseZ);
    }
}
