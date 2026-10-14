package arm;

// Original character kits. Each fighter picks one: stat modifiers plus a
// special ability on cooldown. applyTo runs on top of base stats (after
// fullReset), before any draft powers are applied.
class CharKit {
    public var id: String;
    public var name: String;
    public var desc: String;
    public var color: Int;
    public var specialId: String; // "slam" | "shockwave" | "blink" | "grow"
    public var specialName: String;
    public var specialDesc: String;
    public var specialMax: Float;

    public function new(id: String, name: String, desc: String, color: Int,
                        specialId: String, specialName: String, specialDesc: String, specialMax: Float) {
        this.id = id;
        this.name = name;
        this.desc = desc;
        this.color = color;
        this.specialId = specialId;
        this.specialName = specialName;
        this.specialDesc = specialDesc;
        this.specialMax = specialMax;
    }

    public function applyTo(f: Fighter) {
        f.kit = this;
        f.bodyColor = color;
        f.specialMax = specialMax;
        switch (id) {
            case "bonkboy":
                f.meleeDamage = 30.0;
                f.meleeKb = 20.0;
                f.moveSpeed = 8.5;
            case "wobble":
                f.maxHp = 140.0; f.hp = 140.0;
                f.moveSpeed = 7.0;
                f.knockResist = 0.2;
                f.bulletDamage = 14.0;
            case "dame":
                f.moveSpeed = 10.0;
                f.fireInterval = 0.35;
                f.maxHp = 80.0; f.hp = 80.0;
                f.dashCooldownMax = 1.6;
            case "wumbo":
                f.maxHp = 150.0; f.hp = 150.0;
                f.bulletDamage = 16.0;
                f.moveSpeed = 6.5;
                f.knockResist = 0.3;
                f.meleeKb = 22.0;
        }
    }

    public static var ALL: Array<CharKit> = [
        new CharKit("bonkboy", "Bonk Boy", "Melee brawler. Get close, bonk hard.",
            0xFF29B6F6, "slam", "Ground Slam", "AoE bonk around you", 8.0),
        new CharKit("wobble", "Captain Wobble", "Tanky gunner. Outlast everyone.",
            0xFF66BB6A, "shockwave", "Shockwave", "Radial bullet burst", 10.0),
        new CharKit("dame", "Dame Dash", "Fragile speedster. Blink and punish.",
            0xFFAB47BC, "blink", "Blink Strike", "Teleport strike with i-frames", 7.0),
        new CharKit("wumbo", "Wumbo", "Heavy hitter. Become enormous.",
            0xFFFFA726, "grow", "Grow", "Giant form: +dmg, +knockback", 14.0),
    ];

    public static function byId(id: String): CharKit {
        for (k in ALL) if (k.id == id) return k;
        return ALL[0];
    }
}
