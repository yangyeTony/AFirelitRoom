//
//  Outside.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 17/10/14.
//

import Foundation

final class Outside: Module {
    let _GATHER_DELAY:Double = 60
    let _TRAPS_DELAY:Double = 90
    let _POP_DELAY:[UInt32] = [30, 150]
    
    var popTimer: NSTimer?
    
    var maxPopulation:Int {
        get {return B.hut * 4}
    }

    var gatherWoodButton:ButtonConfig!
    var checkTrapsButton:ButtonConfig!
    var buttonsContainer = [ButtonConfig]()
    
    var popIncreaseScheduled = false
    
    required init() {
        super.init()
        
        id = "outside"
        name = "Outside"
        title = "A Silent Forest"
        displayTab = true
        
        checkTrapsButton = ButtonConfig(id: "trapsButton", text: "check traps", cooldown: _TRAPS_DELAY) {self.checkTraps()}
        
        gatherWoodButton = ButtonConfig(id: "gatherButton", text: "gather wood", cooldown: _GATHER_DELAY, action: {self.gatherWood()})
        buttonsContainer.append(gatherWoodButton)
        
        GD.buildingsObserver = self
        
        GD.availiableLocations["outside"] = true
        
        updateTitle()
    }
    
    func increasePopulation() {
        let space = maxPopulation - GD.population
        if space > 0 {
            var num = Int(space / 2 + Int(arc4random_uniform(UInt32(space) / 2 + 1)))
            if num == 0 {
                num = 1
            }
            var text:String
            switch num {
            case 1:
                text = "a stranger arrives in the night"
            case 2...4:
                text = "a weathered family takes up in one of the huts."
            case 5...9:
                text = "a small group arrives, all dust and bones."
            case 10...29:
                text = "a convoy lurches in, equal parts worry and hope."
            default:
                text = "the town's booming. word does get around."
            }
            NM.notify(self, LS(text));
            GD.population += num
        }
        schedulePopIncrease()
    }
    
    func schedulePopIncrease() {
        let nextIncrease = Int.random(min:30,max:150)
        NSTimer.schedule(delay: Double(nextIncrease)) {[unowned self] _ in
            self.popIncreaseScheduled = false
            self.increasePopulation()
        }
    }
    
    func killVillagers(num:Int) {
        var newPop = GD.population - num
        if newPop < 0 {
            GD.population = 0
        }
        else {
            GD.population = newPop
        }
        
        let remaining = getNumGatherers()
        if remaining < 0 {
            var gap = -remaining
            while gap != 0 {
                for (k,v) in GD.workers {
                    if v > 0 {
                        let remove = (v >= gap) ? gap : v
                        GD.workers[k] = GD.workers[k]! - remove
                        gap -= remove
                    }
                }
            }
        }
    }
    
    func getNumGatherers() -> Int {
        return GD.workers.reduce(GD.population) {$0 - $1.1}
    }
    
    func updateTitle() {
        var numHuts = B.hut
        var title:String
        switch numHuts {
        case 0:
            title = "A Silent Forest"
        case 1:
            title = "A Lonely Hut"
        case 2...4:
            title = "A Tiny Village"
        case 5...8:
            title = "A Modest Village"
        case 9...14:
            title = "A Large Village"
        default:
            title = "A Raucous Village"
        }
        if self.title != title {
            self.title = title
        }
    }
    
    override func onArrival() {
        super.onArrival()
        updateTitle()
        if !GD.seenForest {
            NM.notify(self, LS("the sky is grey and the wind blows relentlessly"))
            GD.seenForest = true
        }
        updateTrapButton()
        updateVillage()
        
        //only for screenshots
        /*
        NSTimer.schedule(delay: 0.2) {_ in
            Events.startEvent(Events.eventPool.takeFirst( {$0.title == "The Thief"})!)
        }
        */
    }
    
    func gatherWood() {
        NM.notify(self, LS("dry brush and dead branches litter the forest floor"))
        S.wood += GD.buildings["cart"] > 0 ? 50 : 10
    }
    
    func checkTraps() {
        var drops = [String:Double]()
        var msg = [String]()
        var numTraps = B.trap
        var numBait = 0
        var seenBait = false
        if let b = GD.stores["bait"] {
            numBait = Int(b)
            seenBait = true
        }
        var numDrops = numTraps + (numBait < numTraps ? numBait : numTraps)
        for i in 0..<numDrops {
            let roll = Double.random(min: 0, max: 1)
            for (dropName, drop) in Res.trapDrops {
                if roll >= drop.rollUnder {
                    var num = drops[dropName]
                    if num == nil {
                        num = 0
                        msg.append(drop.message)
                    }
                    drops[dropName] = num! + 1
                }
            }
        }
        var s = LS("the traps contain ")
        for i in 0..<msg.count {
            if i == msg.count-1 && msg.count != 1 {
                s += LS(" and ")
            } else if i != 0 {
                s += ", "
            }
            s += LS(msg[i])
        }
        if msg.count == 0 {
            s += LS("nothing")
        }
        
        var baitUsed = numBait < numTraps ? numBait : numTraps
        if seenBait {
            drops["bait"] = Double(-baitUsed)
        }
    
        NM.notify(self, s);
        GD.stores += drops
    }
    
    func updateVillage() {
        if B.hut > 0 && !popIncreaseScheduled {
            schedulePopIncrease()
        }
    }
    
    func updateTrapButton() {
        if let stuffObserver = stuffObserver {
            let contains = buttonsContainer.contains(checkTrapsButton)
            if B.trap > 0 && !contains {
                buttonsContainer.append(checkTrapsButton)
            }
            else if B.trap == 0 {
                buttonsContainer.remove(checkTrapsButton)
            }
            stuffObserver.stuffChanged()
        }
    }
    
    var stuffObserver:OutsideStuffObserver?
}

extension Outside: BuildingsObserver {
    func buildingsChanged() {
        let jobMap = ["lodge": ["hunter", "trapper"],
        "tannery": ["tanner"],
        "smokehouse": ["charcutier"],
        "iron mine": ["iron miner"],
        "coal mine": ["coal miner"],
        "sulphur mine": ["sulphur miner"],
        "steelworks": ["steelworker"],
        "armoury" : ["armourer"]]
        for (k,v) in jobMap {
            if GD.buildings[k] > 0 {
                for worker in v {
                    if GD.workers[worker] == nil {
                        GD.workers[worker] = 0
                    }
                }
            }
        }
        stuffObserver?.stuffChanged()
    }
}

protocol OutsideStuffObserver {
    func stuffChanged()
}
