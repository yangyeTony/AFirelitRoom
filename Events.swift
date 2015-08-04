//
//  Events.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 23/10/14.
//

import UIKit

let Events = EventsClass() //TODO: state resoration

final class EventsClass: StoresObserver {
    var eventTimeRange = (min:3.0,max:6.0) // range, in minutes
    var fightSpeed = 0.1 // in seconds
    static var eatCooldown = 5.0
    static var medsCooldown = 7.0
    var stunDuration = 4.0
    var encounters = [Event]()
    var setPieces = [String:Event]()
    
    var eventPool = [Event]()
    var eventStack = [Event]()
    
    var activeScene:Scene?
    var activeEvent:Event? {
        get {
            return eventStack.first
        }
    }
    var isCombat:Bool {
        return activeScene?.combat ?? false
    }
    var won = false
    var enemyAttackTimer:NSTimer?
    var enemyHealth:Int? {
        didSet {
            combatEnemyHealthLabel?.text = "\(enemyHealth!)/\(enemyMaxHealth!)"
        }
    }
    var enemyMaxHealth:Int?
    var enemyStunned = false
    
    var eventView:EventView
    var popupContainer:PopupContainer?
    var activeLoot = [String:Double]()
    var activeButtons = [ButtonConfig]() {
        didSet {
            buttonsChanged()
        }
    }
    
    init() {
        
        eventView = NSBundle.mainBundle().loadNibNamed("EventView", owner: nil, options: nil)[0] as! EventView
        eventView.configure()
        //popupContainer = PopupContainer.generatePopupWithView(eventView)
        
        EventsPopupController.addEventView(eventView)
        
        GD.storesObservers.append(self)
        
        var events = EventsDict["Room"] as! [AnyObject]
        events.each() {
            //self.roomEvents.append(Event(dict: $0))
            self.eventPool.append(Event(dict: $0))
        }
        events = EventsDict["Outside"] as! [AnyObject]
        events.each() {
            //self.outsideEvents.append(Event(dict: $0))
            self.eventPool.append(Event(dict: $0))
        }
        events = EventsDict["Global"] as! [AnyObject]
        events.each() {
            //self.globalEvents.append(Event(dict: $0))
            self.eventPool.append(Event(dict: $0))
        }
        events = EventsDict["Encounters"] as! [AnyObject]
        events.each() {
            self.encounters.append(Event(dict: $0))
        }
        var set = EventsDict["Setpieces"] as! [String:AnyObject]
        set.each() {
            self.setPieces[$0] = Event(dict: $1)
        }
        
        //scheduleNextEvent()
    }
    
    func loadScene(name:String) {
        activeScene = activeEvent!.scenes[name]
        let scene = activeScene!
        
        if let reward = scene.reward {
            GD.stores += reward
        }
        
        scene.onLoad?()
        
        if let notification = scene.notification {
            NM.notify(nil,LS(notification))
        }
        
        activeButtons.removeAll()
        activeLoot.removeAll()
        eventView.sceneDescription.removeAll()
        
        if scene.combat {
            startCombat(scene)
        }
        else {
            startStory(scene)
        }
        
    }
    
    func startCombat(scene:Scene) {
        won = false
        if let desc = scene.notification {
            eventView.sceneDescription.append(desc)
        }
        
        enemyHealth = scene.health
        enemyMaxHealth = scene.health
        
        var numWeapons = 0
        for (weaponName, weapon) in Res.weapons {
            if (GD.outfit[weaponName] ?? 0) > 0 {
                if weapon.damage == nil || (weapon.damage as? Int) == 0 {
                    numWeapons--
                }
                else if let cost = weapon.cost {
                    for (k,v) in cost {
                        if (GD.outfit[k] ?? 0) < v {
                            numWeapons--
                        }
                    }
                }
                numWeapons++
                activeButtons.append(createAttackButton(weaponName))
            }
        }
        if numWeapons == 0 {
            activeButtons.insert(createAttackButton("fists"), atIndex: 0)
        }
        activeButtons.append(createEatMeatButton())
        if (GD.outfit["medicine"] ?? 0) > 0 {
            activeButtons.append(createUseMedsButton())
        }
        
        if let attackDelay = scene.attackDelay {
            enemyAttackTimer = NSTimer.schedule(delay: attackDelay) {[unowned self] _ in
                self.enemyAttack()
            }
        }
        
    }
    
