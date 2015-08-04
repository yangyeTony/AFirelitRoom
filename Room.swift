//
//  Room.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 17/10/14.
//

import Foundation

enum Temperature:Int, IntEnum {
    case Freezing = 0, Cold, Mild, Warm, Hot
    func ld() -> String {
        var s=""
        switch self.rawValue {
        case 0:
            s = "freezing"
        case 1:
            s = "cold"
        case 2:
            s = "mild"
        case 3:
            s = "warm"
        case 4:
            s = "hot"
        default:
            break
        }
        return LS(s)
    }
}

enum Fire:Int, IntEnum {
    case Dead = 0, Smoldering, Flickering, Burning, Roaring
    func ld() -> String {
        var s=""
        switch self.rawValue {
        case 0:
            s = "dead"
        case 1:
            s = "smoldering"
        case 2:
            s = "flickering"
        case 3:
            s = "burning"
        case 4:
            s = "roaring"
        default:
            break
        }
        return LS(s)
    }
}

enum BuilderState:Int, IntEnum {
    case None = -1, Approaching, Collapsed, Shivering, Sleeping, Helping
}

final class Room:Module, StoresObserver {
    let _FIRE_COOL_DELAY:Double = 5 * 60 // time after a stoke before the fire cools
    let _ROOM_WARM_DELAY:Double = 30 // time between room temperature updates
    let _BUILDER_STATE_DELAY:Double = 0.5 * 60 // time between builder state updates
    let _STOKE_COOLDOWN:Double = 10 // cooldown to stoke the fire
    let _NEED_WOOD_DELAY:Double = 15 // from when the stranger shows up, to when you need wood
    
    var lightFireButton:ButtonConfig!
    var stokeFireButton:ButtonConfig!
    var buttonsContainer = [ButtonConfig]()
    
    var fireChanged = false
    var temperatureChanged = false
    var dark = false
    
    var fire:Fire {
        get {
            return GD.fire
        }
        set {
            GD.fire = newValue
            onFireChange()
        }
    }
    
    required init() {
        
        super.init()
        
        id = "room"
        name = "Room"
        title = "A Dark Room"
        displayTab = true
        
        GD.availiableLocations["room"] = true
        
        GD.storesObservers.append(self)
        
        lightFireButton = ButtonConfig(id: "lightButton", text: "light fire", cooldown: 0, cost: ["wood": 5.0], action: {
            self.lightFire();
            self.stokeFireButton.activationTime = NSDate.timeIntervalSinceReferenceDate() + self._STOKE_COOLDOWN}) ~ {$0.forceHideCost = GD.stores["wood"] == nil}
        stokeFireButton = ButtonConfig(id: "stokeButton", text: "stoke fire", cooldown: _STOKE_COOLDOWN, cost: ["wood": 1.0], action: {self.stokeFire()}) ~ {$0.forceHideCost = GD.stores["wood"] == nil}
        buttonsContainer.append(fire == .Dead ? lightFireButton : stokeFireButton)
        
        NSTimer.schedule(repeatInterval: _FIRE_COOL_DELAY) {[unowned self] _ in
            self.coolFire()
        }
        NSTimer.schedule(repeatInterval: _ROOM_WARM_DELAY) {[unowned self] _ in
            self.adjustTemp()
        }
        
        if GD.builderState >= .Approaching && GD.builderState < .Sleeping {
            NSTimer.schedule(delay: _BUILDER_STATE_DELAY) {[unowned self] _ in
                self.updateBuilderState()
            }
        }
        if GD.builderState == .Collapsed {
            NSTimer.schedule(delay: _NEED_WOOD_DELAY) {[unowned self] _ in
                self.unlockForest()
            }
        }
        
        updateTitle()
        
        NSTimer.schedule(repeatInterval: 10.0) { _ in
            GD.collectIncome()
        }
        
        Events.scheduleNextEvent()
    }
    
    
    func notifyTemperature() {
        NM.notify(self, LS("the room is {0}", [GD.temperature.ld()]))
    }
    
    func notifyFire() {
        NM.notify(self, LS("the fire is {0}", [fire.ld()]))
    }
    
    override func onArrival() {
        super.onArrival()
        /*
        if fireChanged {
            notifyFire()
            fireChanged = false
        }
        
        if temperatureChanged {
            notifyTemperature()
            temperatureChanged = false
        }
        */
        if GD.builderState == .Sleeping {
            GD.builderState++
            GD.income["builder"] = ["wood" : 2]
            NM.notify(self, LS("the stranger is standing by the fire. she says she can help. says she builds things."))
        }
        updateTitle()
        updateAvailiableStuff()

    }
    
    func lightFire() {
        if let wood = GD.stores["wood"] {
            lightFireButton.forceHideCost = false
            if S.wood < 5  {
                NM.notify(self, LS("not enough wood to get the fire going"))
                E.buttons["lightButon"]?.clearCooldown()
                return
            } else if S.wood > 4 {
                S.wood -= 5
            }
        }
        fire = .Burning
        buttonsContainer[0] = stokeFireButton
    }
    
