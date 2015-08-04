//
//  World.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 23/10/14.
//

import UIKit

struct Point:Equatable {
    var x:Int, y:Int
}

//typealias Point = (x:Int,y:Int)
func +(lhs:Point,rhs:Point) -> Point {
    return Point(x: lhs.x+rhs.x, y: lhs.y+rhs.y)
}
func +=(inout lhs:Point,rhs:Point) {
    lhs = Point(x: lhs.x+rhs.x, y: lhs.y+rhs.y)
}
func -(lhs:Point,rhs:Point) -> Point {
    return Point(x: lhs.x-rhs.x, y: lhs.y-rhs.y)
}
func -=(inout lhs:Point,rhs:Point) {
    lhs = Point(x: lhs.x-rhs.x, y: lhs.y-rhs.y)
}
func ==(lhs:Point,rhs:Point) -> Bool {
    return lhs.x == rhs.x && lhs.y == rhs.y
}

enum Direction:String  {
    case North = "north", South = "south", West = "west", East = "east", NorthWest = "northwest", NorthEast = "northeast", SouthWest = "southwest", SouthEast = "southeast"
    var point: Point {
        switch self {
        case .North:
            return Point(x: 0,y: -1)
        case .South:
            return Point(x: 0,y: 1)
        case .West:
            return Point(x: -1,y: 0)
        case .East:
            return Point(x: 1,y: 0)
        case .NorthWest:
            return Point(x: -1,y: -1)
        case .NorthEast:
            return Point(x: 1,y: -1)
        case .SouthWest:
            return Point(x: -1,y: 1)
        case .SouthEast:
            return Point(x: 1,y: 1)
        }
    }
}

enum Tile:Character {
    case Village = "A",
    IronMine = "I",
    CoalMine = "C",
    SulphurMine = "S",
    Forest = ";",
    Field = ",",
    Barrens = ".",
    Road = "#",
    House = "H",
    Cave = "V",
    Town = "O",
    City = "Y",
    Outpost = "P",
    Ship = "W",
    Borehole = "B",
    Battlefield = "F",
    Swamp = "M",
    Cache = "U"
    var isTerrain:Bool { return self == .Forest || self == .Field || self == .Barrens}
    static var allTiles:[Character] {return ["A","I","C","S",";",",",".","#","H","V","O","Y","P","W","B","F","M","U"]}
}

struct Landmark {
    let num:Int
    let minRadius:Int
    let maxRadius:Int
    let scene:String
    let label:String
}

final class World:Module {
    let radius = 30
    let villagePosition:Point = Point(x: 30, y: 30)
    let tileProbabilities:[Tile:Double]
    var landmarks:[Tile:Landmark]
    let stickiness = 0.5 // 0 <= x <= 1
    let lightRadius = 2
    let baseWater = 10
    let movesPerFood = 2
    let movesPerWater = 1
    static let deathCooldown:Double = 120
    let fightChance = 0.2
    let baseHealth = 10
    let baseHitChance = 0.8
    var meatHeal:Int {return GD.hasPerk("gastronome") ? 16 : 8 }
    let medsHeal = 20
    let fightDelay = 3 // At least three moves between fights
    