    func startStory(scene:Scene) {
        if let text = scene.text {
            eventView.sceneDescription = text
        }
        //join("\n", (scene.text!.map(){LS($0)})) // scene.text?.reduce("") {$0 + LS($1) + ""}
        
        if let loot = scene.loot {
            createLoot(loot)
        }
        
        createButtons(scene)
    }
    
    func createEatMeatButton(cooldown:Double = eatCooldown) -> ButtonConfig {
        var button = ButtonConfig(id: "eat", text: LS("eat meat"), cooldown: cooldown, cost: ["cured meat": 1]) {[unowned self] in
            self.eatMeat()
        }
        if (GD.outfit["cured meat"] ?? 0) == 0 {
            button.enabled = false
        }
        return button
    }
    
    func createUseMedsButton(cooldown:Double = medsCooldown) -> ButtonConfig {
        var button = ButtonConfig(id: "meds", text: LS("use meds"), cooldown: cooldown, cost: ["medicine": 1]) {[unowned self] in
            self.eatMeat()
        }
        if (GD.outfit["medicine"] ?? 0) == 0 {
            button.enabled = false
        }
        return button
    }
    
    func createAttackButton(weaponName:String) -> ButtonConfig {
        let weapon = Res.weapons[weaponName]!
        var cooldown = weapon.cooldown
        if weapon.weaponType == WeaponType.Unarmed && GD.hasPerk("unarmed master") {
            cooldown = cooldown / 2
        }
        var button = ButtonConfig(id: "attack_" + weaponName, text: LS(weapon.verb), cooldown: cooldown, cost: weapon.cost)
        button.action = {[unowned self] in
            self.useWeapon(button)
        }
        if let damage = weapon.damage as? Int where damage > 0 {
            button.type = .Weapon
        }
        button.enabled = !((weapon.cost?.any() {GD.outfit[$0.0] == nil || GD.outfit[$0.0]! < $0.1}) ?? false)
        
        return button
    }
    
    func eatMeat() {
        if (GD.outfit["cured meat"] ?? 0) > 0 {
            GD.outfit["cured meat"] = GD.outfit["cured meat"]! - 1
            if GD.outfit["cured meat"]! == 0 {
                activeButtons.filter() {$0.id == "eat"}.first?.enabled = false
            }
            E.world!.health += E.world!.meatHeal
            if activeEvent != nil {
                eventView.animateHeal(E.world!.meatHeal)
            }
        }
    }
    
    func useMeds() {
        if (GD.outfit["medicine"] ?? 0) > 0 {
            GD.outfit["medicine"] = GD.outfit["medicine"]! - 1
            if GD.outfit["medicine"]! == 0 {
                activeButtons.filter() {$0.id == "meds"}.first?.enabled = false
            }
            E.world!.health += E.world!.medsHeal
            if activeEvent != nil {
                eventView.animateHeal(E.world!.medsHeal)
            }
        }
    }
    
