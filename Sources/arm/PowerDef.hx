package arm;

class PowerDef {
    public var id: String;
    public var name: String;
    public var desc: String;
    public var color: Int; // ARGB

    public function new(id: String, name: String, desc: String, color: Int) {
        this.id = id;
        this.name = name;
        this.desc = desc;
        this.color = color;
    }
}