    var direction:Direction {
        get {
            return Direction(rawValue:GD.direction)!
        }
        set {
            GD.direction = newValue.rawValue
        }
    }
    var currentPosition:Point {
        get {
            return GD.tempPosition
        }
        set {
            GD.tempPosition = newValue
            playerPositionObserver?.playerPositionChanged()
        }
    }
    var danger = false
    var foodMove:Int {
        get {
            return GD.foodMove
        }
        set {
            GD.foodMove = newValue
        }
    }
    var waterMove:Int {
        get {
            return GD.waterMove
        }
        set {
            GD.waterMove = newValue
        }
    }
    var fightMove:Int {
        get {
            return GD.fightMove
        }
        set {
            GD.fightMove = newValue
        }
    }
    var starvation:Bool {
        get {
            return GD.starvation
        }
        set {
            GD.starvation = newValue
        }
    }
    var thirst:Bool {
        get {
            return GD.thirst
        }
        set {
            GD.thirst = newValue
        }
    }
    var dead:Bool {
        get {
            return GD.dead
        }
        set {
            GD.dead = newValue
        }
    }
    var health:Int {
        set {
            GD.tempHealth = newValue
            if GD.tempHealth > maxHealth {
                GD.tempHealth = maxHealth
            }
            combatPlayerHealthLabel?.text = "\(newValue)/\(maxHealth)"
        }
        get {
            return GD.tempHealth
        }
    }
    //TODO: check if saved and reset correctly
    var water:Int {
        set {
            if newValue > maxWater {
                GD.tempWater = maxWater
            }
            else {
                GD.tempWater = newValue
            }
            worldObserver?.waterChanged()
        }
        get {
            return GD.tempWater
        }
    }
    var terrain:Tile {return Tile(rawValue: GD.tempWorldMap[currentPosition.x][currentPosition.y])! }
    
    required init() {
        tileProbabilities = [.Forest: 0.15,.Field: 0.35,.Barrens: 0.5]
        landmarks = [
            Tile.Outpost: Landmark( num: 0, minRadius: 0, maxRadius: 0, scene: "outpost", label: "An Outpost"),
            Tile.IronMine: Landmark( num: 1, minRadius: 5, maxRadius: 5, scene: "ironmine", label:  "The Iron Mine"),
            Tile.CoalMine: Landmark( num: 1, minRadius: 10, maxRadius: 10, scene: "coalmine", label:  "The Coal Mine"),
            Tile.SulphurMine: Landmark( num: 1, minRadius: 20, maxRadius: 20, scene: "sulphurmine", label:  "The Sulphur Mine"),
            Tile.House: Landmark( num: 10, minRadius: 0, maxRadius: 45, scene: "house", label:  "An Old House"),
            Tile.Cave: Landmark( num: 5, minRadius: 3, maxRadius: 10, scene: "cave", label:  "A Damp Cave"),
            Tile.Town: Landmark( num: 10, minRadius: 10, maxRadius: 20, scene: "town", label:  "An Abandoned Town"),
            Tile.City: Landmark( num: 20, minRadius: 20, maxRadius: 45, scene: "city", label:  "A Ruined City"),
            Tile.Ship: Landmark( num: 1, minRadius: 28, maxRadius: 28, scene: "ship", label:  "A Crashed Starship"),
            Tile.Borehole: Landmark( num: 10, minRadius: 15, maxRadius: 45, scene: "borehole", label:  "A Borehole"),
            Tile.Battlefield: Landmark( num: 5, minRadius: 18, maxRadius: 45, scene: "battlefield", label:  "A Battlefield"),
            Tile.Swamp: Landmark( num: 1, minRadius: 15, maxRadius: 45, scene: "swamp", label:  "A Murky Swamp")]
        
        
        // may be simplified
        if (GD.previous?.stores.reduce(0) {$0! + $1.1}) > 0 {
            landmarks[.Cache] = Landmark(num: 1, minRadius: 10, maxRadius: 45, scene: "cache", label: "A Destroyed Village")
        }
        
        super.init()
        id = "world"
        name = "World"
        title = "A Barren World"
        
        if GD.availiableLocations["world"] == nil {
            GD.availiableLocations["world"] = true
            RunInBackground() {[unowned self] in
                self.generateMap()
                self.newMask()
            }
        }
        else if GD.worldMap.isEmpty { //FIXME: replace isEmpty with GD.something
            RunInBackground() {[unowned self] in
                self.generateMap()
                self.newMask()
            }
        }
    }
    
