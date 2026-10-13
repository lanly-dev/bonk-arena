package arm;

import iron.Trait;
import iron.App;
import iron.Scene;
import iron.object.Object;
import iron.math.Vec4;
import iron.system.Time;
import iron.data.Data;

class Game extends Trait {
    public static var instance: Game;

    public var fighters: Array<Fighter> = [];
    public var projectiles: Array<Projectile> = [];
    public var pillars: Array<{x: Float, y: Float, half: Float}> = [];
    public var zone: Zone;
    public var cameraRig: CameraRig;
    public var playerFighter: Fighter;

    public var state = "countdown"; // countdown | fight | draft | over
    public var stateT = 0.0;
    public var round = 1;
    public var roundWins: Array<Int> = [];
    public var winsNeeded = 3;

    public var zoneRadius = 22.0;
    public var zoneDps = 8.0;

    var phases: Array<{wait: Float, shrink: Float, target: Float, dps: Float}> = [
        {wait: 20.0, shrink: 15.0, target: 15.0, dps: 8.0},
        {wait: 12.0, shrink: 12.0, target: 10.0, dps: 12.0},
        {wait: 10.0, shrink: 10.0, target: 6.0, dps: 16.0},
    ];
    var phaseIdx = 0;
    var phaseT = 0.0;
    var shrinking = false;
    var shrinkFrom = 22.0;
    var overtime = 0.0;

    public var draftOptions: Array<PowerDef> = [];
    var draftPicked = false;
    var draftCards: Array<{x: Float, y: Float, w: Float, h: Float}> = [];

    var messages: Array<{text: String, t: Float, color: Int}> = [];
    var font: kha.Font = null;
    var hitstop = 0;

    var spawnPoints: Array<{x: Float, y: Float}> = [
        {x: 0.0, y: -10.0}, {x: 0.0, y: 10.0}, {x: -10.0, y: 0.0}, {x: 10.0, y: 0.0}
    ];

    public function new() {
        super();
        instance = this;
        notifyOnInit(init);
        notifyOnUpdate(update);
        notifyOnRender2D(render2D);
    }

    function init() {
        Data.getFont("font_default.ttf", function(f: kha.Font) { font = f; });
        var pg = Scene.active.getChild("Pillars");
        if (pg != null) {
            for (c in pg.getChildren()) {
                pillars.push({x: c.transform.loc.x, y: c.transform.loc.y, half: 1.45});
            }
        }
        resetPositions();
        msg("ROUND 1 - FIGHT!", 0xFFFFFFFF);
    }

    public function registerFighter(f: Fighter) {
        fighters.push(f);
        roundWins.push(0);
        if (f.isPlayer) playerFighter = f;
    }

    public function registerProjectile(p: Projectile) {
        projectiles.push(p);
    }

    public function unregisterProjectile(p: Projectile) {
        projectiles.remove(p);
    }

    public function fighterName(f: Fighter): String {
        return f.isPlayer ? "YOU" : f.botName;
    }

    public function msg(text: String, color: Int) {
        messages.push({text: text, t: 3.5, color: color});
        if (messages.length > 6) messages.shift();
    }

    public function spawnProjectile(x: Float, y: Float, vx: Float, vy: Float, dmg: Float, size: Float, owner: Fighter) {
        Scene.active.spawnObject("ProjectileTemplate", null, function(o: Object) {
            var p = o.getTrait(Projectile);
            if (p != null) p.setup(x, y, vx, vy, dmg, size, owner);
        });
    }

    public function onKill(dead: Fighter, killer: Fighter) {
        if (!dead.alive) return;
        dead.alive = false;
        dead.hide();
        dead.moveX = 0; dead.moveY = 0;
        hitstop = 4;
        if (cameraRig != null) cameraRig.shake(0.7);
        var dn = fighterName(dead);
        if (killer == null || killer == dead) {
            msg(dn + " got ZONED!", 0xFFFF9800);
        } else {
            msg(fighterName(killer) + " bonked " + dn + "!", killer.isPlayer ? 0xFF4FC3F7 : 0xFFFF8A65);
        }
        var aliveCount = 0;
        var last: Fighter = null;
        for (f in fighters) if (f.alive) { aliveCount++; last = f; }
        if (aliveCount <= 1) endRound(last);
    }