    func stokeFire() {
        if let wood = GD.stores["wood"] {
            stokeFireButton.forceHideCost = false
            if S.wood == 0  {
                NM.notify(self, LS("the wood has run out"))
                E.buttons["stokeButon"]?.clearCooldown()
                return
            } else if S.wood > 0 {
                S.wood -= 1
            }
        }
        fire++
    }
    
    func onFireChange() {
        if fire == .Dead {
            buttonsContainer[0] = lightFireButton
        }
        if E.activeModule != self {
            fireChanged = true
        }
        notifyFire()
        
        if GD.builderState == .None && fire > .Smoldering {
            GD.builderState = .Approaching
            NM.notify(self, LS("the light from the fire spills from the windows, out into the dark"))
            NSTimer.schedule(delay: _BUILDER_STATE_DELAY) {[unowned self] _ in
                self.updateBuilderState()
            }
        }
        updateTitle()
    }
    
    func coolFire() {
        if fire <= .Flickering && GD.builderState == .Helping && S.wood > 0 {
            NM.notify(self, LS("builder stokes the fire"), noQueue:true);
            S.wood--
        }
        else {
            fire--
        }
    }
    
    func adjustTemp() {
        if GD.temperature.rawValue > GD.fire.rawValue {
            GD.temperature--
            notifyTemperature()
            temperatureChanged = true
        }
        else if GD.temperature.rawValue < GD.fire.rawValue {
            GD.temperature++
            notifyTemperature()
            temperatureChanged = true
        }
    }
    
    func unlockForest() {
        if GD.availiableLocations["outside"] == nil {
            S.wood = 4
            E.loadModule(Outside)
            NM.notify(self, LS("the wind howls outside"))
            NM.notify(self, LS("the wood is running out"))
            E.event("progress", act: "outside")
        }
    }
    
    func updateTitle() {
        let title = fire > .Flickering ? "A Firelit Room" : "A Dark Room"
        dark = fire <= .Flickering
        if self.title != title {
            self.title = title
            stuffObserver?.stuffChanged()
        }
    }
    
    
    func updateBuilderState() {
        if GD.builderState == .Approaching {
            NM.notify(self, LS("a ragged stranger stumbles through the door and collapses in the corner"))
            GD.builderState++
            NSTimer.schedule(delay: _NEED_WOOD_DELAY) {[unowned self] _ in
                self.unlockForest()
            }
        }
        let warm = GD.temperature >= .Warm
        switch GD.builderState {
        case .Collapsed where warm:
            NM.notify(self, LS("the stranger shivers, and mumbles quietly. her words are unintelligible."))
        case .Shivering where warm:
            NM.notify(self, LS("the stranger in the corner stops shivering. her breathing calms."))
        default:
            break
        }
        if GD.builderState < .Sleeping {
            NSTimer.schedule(delay: _BUILDER_STATE_DELAY) {[unowned self] _ in
                self.updateBuilderState()
            }
            if warm {
                GD.builderState++
            }
        }
        E.saveGame()
    }
    
    func buy(button:CooldownButton) {
        var thing = button.buildThing!
        var good = Res.tradeGoods[thing]!
        var numThings = Int(GD.stores[thing]) ?? 0
        if numThings < 0 {
            numThings = 0
        }
        if let max = good.maximum where max != 0 && max <= numThings {
            return
        }
        
        var storeMod = [String:Double]()
        var cost = good.cost!
        for (k,v) in cost {
            var have = GD.stores[k] ?? 0
            if have < v {
                NM.notify(self, LS("not enough " + k))
                return
            } else {
                storeMod[k] = -v
            }
        }
        GD.stores += storeMod
        
        GD.stores[thing]++
        
        NM.notify(self,"+1 \(LS(thing)) (\(Int(GD.stores[thing]!)))")
        
        if thing == "compass" {
            Path.openPath()
        }
        updateAvailiableStuff()
    }
    
    func build(button:CooldownButton) {
        var thing = button.buildThing!
        if GD.temperature <= .Cold {
            NM.notify(self, LS("builder just shivers"))
            return
        }
        var craftable = Res.craftables[thing]!
        
        var numThings = 0
        if craftable.itemType == ItemType.Building {
            numThings = GD.buildings[thing] ?? 0
        } else {
            numThings = Int(GD.stores[thing]) ?? 0
        }
        
        if numThings < 0 {
            numThings = 0
        }
        if let max = craftable.maximum where max != 0 && max <= numThings {
            return
        }
        
        var storeMod = [String:Double]()
        var notEnough = false
        var cost = craftable.getCost()
        for (k,v) in cost {
            var have = GD.stores[k] ?? 0
            if have < v {
                NM.notify(self, LS("not enough " + k))
                notEnough = true
            } else {
                storeMod[k] = -v
            }
        }
        
        if notEnough {
            return
        }
        
        GD.stores += storeMod
        
        
        NM.notify(self, LS(craftable.buildMsg))
        
        if craftable.itemType == .Building {
            GD.buildings[thing]++
            if let max = craftable.maximum, let maxMsg = craftable.maxMsg where max <= GD.buildings[thing] {
                 NM.notify(self, LS(maxMsg))
            }
        }
        else {
            GD.stores[thing]++
            if let max = craftable.maximum, let maxMsg = craftable.maxMsg where max <= Int(GD.stores[thing]) {
                NM.notify(self, LS(maxMsg))
            }
        }
        if thing == "hut" {
            E.outside?.updateTitle()
        }
        
        updateAvailiableStuff()
    }
    
