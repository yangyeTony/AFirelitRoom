//
//  GameData.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 14/05/15.
//

import Foundation

var GD = GameData()

final class GameData: NSObject, NSCoding {
    var previous:GameData?
    var score:Int = 0
    
    var activeModule = "room"
    
    var buildings = [String:Int]() {
        didSet {
            buildingsObserver?.buildingsChanged()
        }
    }
    var stores = [String:Double]() {
        didSet {
            storesObservers.each() {$0.storesChanged()} 
            //if thieves == 0 && availiableLocations["world"] != nil && (stores.any() {$0.1 > 5000}) {
            if thieves == 0 && availiableLocations["world"] != nil && (S.wood > 5000 || S.fur > 5000 || S.meat > 5000) {
                startThieves()
            }
        }
    }
    var workers = [String:Int]() {
        didSet {
            updateIncome()
            populationObserver?.stuffChanged()
        }
    }
    var availiableLocations:[String:Bool] = ["room":true]
    var income = [String:[String:Double]]()
    var perks = [String:Bool]()
    var stolen = [String:Double]()
    
    //room
    var builderState:BuilderState = .None
    var fire:Fire = .Dead
    var temperature:Temperature = .Freezing
    
    //outside
    var population:Int = 0 {
        didSet {
            updateIncome()
            populationObserver?.stuffChanged()
        }
    }
    var seenForest = false
    var thieves = 0
    
    //path
    var outfit = [String:Double]() {
        didSet {
            worldObserver?.outfitChanged()
        }
    }
    
    //world
    var direction = "north"
    var worldMap = [[Character]]()
    var worldMask = [[Bool]]()
    var worldVisited = [[Bool]]()
    var usedOutposts = [Point]()
    var cityCleared = false
    var characterStarved: Int = 0
    var characterDehydrated: Int = 0
    var characterPunches: Int = 0
    var tempPosition = Point(x: 30, y: 30)
    var tempWorldMap = [[Character]]()
    var tempWorldMask = [[Bool]]()
    var tempWorldVisited = [[Bool]]()
    var tempSulphurMine = false
    var tempIronMine = false
    var tempCoalMine = false
    var tempShip = false
    var tempWater = 0
    var tempHealth = 0
    var starvation = false
    var thirst = false
    var dead = true
    var foodMove:Int = 0
    var waterMove:Int = 0
    var fightMove:Int = 0
    
    //ship
    var seenShip = false
    var seenWarning = false
    var shipThrusters = 1
    var shipHull = 0 {
        didSet {
            hullObserver?.hullChanged()
        }
    }
    
    //misc
    var buttons = [String:Bool]()
    
    var avatarId: Int = 1
    var avatarSelected = false
    
    override init(){
        super.init()
    }
    
    func hasPerk(perk: String) -> Bool {
        return perks[perk] != nil
    }
    
    func addPerk(perk:String) {
        perks[perk] = true
    }
    
    func updateIncome() {
        for (worker, num) in workers {
            var income = Res.income[worker]!.map() {($0,$1*Double(num))}
            self.income[worker] = income
        }
        if let gatherers = E.outside?.getNumGatherers() {
            var income = Res.income["gatherer"]!.map() {($0,$1*Double(gatherers))}
            self.income["gatherer"] = income
        }
    }
    
    func collectIncome() {
        
        for (source,inc) in income {
            var ok = true
            if source != "thieves" {
                ok = !inc.any() {$1 + (self.stores[$0] ?? 0) < 0}
                if ok {
                    stores += inc
                }
            }
            else {
                addStolen(inc)
            }
        }
    }
    
    func addStolen(stores:[String:Double]) {
        for (k,v) in stores {
            let old = self.stores[k] ?? 0
            let add = (old + v < 0) ? -old : v
            self.stores[k] = (self.stores[k] ?? 0) + add
            /*
            let short = old + v
            let add:Double
            if short < 0 {
                add = short - v
            }
            else {
                add = -v
            }
            */
            
            stolen[k] = (stolen[k] ?? 0) - add
        }
    }
    