    func useWeapon(button:ButtonConfig) {
        let weaponName = button.id.substringFromIndex(advance(button.id.startIndex,7))
        let weapon = Res.weapons[weaponName]!
        if weapon.weaponType == .Unarmed {
            GD.characterPunches++
            switch GD.characterPunches {
            case 50 where !GD.hasPerk("boxer"):
                GD.addPerk("boxer")
            case 150 where !GD.hasPerk("martial artist"):
                GD.addPerk("martial artist")
            case 300 where !GD.hasPerk("unarmed master"):
                GD.addPerk("unarmed master")
            default:
                break
            }
        }
        if let cost = weapon.cost {
            var mod = [String:Double]()
            var out = false
            for (k,v) in cost {
                if (GD.outfit[k] ?? 0) < v {
                    return
                }
                mod[k] = -v
                if (GD.outfit[k] ?? 0) - v < v {
                    out = true
                }
            }
            GD.outfit += mod
            if out {
                button.enabled = false
                var validWeapons = activeButtons.any() {$0.enabled && $0.id != "attack_fists"}
                if !validWeapons {
                    if let fistsButton = (activeButtons.filter() {$0.id == "attack_fists"}.first) {
                        fistsButton.enabled = true
                        buttonsChanged()
                    }
                    else {
                        activeButtons.insert(createAttackButton("fists"), atIndex: 0)
                    }
                }
                else {
                    buttonsChanged()
                }
            }
        }
        var dmg = -1
        if Double.random(min: 0, max: 1) < E.world!.hitChance {
            if let damage = weapon.damage as? Int {
                dmg = damage
                switch weapon.weaponType {
                case .Unarmed where GD.hasPerk("boxer"):
                    dmg *= 2
                case .Unarmed where GD.hasPerk("martial artist"):
                    dmg *= 4
                case .Unarmed where GD.hasPerk("unarmed master"):
                    dmg *= 3
                case .Melee where GD.hasPerk("barbarian"):
                    dmg  = Int(Double(dmg)*1.5)
                default:
                    break
                }
            }
        }
        
        var attackFn = (weapon.weaponType == .Ranged) ? attackRanged : attackMelee
        
        attackFn(enemy: false, dmg: dmg, weaponName: weaponName) {[unowned self] in
            if let enemyHp = self.enemyHealth where enemyHp <= 0 && !self.won {
                self.winFight()
            }
        }
    }
    
    func attack(enemy:Bool = false, dmg:AnyObject) -> String {
        var dmgString = ""
        var damage = 0
        if let dmg = dmg as? Int {
            if dmg >= 0 {
                dmgString = "-\(dmg)"
                damage = dmg
                if enemy {
                    if E.world!.health - damage < 0{
                        E.world!.health = 0
                    }
                    else {
                        E.world!.health -= damage
                    }
                }
                else {
                    if enemyHealth! - damage < 0 {
                        enemyHealth = 0
                    }
                    else {
                        enemyHealth! -= damage
                    }
                }
            }
            else {
                dmgString = LS("miss")
            }
        }
            
        else if let dmg = dmg as? String where dmg == "stun" {
            dmgString = LS("stunned")
            enemyStunned = true
            NSTimer.schedule(delay: stunDuration) {[unowned self] _ in
                self.enemyStunned = false
            }
        }
        return dmgString
    }
    
    func attackMelee(enemy:Bool = false, dmg:AnyObject,weaponName:String?, callback:(()->Void)) {
        let dmgString = attack(enemy: enemy,dmg: dmg)
        
        eventView.animateHit(dmgString, ranged:false, enemy:enemy, weaponName:weaponName, duration:fightSpeed)
        
        NSTimer.schedule(delay: fightSpeed*2) {_ in
            callback()
        }
    }
    
    func attackRanged(enemy:Bool = false, dmg:AnyObject,weaponName:String?, callback:(()->Void)) {
        let dmgString = attack(enemy: enemy,dmg: dmg)
        
        eventView.animateHit(dmgString, ranged:true, enemy:enemy, weaponName:weaponName, duration:fightSpeed)
        
        NSTimer.schedule(delay: fightSpeed*2) {_ in
            callback()
        }
    }
    
    func enemyAttack() {
        if !enemyStunned {
            let toHit = activeScene!.hit! * (GD.hasPerk("evasive") ? 0.8 : 1)
            var dmg = -1
            if Double.random(min:0, max:1) <= toHit {
                dmg = activeScene!.damage!
            }
            
            var attackFn = activeScene!.ranged ? attackRanged : attackMelee
            
            attackFn(enemy: true, dmg: dmg,weaponName:nil) {[unowned self] in
                if E.world!.health <= 0 {
                    self.enemyAttackTimer?.invalidate()
                    self.enemyAttackTimer = nil
                    self.endEvent()
                    E.world!.die()
                }
            }
        }
        enemyAttackTimer = NSTimer.schedule(delay: activeScene!.attackDelay!) {[unowned self] _ in
            self.enemyAttack()
        }
    }
    