    func needsWorkshop(type:ItemType) -> Bool {
        return type == .Weapon || type == .Upgrade || type == .Tool
    }
    
    func craftUnlocked(thing:String) -> Bool {

        if GD.buttons[thing] == true {
            return true
        }
        if GD.builderState < .Helping {
            return false
        }
        var craftable = Res.craftables[thing]!
        
        if needsWorkshop(craftable.itemType) && GD.buildings["workshop"] == nil {
            return false
        }
        var cost = craftable.getCost()
        
        //show button if one has already been built
        if GD.buildings[thing] > 0{
            GD.buttons[thing] = true
            return true;
        }
        // Show buttons if we have at least 1/2 the wood, and all other components have been seen.
        if let woodCost = cost["wood"] {
            if S.wood < woodCost / 2 {
                return false
            }
        }
        
        for (k,v) in cost {
            if GD.stores[k] == nil {
                return false
            }
        }
        
        GD.buttons[thing] = true
        //don't notify if it has already been built before
        if GD.buildings[thing] == nil{
            NM.notify(self, LS(craftable.availableMsg))
        }
        return true
    }
    
    func buyUnlocked(thing:String) -> Bool {
        if GD.buttons[thing] == true {
            return true
        } else if GD.buildings["trading post"] > 0 {
            if thing == "compass" || GD.stores[thing] != nil {
                // Allow the purchase of stuff once you've seen it
                return true
            }
        }
        return false
    }
    
    func updateAvailiableStuff() {
        let crafts = Res.craftables.filter() {[unowned self] (k,v) in
            if let max = v.maximum where max <= ((v.itemType == ItemType.Building) ? (GD.buildings[k] ?? 0) : Int(GD.stores[k] ?? 0)){
                return false
            }
            return self.craftUnlocked(k)
            }
            //.each() {println($0.0)}
        availiableCrafts = crafts.filter() {[unowned self] (k,v) in self.needsWorkshop(v.itemType)}.keys.array
        availiableBuildings = crafts.filter() {[unowned self] (k,v) in !self.needsWorkshop(v.itemType)}.keys.array
        
        availiableGoods = Res.tradeGoods.filter() {[unowned self] (k,v) in
            if let max = v.maximum where max <= Int(GD.stores[k] ?? 0){
                return false
            }
            return self.buyUnlocked(k)
        }.keys.array
        
    }
    
    var availiableCrafts = [String]() {
        didSet{
            if let stuffObserver = stuffObserver {
                let contains = buttonsContainer.contains(stuffObserver.craftButton)
                if availiableCrafts.count > 0 && !contains {
                    buttonsContainer.append(stuffObserver.craftButton)
                }
                else if availiableCrafts.count == 0 {
                    buttonsContainer.remove(stuffObserver.craftButton)
                }
                stuffObserver.stuffChanged()
            }
        }
    }
    var availiableBuildings = [String]() {
        didSet{
            if let stuffObserver = stuffObserver {
                let contains = buttonsContainer.contains(stuffObserver.buildButton)
                if availiableBuildings.count > 0 && !contains {
                    buttonsContainer.append(stuffObserver.buildButton)
                }
                else if availiableBuildings.count == 0 {
                    buttonsContainer.remove(stuffObserver.buildButton)
                }
                stuffObserver.stuffChanged()
            }
        }
    }
    var availiableGoods = [String]() {
        didSet{
            if let stuffObserver = stuffObserver {
                let contains = buttonsContainer.contains(stuffObserver.buyButton)
                if availiableGoods.count > 0 && !contains {
                    buttonsContainer.append(stuffObserver.buyButton)
                }
                else if availiableGoods.count == 0 {
                    buttonsContainer.remove(stuffObserver.buyButton)
                }
                stuffObserver.stuffChanged()
            }
        }
    }
    var stuffObserver:RoomStuffObserver?
    
    func storesChanged() {
        updateAvailiableStuff()
    }
}

protocol RoomStuffObserver {
    func stuffChanged()
    var buildButton:ButtonConfig {get}
    var buyButton:ButtonConfig {get}
    var craftButton:ButtonConfig {get}
}