    function endRound(winner: Fighter) {
        if (winner != null) {
            var i = fighters.indexOf(winner);
            roundWins[i]++;
            msg(fighterName(winner) + " takes round " + round + "!", 0xFFFFFF00);
        } else {
            msg("Round " + round + " - draw!", 0xFFFFFF00);
        }
        for (p in projectiles.copy()) p.destroy();

        // Bots draft immediately
        var opts = rollPowers();
        for (f in fighters) {
            if (f.isPlayer) continue;
            var bot = f.object.getTrait(Bot);
            var pick = bot != null ? bot.draftPick(opts) : opts[Std.random(opts.length)];
            f.applyPower(pick.id);
        }

        // Match over?
        for (i in 0...fighters.length) {
            if (roundWins[i] >= winsNeeded) {
                state = "over";
                stateT = 0;
                msg(fighterName(fighters[i]) + " WINS THE MATCH!", 0xFFFFFF00);
                return;
            }
        }

        state = "draft";
        stateT = 0;
        draftPicked = false;
        draftOptions = rollPowers();
    }

    function rollPowers(): Array<PowerDef> {
        var pool = Powers.ALL.copy();
        var out: Array<PowerDef> = [];
        for (k in 0...3) {
            var idx = Std.random(pool.length);
            out.push(pool[idx]);
            pool.splice(idx, 1);
        }
        return out;
    }

    public function chooseDraft(i: Int) {
        if (state != "draft" || draftPicked || i < 0 || i >= draftOptions.length) return;
        draftPicked = true;
        var me = playerFighter;
        if (me != null) {
            me.applyPower(draftOptions[i].id);
            msg("You took " + draftOptions[i].name + "!", 0xFF69F0AE);
        }
        resetRound();
    }

    public function clickDraft(mx: Float, my: Float) {
        for (i in 0...draftCards.length) {
            var c = draftCards[i];
            if (mx >= c.x && mx <= c.x + c.w && my >= c.y && my <= c.y + c.h) {
                chooseDraft(i);
                return;
            }
        }
    }

    function resetPositions() {
        for (i in 0...fighters.length) {
            var sp = spawnPoints[i % spawnPoints.length];
            fighters[i].resetForRound(sp.x, sp.y);
        }
    }

    function resetRound() {
        round++;
        resetPositions();
        zoneRadius = 22.0;
        zoneDps = 8.0;
        if (zone != null) zone.setRadius(22.0);
        phaseIdx = 0; phaseT = 0; shrinking = false; overtime = 0;
        state = "countdown";
        stateT = 0;
        msg("ROUND " + round + " - FIGHT!", 0xFFFFFFFF);
    }

    public function rematch() {
        for (f in fighters) f.fullReset();
        for (i in 0...roundWins.length) roundWins[i] = 0;
        round = 0;
        resetRound();
    }

    public function clampToArena(f: Fighter) {
        var loc = f.object.transform.loc;
        var r = Math.sqrt(loc.x * loc.x + loc.y * loc.y);
        var maxR = 24.0;
        if (r > maxR) {
            loc.x *= maxR / r;
            loc.y *= maxR / r;
        }
    }

    public function collidePillars(f: Fighter) {
        var loc = f.object.transform.loc;
        for (pl in pillars) {
            var cx = Math.max(pl.x - pl.half, Math.min(loc.x, pl.x + pl.half));
            var cy = Math.max(pl.y - pl.half, Math.min(loc.y, pl.y + pl.half));
            var dx = loc.x - cx, dy = loc.y - cy;
            var d2 = dx * dx + dy * dy;
            if (d2 < f.radius * f.radius) {
                if (d2 > 0.0001) {
                    var d = Math.sqrt(d2);
                    loc.x = cx + dx / d * f.radius;
                    loc.y = cy + dy / d * f.radius;
                } else {
                    loc.x = pl.x + pl.half + f.radius;
                }
            }
        }
    }