    func winFight() {
        won = true
        enemyAttackTimer?.invalidate()
        enemyAttackTimer = nil
        
        activeButtons.removeAll()
        NSTimer.schedule(delay: 1) {[unowned self] _ in
            if let deathMsg = self.activeScene?.deathMessage {
                self.eventView.sceneDescription = [deathMsg]
            }
            else {
                self.eventView.sceneDescription.removeAll()
            }
            if let loot = self.activeScene?.loot {
                self.createLoot(loot)
            }
            if !self.activeScene!.buttons.isEmpty {
                self.createButtons(self.activeScene!)
            }
            else {
                let button = ButtonConfig(id: "leaveBtn", text: LS("leave"), cooldown: 1) {[unowned self] in
                    if let nextScene = self.activeScene?.nextScene where nextScene != "end" {
                        self.loadScene(nextScene)
                    }
                    else {
                        self.endEvent()
                    }
                }
                self.activeButtons.append(button)
            }
            self.activeButtons.append(self.createEatMeatButton(cooldown: 0))
            if (GD.outfit["medicine"] ?? 0) > 0 {
                self.activeButtons.append(self.createUseMedsButton(cooldown: 0))
            }
        }
    }
    
    func createLoot(loot:[String:[String:Double]]) {
        for (item,params) in loot {
            if let chance = params["chance"], let min = params["min"], let max = params["max"] {
                if Double.random(min: 0, max: 1) < chance {
                    activeLoot[item] = Double(Int.random(min: Int(min), max: Int(max)))
                }
            }
        }
        buttonsChanged()
    }
    
    func createButtons(scene:Scene) {
        for (k,v) in scene.buttons {
            let button = ButtonConfig(eventButtonConfig: v, id: k)
            if let av = v.isAvailiable where !av() {
                button.enabled = false
            }
            if v.cooldown > 0 {
                button.startCooldown()
            }
            activeButtons.append(button)
        }
        updateButtons()
    }
    
    func updateButtons() {
        for button in activeButtons {
            let wasEnabled = button.enabled
            if let info = button.eventButtonConfig {
                if let av = info.isAvailiable where !av(){
                    if wasEnabled {
                        button.enabled = false
                        buttonsChanged()
                    }
                }
                else if let cost = info.cost {
                    var enabled = true
                    for (k,v) in cost {
                        var num = E.activeModule == E.world ? (GD.outfit[k] ?? 0) : (GD.stores[k] ?? 0)
                        if(num < v) {
                            enabled = false
                            break
                        }
                    }
                    if enabled != wasEnabled {
                        button.enabled = enabled
                        buttonsChanged()
                    }
                }
            }
        }
    }
    
    func buttonTap(button:CooldownButton) {
        if let id = button.config?.id, info = activeScene?.buttons[id] {
            if let cost = info.cost {
                var costMod = [String:Double]()
                for (k,v) in cost {
                    var num = E.activeModule == E.world ? (GD.outfit[k] ?? 0) : (GD.stores[k] ?? 0)
                    if(num < v) {
                        return
                    }
                    costMod[k] = -v
                }
                if E.activeModule == E.world {
                    GD.outfit += costMod
                }
                else {
                    GD.stores += costMod
                }
            }
            
            info.onChoose?()
            
            if let reward = info.reward {
                GD.stores += reward
            }
            
            if let notification = info.notification {
                NM.notify(nil,LS(notification))
            }
            
            if let nextScenes = info.nextScenes {
                if nextScenes.count == 1 && nextScenes.keys.array[0] == "end" {
                    endEvent()
                }
                else {
                    var r = Double.random(min: 0, max: 1)
                    var lowestMatch:Double?
                    var sceneKey:String?
                    for (k,v) in nextScenes {
                        if r < v && (lowestMatch == nil || v < lowestMatch!) {
                            lowestMatch = v
                            sceneKey = k
                        }
                    }
                    
                    if let sceneKey = sceneKey {
                        loadScene(sceneKey)
                        return
                    }
                    //no scenes found
                    endEvent()
                }
            }
        }
    }
    
