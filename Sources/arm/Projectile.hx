package arm;

import iron.Trait;
import iron.system.Time;

class Projectile extends Trait {
    public var vx = 0.0;
    public var vy = 0.0;
    public var damage = 12.0;
    public var owner: Fighter;
    public var life = 2.5;
    public var dead = false;

    var game: Game;

    public function new() {
        super();
        notifyOnInit(function() {
            game = Game.instance;
            game.registerProjectile(this);
        });
        notifyOnUpdate(update);
    }

    public function setup(px: Float, py: Float, vx: Float, vy: Float, damage: Float, size: Float, owner: Fighter) {
        object.transform.loc.set(px, py, 1.05);
        object.transform.scale.set(size, size, size);
        this.vx = vx; this.vy = vy;
        this.damage = damage;
        this.owner = owner;
        this.life = 2.5;
        this.dead = false;
    }

    function update() {
        if (dead) return;
        var dt = Time.delta;
        if (dt <= 0) return;
        life -= dt;
        if (life <= 0) { destroy(); return; }

        var loc = object.transform.loc;
        loc.x += vx * dt;
        loc.y += vy * dt;

        var r = Math.sqrt(loc.x * loc.x + loc.y * loc.y);
        if (r > 27) { destroy(); return; }
        if (game.hitPillar(loc.x, loc.y, 0.35)) { destroy(); return; }

        var pr = 0.35 * object.transform.scale.x;
        for (f in game.fighters) {
            if (f == owner || !f.alive) continue;
            var dx = f.object.transform.loc.x - loc.x;
            var dy = f.object.transform.loc.y - loc.y;
            var rr = f.radius + pr;
            if (dx * dx + dy * dy < rr * rr) {
                var l = Math.sqrt(vx * vx + vy * vy) + 0.001;
                var kd = (owner != null) ? owner.knockDealt : 1.0;
                var kb = 7.0 * kd * (1 - f.knockResist);
                f.velX += vx / l * kb;
                f.velY += vy / l * kb;
                f.damage(damage, owner);
                if (owner != null && owner.lifesteal > 0 && owner.alive) owner.heal(damage * owner.lifesteal);
                destroy();
                return;
            }
        }
    }

    public function destroy() {
        if (dead) return;
        dead = true;
        if (game != null) game.unregisterProjectile(this);
        object.remove();
    }
}
