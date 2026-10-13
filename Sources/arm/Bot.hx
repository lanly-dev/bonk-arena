package arm;

import iron.Trait;
import iron.math.Vec4;
import iron.system.Time;

class Bot extends Trait {
    var fighter: Fighter;
    var game: Game;

    // Personality
    var aggro = 0.5;
    var accuracy = 0.7;
    var dodgeSkill = 0.5;
    var preferRange = 11.0;
    var strafeDir = 1.0;

    var thinkT = 0.0;
    var tx = 0.0;
    var ty = 0.0;
    var wantFire = false;

    public function new() {
        super();
        notifyOnInit(init);
        notifyOnUpdate(update);
    }

    function init() {
        fighter = object.getTrait(Fighter);
        game = Game.instance;
        var kind = Std.random(3);
        if (kind == 0) {
            aggro = 0.85; accuracy = 0.6; dodgeSkill = 0.45; preferRange = 8.0;
            fighter.botName = "Aggro-Bot";
        } else if (kind == 1) {
            aggro = 0.35; accuracy = 0.9; dodgeSkill = 0.6; preferRange = 14.0;
            fighter.botName = "Sniper-Bot";
        } else {
            aggro = 0.5; accuracy = 0.7; dodgeSkill = 0.85; preferRange = 11.0;
            fighter.botName = "Ninja-Bot";
        }
        if (Math.random() < 0.5) strafeDir = -strafeDir;
        thinkT = Math.random() * 0.12;
    }

    function nearestEnemy(): Fighter {
        var best: Fighter = null;
        var bd = 1e18;
        var p = fighter.object.transform.loc;
        for (f in game.fighters) {
            if (f == fighter || !f.alive) continue;
            var dx = f.object.transform.loc.x - p.x;
            var dy = f.object.transform.loc.y - p.y;
            var d = dx * dx + dy * dy;
            if (d < bd) { bd = d; best = f; }
        }
        return best;
    }

    function update() {
        if (game.state != "fight" || !fighter.alive) {
            fighter.moveX = 0; fighter.moveY = 0;
            return;
        }
        var dt = Time.delta;
        var p = fighter.object.transform.loc;

        // Dodge incoming projectiles
        for (pr in game.projectiles) {
            if (pr.owner == fighter || pr.dead) continue;
            var rx = p.x - pr.object.transform.loc.x;
            var ry = p.y - pr.object.transform.loc.y;
            var vx = pr.vx, vy = pr.vy;
            var v2 = vx * vx + vy * vy;
            if (v2 < 0.01) continue;
            var t = -(rx * vx + ry * vy) / v2;
            if (t > 0 && t < 0.45) {
                var cx = pr.object.transform.loc.x + vx * t;
                var cy = pr.object.transform.loc.y + vy * t;
                var dx = p.x - cx, dy = p.y - cy;
                if (dx * dx + dy * dy < 1.44 && Math.random() < dodgeSkill) {
                    var l = Math.sqrt(v2);
                    var qx = -vy / l, qy = vx / l;
                    if (Math.random() < 0.5) { qx = -qx; qy = -qy; }
                    fighter.tryDash(qx, qy);
                    break;
                }
            }
        }

        thinkT -= dt;
        if (thinkT <= 0) {
            thinkT = 0.12 + Math.random() * 0.06;
            think(p);
        }

        fighter.moveX = tx;
        fighter.moveY = ty;
        if (wantFire) fighter.tryFire();
    }

    function think(p: Vec4) {
        var e = nearestEnemy();
        tx = 0; ty = 0; wantFire = false;
        if (e == null) return;
        var ep = e.object.transform.loc;
        var dx = ep.x - p.x, dy = ep.y - p.y;
        var dist = Math.sqrt(dx * dx + dy * dy) + 0.001;
        var nx = dx / dist, ny = dy / dist;

        // Zone safety first
        var pr = Math.sqrt(p.x * p.x + p.y * p.y);
        if (pr > game.zoneRadius - 1.5) {
            tx = -p.x / pr; ty = -p.y / pr;
            aimAt(e, dist);
            wantFire = dist < 20;
            return;
        }

        // Flee when weak and enemy close
        if (fighter.hp < fighter.maxHp * 0.3 && dist < 12) {
            tx = -nx; ty = -ny;
            if (Math.random() < 0.35) { tx = -ny * strafeDir; ty = nx * strafeDir; }
            aimAt(e, dist);
            wantFire = true;
            return;
        }

        // Engage: range control + strafing orbit
        if (Math.random() < 0.06) strafeDir = -strafeDir;
        if (dist > preferRange + 3) { tx = nx; ty = ny; }
        else if (dist < preferRange - 3) { tx = -nx; ty = -ny; }
        else { tx = -ny * strafeDir; ty = nx * strafeDir; }
        tx += nx * (aggro - 0.5) * 0.6;
        ty += ny * (aggro - 0.5) * 0.6;
        var tl = Math.sqrt(tx * tx + ty * ty);
        if (tl > 0.01) { tx /= tl; ty /= tl; }

        aimAt(e, dist);
        wantFire = dist < 21;
    }

    function aimAt(e: Fighter, dist: Float) {
        var p = fighter.object.transform.loc;
        var ep = e.object.transform.loc;
        // Lead the target a little
        var t = dist / 18.0;
        var gx = ep.x + e.moveX * e.moveSpeed * t * 0.8;
        var gy = ep.y + e.moveY * e.moveSpeed * t * 0.8;
        var dx = gx - p.x, dy = gy - p.y;
        var err = (1 - accuracy) * 0.35;
        var a = Math.atan2(dy, dx) + (Math.random() * 2 - 1) * err;
        fighter.aimX = Math.cos(a);
        fighter.aimY = Math.sin(a);
    }

    public function draftPick(options: Array<PowerDef>): PowerDef {
        // Weighted random: prefer damage & mobility
        var best: PowerDef = null;
        var bs = -1.0;
        for (o in options) {
            var w = Math.random();
            if (o.id == "big" || o.id == "rapid" || o.id == "multi") w += 0.5;
            if (o.id == "swift" || o.id == "dash") w += 0.3;
            if (w > bs) { bs = w; best = o; }
        }
        return best;
    }
}