    func tileNameForChar(char:Character) -> String {
        var imageName = ""
        switch char {
        case "A":
            imageName = "Village"
        case "I":
            imageName = "IronMine"
        case "C":
            imageName = "CoalMine"
        case "S":
            imageName = "SulphurMine"
        case ";":
            imageName = "Forest"
        case ",":
            imageName = "Field"
        case "#":
            imageName = "Road"
        case "H":
            imageName = "House"
        case "V":
            imageName = "Cave"
        case "O":
            imageName = "Town"
        case "Y":
            imageName = "City"
        case "P":
            imageName = "Outpost"
        case "W":
            imageName = "Ship"
        case "B":
            imageName = "Borehole"
        case "F":
            imageName = "Battlefield"
        case "M":
            imageName = "Swamp"
        case "U":
            imageName = "Cache"
        default:
            break
        }
        return imageName
    }
    
    func clearDungeon() {
        GD.tempWorldMap[currentPosition.x][currentPosition.y] = Tile.Outpost.rawValue
        worldObserver?.tileUpdated(currentPosition.x, y: currentPosition.y,gray:false)
        drawRoad()
    }
    
    func drawRoad() {
        func findClosestRoad(startPos:Point) -> Point {
            var searchX:Int, searchY:Int, dtmp:Int,
            x = 0,
            y = 0,
            dx = 1,
            dy = -1
            for i in 0..<Int(pow(Double(getDistance(from: startPos, to: villagePosition)), 2)) {
                searchX = startPos.x + x
                searchY = startPos.y + y
                if (0 < searchX && searchX < radius * 2 && 0 < searchY && searchY < radius * 2) {
                    // check for road
                    var tile = Tile(rawValue: GD.tempWorldMap[searchX][searchY])
                    if (tile == .Road ||
                        (tile == .Outpost && !(x == 0 && y == 0))  || // outposts are connected to roads
                        tile == .Village // all roads lead home
                        ) {
                            return Point(x: searchX, y: searchY)
                    }
                }
                if (x == 0 || y == 0) {
                    // Turn the corner
                    dtmp = dx
                    dx = -dy
                    dy =  dtmp
                }
                if (x == 0 && y <= 0) {
                    x++
                } else {
                    x += dx
                    y += dy
                }
            }
            return villagePosition
        }
        let closestRoad = findClosestRoad(currentPosition)
        let dist = currentPosition - closestRoad
        let xDir = dist.x == 0 ? 0 : abs(dist.x)/dist.x
        let yDir = dist.y == 0 ? 0 : abs(dist.y)/dist.y
        var xIntersect:Int, yIntersect:Int
        if abs(dist.x) > abs(dist.y) {
            xIntersect = closestRoad.x;
            yIntersect = closestRoad.y + dist.y;
        } else {
            xIntersect = closestRoad.x + dist.x;
            yIntersect = closestRoad.y;
        }
        
        for x in 0..<abs(dist.x) {
            if isTerrain(GD.tempWorldMap[closestRoad.x + (xDir*x)][yIntersect]) {
                GD.tempWorldMap[closestRoad.x + (xDir*x)][yIntersect] = Tile.Road.rawValue
                worldObserver?.tileUpdated(closestRoad.x + (xDir*x), y: yIntersect,gray:false)
            }
        }
        for y in 0..<abs(dist.y) {
            if isTerrain(GD.tempWorldMap[xIntersect][closestRoad.y + (yDir*y)]) {
                GD.tempWorldMap[xIntersect][closestRoad.y + (yDir*y)] = Tile.Road.rawValue
                 worldObserver?.tileUpdated(xIntersect, y: closestRoad.y + (yDir*y),gray:false)
            }
        }
        drawMap()
    }
    
    func isTerrain(tile:Character) -> Bool {
        return Tile(rawValue: tile)!.isTerrain
    }
    
    func moveNorth() {
        if currentPosition.y > 0 {
            move(.North)
        }
    }
    
    func moveSouth() {
        if currentPosition.y < radius * 2 {
            move(.South)
        }
    }
    
