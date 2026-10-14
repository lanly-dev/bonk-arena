package arm;

import iron.Trait;
import iron.math.Vec4;
import iron.object.Object;
import iron.system.Time;

class Fighter extends Trait {
    public var isPlayer = false;
    public var botName = "";
    public var bodyColor = 0xFF9E9E9E;
    public var kit: CharKit = null;

    public var hp = 100.0;
    public var maxHp = 100.0;
    public var alive = true;

    // Stats (modified by kit + powers)
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
    // BAPBAP-ify stats
    public var meleeDamage = 22.0;
    public var meleeRange = 3.2;
    public var meleeKb = 17.0;
    public var knockDealt = 1.0;
    public var specialMax = 8.0;
    public var dashMax = 1;
    public var dashCharges = 1;
    public var secondWind = 0;
    public var shrapnel = 0;
    public var rage = 0;
    public var sizeMult = 1.0;

    // Per-frame intent (set by Player / Bot traits)
    public var moveX = 0.0;
    public var moveY = 0.0;
    public var aimX = 1.0;
    public var aimY = 0.0;

    // Knockback velocity
    public var velX = 0.0;
    public var velY = 0.0;

    // Ring-out credit
    public var lastHitBy: Fighter = null;
    public var lastHitT = 99.0;

    public var fireTimer = 0.0;
    public var bonkTimer = 0.0;
    public var bonkMax = 0.75;
    public var specialTimer = 0.0;
    public var dashTimer = 0.0; // per-charge recharge progress uses dashChargeT
    public var dashChargeT = 0.0;
    public var dashActive = 0.0;
    public var dashDirX = 1.0;
    public var dashDirY = 0.0;
    public var iframes = 0.0;
    public var hitFlash = 0.0;
    public var growT = 0.0;

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
        // Set before registerFighter: Fighter.init runs before Player.init
        // on the same object (trait add order), so Player can't set this first.
        isPlayer = (object.name == "Player");
        game.registerFighter(this);
    }

    public function stacks(id: String): Int {
        var v = powers.get(id);
        return v == null ? 0 : v;
    }

    public function rageMult(): Float {
        if (rage <= 0 || maxHp <= 0) return 1.0;
        return 1.0 + 0.4 * rage * (1.0 - hp / maxHp);
    }

    public function applyPower(id: String) {
        var n = stacks(id) + 1;
        powers.set(id, n);
        // Multiplicative / additive on current values so character kits survive drafts.
        switch (id) {
            case "rapid": fireInterval = Math.max(0.12, fireInterval / 1.35);
            case "big": bulletDamage *= 1.6; bulletSize += 0.25;
            case "swift": moveSpeed *= 1.2;
            case "dash": dashRange *= 1.5; dashCooldownMax = Math.max(0.9, dashCooldownMax * 0.8);
            case "vamp": lifesteal += 0.2;
            case "thorns": thorns += 0.3;
            case "multi": bulletCount += 1;
            case "heavy": maxHp += 50; hp = Math.min(hp + 50, maxHp); knockResist = Math.min(0.85, knockResist + 0.25);
            case "blitz": dashDamage += 18.0;
            case "regen": regen += 4.0;
            case "giant": sizeMult += 0.3; bulletDamage *= 1.15; knockDealt += 0.3;
            case "multidash": dashMax += 1; dashCharges += 1;
            case "bonkaura": meleeRange *= 1.35; meleeDamage *= 1.4;
            case "secondwind": secondWind += 1;
            case "shrapnel": shrapnel += 1;
            case "heavyhits": knockDealt += 0.35;
            case "rage": rage += 1;
            case "anchor": knockResist = Math.min(0.85, knockResist + 0.3); maxHp += 30; hp = Math.min(hp + 30, maxHp);
        }
    }

    public function resetForRound(x: Float, y: Float) {
        if (growT > 0) { maxHp -= 60; growT = 0; }
        hp = maxHp;
        alive = true;
        show();
        object.transform.loc.set(x, y, 0);
        velX = 0; velY = 0; moveX = 0; moveY = 0;
        aimX = 0; aimY = 0;
        var d = Math.sqrt(x * x + y * y) + 0.001;
        aimX = -x / d; aimY = -y / d;
        fireTimer = 0; bonkTimer = 0; specialTimer = 0;
        dashActive = 0; dashChargeT = 0; dashCharges = dashMax;
        iframes = 0; hitFlash = 0;
        lastHitBy = null; lastHitT = 99;
        secondWind = stacks("secondwind");
        object.transform.scale.set(1, 1, 1);
    }

    public function fullReset() {
        powers = new Map();
        kit = null;
        moveSpeed = 8.0; fireInterval = 0.45; bulletDamage = 12.0; bulletSize = 1.0;
        bulletCount = 1; dashCooldownMax = 2.2; dashRange = 6.0; regen = 0.0;
        lifesteal = 0.0; thorns = 0.0; dashDamage = 0.0; knockResist = 0.0; maxHp = 100.0;
        meleeDamage = 22.0; meleeRange = 3.2; meleeKb = 17.0; knockDealt = 1.0;
        specialMax = 8.0; dashMax = 1; dashCharges = 1;
        secondWind = 0; shrapnel = 0; rage = 0; sizeMult = 1.0; growT = 0;
        bodyColor = 0xFF9E9E9E;
    }

    public function tryFire() {
        if (!alive || fireTimer > 0 || game.state != "fight") return;
        fireTimer = fireInterval;
        var px = object.transform.loc.x;
        var py = object.transform.loc.y;
        var base = Math.atan2(aimY, aimX);
        var dmg = bulletDamage * rageMult();
        for (i in 0...bulletCount) {
            var off = (i - (bulletCount - 1) / 2) * 0.14;
            var a = base + off;
            var dx = Math.cos(a), dy = Math.sin(a);
            game.spawnProjectile(px + dx * 1.3, py + dy * 1.3, dx * 18.0, dy * 18.0, dmg, bulletSize, this);
        }
    }

    public function tryBonk() {
        if (!alive || bonkTimer > 0 || game.state != "fight") return;
        bonkTimer = bonkMax;
        var sx = object.transform.loc.x;
        var sy = object.transform.loc.y;
        var dmg = meleeDamage * rageMult();
        var hitAny = false;
        for (f in game.fighters) {
            if (f == this || !f.alive) continue;
            var dx = f.object.transform.loc.x - sx;
            var dy = f.object.transform.loc.y - sy;
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dist > meleeRange + f.radius) continue;
            // Frontal arc (~80 degrees)
            var dot = (dx * aimX + dy * aimY) / (dist + 0.001);
            if (dot < 0.17) continue;
            var nx = dx / (dist + 0.001), ny = dy / (dist + 0.001);
            var kb = meleeKb * knockDealt * (1 - f.knockResist);
            f.velX += nx * kb;
            f.velY += ny * kb;
            f.damage(dmg, this);
            hitAny = true;
        }
        if (hitAny) {
            game.hitstop = 3;
            if (game.cameraRig != null) game.cameraRig.shake(0.35);
            hitFlash = 0.12;
        }
    }

    public function trySpecial() {
        if (!alive || kit == null || specialTimer > 0 || game.state != "fight") return;
        var sx = object.transform.loc.x;
        var sy = object.transform.loc.y;
        switch (kit.specialId) {
            case "slam":
                // Ground Slam: AoE damage + radial knockback
                for (f in game.fighters) {
                    if (f == this || !f.alive) continue;
                    var dx = f.object.transform.loc.x - sx;
                    var dy = f.object.transform.loc.y - sy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist > 6.5 + f.radius) continue;
                    var nx = dx / (dist + 0.001), ny = dy / (dist + 0.001);
                    var kb = 20.0 * knockDealt * (1 - f.knockResist);
                    f.velX += nx * kb;
                    f.velY += ny * kb;
                    f.damage(25.0 * rageMult(), this);
                }
                game.hitstop = 3;
                if (game.cameraRig != null) game.cameraRig.shake(0.6);
            case "shockwave":
                // Shockwave: radial bullet burst
                for (i in 0...12) {
                    var a = i / 12 * Math.PI * 2;
                    var dx = Math.cos(a), dy = Math.sin(a);
                    game.spawnProjectile(sx + dx * 1.3, sy + dy * 1.3, dx * 16.0, dy * 16.0,
                        bulletDamage * 0.8 * rageMult(), bulletSize, this);
                }
                if (game.cameraRig != null) game.cameraRig.shake(0.3);
            case "blink":
                // Blink Strike: teleport toward aim, strike on arrival
                var nx = sx + aimX * 8.0;
                var ny = sy + aimY * 8.0;
                var r = Math.sqrt(nx * nx + ny * ny);
                if (r > 22.0) { nx *= 22.0 / r; ny *= 22.0 / r; }
                object.transform.loc.set(nx, ny, 0);
                game.collidePillars(this);
                velX = 0; velY = 0;
                iframes = Math.max(iframes, 0.5);
                var lx = object.transform.loc.x;
                var ly = object.transform.loc.y;
                for (f in game.fighters) {
                    if (f == this || !f.alive) continue;
                    var dx = f.object.transform.loc.x - lx;
                    var dy = f.object.transform.loc.y - ly;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist > 3.5 + f.radius) continue;
                    var bx = dx / (dist + 0.001), by = dy / (dist + 0.001);
                    var kb = 14.0 * knockDealt * (1 - f.knockResist);
                    f.velX += bx * kb;
                    f.velY += by * kb;
                    f.damage(20.0 * rageMult(), this);
                }
            case "grow":
                // Grow: giant form for 6s
                if (growT > 0) return;
                growT = 6.0;
                maxHp += 60;
                hp += 60;
        }
        specialTimer = specialMax;
    }

    public function tryDash(dx: Float, dy: Float) {
        if (!alive || dashCharges <= 0 || game.state != "fight") return;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len < 0.01) { dx = aimX; dy = aimY; len = Math.sqrt(dx * dx + dy * dy) + 0.001; }
        dashDirX = dx / len; dashDirY = dy / len;
        dashActive = 0.18;
        dashCharges--;
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
                    f.damage(dashDamage * rageMult(), this);
                    var nx = fx - sx, ny = fy - sy;
                    var nl = Math.sqrt(nx * nx + ny * ny) + 0.001;
                    var kb = 10.0 * knockDealt * (1 - f.knockResist);
                    f.velX += nx / nl * kb;
                    f.velY += ny / nl * kb;
                }
            }
        }
    }

    public function damage(amount: Float, source: Fighter) {
        if (!alive || iframes > 0 || game.state != "fight") return;
        if (source == this) return;
        lastHitBy = source;
        lastHitT = 0;
        if (hp - amount <= 0 && secondWind > 0) {
            // Cheat death once per charge
            secondWind--;
            hp = maxHp * 0.4;
            iframes = 1.2;
            hitFlash = 0.3;
            game.msg(game.fighterName(this) + " CHEATED DEATH!", 0xFF69F0AE);
            return;
        }
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
        if (bonkTimer > 0) bonkTimer -= dt;
        if (specialTimer > 0) specialTimer -= dt;
        if (iframes > 0) iframes -= dt;
        if (hitFlash > 0) hitFlash -= dt;
        if (lastHitT < 90) lastHitT += dt;
        if (!alive) return;

        if (regen > 0) heal(regen * dt);

        // Grow expiry
        if (growT > 0) {
            growT -= dt;
            if (growT <= 0) {
                growT = 0;
                maxHp -= 60;
                hp = Math.min(hp, maxHp);
            }
        }

        // Dash charge recharge
        if (dashCharges < dashMax) {
            dashChargeT += dt;
            if (dashChargeT >= dashCooldownMax) {
                dashChargeT = 0;
                dashCharges++;
            }
        }

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

        // Ring-outs: heavy knockback can carry you past the edge.
        // Normal movement is still clamped; only flying bodies escape.
        var kv = Math.sqrt(velX * velX + velY * velY);
        if (kv < 10) game.clampToArena(this);
        var r = Math.sqrt(loc.x * loc.x + loc.y * loc.y);
        if (r > 26.5) {
            game.onKill(this, lastHitT < 2.5 ? lastHitBy : null, true);
            return;
        }

        game.collidePillars(this);

        // Face aim direction (forward = +Y)
        object.transform.rot.fromAxisAngle(zAxis, -Math.atan2(aimY, aimX));

        // Scale: hit-flash pop x kit/power size x grow
        var s = (hitFlash > 0 ? 1.18 : 1.0) * sizeMult * (growT > 0 ? 1.6 : 1.0);
        object.transform.scale.set(s, s, s);
        object.transform.buildMatrix();
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
