//
//  Ship.swift
//  A Dark Room
//
//  Created by Denis Tokarev on 23/10/14.
//

import Foundation
import UIKit

final class Ship:Module {
    static let liftOffCooldown = 120.0
    let liftOffButton = ButtonConfig(id: "liftoffButton", text: LS("lift off"), cooldown: liftOffCooldown, action: {
        E.ship?.checkLiftOff()
    })
    let hullButton = ButtonConfig(id: "hullButton", text: LS("reinforce hull"), cost:["alien alloy":1], action: {
        E.ship?.reinforceHull()
    })
    let engineButton = ButtonConfig(id: "engineButton", text: LS("upgrade engine"), cost:["alien alloy":1], action: {
        E.ship?.upgradeEngine()
    })
    var observer:ShipObserver?
    
    required init() {
        super.init()
        id = "ship"
        name = "Ship"
        title = "An Old Starship"
        displayTab = true
        
        GD.availiableLocations["ship"] = true
        
        E.loadModule(Space)
    }
    
    override func onArrival() {
        super.onArrival()
        if !GD.seenShip {
            GD.seenShip = true
            NM.notify(self, "somewhere above the debris cloud, the wanderer fleet hovers. been on this rock too long.")
        }
    }
    
    func reinforceHull() {
        if S.alienAlloy < 1 {
            NM.notify(self, LS("not enough alien alloy"))
            return
        }
        S.alienAlloy--
        GD.shipHull++
    }
    
    func upgradeEngine() {
        if S.alienAlloy < 1 {
            NM.notify(self, LS("not enough alien alloy"))
            return
        }
        S.alienAlloy--
        GD.shipThrusters++
    }
    
    func checkLiftOff() {
        
        observer?.checkLiftOff()
        /*
        if GD.seenWarning {
            liftOff()
        }
        else {
            
            let event = Event(dict: ["title":"Ready to Leave?",
                "scenes":
                    ["start":
                        ["text":["time to get out of this place. won't be coming back."],
                        "buttons":
                            ["fly":
                                ["text":"lift off",
                                "nextScene":"end"],
                            "wait":
                                ["text":"linger",
                                "nextScene":"end"]
                            ]
                        ]
                    ]
                ])
            event.scenes["start"]!.buttons["fly"]!.onChoose = {[unowned self] in
                GD.seenWarning = true
                self.liftOff()
            }
            event.scenes["start"]!.buttons["wait"]!.onChoose = {[unowned self] in
                self.liftOffButton.button?.clearCooldown()
            }
            Events.startEvent(event)
        }
*/
    }
    
    func liftOff() {
        E.activeModule = E.space
        E.space?.onArrival()
    }
}

protocol ShipObserver {
    func checkLiftOff()
}