package arm;

class Powers {
    public static var ALL: Array<PowerDef> = [
        new PowerDef("rapid", "Rapid Fire", "+35% fire rate", 0xFFFFB300),
        new PowerDef("big", "Big Bullets", "+60% damage & size", 0xFFFF5722),
        new PowerDef("swift", "Swift Boots", "+20% move speed", 0xFF4FC3F7),
        new PowerDef("dash", "Long Dash", "+50% dash range, -20% cooldown", 0xFFBA68C8),
        new PowerDef("vamp", "Vampire", "Heal 20% of damage dealt", 0xFFE53935),
        new PowerDef("thorns", "Thorns", "Reflect 30% of damage taken", 0xFF8BC34A),
        new PowerDef("multi", "Multishot", "+1 projectile per shot", 0xFFFFEE58),
        new PowerDef("heavy", "Heavy Body", "+50 max HP, knockback resist", 0xFF90A4AE),
        new PowerDef("blitz", "Blitz", "Your dash damages enemies", 0xFF40C4FF),
        new PowerDef("regen", "Regen", "+4 HP per second", 0xFF69F0AE),
    ];

    public static function byId(id: String): PowerDef {
        for (p in ALL) if (p.id == id) return p;
        return null;
    }
}