    func triggerFight() {
        var possibleFights = encounters.filter() {$0.isAvailiable()}
        if let event = possibleFights.randomElement {
            startEvent(event)
        }
    }
    
    func triggerEvent() {
        if activeEvent == nil {
            var possibleEvents = eventPool.filter() {$0.isAvailiable()}
            
            if let event = possibleEvents.randomElement {
                startEvent(event)
            }
            else {
                scheduleNextEvent(scale: 0.5)
            }
        }
        else {
            scheduleNextEvent()
        }
    }
    
    func scheduleNextEvent(scale:Double = 1) {
        var nextEvent = Double.random(min: eventTimeRange.min, max: eventTimeRange.max) * scale
        NSTimer.schedule(delay: nextEvent*60) {[unowned self] _ in
            self.triggerEvent()
        }
    }
    
    func startEvent(event:Event) {
        eventStack.unshift(event)
        eventView.title = event.title
        loadScene("start")
        
        eventView.reloadData()
        //popupContainer.show()
        EventsPopupController.show()
    }
    
    func endEvent(completion: (() -> Void)? = nil) {
        eventStack.shift()
        //popupContainer.close()
        EventsPopupController.close(completion: completion)
    }
    
    func storesChanged() {
        updateButtons()
    }
    
    func buttonsChanged() {
        eventView.reloadData()
       // buttonsObserver?.buttonsChanged()
    }
    
    weak var combatEnemyHealthLabel:UILabel?
    var buttonsObserver:EventButtonsObserver?
}


protocol EventButtonsObserver {
    func buttonsChanged()
}




//Mark: Resources

let EventsDict = NSDictionary(contentsOfFile: NSBundle.mainBundle().pathForResource("events", ofType: "plist")!)! as! [String:AnyObject]

class Event {
    var title:String
    var isAvailiable:(()->Bool)!
    var scenes = [String:Scene]()
    init(dict:AnyObject) {
        let dict = dict as! [String:AnyObject]
        title = dict["title"] as! String
        customInit()
        for (k,v) in dict["scenes"] as! [String:AnyObject] {
            scenes[k] = Scene(dict: v, eventTitle: title, sceneKey: k)
        }
        
        //temporary
        //println(LS(title))
    }
    
    func customInit() {
        switch title {
    //Room
        case "The Nomad","The Beggar":
            isAvailiable = {return E.activeModule == E.room && S.fur > 0}
        case "Noises", "The Mysterious Wanderer":
            isAvailiable = {return E.activeModule == E.room && GD.stores["wood"] != nil}
        case "The Scout", "The Master":
            isAvailiable = {return E.activeModule == E.room && GD.availiableLocations["world"] != nil}
        case "The Sick Man":
            isAvailiable = {return E.activeModule == E.room && (GD.stores["medicine"] ?? 0) > 0}
    //Global
        case "The Thief":
            isAvailiable = {return GD.thieves == 1 && (E.activeModule == E.room || E.activeModule == E.outside)}
    //Outside
        case "A Ruined Trap":
            isAvailiable = {return E.activeModule == E.outside && B.trap > 0}
        case "Fire":
            isAvailiable = {return E.activeModule == E.outside && B.hut > 0 && GD.population > 5}
        case "Sickness":
            isAvailiable = {return E.activeModule == E.outside && (GD.stores["medicine"] ?? 0) > 0 && GD.population > 10 && GD.population < 50}
        case "Plague":
            isAvailiable = {return E.activeModule == E.outside && (GD.stores["medicine"] ?? 0) > 0 && GD.population > 50}
        case "A Beast Attack":
            isAvailiable = {return E.activeModule == E.outside && GD.population > 1}
        case "A Military Raid":
            isAvailiable = {return E.activeModule == E.outside && GD.population > 0 && GD.cityCleared}
    //Encounters
        case "A Snarling Beast":
            isAvailiable = {return E.world!.getDistance() <= 10 && E.world!.terrain == .Forest}
        case "A Gaunt Man":
            isAvailiable = {return E.world!.getDistance() <= 10 && E.world!.terrain == .Barrens}
        case "A Strange Bird":
            isAvailiable = {return E.world!.getDistance() <= 10 && E.world!.terrain == .Field}
        case "A Shivering Man", "A Scavenger":
            isAvailiable = {return E.world!.getDistance() > 10 && E.world!.getDistance() <= 20 && E.world!.terrain == .Barrens}
        case "A Man-Eater":
            isAvailiable = {return E.world!.getDistance() > 10 && E.world!.getDistance() <= 20 && E.world!.terrain == .Forest}
        case "A Huge Lizard":
            isAvailiable = {return E.world!.getDistance() > 10 && E.world!.getDistance() <= 20 && E.world!.terrain == .Field}
        case "A Feral Terror":
            isAvailiable = {return E.world!.getDistance() > 20 && E.world!.terrain == .Forest}
        case "A Soldier":
            isAvailiable = {return E.world!.getDistance() > 20 && E.world!.terrain == .Barrens}
        case "A Sniper":
            isAvailiable = {return E.world!.getDistance() > 20 && E.world!.terrain == .Field}
        default:
            break
        }
    }
}