    func startThieves() {
        thieves = 1
        income["thieves"] = [
            "wood": -10,
            "fur": -5,
            "meat": -5]
    }

    func incomeForResource(res:String) -> Double {
        return GD.income.filter() { source,inc in
            return (source == "thieves" || !inc.any() {k,v in return v + (self.stores[k] ?? 0) < 0})
        }.reduce(0.0) {
                return $0 + ($1.1[res] ?? 0)
        }
        /*
        return GD.income.reduce(0.0) {
                return $0 + ($1.1[res] ?? 0)
        }
*/
    }
    
    required convenience init(coder decoder: NSCoder) {
        self.init()
        previous = decoder.decodeObjectForKey("previous") as? GameData
        if let am = decoder.decodeObjectForKey("activeModule") as? String {
            activeModule = am
        }
        score = decoder.decodeIntegerForKey("score")
        buildings = decoder.decodeObjectForKey("buildings") as! [String:Int]
        stores = decoder.decodeObjectForKey("stores") as! [String:Double]
        workers = decoder.decodeObjectForKey("workers") as! [String:Int]
        availiableLocations = decoder.decodeObjectForKey("availiableLocations") as! [String:Bool]
        income = decoder.decodeObjectForKey("income") as! [String:[String:Double]]
        perks = decoder.decodeObjectForKey("perks") as! [String:Bool]
        stolen = decoder.decodeObjectForKey("stolen") as! [String:Double]
        builderState = BuilderState(rawValue: decoder.decodeIntegerForKey("builderState"))!
        fire = Fire(rawValue: decoder.decodeIntegerForKey("fire"))!
        temperature = Temperature(rawValue: decoder.decodeIntegerForKey("temperature"))!
        population = decoder.decodeIntegerForKey("population")
        seenForest = decoder.decodeBoolForKey("seenForest")
        tempWater = decoder.decodeIntegerForKey("tempWater")
        tempHealth = decoder.decodeIntegerForKey("tempHealth")
        thieves = decoder.decodeIntegerForKey("thieves")
        outfit = decoder.decodeObjectForKey("outfit") as! [String:Double]
        worldMap = (decoder.decodeObjectForKey("worldMap") as! [String]).map() {Array($0)}
        worldMask = decoder.decodeObjectForKey("worldMask") as! [[Bool]]
        worldVisited = decoder.decodeObjectForKey("worldVisited") as! [[Bool]]
        usedOutposts = (decoder.decodeObjectForKey("usedOutposts") as! [[Int]]).map() {Point(x:$0[0],y:$0[1])}
        cityCleared = decoder.decodeBoolForKey("cityCleared")
        characterStarved = decoder.decodeIntegerForKey("characterStarved")
        characterDehydrated = decoder.decodeIntegerForKey("characterDehydrated")
        characterPunches = decoder.decodeIntegerForKey("characterPunches")
        if let tempPositionArray = decoder.decodeObjectForKey("tempPosition") as? [Int] {
            tempPosition = Point(x:tempPositionArray[0],y:tempPositionArray[1])
        }
        
        //direction = decoder.decodeObjectForKey("direction") as! String
        tempWorldMap = (decoder.decodeObjectForKey("tempWorldMap") as! [String]).map() {Array($0)}
        tempWorldMask = decoder.decodeObjectForKey("tempWorldMask") as! [[Bool]]
        tempWorldVisited = decoder.decodeObjectForKey("tempWorldVisited") as! [[Bool]]
        tempSulphurMine = decoder.decodeBoolForKey("tempSulphurMine")
        tempIronMine = decoder.decodeBoolForKey("tempIronMine")
        tempCoalMine = decoder.decodeBoolForKey("tempCoalMine")
        starvation = decoder.decodeBoolForKey("starvation")
        thirst = decoder.decodeBoolForKey("thirst")
        dead = decoder.decodeBoolForKey("dead")
        //foodMove = decoder.decodeIntegerForKey("foodMove")
        //waterMove = decoder.decodeIntegerForKey("waterMove")
        //fightMove = decoder.decodeIntegerForKey("fightMove")
        tempShip = decoder.decodeBoolForKey("tempShip")
        seenShip = decoder.decodeBoolForKey("seenShip")
        seenWarning = decoder.decodeBoolForKey("seenWarning")
        shipThrusters = decoder.decodeIntegerForKey("shipThrusters")
        shipHull = decoder.decodeIntegerForKey("shipHull")
        buttons = decoder.decodeObjectForKey("buttons") as! [String:Bool]
        avatarId = decoder.decodeIntegerForKey("avatarId")
        avatarSelected = decoder.decodeBoolForKey("avatarSelected")

    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(previous, forKey: "previous")
        coder.encodeObject(activeModule, forKey: "activeModule")
        coder.encodeInteger(score, forKey: "score")
        coder.encodeObject(buildings, forKey: "buildings")
        coder.encodeObject(stores, forKey: "stores")
        coder.encodeObject(workers, forKey: "workers")
        coder.encodeObject(availiableLocations, forKey: "availiableLocations")
        coder.encodeObject(income, forKey: "income")
        coder.encodeObject(perks, forKey: "perks")
        coder.encodeObject(stolen, forKey: "stolen")
        coder.encodeInteger(builderState.rawValue, forKey: "builderState")
        coder.encodeInteger(fire.rawValue, forKey: "fire")
        coder.encodeInteger(temperature.rawValue, forKey: "temperature")
        coder.encodeInteger(population, forKey: "population")
        coder.encodeBool(seenForest, forKey: "seenForest")
        coder.encodeInteger(thieves, forKey: "thieves")
        coder.encodeObject(outfit, forKey: "outfit")
        coder.encodeObject(direction, forKey: "direction")
        coder.encodeObject(worldMap.map() {String($0)}, forKey: "worldMap")
        coder.encodeObject(worldMask, forKey: "worldMask")
        coder.encodeObject(worldVisited, forKey: "worldVisited")
        coder.encodeObject(usedOutposts.map() {[$0.x, $0.y]}, forKey: "usedOutposts")
        coder.encodeBool(cityCleared, forKey: "cityCleared")
        coder.encodeInteger(characterStarved, forKey: "characterStarved")
        coder.encodeInteger(characterDehydrated, forKey: "characterDehydrated")
        coder.encodeInteger(characterPunches, forKey: "characterPunches")
        coder.encodeObject([tempPosition.x, tempPosition.y], forKey: "tempPosition")
        coder.encodeObject(tempWorldMap.map() {String($0)}, forKey: "tempWorldMap")
        coder.encodeObject(tempWorldMask, forKey: "tempWorldMask")
        coder.encodeObject(tempWorldVisited, forKey: "tempWorldVisited")
        coder.encodeInteger(tempWater, forKey: "tempWater")
        coder.encodeInteger(tempHealth, forKey: "tempHealth")
        coder.encodeBool(tempSulphurMine, forKey: "tempSulphurMine")
        coder.encodeBool(tempIronMine, forKey: "tempIronMine")
        coder.encodeBool(tempCoalMine, forKey: "tempCoalMine")
        coder.encodeBool(tempShip, forKey: "tempShip")
        coder.encodeBool(starvation, forKey: "starvation")
        coder.encodeBool(thirst, forKey: "thirst")
        coder.encodeBool(dead, forKey: "dead")
        coder.encodeInteger(foodMove, forKey: "foodMove")
        coder.encodeInteger(waterMove, forKey: "waterMove")
        coder.encodeInteger(fightMove, forKey: "fightMove")
        coder.encodeBool(seenShip, forKey: "seenShip")
        coder.encodeBool(seenWarning, forKey: "seenWarning")
        coder.encodeInteger(shipThrusters, forKey: "shipThrusters")
        coder.encodeInteger(shipHull, forKey: "shipHull")
        coder.encodeObject(buttons, forKey:"buttons")
        coder.encodeInteger(avatarId, forKey: "avatarId")
        coder.encodeBool(avatarSelected, forKey: "avatarSelected")
    }
    
    
    var storesObservers = [StoresObserver]()
    var populationObserver:OutsideStuffObserver?
    var buildingsObserver:BuildingsObserver?
    var worldObserver:WorldObserver?
    var hullObserver:HullObserver?
}


