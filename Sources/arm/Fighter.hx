package arm;

import iron.Trait;
import iron.math.Vec4;
import iron.object.Object;
import iron.system.Time;

class Fighter extends Trait {
    public var isPlayer = false;
    public var botName = "";
    public var bodyColor = 0xFFFFFFFF;

    public var hp = 100.0;
    public var maxHp = 100.0;
    public var alive = true;

    // Stats (modified by powers)
    public var moveSpeed = 8.0;
    public var fireInterval = 0.45;
    public var bulletDamage = 12.0;
    public var bulletSize = 1.0;
    public var bulletCount = 1;
    public var dashCooldownMax = 2.2;
    public var dashRange = 6.0;
    public var regen = 0.0;
    public var lifesteal = 0.0;
    public var thorns = 0.0;
    public var dashDamage = 0.0;
    public var knockResist = 0.0;

    // Per-frame intent (set by Player / Bot traits)
    public var moveX = 0.0;
    public var moveY = 0.0;
    public var aimX = 1.0;
    public var aimY = 0.0;

    // Knockback velocity
    public var velX = 0.0;
    public var velY = 0.0;

    public var fireTimer = 0.0;
    public var dashTimer = 0.0;
    public var dashActive = 0.0;
    public var dashDirX = 1.0;
    public var dashDirY = 0.0;
    public var iframes = 0.0;
    public var hitFlash = 0.0;

    public var radius = 0.9;
    public var powers: Map<String, Int> = new Map();

    var game: Game;
    var zAxis = new Vec4(0, 0, 1);

    public function new() {
        super();
        notifyOnInit(init);
        notifyOnUpdate(update);
    }

    function init() {
        game = Game.instance;
        var n = object.name;
        if (n == "Player") bodyColor = 0xFF00BCD4;
        else if (n == "Bot1") bodyColor = 0xFFF44336;
        else if (n == "Bot2") bodyColor = 0xFFFF9800;
        else bodyColor = 0xFF9C27B0;
        game.registerFighter(this);
    }

    public function stacks(id: String): Int {
        var v = powers.get(id);
        return v == null ? 0 : v;
    }

    public function applyPower(id: String) {
        var n = stacks(id) + 1;
        powers.set(id, n);
        switch (id) {
            case "rapid": fireInterval = 0.45 / (1 + 0.35 * n);
            case "big": bulletDamage = 12.0 * (1 + 0.6 * n); bulletSize = 1.0 + 0.25 * n;
            case "swift": moveSpeed = 8.0 * (1 + 0.2 * n);
            case "dash": dashRange = 6.0 * (1 + 0.5 * n); dashCooldownMax = 2.2 * Math.max(0.4, 1 - 0.2 * n);
            case "vamp": lifesteal = 0.2 * n;
            case "thorns": thorns = 0.3 * n;
            case "multi": bulletCount = 1 + n;
            case "heavy": maxHp = 100.0 + 50 * n; knockResist = Math.min(0.7, 0.25 * n); hp = Math.min(hp + 50, maxHp);
            case "blitz": dashDamage = 18.0 * n;
            case "regen": regen = 4.0 * n;
        }
    }

    public function resetForRound(x: Float, y: Float) {
        hp = maxHp;
        alive = true;
        show();
        object.transform.loc.set(x, y, 0);
        velX = 0; velY = 0; moveX = 0; moveY = 0;
        aimX = 0; aimY = 0;
        // Face arena center
        var d = Math.sqrt(x * x + y * y) + 0.001;
        aimX = -x / d; aimY = -y / d;
        fireTimer = 0; dashTimer = 0; dashActive = 0; iframes = 0; hitFlash = 0;
        object.transform.scale.set(1, 1, 1);
    }

    public function fullReset() {
        powers = new Map();
        moveSpeed = 8.0; fireInterval = 0.45; bulletDamage = 12.0; bulletSize = 1.0;
        bulletCount = 1; dashCooldownMax = 2.2; dashRange = 6.0; regen = 0.0;
        lifesteal = 0.0; thorns = 0.0; dashDamage = 0.0; knockResist = 0.0; maxHp = 100.0;
    }