class Scene {
    //var blink = false
    var notification:String?
    var buttons = [String:EventButton]()
    var text:[String]?
    var reward:[String:Double]?
    var onLoad:(()->Void)?
    //Encounters
    var combat = false
    var ranged = false
    var damage:Int?
    var hit:Double?
    private var enemyName:String?
    var attackDelay:Double?
    var health:Int?
    var loot:[String:[String:Double]]?
    var chara:String?
    var deathMessage:String?
    var enemy:String?
    var nextScene:String?
    
    init(dict:AnyObject, eventTitle:String, sceneKey:String) {
        //blink = (dict["blink"] as? Bool) ?? false
        if let dict = dict as? [String:AnyObject] {
            text = dict["text"] as? [String]
            reward = dict["reward"] as? [String:Double]
            combat = (dict["combat"] as? Bool) ?? false
            ranged = (dict["ranged"] as? Bool) ?? false
            damage = dict["damage"] as? Int
            hit = dict["hit"] as? Double
            enemyName = dict["enemyName"] as? String
            attackDelay = dict["attackDelay"] as? Double
            health = dict["health"] as? Int
            loot = dict["loot"] as? [String:[String:Double]]
            chara = dict["chara"] as? String
            deathMessage = dict["deathMessage"] as? String
            enemy = dict["enemy"] as? String
            nextScene = dict["nextScene"] as? String
            if let buttons = dict["buttons"] as? [String:AnyObject] {
                for (k,v) in buttons {
                    self.buttons[k] = EventButton(dict: v, eventTitle: eventTitle, sceneKey: sceneKey, buttonKey: k)
                }
            }
        }
        customInit(eventTitle, sceneKey: sceneKey)
        
        //temporary
        /*
        if let t = deathMessage {
            println(LS(t))
        }
        
        if let text = text {
            text.each() {
                println(LS($0))
            }
            
        }
*/
    }
    