let GameDataDict = NSDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("gamedata", ofType: "plist")!)! as! [String:[String:AnyObject]]

class GameDataContainer<T:Serializable>:Serializable {
    var contents = [String:T]()
    subscript(key: String) -> T? {
        get {return contents[key]}
        set {contents[key] = newValue}
    }
    override init() {
        super.init()
        loadData()
    }
    func loadData() {
        for (k,v) in GameDataDict[T.containerPlistKey]! {
            //println(k)
            //println(v)
            contents[k] = initElement(v)
        }
    }
    func initElement(dict:AnyObject) -> T {
        return T.self(dict: dict)
    }
    func reset() {
        contents = [String:T]()
        loadData()
    }
}


enum ItemType:String {
    case Building = "building"
    case Tool = "tool"
    case Upgrade = "upgrade"
    case Weapon = "weapon"
    case Good = "good"
}


enum WeaponType:String {
    case Unarmed = "unarmed"
    case Melee = "melee"
    case Ranged = "ranged"
}

final class Craftable: Serializable
{
    override class var containerPlistKey:String {get{return "Craftables"}}
    var name:String!
    private var type:String!
    var buildMsg:String! //?
    var availableMsg:String?
    var maxMsg:String?
    var maximum:Int?
    private var cost:[String:Double]!
    var getCost:(()->[String:Double])!
    var itemType:ItemType! // {get {return ItemType(rawValue: type)!}}
    override func customInit() {
        switch name {
            case "hut":
                getCost = {return ["wood":(Double(GD.buildings["hut"]) ?? 0) * 50 + 100]}
            case "trap":
                getCost = {return ["wood":(Double(GD.buildings["trap"]) ?? 0) * 10 + 10]}
            default:
                getCost = {return self.cost}
        }
    }
    
