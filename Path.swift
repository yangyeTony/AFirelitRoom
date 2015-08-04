//
//  Path.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 21/10/14.
//

import Foundation

final class Path:Module,StoresObserver {
    let DEFAULT_BAG_SPACE:Double = 10
    let carryable = Res.craftables.filter() {$0.1.itemType == ItemType.Weapon || $0.1.itemType == ItemType.Tool}.keys.array.union(["cured meat","bullets","grenade","bolas","laser rifle","energy cell","bayonet","charm","medicine"])
    
    required init() {
        super.init()
        
        id = "path"
        name = "Path"
        title = "A Dusty Path"
        displayTab = true
        
        GD.storesObservers.append(self)
        
        GD.availiableLocations["path"] = true
        
        E.loadModule(World)
        
        updateOutfit()
    }
    
    class func openPath() {
        E.loadModule(Path)
        E.event("progress", act: "path")
        NM.notify(E.path, LS("the compass points " + E.world!.direction.rawValue))
    }
    
    func getWeight(thing:String) -> Double {
        return Res.weight[thing] ?? 1
    }
    
    var capacity:Double {
        var plus:Double = 0
        if S.convoy > 0 {
            plus = 60
        } else if S.wagon > 0 {
            plus = 30
        } else if S.rucksack > 0 {
            plus = 10
        }
        return DEFAULT_BAG_SPACE + plus
    }
    
    var freeSpace:Double {
        return GD.outfit.reduce(capacity) {$0 - self.getWeight($1.0) * $1.1}
    }
    
    func embark() {
        GD.stores -= GD.outfit
        E.activeModule = E.world
    }
    
    func updateOutfit() {
        for item in carryable {
            if GD.outfit[item] == nil && GD.stores[item] != nil {
                GD.outfit[item] = 0
            }
        }
    }
    
    override func onArrival() {
        super.onArrival()
        updateOutfit()
    }
    
    func storesChanged() {
        updateOutfit()
        outfitObserver?.outfitChanged()
    }
    
    var outfitObserver:OutfitObserver?
}

protocol OutfitObserver {
    func outfitChanged()
    weak var embarkCellButton:CooldownButton? {get}
}
