//
//  Engine.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 17/10/14.
//

import UIKit

let E = Engine()
/*
enum ModuleEnum:Any  {
    case Room = "room", Outside = "outside", Path = "path", World = "world", Ship = "ship", Space = "space"
}
*/
final class Engine {
    var modules = [String:Module]()
    var allModuleIds = ["room","outside","path","world","ship","space"]
    var activeModule:Module? {
        didSet {
            GD.activeModule = activeModule?.id ?? ""
            NM.moduleChanged(activeModule)
        }
    }
    var state:NSDictionary?
    var buttons = [String:CooldownButton]()
    var vc:DemoViewController?
    
    var room:Room {
    get {return modules["room"] as! Room}
    }
    var outside:Outside? {
        get {return modules["outside"] as? Outside}
    }
    var path:Path? {
        get {return modules["path"] as? Path}
    }
    var world:World? {
        get {return modules["world"] as? World}
    }
    var ship:Ship? {
        get {return modules["ship"] as? Ship}
    }
    var space:Space? {
        get {return modules["space"] as? Space}
    }
    
    var saveTimer:NSTimer?
    
    init() {
       // loadModule(Room)
        saveTimer = NSTimer.schedule(repeatInterval: 300) {_ in
            self.saveGame()
        }
    }
    
    func saveGame() {
        let documentsDirectory = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0] as! String
        NSKeyedArchiver.archiveRootObject(GD, toFile: documentsDirectory.stringByAppendingPathComponent("gameData"))
    }
    
    func loadGame() {
        for loc in allModuleIds {
            if GD.availiableLocations[loc] != nil {
                loadModule(loc)
            }
        }
        modules[GD.activeModule]?.onArrival()
    }
    
    func loadModule(module:Module.Type) {
        let m = module()
        if modules[m.id] == nil {
            modules[m.id] = m
            if m.displayTab {
                vc?.loadVCForModule(m)
            }
        }
    }
    
    func loadModule(id:String) {
        var m:Module.Type?
        switch id {
            case "room":
            m = Room.self
            case "outside":
            m = Outside.self
            case "path":
            m = Path.self
            case "world":
            m = World.self
            case "ship":
            m = Ship.self
            case "space":
            m = Space.self
        default:
            break
        }
        if let m = m {
            loadModule(m)
        }
    }
    
    func restart() {
        GD = GameData()
        saveGame()
    }

    func locationTitleUpdated(module:Module) {
        vc?.slidingContainerViewController?.titles = vc?.moduleIds.map() {E.modules[$0]!}.map() {LS($0.title)}
    }
    
    func event(cat:String, act:String) {
        
    }
    
}

class Module: NSObject {
    var id = ""
    var name = ""
    var displayTab = false
    var title:String = "" {
        didSet{
            E.locationTitleUpdated(self)
        }
    }
    
    func onArrival() {
        E.activeModule = self
    }
    
    required override init() {
        super.init()
    }
}

extension Module : Equatable {}
func ==(lhs:Module, rhs:Module) -> Bool {
    return lhs.id == rhs.id
}

class Container {
    var buttons = []
    func addButton(options:[String:Any],action:()->Void) {
        
    }
}