    override init(dict:AnyObject) {
        if let d = dict as? [String:AnyObject] {
            name = d["name"] as! String
            //type = d["type"] as! String
            buildMsg = d["buildMsg"] as! String
            maxMsg = d["maxMsg"] as? String
            availableMsg = d["availableMsg"] as? String
            maximum = d["maximum"] as? Int
            cost = d["cost"] as? [String:Double]
            itemType = ItemType(rawValue: d["type"] as! String)!
        }
        super.init()
        customInit()
    }
}

final class TradeGood: Serializable
{
    override class var containerPlistKey:String {get{return "TradeGoods"}}
    private var type:String!
    var itemType:ItemType! //{get {return ItemType(rawValue: type)!}}
    var cost:[String:Double]!
    var maximum:Int?
    
    override init(dict:AnyObject) {
        if let d = dict as? [String:AnyObject] {
            maximum = d["maximum"] as? Int
            cost = d["cost"] as? [String:Double]
            itemType = ItemType(rawValue: d["type"] as! String)!
        }
        super.init()
        customInit()
    }
}

final class TrapDrop: Serializable
{
    override class var containerPlistKey:String {get{return "TrapDrops"}}
    var message:String!
    var rollUnder:Double!
    
    override init(dict:AnyObject) {
        if let d = dict as? [String:AnyObject] {
            message = d["message"] as! String
            rollUnder = d["rollUnder"] as! Double
        }
        super.init()
        customInit()
    }
}

final class Weapon: Serializable
{
    override class var containerPlistKey:String {get{return "Weapons"}}
    var damage:AnyObject!
    var verb:String!
    private var type:String!
    var weaponType:WeaponType = .Unarmed //{get {return WeaponType(rawValue: type)!}}
    var cooldown:Double!
    var cost:[String:Double]?
    
    override init(dict:AnyObject) {
        if let d = dict as? [String:AnyObject] {
            verb = d["verb"] as? String
            cooldown = d["cooldown"] as? Double
            damage = d["damage"] as? Int
            cost = d["cost"] as? [String:Double]
            weaponType = WeaponType(rawValue: d["type"] as! String)!
        }
        super.init()
        customInit()
    }
}