    public function hitPillar(x: Float, y: Float, r: Float): Bool {
        for (pl in pillars) {
            var cx = Math.max(pl.x - pl.half, Math.min(x, pl.x + pl.half));
            var cy = Math.max(pl.y - pl.half, Math.min(y, pl.y + pl.half));
            var dx = x - cx, dy = y - cy;
            if (dx * dx + dy * dy < r * r) return true;
        }
        return false;
    }

    function update() {
        var dt = Time.delta;
        if (dt <= 0) return;

        if (hitstop > 0) {
            hitstop--;
            Time.scale = 0.05;
            if (hitstop == 0) Time.scale = 1.0;
        }

        for (m in messages) m.t -= dt;
        while (messages.length > 0 && messages[0].t <= 0) messages.shift();

        stateT += dt;

        if (state == "countdown") {
            if (stateT >= 3.0) { state = "fight"; stateT = 0; }
        } else if (state == "fight") {
            if (phaseIdx < phases.length) {
                var ph = phases[phaseIdx];
                if (!shrinking) {
                    phaseT += dt;
                    if (phaseT >= ph.wait) {
                        shrinking = true; phaseT = 0;
                        shrinkFrom = zoneRadius;
                        zoneDps = ph.dps;
                        msg("ZONE SHRINKING!", 0xFFFF5722);
                    }
                } else {
                    phaseT += dt;
                    var k = Math.min(1, phaseT / ph.shrink);
                    zoneRadius = shrinkFrom + (ph.target - shrinkFrom) * k;
                    if (zone != null) zone.setRadius(zoneRadius);
                    if (k >= 1) { shrinking = false; phaseT = 0; phaseIdx++; }
                }
            } else {
                overtime += dt;
                zoneDps = 20 + overtime * 2;
                if (overtime > 25) {
                    var best: Fighter = null;
                    var bh = -1.0;
                    for (f in fighters) if (f.alive) {
                        var h = f.hp / f.maxHp;
                        if (h > bh) { bh = h; best = f; }
                    }
                    endRound(best);
                }
            }
        }
    }

    // ---------------- HUD ----------------