    func moveWest() {
        if currentPosition.x > 0 {
            move(.West)
        }
    }
    
    func moveEast() {
        if currentPosition.x < radius * 2 {
            move(.East)
        }
    }
    
    func move(direction:Direction) {
        let oldTile = Tile(rawValue: GD.tempWorldMap[currentPosition.x][currentPosition.y])!
        currentPosition += direction.point
        let newTile = Tile(rawValue: GD.tempWorldMap[currentPosition.x][currentPosition.y])!
        narrateMove(oldTile, newTile)
        GD.tempWorldMask = lightMap(currentPosition, GD.tempWorldMask);
        drawMap()
        doSpace()
        if checkDanger() {
            if danger {
                NM.notify(self, LS("dangerous to be this far from the village without proper protection"))
            } else {
                NM.notify(self, LS("safer here"))
            }
        }
    }
    
    func checkDanger() -> Bool {
        if !danger {
            if (GD.stores["i armour"] ?? 0 == 0 && getDistance() >= 8) ||
               (GD.stores["s armour"] ?? 0 == 0 && getDistance() >= 18) {
                danger = true
                return true
            }
        }
        else if getDistance() < 8 ||
               (getDistance() < 18 && GD.stores["i armour"] ?? 0 > 0) {
                danger = false
                return true
            }
        
        return false
    }
    
    func useSupplies() -> Bool {
        foodMove++
        waterMove++
        // Food
        let movesPerFood = GD.hasPerk("slow metabolism") ? self.movesPerFood * 2 : self.movesPerFood
        if foodMove >= movesPerFood {
            foodMove = 0
            var num = Int(GD.outfit["cured meat"]) ?? 0
            num--
            if num == 0 {
                NM.notify(self, LS("the meat has run out"))
            } else if num < 0 {
                // Starvation! Hooray!
                num = 0;
                if !starvation {
                    NM.notify(self, LS("starvation sets in"))
                    starvation = true;
                } else {
                    GD.characterStarved++
                    if (GD.characterStarved >= 10 && !GD.hasPerk("slow metabolism")) {
                        GD.addPerk("slow metabolism")
                    }
                    die()
                    return false
                }
            } else {
                starvation = false;
                health += meatHeal
            }
            GD.outfit["cured meat"] = Double(num)
        }
        // Water
        let movesPerWater = GD.hasPerk("desert rat") ? self.movesPerWater * 2 : self.movesPerWater
        if waterMove >= movesPerWater {
            waterMove = 0
            water--
            if water == 0 {
                NM.notify(self, LS("there is no more water"))
            } else if(water < 0) {
                water = 0;
                if !thirst {
                    NM.notify(self, LS("the thirst becomes unbearable"))
                    thirst = true
                } else {
                    GD.characterDehydrated++
                    if (GD.characterDehydrated >= 10 && !GD.hasPerk("desert rat")) {
                        GD.addPerk("desert rat")
                    }
                    die()
                    return false
                }
            } else {
                thirst = false;
            }
            updateSupplies()
        }
        return true;
    }
    
    func updateSupplies() {
        
    }
    
    func checkFight() {
        fightMove++
        if fightMove > fightDelay {
            let chance = GD.hasPerk("stealthy") ? (fightChance / 2) : fightChance
            let random = Double.random(min: 0, max: 1)
            if random < chance {
                fightMove = 0
                Events.triggerFight()
            }
        }
    }
    
    func doSpace() {
        var curTile = Tile(rawValue:GD.tempWorldMap[currentPosition.x][currentPosition.y])!
        
        if curTile == .Village {
            goHome()
        } else if let landmark = landmarks[curTile] {
            if (curTile != .Outpost) || !outpostUsed(currentPosition) {
                Events.startEvent(Events.setPieces[landmark.scene]!);
            }
            else {
                water = maxWater
                NM.notify(nil, LS("water replenished"))
            }
        } else if useSupplies() {
            checkFight()
        }
        
    }
    
