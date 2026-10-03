class_name VesselData
extends RefCounted
## Static tables for vessel types and port classes.

enum Port { MARINA, FISHING, PASSENGER, CARGO, FUEL, NAVAL, ANY }
enum Type { SAILBOAT, TRAWLER, FERRY, SPEEDBOAT, CONTAINER, TUG, CRUISE, TANKER, PATROL, SUBMARINE }

const PORT_COLORS := {
	Port.MARINA: Color("ffcf3f"),
	Port.FISHING: Color("5ad46a"),
	Port.PASSENGER: Color("3aa8ff"),
	Port.CARGO: Color("ff8a3d"),
	Port.FUEL: Color("ff4d6a"),
	Port.NAVAL: Color("b580ff"),
	Port.ANY: Color("ffffff"),
}

const PORT_NAMES := {
	Port.MARINA: "Marina",
	Port.FISHING: "Fishing Harbor",
	Port.PASSENGER: "Passenger Terminal",
	Port.CARGO: "Cargo Terminal",
	Port.FUEL: "Fuel Terminal",
	Port.NAVAL: "Naval Base",
	Port.ANY: "Any Port",
}

const PORT_ICONS := {
	Port.MARINA: "res://assets/ui/port_marina.svg",
	Port.FISHING: "res://assets/ui/port_fishing.svg",
	Port.PASSENGER: "res://assets/ui/port_passenger.svg",
	Port.CARGO: "res://assets/ui/port_cargo.svg",
	Port.FUEL: "res://assets/ui/port_fuel.svg",
	Port.NAVAL: "res://assets/ui/port_naval.svg",
	Port.ANY: "res://assets/ui/port_any.svg",
}

## speed: world units/s, length/width: hull size, weight: base spawn weight.
const TYPES := {
	Type.SAILBOAT: {"name": "Sailboat", "port": Port.MARINA, "unlock": 1, "speed": 1.15, "length": 1.26, "width": 0.48, "weight": 1.0},
	Type.TRAWLER: {"name": "Fishing Trawler", "port": Port.FISHING, "unlock": 1, "speed": 1.3, "length": 1.55, "width": 0.57, "weight": 1.0},
	Type.FERRY: {"name": "Ferry", "port": Port.PASSENGER, "unlock": 3, "speed": 1.45, "length": 2.07, "width": 0.71, "weight": 1.0},
	Type.SPEEDBOAT: {"name": "Speedboat", "port": Port.MARINA, "unlock": 5, "speed": 2.3, "length": 1.09, "width": 0.44, "weight": 0.8},
	Type.CONTAINER: {"name": "Container Ship", "port": Port.CARGO, "unlock": 7, "speed": 1.05, "length": 2.99, "width": 0.8, "weight": 0.9},
	Type.TUG: {"name": "Tugboat", "port": Port.ANY, "unlock": 9, "speed": 1.35, "length": 1.09, "width": 0.53, "weight": 0.6},
	Type.CRUISE: {"name": "Cruise Liner", "port": Port.PASSENGER, "unlock": 12, "speed": 0.95, "length": 3.45, "width": 0.94, "weight": 0.7},
	Type.TANKER: {"name": "Oil Tanker", "port": Port.FUEL, "unlock": 15, "speed": 0.85, "length": 3.56, "width": 0.9, "weight": 0.8},
	Type.PATROL: {"name": "Patrol Boat", "port": Port.NAVAL, "unlock": 18, "speed": 2.0, "length": 1.61, "width": 0.53, "weight": 0.8},
	Type.SUBMARINE: {"name": "Submarine", "port": Port.NAVAL, "unlock": 22, "speed": 1.25, "length": 2.3, "width": 0.48, "weight": 0.7},
}

const TRAITS := {
	Type.SPEEDBOAT: "Very fast!",
	Type.TUG: "Docks at ANY port",
	Type.CRUISE: "Huge and slow",
	Type.TANKER: "Biggest ship at sea",
	Type.PATROL: "Fast navy boat",
	Type.SUBMARINE: "Dives under other ships",
}


static func info(type: int) -> Dictionary:
	return TYPES[type]


static func port_of(type: int) -> int:
	return TYPES[type]["port"]


static func port_color(port: int) -> Color:
	return PORT_COLORS[port]


static func accepts(port_class: int, vessel_port: int) -> bool:
	return vessel_port == Port.ANY or port_class == vessel_port


static func unlocked_types(level: int) -> Array[int]:
	var out: Array[int] = []
	for t: int in TYPES:
		if TYPES[t]["unlock"] <= level:
			out.append(t)
	return out


static func type_unlocked_at(level: int) -> int:
	for t: int in TYPES:
		if TYPES[t]["unlock"] == level:
			return t
	return -1