    func customInit(eventTitle:String, sceneKey:String) {
        switch sceneKey {
        case "scales" where eventTitle == "Noises":
            onLoad = {[unowned GD] in
                var numWood = floor(S.wood * 0.1)
                var numScales = floor(numWood / 5)
                GD.stores += ["wood":-(numWood == 0 ? 1 : numWood),"scales":(numScales == 0 ? 1 : numScales)]
            }
        case "teeth" where eventTitle == "Noises":
            onLoad = {[unowned GD] in
                var numWood = floor(S.wood * 0.1)
                var numScales = floor(numWood / 5)
                GD.stores += ["wood":-(numWood == 0 ? 1 : numWood),"teeth":(numScales == 0 ? 1 : numScales)]
            }
        case "cloth" where eventTitle == "Noises":
            onLoad = {[unowned GD] in
                var numWood = floor(S.wood * 0.1)
                var numScales = floor(numWood / 5)
                GD.stores += ["wood":-(numWood == 0 ? 1 : numWood),"cloth":(numScales == 0 ? 1 : numScales)]
            }
        case "100wood" where eventTitle == "The Mysterious Wanderer":
            onLoad = {
                if Bool.random {
                    NSTimer.schedule(delay: 60) {_ in
                        S.wood += 300
                        NM.notify(E.room, LS("the mysterious wanderer returns, cart piled high with wood."))
                    }
                }
            }
        case "500wood" where eventTitle == "The Mysterious Wanderer":
            onLoad = {
                if Bool.random {
                    NSTimer.schedule(delay: 60) {_ in
                        S.wood += 1500
                        NM.notify(E.room, LS("the mysterious wanderer returns, cart piled high with wood."))
                    }
                }
            }
        case "100fur" where eventTitle == "The Mysterious Wanderer":
            onLoad = {
                if Bool.random {
                    NSTimer.schedule(delay: 60) {_ in
                        S.fur += 300
                        NM.notify(E.room, LS("the mysterious wanderer returns, cart piled high with furs."))
                    }
                }
            }
        case "500fur" where eventTitle == "The Mysterious Wanderer":
            onLoad = {
                if Bool.random {
                    NSTimer.schedule(delay: 60) {_ in
                        S.fur += 1500
                        NM.notify(E.room, LS("the mysterious wanderer returns, cart piled high with furs."))
                    }
                }
            }
        case "alloy" where eventTitle == "The Sick Man":
            onLoad = {
                S.alienAlloy++
            }
        case "cells" where eventTitle == "The Sick Man":
            onLoad = {
                S.energyCell += 3
            }
        case "scales" where eventTitle == "The Sick Man":
            onLoad = {
                S.scales += 5
            }
        case "hang" where eventTitle == "The Thief":
            onLoad = {[unowned GD] in
                GD.thieves = 2
                GD.income["thieves"] = nil
                GD.stores += GD.stolen
            }
        case "spare" where eventTitle == "The Thief":
            onLoad = {[unowned GD] in
                GD.thieves = 2
                GD.income["thieves"] = nil
                GD.addPerk("stealthy")
            }
        case "start" where eventTitle == "A Ruined Trap":
            onLoad = {[unowned E] in
                var numWrecked = Int.random(min: 1, max: B.trap)
                B.trap -= numWrecked
                E.outside?.updateTrapButton()
            }
        case "start" where eventTitle == "Fire":
            onLoad = {[unowned E] in
                B.hut--
                E.outside?.killVillagers(4)
            }
        case "death" where eventTitle == "Sickness":
            onLoad = {[unowned E] in
                E.outside?.killVillagers(Int.random(min: 1, max: 21))
            }
        case "healed" where eventTitle == "Plague":
            onLoad = {[unowned E] in
                E.outside?.killVillagers(Int.random(min: 2, max: 7))
            }
        case "death" where eventTitle == "Plague":
            onLoad = {[unowned E] in
                E.outside?.killVillagers(Int.random(min: 10, max: 90))
            }
        case "start" where eventTitle == "A Beast Attack":
            onLoad = {[unowned E] in
                let max = GD.population - 1
                E.outside?.killVillagers(Int.random(min: 1, max: (max > 11 ? 11 : max)))
            }
        case "start" where eventTitle == "A Military Raid":
            onLoad = {[unowned E,GD] in
                let max = GD.population - 1
                E.outside?.killVillagers(Int.random(min: 1, max: (max > 41 ? 41 : max)))
            }
    //SetPieces
        case "start" where eventTitle == "An Outpost":
            onLoad = {[unowned E] in
                E.world?.useOutpost()
            }
        case "talk" where eventTitle == "A Murky Swamp":
            onLoad = {[unowned E,GD] in
                GD.addPerk("gastronome")
                E.world!.markVisited(E.world!.currentPosition)
            }
        case "end1","end2","end3","end4","end5","end6" where eventTitle == "A Damp Cave" || eventTitle == "An Abandoned Town":
            onLoad = {[unowned E] in
                E.world?.clearDungeon()
            }
        case "end1","end2","end3","end4","end5","end6","end7","end8","end9","end10","end11","end12","end13","end14","end15" where eventTitle == "A Ruined City":
            onLoad = {[unowned E,GD] in
                E.world?.clearDungeon()
                GD.cityCleared = true
            }
        case "supplies" where eventTitle == "An Old House":
            onLoad = {[unowned E] in
                E.world!.markVisited(E.world!.currentPosition)
                E.world!.water = E.world!.maxWater
                NM.notify(nil, LS("water replenished"))
            }
        case "medicine","occupied" where eventTitle == "An Old House":
            onLoad = {[unowned E] in
                E.world!.markVisited(E.world!.currentPosition)
            }
        case "start" where eventTitle == "A Forgotten Battlefield" || eventTitle == "A Huge Borehole":
            onLoad = {[unowned E] in
                E.world!.markVisited(E.world!.currentPosition)
            }
        case "start" where eventTitle == "A Crashed Starship":
            onLoad = {[unowned E,GD] in
                E.world!.markVisited(E.world!.currentPosition)
                E.world!.drawRoad()
                GD.tempShip = true
            }
        case "cleared" where eventTitle == "The Sulphur Mine":
            onLoad = {[unowned E,GD] in
                E.world!.markVisited(E.world!.currentPosition)
                E.world!.drawRoad()
                GD.tempSulphurMine = true
            }
        case "cleared" where eventTitle == "The Coal Mine":
            onLoad = {[unowned E,GD] in
                E.world!.markVisited(E.world!.currentPosition)
                E.world!.drawRoad()
                GD.tempCoalMine = true
            }
        case "cleared" where eventTitle == "The Iron Mine":
            onLoad = {[unowned E,GD] in
                E.world!.markVisited(E.world!.currentPosition)
                E.world!.drawRoad()
                GD.tempIronMine = true
            }
        case "exit" where eventTitle == "A Destroyed Village":
            onLoad = {[unowned E] in
                E.world!.markVisited(E.world!.currentPosition)
                Prestige.collectStores()
            }
        default:
            break
        }
    }
}