    function render2D(g: kha.graphics2.Graphics) {
        if (font == null) return;
        var w = App.w();
        var h = App.h();
        var s = h / 720.0; // UI scale

        // Kill feed (top-left)
        g.font = font;
        var fs = Math.round(20 * s);
        g.fontSize = fs;
        var my = 14 * s;
        for (m in messages) {
            var a = Math.min(1, m.t);
            g.color = fade(m.color, a);
            g.drawString(m.text, 14 * s, my);
            my += fs + 10 * s;
        }

        // Top center: round + win pips
        var cx = w / 2;
        g.color = kha.Color.White;
        centerText(g, "ROUND " + round, cx, 12 * s, Math.round(26 * s));
        var px = cx - (fighters.length * 44 * s) / 2;
        for (i in 0...fighters.length) {
            var f = fighters[i];
            g.color = kha.Color.fromValue(f.bodyColor);
            g.fillRect(px, 48 * s, 18 * s, 18 * s); // fighter dot
            g.color = kha.Color.fromValue(0xFFFFFF00);
            for (k in 0...roundWins[i]) {
                g.fillRect(px + k * 8 * s, 70 * s, 6 * s, 6 * s); // win pips
            }
            px += 44 * s;
        }

        // Zone status (top-right)
        g.fontSize = Math.round(20 * s);
        var zt = "";
        var zc = 0xFFFFFFFF;
        if (state == "fight") {
            if (shrinking) { zt = "!! ZONE SHRINKING !!"; zc = 0xFFFF5722; }
            else if (phaseIdx < phases.length) {
                var left = Math.ceil(phases[phaseIdx].wait - phaseT);
                zt = "Zone shrinks in " + left + "s";
            } else { zt = "SUDDEN DEATH"; zc = 0xFFFF0000; }
        }
        g.color = kha.Color.fromValue(zc);
        rightText(g, zt, w - 14 * s, 14 * s, Math.round(20 * s));

        // Player HP bar (bottom-center)
        var me = playerFighter;
        if (me != null) {
            var bw = 320 * s, bh = 22 * s;
            var bx = w / 2 - bw / 2, by = h - 60 * s;
            g.color = kha.Color.fromValue(0xAA222222);
            g.fillRect(bx, by, bw, bh);
            var hpk = Math.max(0, me.hp / me.maxHp);
            g.color = kha.Color.fromValue(hpk > 0.5 ? 0xFF69F0AE : (hpk > 0.25 ? 0xFFFFB300 : 0xFFE53935));
            g.fillRect(bx, by, bw * hpk, bh);
            // power icons
            var ix = w / 2 - bw / 2;
            g.fontSize = Math.round(16 * s);
            for (id in me.powers.keys()) {
                var pd = Powers.byId(id);
                if (pd == null) continue;
                g.color = kha.Color.fromValue(pd.color);
                g.fillRect(ix, by - 34 * s, 28 * s, 28 * s);
                g.color = kha.Color.Black;
                g.drawString("" + me.powers.get(id), ix + 8 * s, by - 32 * s);
                ix += 34 * s;
            }
        }

        // Countdown
        if (state == "countdown") {
            var n = 3 - Math.floor(stateT);
            var txt = n > 0 ? "" + n : "GO!";
            g.color = kha.Color.White;
            centerText(g, txt, w / 2, h / 2 - 60 * s, Math.round(90 * s));
        }

        // Draft overlay
        if (state == "draft") {
            g.color = kha.Color.fromValue(0xCC000000);
            g.fillRect(0, 0, w, h);
            g.color = kha.Color.White;
            centerText(g, "DRAFT A POWER  (click or 1/2/3)", w / 2, 120 * s, Math.round(34 * s));
            draftCards = [];
            var cw = 300 * s, ch = 170 * s, gap = 30 * s;
            var totalW = 3 * cw + 2 * gap;
            var sx = w / 2 - totalW / 2;
            var sy = h / 2 - ch / 2;
            for (i in 0...draftOptions.length) {
                var pd = draftOptions[i];
                var cx0 = sx + i * (cw + gap);
                draftCards.push({x: cx0, y: sy, w: cw, h: ch});
                g.color = kha.Color.fromValue(0xFF222831);
                g.fillRect(cx0, sy, cw, ch);
                g.color = kha.Color.fromValue(pd.color);
                g.fillRect(cx0, sy, cw, 10 * s);
                g.color = kha.Color.White;
                centerText(g, pd.name, cx0 + cw / 2, sy + 30 * s, Math.round(26 * s));
                g.color = kha.Color.fromValue(0xFFBBBBBB);
                centerText(g, pd.desc, cx0 + cw / 2, sy + 80 * s, Math.round(19 * s));
                var st = me != null ? me.stacks(pd.id) : 0;
                if (st > 0) {
                    g.color = kha.Color.fromValue(0xFF69F0AE);
                    centerText(g, "owned x" + st, cx0 + cw / 2, sy + 115 * s, Math.round(19 * s));
                }
            }
        }

        // Match over
        if (state == "over") {
            g.color = kha.Color.fromValue(0xCC000000);
            g.fillRect(0, 0, w, h);
            var champ: Fighter = null;
            for (i in 0...fighters.length) if (roundWins[i] >= winsNeeded) champ = fighters[i];
            g.color = kha.Color.fromValue(0xFFFFFF00);
            var t = champ != null ? fighterName(champ) + " WINS!" : "DRAW!";
            centerText(g, t, w / 2, h / 2 - 40 * s, Math.round(64 * s));
            g.color = kha.Color.White;
            centerText(g, "click to rematch", w / 2, h / 2 + 40 * s, Math.round(24 * s));
        }
    }

    function fade(color: Int, a: Float): kha.Color {
        var c = kha.Color.fromValue(color);
        c.A = Math.round(a * 255) / 255;
        return c;
    }

    function centerText(g: kha.graphics2.Graphics, s: String, cx: Float, y: Float, size: Int) {
        g.fontSize = size;
        var tw = font.width(size, s);
        g.drawString(s, cx - tw / 2, y);
    }

    function rightText(g: kha.graphics2.Graphics, s: String, rx: Float, y: Float, size: Int) {
        g.fontSize = size;
        var tw = font.width(size, s);
        g.drawString(s, rx - tw, y);
    }
}