    func getDistance(var from:Point? = nil,var to:Point? = nil) -> Int {
        if from == nil {
            from = currentPosition
        }
        if to == nil {
            to = villagePosition
        }
        return abs(from!.x - to!.x) + abs (from!.y - to!.y)
    }
    
    func narrateMove(oldTile:Tile,_ newTile:Tile) {
        var msg:String?
        switch (oldTile, newTile) {
        case (.Forest, .Field):
            msg = "the trees yield to dry grass. the yellowed brush rustles in the wind."
        case (.Forest, .Barrens):
            msg = "the trees are gone. parched earth and blowing dust are poor replacements."
        case (.Field, .Forest):
            msg = "trees loom on the horizon. grasses gradually yield to a forest floor of dry branches and fallen leaves."
        case (.Field, .Barrens):
            msg = "the grasses thin. soon, only dust remains."
        case (.Barrens, .Field):
            msg = "the barrens break at a sea of dying grass, swaying in the arid breeze."
        case (.Barrens, .Forest):
            msg = "a wall of gnarled trees rises from the dust. their branches twist into a skeletal canopy overhead."
        default: break
        }
        if msg != nil {
            NM.notify(self, LS(msg))
        }
    }
    
    func newMask() {
        GD.worldMask = [[Bool]](count: radius * 2 + 1, repeatedValue: [Bool](count: radius * 2 + 1, repeatedValue: false))
        GD.worldMask = lightMap(villagePosition, GD.worldMask)
    }
    
    func lightMap(point:Point,_ mask:[[Bool]]) -> [[Bool]] {
        let r = GD.hasPerk("scout") ? lightRadius * 2 : lightRadius
        return uncoverMap(point, r: r, mask)
    }
    
    func uncoverMap(point:Point, r:Int,var _ mask:[[Bool]]) -> [[Bool]] {
        if mask[point.x][point.y] == false {
            mask[point.x][point.y] = true;
            worldObserver?.tileUpdated(point.x, y: point.y,gray:false)
        }
        
        for i in -r...r {
            for j in (-r + abs(i)) ... (r - abs(i)) {
                if(point.y + j >= 0 && point.y + j <= radius * 2 &&
                    point.x + i <= radius * 2 &&
                    point.x + i >= 0) {
                        if mask[point.x+i][point.y+j] == false {
                            mask[point.x+i][point.y+j] = true;
                            worldObserver?.tileUpdated(point.x+i, y: point.y+j,gray:false)
                        }
                }
            }
        }
        return mask
    }
    
    func applyMap() {
        var x = Int.random(min: 1, max: radius * 2 + 1)
        var y = Int.random(min: 1, max: radius * 2 + 1)
        GD.worldMask = uncoverMap(Point(x: x, y: y), r: 5, GD.worldMask)
    }
    
    func generateMap() {
        GD.worldVisited = [[Bool]](count: radius * 2 + 1, repeatedValue: [Bool](count: radius * 2 + 1, repeatedValue: false))
        GD.worldMap = [[Character]](count: radius * 2 + 1, repeatedValue: [Character](count: radius * 2 + 1, repeatedValue: "?"))
        // The Village is always at the exact center
        // Spiral out from there
        GD.worldMap[radius][radius] = Tile.Village.rawValue
        for  r in 1...radius {
            for t in 0 ..< r * 8 {
                var x:Int, y:Int
                if(t < 2 * r) {
                    x = radius - r + t
                    y = radius - r
                } else if(t < 4 * r) {
                    x = radius + r
                    y = radius - (3 * r) + t
                } else if(t < 6 * r) {
                    x = radius + (5 * r) - t
                    y = radius + r
                } else {
                    x = radius - r
                    y = radius + (7 * r) - t
                }
                GD.worldMap[x][y] = chooseTile(Point(x: x, y: y))
            }
        }
        
        // Place landmarks
        for (k,landmark) in landmarks {
            for i in 0 ..< landmark.num {
                let pos = placeLandmark(landmark, k)
                if k == .Ship {
                    let dx = pos.x - radius, dy = pos.y - radius
                    let horz:Direction = dx < 0 ? .West : .East
                    let vert:Direction = dy < 0 ? .North : .South
                    if abs(dx) / 2 > abs(dy) {
                        direction = horz
                    } else if abs(dy) / 2 >  abs(dx) {
                       direction = vert;
                    } else {
                        direction = Direction(rawValue: vert.rawValue + horz.rawValue)!
                    }
                }
            }
        }
    }
    