class EventButton {
    var text:String
    var nextScenes:[String:Double]?
    var reward:[String:Double]?
    var cost:[String:Double]?
    var notification:String?
    var isAvailiable:(()->Bool)?
    //TODO: check js code again for overlooked functions
    var onChoose:(()->Void)?
    var cooldown = 0.0
    
    init(dict:AnyObject, eventTitle:String, sceneKey:String, buttonKey:String) {
        let dict = dict as! [String:AnyObject]
        text = dict["text"] as! String
        nextScenes = dict["nextScene"] as? [String:Double]
        if let nextScene = dict["nextScene"] as? String {
            self.nextScenes = [nextScene:1]
        }
        cost = dict["cost"] as? [String:Double]
        reward = dict["reward"] as? [String:Double]
        notification = dict["notification"] as? String
        //if let cooldownString = dict["cooldown"] as? String where cooldownString == "leave_cooldown"/{
        if dict["cooldown"] != nil { //looks like there is only one possible value
            cooldown = 1.0
        }

        customInit(eventTitle, sceneKey: sceneKey, buttonKey: buttonKey)
        
    }
    
    func customInit(eventTitle:String, sceneKey:String, buttonKey:String) {
        switch buttonKey {
        case "buyCompass" where eventTitle == "The Nomad":
            isAvailiable = {return S.compass < 1}
            onChoose = {Path.openPath()}
        case "learn" where eventTitle == "The Scout":
            isAvailiable = {[unowned GD] in return !GD.hasPerk("scout")}
            onChoose = {[unowned GD] in GD.addPerk("scout")}
        case "buyMap" where eventTitle == "The Scout":
            onChoose = {[unowned E] in E.world?.applyMap()}
        case "evasion" where eventTitle == "The Master":
            isAvailiable = {[unowned GD] in return !GD.hasPerk("evasive")}
            onChoose = {[unowned GD] in GD.addPerk("evasive")}
        case "precison" where eventTitle == "The Master":
            isAvailiable = {[unowned GD] in return !GD.hasPerk("precise")}
            onChoose = {[unowned GD] in GD.addPerk("precise")}
        case "force" where eventTitle == "The Master":
            isAvailiable = {[unowned GD] in return !GD.hasPerk("barbarian")}
            onChoose = {[unowned GD] in GD.addPerk("barbarian")}
        default:
            break
        }
    }
}