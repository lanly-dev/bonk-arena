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

    public var state = "select"; // select | countdown | fight | draft | over
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
    public var hitstop = 0;

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
        msg("CHOOSE YOUR FIGHTER!", 0xFFFFFFFF);
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

    public function onKill(dead: Fighter, killer: Fighter, ringOut = false) {
        if (!dead.alive) return;
        dead.alive = false;
        dead.hide();
        dead.moveX = 0; dead.moveY = 0;
        hitstop = 4;
        if (cameraRig != null) cameraRig.shake(0.7);
        var dn = fighterName(dead);
        if (ringOut) {
            if (killer != null && killer != dead) msg(fighterName(killer) + " RANG OUT " + dn + "!", 0xFFFFFF00);
            else msg(dn + " got RUNG OUT!", 0xFFFF9800);
        } else if (killer == null || killer == dead) {
            msg(dn + " got ZONED!", 0xFFFF9800);
        } else {
            msg(fighterName(killer) + " bonked " + dn + "!", killer.isPlayer ? 0xFF4FC3F7 : 0xFFFF8A65);
        }
        // Shrapnel: kills explode into bullets
        if (killer != null && killer != dead && killer.alive && killer.shrapnel > 0) {
            var dx = dead.object.transform.loc.x;
            var dy = dead.object.transform.loc.y;
            var n = 4 * killer.shrapnel;
            for (i in 0...n) {
                var a = i / n * Math.PI * 2 + Math.random() * 0.4;
                var c = Math.cos(a), s2 = Math.sin(a);
                spawnProjectile(dx + c * 1.2, dy + s2 * 1.2, c * 14.0, s2 * 14.0,
                    killer.bulletDamage * 0.6, killer.bulletSize * 0.8, killer);
            }
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
        state = "select";
        stateT = 0;
        msg("CHOOSE YOUR FIGHTER!", 0xFFFFFFFF);
    }

    // ---- Character select ----

    var selectCards: Array<{x: Float, y: Float, w: Float, h: Float}> = [];

    public function chooseCharacter(i: Int) {
        if (state != "select" || i < 0 || i >= CharKit.ALL.length) return;
        var me = playerFighter;
        if (me != null) {
            me.fullReset();
            CharKit.ALL[i].applyTo(me);
            msg("You are " + CharKit.ALL[i].name + "!", 0xFF69F0AE);
        }
        startMatch();
    }

    public function clickSelect(mx: Float, my: Float) {
        for (i in 0...selectCards.length) {
            var c = selectCards[i];
            if (mx >= c.x && mx <= c.x + c.w && my >= c.y && my <= c.y + c.h) {
                chooseCharacter(i);
                return;
            }
        }
    }

    function startMatch() {
        // Bots get random unique kits
        var pool = CharKit.ALL.copy();
        for (f in fighters) {
            if (f.isPlayer) continue;
            f.fullReset();
            var idx = Std.random(pool.length);
            var kit = pool[idx];
            pool.splice(idx, 1);
            kit.applyTo(f);
            f.botName = kit.name;
        }
        resetRound();
    }

    // ---- Touch/mouse action buttons (fight state) ----

    var btnBonk: {x: Float, y: Float, w: Float, h: Float} = null;
    var btnSpecial: {x: Float, y: Float, w: Float, h: Float} = null;

    public function uiButtonAt(mx: Float, my: Float): String {
        if (state != "fight") return null;
        if (btnBonk != null && mx >= btnBonk.x && mx <= btnBonk.x + btnBonk.w
            && my >= btnBonk.y && my <= btnBonk.y + btnBonk.h) return "bonk";
        if (btnSpecial != null && mx >= btnSpecial.x && mx <= btnSpecial.x + btnSpecial.w
            && my >= btnSpecial.y && my <= btnSpecial.y + btnSpecial.h) return "special";
        return null;
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
            // Character name + special cooldown
            if (me.kit != null) {
                g.color = kha.Color.fromValue(me.kit.color);
                centerText(g, me.kit.name, w / 2, by - 64 * s, Math.round(18 * s));
                var sw = 200 * s, sh = 12 * s;
                var sx2 = w / 2 - sw / 2, sy2 = by + bh + 8 * s;
                g.color = kha.Color.fromValue(0xAA222222);
                g.fillRect(sx2, sy2, sw, sh);
                var rk = me.specialMax > 0 ? 1 - me.specialTimer / me.specialMax : 1;
                if (rk < 0) rk = 0; if (rk > 1) rk = 1;
                g.color = kha.Color.fromValue(rk >= 1 ? 0xFF69F0AE : 0xFF4FC3F7);
                g.fillRect(sx2, sy2, sw * rk, sh);
                g.color = kha.Color.White;
                centerText(g, me.kit.specialName + (rk >= 1 ? " READY" : ""), w / 2, sy2 + sh + 6 * s, Math.round(15 * s));
            }
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

        // Character select
        if (state == "select") {
            g.color = kha.Color.fromValue(0xCC000000);
            g.fillRect(0, 0, w, h);
            g.color = kha.Color.White;
            centerText(g, "CHOOSE YOUR FIGHTER  (click or 1-4)", w / 2, 90 * s, Math.round(32 * s));
            selectCards = [];
            var cw = 270 * s, ch = 320 * s, gap = 24 * s;
            var totalW = 4 * cw + 3 * gap;
            var sx = w / 2 - totalW / 2;
            var sy = h / 2 - ch / 2 + 30 * s;
            for (i in 0...CharKit.ALL.length) {
                var kit = CharKit.ALL[i];
                var cx0 = sx + i * (cw + gap);
                selectCards.push({x: cx0, y: sy, w: cw, h: ch});
                g.color = kha.Color.fromValue(0xFF222831);
                g.fillRect(cx0, sy, cw, ch);
                g.color = kha.Color.fromValue(kit.color);
                g.fillRect(cx0, sy, cw, 12 * s);
                g.color = kha.Color.White;
                centerText(g, kit.name, cx0 + cw / 2, sy + 36 * s, Math.round(26 * s));
                g.color = kha.Color.fromValue(0xFFBBBBBB);
                var dl = wrapLines(g, kit.desc, cw - 30 * s, Math.round(17 * s));
                var dyy = sy + 84 * s;
                for (ln in dl) { centerText(g, ln, cx0 + cw / 2, dyy, Math.round(17 * s)); dyy += 24 * s; }
                g.color = kha.Color.fromValue(0xFFFFFF00);
                centerText(g, kit.specialName, cx0 + cw / 2, sy + 170 * s, Math.round(22 * s));
                g.color = kha.Color.fromValue(0xFFBBBBBB);
                var sl = wrapLines(g, kit.specialDesc, cw - 30 * s, Math.round(17 * s));
                var syy = sy + 204 * s;
                for (ln in sl) { centerText(g, ln, cx0 + cw / 2, syy, Math.round(17 * s)); syy += 24 * s; }
                g.color = kha.Color.fromValue(0xFF888888);
                centerText(g, "[" + (i + 1) + "]", cx0 + cw / 2, sy + ch - 44 * s, Math.round(20 * s));
            }
        }

        // Fight action buttons (bottom-right, touch + mouse)
        btnBonk = null;
        btnSpecial = null;
        if (state == "fight" && me != null && me.alive) {
            var bs = 110 * s;
            var bx0 = w - bs - 20 * s;
            btnBonk = {x: bx0, y: h - bs - 20 * s, w: bs, h: bs};
            g.color = kha.Color.fromValue(0xAA222222);
            g.fillRect(btnBonk.x, btnBonk.y, bs, bs);
            g.color = kha.Color.fromValue(0xFFFFD54F);
            centerText(g, "BONK", bx0 + bs / 2, btnBonk.y + bs / 2 - 18 * s, Math.round(22 * s));
            g.color = kha.Color.fromValue(0xFFAAAAAA);
            centerText(g, "SPACE", bx0 + bs / 2, btnBonk.y + bs / 2 + 10 * s, Math.round(15 * s));
            if (me.kit != null) {
                btnSpecial = {x: bx0, y: h - 2 * bs - 40 * s, w: bs, h: bs};
                var ready = me.specialTimer <= 0;
                g.color = kha.Color.fromValue(ready ? 0xAA2E7D32 : 0xAA222222);
                g.fillRect(btnSpecial.x, btnSpecial.y, bs, bs);
                g.color = kha.Color.fromValue(me.kit.color);
                var sn = me.kit.specialName.split(" ")[0].toUpperCase();
                centerText(g, sn, bx0 + bs / 2, btnSpecial.y + bs / 2 - 18 * s, Math.round(20 * s));
                g.color = kha.Color.fromValue(0xFFAAAAAA);
                var sub = ready ? "Q" : ("" + Math.ceil(me.specialTimer) + "s");
                centerText(g, sub, bx0 + bs / 2, btnSpecial.y + bs / 2 + 10 * s, Math.round(15 * s));
            }
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

    function wrapLines(g: kha.graphics2.Graphics, text: String, maxW: Float, size: Int): Array<String> {
        g.fontSize = size;
        var words = text.split(" ");
        var lines: Array<String> = [];
        var cur = "";
        for (wd in words) {
            var t = cur == "" ? wd : cur + " " + wd;
            if (font.width(size, t) > maxW && cur != "") { lines.push(cur); cur = wd; }
            else cur = t;
        }
        if (cur != "") lines.push(cur);
        return lines;
    }
}