    func placeLandmark(landmark:Landmark,_ tile:Tile) -> Point {
        var x = radius, y = radius;
        while !isTerrain(GD.worldMap[x][y]) {
            let r = Int.random(min: landmark.minRadius, max: landmark.maxRadius)
            var xDist = Int.random(min: 0, max: r)
            var yDist = r - xDist
            if Bool.random {
                xDist = -xDist
            }
            if Bool.random {
                yDist = -yDist
            }
            x = radius + xDist
            if x < 0 {
                x = 0
            }
            if x > radius * 2 {
                x = radius * 2
            }
            y = radius + yDist
            if y < 0 {
                y = 0
            }
            if y > radius * 2 {
                y = radius * 2
            }
        }
        GD.worldMap[x][y] = tile.rawValue
        return Point(x: x, y: y)
    }
    
    func chooseTile(point:Point) -> Character {
        var adjacent = [Character]()
        if point.y > 0 {
            adjacent.append(GD.worldMap[point.x][point.y-1])
        }
        if point.y < radius * 2 {
            adjacent.append(GD.worldMap[point.x][point.y+1])
        }
        if point.x < radius * 2 {
            adjacent.append(GD.worldMap[point.x+1][point.y])
        }
        if point.x > 0 {
            adjacent.append(GD.worldMap[point.x-1][point.y])
        }
        adjacent = adjacent.filter() {$0 != "?"}
        
        var chances = [Character:Double]()
        var nonSticky = 1.0
        for tile in adjacent {
                if tile == Tile.Village.rawValue {
                    // Village must be in a forest to maintain thematic consistency, yo.
                    return Tile.Forest.rawValue
                } else  {
                    chances[tile] = (chances[tile] ?? 0) + stickiness
                    nonSticky -= stickiness
                }
        }
        for (k,v) in tileProbabilities {
            //if k != .Barrens {
                var cur = chances[k.rawValue] ?? 0
                cur += (v * nonSticky)
                chances[k.rawValue] = cur
            //}
        }
        
        var list = chances.toArray() {"\($1)\($0)"}.sorted()
            {$0.substringToIndex($0.endIndex.predecessor()).toDouble()! > $1.substringToIndex($1.endIndex.predecessor()).toDouble()!}
        //NSLog(list * " | ")
        var c = 0.0
        var r = Double.random(min: 0, max: 1)
        for i in list {
            c += i.substringToIndex(i.endIndex.predecessor()).toDouble()!
            if r < c {
                return i[i.endIndex.predecessor()]
            }
        }
        return Tile.Barrens.rawValue
    }
    
    func markVisited(point:Point) {
        GD.tempWorldVisited[point.x][point.y] = true
        worldObserver?.tileUpdated(point.x, y: point.y, gray:false)
    }
    
    func drawMap() {
        
    }
    
    func die() {
        if !dead {
            dead = true
            GD.tempWorldMap = GD.worldMap
            GD.tempWorldMask = GD.worldMask
            GD.tempWorldVisited = GD.worldVisited
            GD.tempSulphurMine = false
            GD.tempIronMine = false
            GD.tempCoalMine = false
            GD.tempShip = false
            E.event("game event", act: "death")
            NM.notify(self, LS("the world fades"))
            GD.outfit.removeAll()
            E.activeModule = E.modules["room"]
            //TODO: cooldown embark button
            
            worldObserver?.died()
        }
    }
    