final class Perk: Serializable
{
    override class var containerPlistKey:String {get{return "Perks"}}
    var name:String!
    var desc:String!
    var notify:String!
    
    override init(dict:AnyObject) {
        if let d = dict as? [String:AnyObject] {
            name = d["name"] as? String
            desc = d["desc"] as? String
            notify = d["notify"] as? String
        }
        super.init()
        customInit()
    }
}


let Res = Resources()

final class Resources {
    let income = GameDataDict["Income"] as! [String:[String:Double]]
    let weight = GameDataDict["Weight"] as! [String:Double]
    let storesMap = GameDataDict["storesMap"] as! [String:String]
    //let perks = GameDataDict["Perks"] as! [String:[String:String]]
    var craftables = [String:Craftable]()
    //var craftables = GameDataContainer<Craftable>()
    var tradeGoods = [String:TradeGood]()
    var trapDrops = [String:TrapDrop]()
    var weapons = [String:Weapon]()
    var perks = [String:Perk]()
    
    init() {
        GameDataDict["Craftables"]!.each() {[unowned self] k,v in
            self.craftables[k] = Craftable(dict: v)
        }
        GameDataDict["TradeGoods"]!.each() {[unowned self] k,v in
            self.tradeGoods[k] = TradeGood(dict: v)
        }
        GameDataDict["TrapDrops"]!.each() {[unowned self] k,v in
            self.trapDrops[k] = TrapDrop(dict: v)
        }
        GameDataDict["Weapons"]!.each() {[unowned self] k,v in
            self.weapons[k] = Weapon(dict: v)
        }
        GameDataDict["Perks"]!.each() {[unowned self] k,v in
            self.perks[k] = Perk(dict: v)
        }
    }

}

//MARK: shortcuts

let S = Stores()
final class Stores {
    var wood:Double {
        get { return GD.stores["wood"] ?? 0 }
        set { GD.stores["wood"] = newValue }
    }
    var fur:Double {
        get { return GD.stores["fur"] ?? 0 }
        set { GD.stores["fur"] = newValue }
    }
    var meat:Double {
        get { return GD.stores["meat"] ?? 0 }
        set { GD.stores["meat"] = newValue }
    }
    var alienAlloy:Double {
        get { return GD.stores["alien alloy"] ?? 0 }
        set { GD.stores["alien alloy"] = newValue }
    }
    var energyCell:Double {
        get { return GD.stores["energy cell"] ?? 0 }
        set { GD.stores["energy cell"] = newValue }
    }
    var scales:Double {
        get { return GD.stores["scales"] ?? 0 }
        set { GD.stores["scales"] = newValue }
    }
    var bait:Double {
        get { return GD.stores["bait"] ?? 0 }
        set { GD.stores["bait"] = newValue }
    }
    var convoy:Double {
        get { return GD.stores["convoy"] ?? 0 }
        set { GD.stores["convoy"] = newValue }
    }
    var wagon:Double {
        get { return GD.stores["wagon"] ?? 0 }
        set { GD.stores["wagon"] = newValue }
    }
    var rucksack:Double {
        get { return GD.stores["rucksack"] ?? 0 }
        set { GD.stores["rucksack"] = newValue }
    }
    var compass:Double {
        get { return GD.stores["compass"] ?? 0 }
        set { GD.stores["compass"] = newValue }
    }
}

let B = Buildings()
final class Buildings {
    var hut:Int {
        get { return GD.buildings["hut"] ?? 0 }
        set { GD.buildings["hut"] = newValue
            E.outside?.updateTitle()}
    }
    
    var trap:Int {
        get { return GD.buildings["trap"] ?? 0 }
        set { GD.buildings["trap"] = newValue }
    }
    
    var workshop:Int {
        get { return GD.buildings["workshop"] ?? 0 }
        set { GD.buildings["workshop"] = newValue }
    }
    
}

protocol StoresObserver {
    func storesChanged()
}
protocol BuildingsObserver {
    func buildingsChanged()
}