    public function tryFire() {
        if (!alive || fireTimer > 0 || game.state != "fight") return;
        fireTimer = fireInterval;
        var px = object.transform.loc.x;
        var py = object.transform.loc.y;
        var base = Math.atan2(aimY, aimX);
        for (i in 0...bulletCount) {
            var off = (i - (bulletCount - 1) / 2) * 0.14;
            var a = base + off;
            var dx = Math.cos(a), dy = Math.sin(a);
            game.spawnProjectile(px + dx * 1.3, py + dy * 1.3, dx * 18.0, dy * 18.0, bulletDamage, bulletSize, this);
        }
    }

    public function tryDash(dx: Float, dy: Float) {
        if (!alive || dashTimer > 0 || game.state != "fight") return;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.01) { dx = aimX; dy = aimY; len = Math.sqrt(dx * dx + dy * dy) + 0.001; }
        dashDirX = dx / len; dashDirY = dy / len;
        dashActive = 0.18;
        dashTimer = dashCooldownMax;
        if (iframes < 0.28) iframes = 0.28;
        if (dashDamage > 0) {
            var sx = object.transform.loc.x;
            var sy = object.transform.loc.y;
            var ex = sx + dashDirX * dashRange;
            var ey = sy + dashDirY * dashRange;
            for (f in game.fighters) {
                if (f == this || !f.alive) continue;
                var fx = f.object.transform.loc.x;
                var fy = f.object.transform.loc.y;
                if (distToSeg(fx, fy, sx, sy, ex, ey) < 1.6) {
                    f.damage(dashDamage, this);
                    var nx = fx - sx, ny = fy - sy;
                    var nl = Math.sqrt(nx * nx + ny * ny) + 0.001;
                    var kb = 10.0 * (1 - f.knockResist);
                    f.velX += nx / nl * kb;
                    f.velY += ny / nl * kb;
                }
            }
        }
    }

    public function damage(amount: Float, source: Fighter) {
        if (!alive || iframes > 0 || game.state != "fight") return;
        if (source == this) return;
        hp -= amount;
        hitFlash = 0.15;
        if (thorns > 0 && source != null && source.alive) {
            source.hp -= amount * thorns;
            if (source.hp <= 0) game.onKill(source, this);
        }
        if (hp <= 0) {
            hp = 0;
            game.onKill(this, source);
        }
    }

    public function heal(amount: Float) {
        if (!alive) return;
        hp = Math.min(maxHp, hp + amount);
    }

    public function hide() { setVisible(object, false); }
    public function show() { setVisible(object, true); }

    function setVisible(o: Object, v: Bool) {
        o.visible = v;
        for (c in o.getChildren()) setVisible(c, v);
    }

    function update() {
        var dt = Time.delta;
        if (dt <= 0) return;
        if (fireTimer > 0) fireTimer -= dt;
        if (dashTimer > 0) dashTimer -= dt;
        if (iframes > 0) iframes -= dt;
        if (hitFlash > 0) hitFlash -= dt;
        if (!alive) return;

        if (regen > 0) heal(regen * dt);

        var vx = moveX * moveSpeed + velX;
        var vy = moveY * moveSpeed + velY;
        if (dashActive > 0) {
            dashActive -= dt;
            var spd = dashRange / 0.18;
            vx = dashDirX * spd;
            vy = dashDirY * spd;
        }
        var loc = object.transform.loc;
        loc.x += vx * dt;
        loc.y += vy * dt;

        // Knockback decay
        var d = Math.pow(0.02, dt);
        velX *= d; velY *= d;

        game.clampToArena(this);
        game.collidePillars(this);

        // Face aim direction (forward = +Y)
        object.transform.rot.fromAxisAngle(zAxis, -Math.atan2(aimY, aimX));

        // Hit-flash scale pop
        var s = hitFlash > 0 ? 1.18 : 1.0;
        object.transform.scale.set(s, s, s);
    }

    static function distToSeg(px: Float, py: Float, ax: Float, ay: Float, bx: Float, by: Float): Float {
        var dx = bx - ax, dy = by - ay;
        var l2 = dx * dx + dy * dy;
        var t = l2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0;
        t = Math.max(0, Math.min(1, t));
        var cx = ax + t * dx - px, cy = ay + t * dy - py;
        return Math.sqrt(cx * cx + cy * cy);
    }
}