    func goHome() {
        GD.worldMap = GD.tempWorldMap
        GD.worldMask = GD.tempWorldMask
        GD.worldVisited = GD.tempWorldVisited
        if GD.tempSulphurMine && (GD.buildings["sulphur mine"] ?? 0) == 0 {
            GD.buildings["sulphur mine"]++
            E.event("progress", act: "sulphur mine")
        }
        if GD.tempIronMine && (GD.buildings["iron mine"] ?? 0) == 0 {
            GD.buildings["iron mine"]++
            E.event("progress", act: "iron mine")
        }
        if GD.tempCoalMine && (GD.buildings["coal mine"] ?? 0) == 0 {
            GD.buildings["coal mine"]++
            E.event("progress", act: "coal mine")
        }
        if GD.tempShip && (GD.availiableLocations["ship"] ?? false) == false {
            E.loadModule(Ship)
            E.event("progress", act: "ship")
        }
        foodMove = 0
        waterMove = 0
        fightMove = 0
        //TODO: Clear the embark cooldown
        /*
        var btn = Button.clearCooldown($('#embarkButton'));
        if(Path.outfit['cured meat'] > 0) {
            Button.setDisabled(btn, false);
        }
*/
        for (k,v) in GD.outfit {
            GD.stores[k] = (GD.stores[k] ?? 0) + v
            if leaveItAtHome(k) {
                GD.outfit[k] = 0
            }
        }
        
        dead = true
        
        E.activeModule = E.modules["path"]
        worldObserver?.wentHome()
    }
    
    func leaveItAtHome(thing:String) -> Bool {
        return thing != "cured meat" && thing != "bullets" && thing != "energy cell"  && thing != "charm" && thing != "medicine" && Res.weapons[thing] == nil && Res.craftables[thing] == nil
    }
    
    var maxHealth:Int {
        if GD.stores["s armour"] > 0 {
            return baseHealth + 35
        }
        else if GD.stores["i armour"] > 0 {
            return baseHealth + 15
        }
        else if GD.stores["l armour"] > 0 {
            return baseHealth + 5
        }
        return baseHealth
    }
    
    var hitChance:Double {
        return GD.hasPerk("precise") ? baseHitChance + 0.1 : baseHitChance
    }
    
    var maxWater:Int {
        if GD.stores["water tank"] > 0 {
            return baseWater + 50
        }
        else if GD.stores["cask"] > 0 {
            return baseWater + 20
        }
        else if GD.stores["waterskin"] > 0 {
            return baseWater + 10
        }
        return baseWater
    }
    
    func outpostUsed(point:Point?) -> Bool {
        return GD.usedOutposts.contains(point ?? currentPosition)
    }
    
    func useOutpost() {
        NM.notify(self, LS("water replenished"))
        water = maxWater
        GD.usedOutposts.append(currentPosition)
        worldObserver?.tileUpdated(currentPosition.x, y: currentPosition.y, gray:true)
    }
    
    override func onArrival() {
        super.onArrival()
        if dead {
            dead = false
            GD.tempWorldMap = GD.worldMap
            GD.tempWorldMask = GD.worldMask
            GD.tempWorldVisited = GD.worldVisited
            water = maxWater
            health = maxHealth
            starvation = false
            thirst = false
            currentPosition = villagePosition
            GD.usedOutposts.removeAll()
        }
        //drawMap()
        //updateSupplies()
    }
    
    weak var combatPlayerHealthLabel:UILabel?
    var playerPositionObserver:PlayerPositionObserver?
    var worldObserver:WorldObserver?
}

protocol PlayerPositionObserver {
    func playerPositionChanged()
}

protocol WorldObserver {
    func waterChanged()
    func outfitChanged()
    func tileUpdated(x:Int,y:Int,gray:Bool)
    func died()
    func wentHome()
}