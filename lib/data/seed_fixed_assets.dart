// lib/data/seed_fixed_assets.dart
//
// 710 Fixed Asset items parsed from Fixed_Assets_CDA.xlsx
// (auto-classified from the CDA Admin / CDA Ops inventory spreadsheets).
// Feed into Firestore via FixedAssetService.seedAssets(SeedFixedAssets.allItems)

class SeedFixedAssets {
  SeedFixedAssets._();

  static List<Map<String, dynamic>> get allItems => [
    // ── ADMIN ROOM ──
    {'name': '15 Inch Frame', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': '3A Ubec For Drone', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': '3D Print Tool Kit Holder Unused', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': '3D Print Tool Kit Holder Used', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': '3D Print Tool Kit Holders Bos', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': '3D Printer', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': '3D Tool Holder', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': '450 Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': '4S Batery 3D Printer-3 Set', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': '5 Inch Frame', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': '5 Inch Race Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Ac', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Ac By Dc Adapter Double Adapter', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Action Pro Landing Gear/ Stabilizer', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Adjustable Tripad Stand', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Admin Monitor', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Admin Sys. Ups', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Admin System Table', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Aerial Form Rack 2', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Agricultre Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM, ROW-2 ──
    {'name': 'Allen Key', 'category': 'Manager Room, Row-2', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Allen Key Large', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── NAVIN KIT, TOOL KITS ──
    {'name': 'Allen Key Set', 'category': 'Navin Kit, Tool Kits', 'quantity': 3, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Allen Wrench Full Set', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Allen Wrench Spanner', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Am Ac', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Am Canon Printer', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Am Desk', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Analog Monitor', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Anemometer', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Autel Robotics Drone Kit Eo2 Series', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Barcode Printer', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Barcode Scanner', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Battery Charging Station', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Blue Chair', 'category': 'Admin Room, Training Room', 'quantity': 11, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Blue Star Ac Remote', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Blue Table', 'category': 'Training Room', 'quantity': 7, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Bluestar Ac', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Broken Keyboard Laptop', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Brother Printer', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Brushless Cooling Fan Big', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Brushless Cooling Fan Small', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Budha Statue', 'category': 'Md Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Butterfly Drone', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, STATIONARY ──
    {'name': 'Calculator', 'category': 'Admin Room, Stationary', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Camera', 'category': 'Service Rack(Fourthrow)', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Camera Brackets Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Camera Stand', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Carbon Fibre Racing Drone Quad Frame', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS, LAB ROOM, MD ROOM ──
    {'name': 'Cctv', 'category': 'Corridor Things, Lab Room, Md Room', 'quantity': 4, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Cctv Cam', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Cctv Camera', 'category': 'Admin Room, Training Room', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Cctv Monitor', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Cda 3 Inch Analog Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Cda Banner', 'category': 'Admin Room, Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Cda Catlog In Walk Rack', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Cda Flag', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Chairs', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Charger Body Part Damage', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Charging Station Cupboard 2', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Clock', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Computer Desk', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Computer Sabrani', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM, TRAINING ROOM ──
    {'name': 'Cpu', 'category': 'Admin Room, Instructor Room, Training Room', 'quantity': 9, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Cpu Aplle', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Crompton Fan', 'category': 'Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Cupboard Things', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Cushion Chair', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daikin Ac', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── NAVIN KIT ──
    {'name': 'Damged Flyfish Drone Frame', 'category': 'Navin Kit', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Damged Gaming Keyboard', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Dead Cat Frame 3D', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Dining Chair Black', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Dji 100 Watts Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE &DELIVERY IN ──
    {'name': 'Dji Goggles N3', 'category': 'Service &Delivery In', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Dji Mic', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Dji Mini 3 Camera', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Dji Power Adapter Ad019', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Dji Rc Transmitter Neck Strap', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Drone', 'category': 'Rpto', 'quantity': 4, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Drone Arms', 'category': 'Charging Station', 'quantity': 6, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Drone Flyinf Zones', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Dual Output Lipo Charger-1 Agri', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, MD ROOM, REST ROOM THING, RESTROOM THINGS, TRAINING ROOM ──
    {'name': 'Dustbin', 'category': 'Admin Room, Md Room, Rest Room Thing, Restroom Things, Training Room', 'quantity': 10, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Dxp S6 Pro Drone With Kit', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Eachine Ev800 Goggles', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Editor Table', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Electric Screwdriver Set', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Essl Machine', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM, MD ROOM ──
    {'name': 'Fan', 'category': 'Lab Room, Md Room', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Fatshark Dominator Fpv Goggles', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM, LAB ROOM ──
    {'name': 'Fire Extinguisher', 'category': 'Instructor Room, Lab Room', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Fire Extingusher Ball', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Form Rack', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Fpv Form Rack 3 Piloting', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Fpv Transmitter Harness', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Fpv Transmitter Harness Eachine', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Frame Kit Box1', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Frame Kit Box2', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Geprc Cinelog 35 Frame Black', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Geprc Cinelog 35 Frame Green', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gimbal Camera Protector', 'category': 'Service Rack(Fourthrow)', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'God Frame', 'category': 'Admin Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Goggles Eachine Vr006', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Gopro 12 Black Action Camera Frame', 'category': 'Service Rack(Fourthrow)', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gopro Action Camera Mount', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Hammer', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Hardisk', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Harsha Bro Table', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'High Capacity Drone Charging Powerbank Pack', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Hood Lock Buckle(Gimbal Camera)', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Hota D6 Pro Smart Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hota F6 Quad Channel Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Ic Ac', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Ic Ac Stablizer', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Ic Cctv Cam', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Ic Chair', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Ic Desk', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── HOUSEKEEPING SUPPLIES ──
    {'name': 'Ic Dustbin', 'category': 'Housekeeping Supplies', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Ic Fire Extinguisher', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Ic Keyboard', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Ic Wall Fan', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Imax Dual Power Ac Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Ipad Stand', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Iron Scale', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Kavya Mam Table', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, CORRIDOR THINGS ──
    {'name': 'Key Holder', 'category': 'Admin Room, Corridor Things', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Keyboard', 'category': 'Admin Room, Training Room', 'quantity': 10, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Kuberan Statue', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── HOUSEKEEPING SUPPLIES ──
    {'name': 'Lab Dustbin', 'category': 'Housekeeping Supplies', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Laptop Charger', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Laptop With Adapter Additional', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Lenova Laptop 2', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Lg Ac', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Long Size Scale', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'M6D Dual Smart Charger New', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'M7Toolkik Multi Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Machine Charger', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Magnetic Screwdriver (Interchangle Bits)-28 Elecronics', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Magnetic Screwdriver Holder', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Magnetizer Demagnetizer Tool For Screwdriver Magnetic', 'category': 'Row-2', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Mark 5 X Frame Green', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Mark5 Pro Frame Kit', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Maxicom S 24 12 Power Supply Metalcasing', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Meteor Drone Old', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Middle Cupboard', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Mini Torx Screwdriver Black', 'category': 'Tools', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Mini Torx Screwdriver Grey', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Mini Torx Screwdriver T2 Star Head', 'category': 'Tools', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Mobile Stand', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Monitor', 'category': 'Admin Room', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Mouse', 'category': 'Admin Room', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Mouse Wired Old', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION, TOOL KITS ──
    {'name': 'Multimeter', 'category': 'Charging Station, Tool Kits', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Nandhi Statue', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'New Cutter', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Newbee Drone Bee Brain Blv5 Aio', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Normal Chair', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Nose Cutter', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'O3 Camera', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'O3 Camera Holder', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE &DELIVERY IN ──
    {'name': 'Pavo Series Whoop Drone', 'category': 'Service &Delivery In', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Pcb Holder Stand', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Phantom 4 Charger-Adambakkam', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Phantom Charger 4 Ph4C100', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Phantom Drone', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Pixhawk 2.4.8 Fc Drone', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Pooja Cupboard', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Portable Spot Welding Machine Circuit Board', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Powerbank', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': 'Precision Electric Screwdriver Set', 'category': 'Row 4', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Printer', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Printer Machine Lpc88A', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Printer Table', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, STATIONARY ──
    {'name': 'Punching Machine', 'category': 'Admin Room, Stationary', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Quotes Frame Hv', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Racing Drone Frame', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Rack 1 Stationary', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Rainproof Led Power Supply', 'category': 'Charging Station', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Rc Stick Holder', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Rgb Adapter', 'category': 'Editor Draws', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, MD ROOM, TRAINING ROOM ──
    {'name': 'Rolling Chair', 'category': 'Admin Room, Md Room, Training Room', 'quantity': 9, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Router', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Sabrani Stand', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-5 ──
    {'name': 'Sanyoi Ni-Mh Battery Charger', 'category': 'Row-5', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Scale', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Sharp Cutter', 'category': 'Tool Kits', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Shivan Statue', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Shoe Rack', 'category': 'Corridor Things', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Simulator', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Skyrc Dual Output Lipo Charger', 'category': 'Rpto', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Sofa', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Soldering Iron', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-5 ──
    {'name': 'Soldering Iron Protective Sleeve And Knurled Metal Ring', 'category': 'Row-5', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Soldering Machine', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Soldering Station', 'category': 'Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Soldering Station (Not Working)', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-5 ──
    {'name': 'Soldering Station Not Working Tray2', 'category': 'Row-5', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Soldering Station Working Tray 1', 'category': 'Row-5', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Sony Camera Kit With 2 Lens', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Spanner', 'category': 'Tools', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Spanner Small Size', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Speedy Bee X Frame', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, MANAGER ROOM, MD ROOM ──
    {'name': 'Stablizer', 'category': 'Admin Room, Manager Room, Md Room', 'quantity': 3, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Steel Scale', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM, TRAINING ROOM ──
    {'name': 'Stool', 'category': 'Lab Room, Training Room', 'quantity': 8, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Student Chair', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Swiping Machine', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Switching Power Adapter 2 Pronged Us Type', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'System Cpu', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'System Keyboard', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'System Monitor', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'System Mouse', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'System Table', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'System Ups', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'T Shape Sign Boards', 'category': 'Editor Draws', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'T-Handle Socket Wrench', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM, MD ROOM, ONFIELD ──
    {'name': 'Table', 'category': 'Instructor Room, Md Room, Onfield', 'quantity': 3, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Table 2 Draw 1', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Table Fan', 'category': 'Admin Room, Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Table Light', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Telephone', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Type C To Headphone Jack Adapter', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Ups', 'category': 'Admin Room, Training Room', 'quantity': 9, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Usb To Uart Adapter', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Uv Protector Lens', 'category': 'Service Rack(Fourthrow)', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'V Guard Stabilizer', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Vaccum Cleaner', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Vegetable Cutter', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Vinayagar Statue', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Visting Card Holder', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Waiting Chair', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Walk In Rack', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL, RPTO ──
    {'name': 'Walkie Talkie', 'category': 'Electronics And Electrical, Rpto', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Wall Clock', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Wall Fan', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Water Dispenser', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Water Dispenser Machine', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION, ELECTRONICS AND ELECTRICAL ──
    {'name': 'Weight Machine', 'category': 'Charging Station, Electronics And Electrical', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'White Board', 'category': 'Admin Room, Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Wifi & Router', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM, TRAINING ROOM ──
    {'name': 'Wifi Dongle', 'category': 'Instructor Room, Training Room', 'quantity': 3, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Wifi Router', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Wooden Cupboard', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Wooden Table', 'category': 'Admin Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Work Station Table', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Writing Chair', 'category': 'Training Room', 'quantity': 7, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Yellow Toy Drone', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Bms Charger', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Built Class Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Cda Defense Drone With Thermal Camera', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Goggles 3', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Quba Camera', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Speedy Bee Drone', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': '2 Prong Ac Power Cord Cable', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': '3 Pin Computer Power Cord Cable', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': '8S Battery 3D Printer', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Battery Fan', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Battery &Charger Compaitability File', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Double Antenna Google Charger', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Expense Voucher Book Table', 'category': 'Admin Room', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Hota D6 Prosmart Charger New With Cable', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Ic Printer Cover', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Plate Tripod', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Printer Cover', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Printer Roll', 'category': 'Admin Room, Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Switching Power Adapter Ac To Dc (Single Antenna)', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': '3 Blade Propller Crystal Blue', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': '3 Blade Propller Pink', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': '3 Watts Loudspeaker', 'category': 'Row-3', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': '3.5 Inch With Motors', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': '3D Print Mount Box', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': '3Dr Radiotelementry Kit 433Mhz', 'category': 'Row 4', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': '3D Print Smart Switch', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Adustable Tripop', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS, MD ROOM ──
    {'name': 'Agal Vilaku', 'category': 'Corridor Things, Md Room', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Agri Remote Controller', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Agriculture Spare Tray', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Air Tag', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Aircraft Act Bok', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Aircraft Electrical System', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Airved', 'category': 'Tools', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Aivation Maintenance', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'All Catelogs', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Am Cahir', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Ameer Desai Spare (Naked Gopro)', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Ansh Empire -Hand Free Operator', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Anti Skid Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Araldite Eproxy Hardener', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Ardiuno Nano V3 Module', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Attendence', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Av Male To 3Rca Female', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Azure Power 5150 Crystal Clear', 'category': 'Propeller Box', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Bang Good', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Battery Charging Satation Cupboard1', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM, MD ROOM, RESTROOM THINGS ──
    {'name': 'Bero', 'category': 'Manager Room, Md Room, Restroom Things', 'quantity': 4, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Beta Fpv Small', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Black', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Black + Decker', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Black Red', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Black Velvet Bags', 'category': 'Service Rack(Fourthrow)', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Blackblue', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Blitzz Practice Board', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Blue', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Blue Barrel', 'category': 'Restroom Things', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Blue Bin', 'category': 'Md Room', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Blue Box', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Brushed Esc', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Buck Conventoe', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Business Team Sim Card', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Bussiness Head Board', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'C To Lighting Damaged', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'C Type', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'C Type Headphone', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Caldender Hv', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Camlin Permanent Black', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Camlin Permanent Blue', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, MD ROOM ──
    {'name': 'Cash Box', 'category': 'Admin Room, Md Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Cat Food Box', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Caution', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Gift Box-3]Nm6T', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Cda Mobile', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Cda Puzzle', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Tshirt', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Cinelog 35 O4 3 Dprint', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Cinelog 35 O4 Gps 3D Print', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Cinelog 35 V2 O3', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Clear Blue Files', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── HOUSEKEEPING SUPPLIES ──
    {'name': 'Clearmate', 'category': 'Housekeeping Supplies', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Club Bollywood High School Micro Hdmi', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Coliner', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Cone', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Courier Bnage 34.5X47', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Courier Green Files', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Cpl Filter', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Cuptray', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Custom Cda Rc', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Cutting Blade', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Dalderop T5045 Red', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daldrop 5045 Orange', 'category': 'Propeller Box', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daldrop 5045 Purple', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daldrop T5040 Orange', 'category': 'Propeller Box', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daldrop T5050 Orange', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Daldropt5045 Red', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Damage Xing Motor Kv 1800', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Damaged Motor Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Damagegeprc Speedx Motor Kv2650', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Dampler Balls -1 Box', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Dampler Box', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Dampling Balls', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Deburring Tool-1 With Kits', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Delta Dvp -14Ss2 Plc', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Diamond Burr Set', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Diatone', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES, REMOTE CONTROLLER ──
    {'name': 'Dji', 'category': 'Fpv Drones, Remote Controller', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Dji Fpv Remote Controller2-Fc7Bgc', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Dji Inspire Proprller', 'category': 'Row-3', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Dji Model Gl3008', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Dji Model Gl6D10A Inspire2', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Dji O4 Air Unit Pro Mount', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Dji Phantom Kit', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Dji Remote Controller', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Dji Snail Esc Module', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Domex Cleaner', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS, HOUSEKEEPING SUPPLIES ──
    {'name': 'Door Mat', 'category': 'Corridor Things, Housekeeping Supplies', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Dropping Mechanism With Servo', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Dustpan', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Dvdr', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Dvr', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Eachine Half Part', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Eachine Pr058 Rx Fpv Receiver', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Eb Card Cda', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Elastic Welgro Starp', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Electric Soldering Ion', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': 'Elrs Receiver 2.4Ghz (Harshath)', 'category': 'Row 4', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Empty Box Tray', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Empty Box Withscrew', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Empty Boxes', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Esc', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Esc (Practise Board)', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Essl', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Fibre Cloth', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Filament', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Filament Heater', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Fire Bell', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Fire Bucket', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, TRAINING ROOM ──
    {'name': 'Fire Extingher', 'category': 'Admin Room, Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Fire Safety Officer Jacket', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'First Aid Kits', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Firstaid Kit', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Flat Floor Mop', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, CORRIDOR THINGS ──
    {'name': 'Flower', 'category': 'Admin Room, Corridor Things', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Flyrc Fs X6B Receiver', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Flysky Fs-R6A 2.4Ghz Receiver', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Flywoo', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Flywoo Gm10 Nano V3', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Flywoo Mount', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Football Gauge', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Foxxer Or Caddx Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Fpv Build & Piloting', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Fpv Build Form Track', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Fpv Direct', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Frsky Taranis X9Dplus', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Frsky X8R 8/16Ch Telementry Receiver', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── HOUSEKEEPING SUPPLIES ──
    {'name': 'Garbage Bags - 2 Box Lab', 'category': 'Housekeeping Supplies', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Gemfan 5144 Skyblue', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan 51466 Crystal Clear', 'category': 'Propeller Box', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan 51499 Purple', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan 51499 Skyblue', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan 5152 Pink', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan 5152 Sky Blue', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan Beta Fpv Small', 'category': 'Propeller Box', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Gemfan51499 Orange', 'category': 'Propeller Box', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Geprc Gep F722 Aio Fc', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Geprc Gep-F722 45A Aio V2', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS, ROW-2 ──
    {'name': 'Geprc Keychain', 'category': 'Gojan In Products, Row-2', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Geprc Naked Gopro Kit Sapr Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Gimbal Protector', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Gimbal Stick Head', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Gl200A (Dji Mavic Pro Series)', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Glass', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Godox Led Video Light', 'category': 'Editor Draws', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── NAVIN KIT ──
    {'name': 'Googles Intgra', 'category': 'Navin Kit', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Gopro Hero 11 Black Mini', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Gopro Hero 11 Blkack Original Usb Charging Port Flex Cabel', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Gps Circuit Board Gopro Hero', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Green', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Green Box', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Grey Spiral Lapster Box', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Grooming Smakk Scissor', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Gum', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Hack Saw Blade', 'category': 'Tools', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Harsh Bro', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Head Set Hv', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Heat Sleeve Kit', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Hit Calk', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Hobbywing Xmotor Fpv Esc', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Hot Air Gun', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hot Airgun Nozzle', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hota F6+ Empty Box', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Hotaspare', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'House Wares', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Hq 5X 4.8X 3 V1S Skyblue', 'category': 'Propeller Box', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hq 5X 4.8X 3R Green', 'category': 'Propeller Box', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hq 5X4.8X3V1S Purple', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hq Prop5X 3.7X3 Grey', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Hqprop Ethixs4 Flroscent', 'category': 'Propeller Box', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Humidity Tester', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Ic Bero', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Ic Surface Light', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Ic Window Screen', 'category': 'Instructor Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Iflight Blitzz F7 V1.2 Fc', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'In Restroom Cooridor', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Insert', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Inspire Broken', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Inspire Broken Parts In Cotton Box', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Inspire Controller A,B', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Instructor Jacket', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Instructor Log Rpas', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Intgra Googles', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Invelop Bundle Used', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ONFIELD ──
    {'name': 'Ipad', 'category': 'Onfield', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': 'Jackhammer Retainervpin Kit', 'category': 'Row 4', 'quantity': 49, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Jaishavi', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Jumper Hall V2 Gimbal', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Karandi', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Key', 'category': 'Editor Draws', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Knee Lifter Assembly', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Kuthu Vilaku', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Large Bucket', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Lcd Or Led Cleaner', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Leaf Bowls', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Leaf Files', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Led Ddr4 Ram Module', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Led Strip', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Letter Head Cda', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Letter Head Pvt', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Letter Head Skylynk', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Li Ion 2Cell 2000Mah Front New', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Li Ion 4 Cell 4000Mah Front Old', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Li Ion 4 Cell 4000Mahfront New', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Lights', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Lion 4Cell 4000Mah Back Old', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── NAVIN KIT, RPTO, TOOL KITS, TOOLS ──
    {'name': 'Lipo Checker', 'category': 'Navin Kit, Rpto, Tool Kits, Tools', 'quantity': 5, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Lithium Ion Dronebattery 16046', 'category': 'Charging Station', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Lithium Ion Remotebattery 18650', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Lizel', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Lm2596 Dc Dc Buck Conventor', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Logo Light', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Loiion 4 Cell 10000Mah Front New', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Long Strap', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Male Header Strip Or Berg Strip', 'category': 'Row-3', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Mamba F405 Mini Mk2 Fc', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CORRIDOR THINGS ──
    {'name': 'Mango Leaf', 'category': 'Corridor Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Manuals', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Mark 5 Gps Mount', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Massager', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Master Controller', 'category': 'Rpto', 'quantity': 4, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, CORRIDOR THINGS ──
    {'name': 'Mat', 'category': 'Admin Room, Corridor Things', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Mat Unused', 'category': 'Restroom Things', 'quantity': 8, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Mat Used', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Match Box', 'category': 'Md Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Mate', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Mavac 2 Controller', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Maverick Mrx -242 2.4 Ghz', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Megaphone', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Mg995 Metal Gera Servo Motor -180 Set', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Mi Power Bank', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Module Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Mohan Anna Kit Box', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Molding Clay(Gluetag)', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Momento Award', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Monitors', 'category': 'Training Room', 'quantity': 6, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Mop', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Motor Mount Support Set', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Naga Sai Spares', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Naked Gopro Black Hero 11 Kit', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Naked Gopro Spares Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Name Lables', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Neck Straps', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Neutron Rc At32F435 5 In 1 Aio', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'New Tweezer Set', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Notes Small', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Notice Board', 'category': 'Training Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Nyon Yarn Thin Thread', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'O3 Air Unit Only Outer Box', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Old Bms', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Old Drones', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'One Plus Wrap Charge Type C (Red)', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Orange Bucket', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Osmo Dji Gimbal', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Other Pooja Things', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Oxt60 Connecter Male', 'category': 'Additional Drone Spare', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Payload Dropping Box', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Pendrive', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Perunkaayam Box', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Phantom Conroller', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Photo Frames Official', 'category': 'Admin Room', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Pink Box', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Pizzacutter 5037', 'category': 'Propeller Box', 'quantity': 5, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Pla White', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Pla White New', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Plastic Box', 'category': 'Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Plastic Pust Pan', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Plywood', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Poojai Self With Poojai Saman', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Power Board Circuit(Hota)', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Power Extension Box', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Power Filter', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Practice Board', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Printed Papers', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Pteg Black New', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Pteg Blue', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Pteg Blue New', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Pteg White', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Qr Code', 'category': 'Admin Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Quadkart', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Radiomaster Boxer (Transparent)', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Radiomaster Boxer Crush Pink', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── NAVIN KIT ──
    {'name': 'Radiomaster Boxer Special Edition', 'category': 'Navin Kit', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Radiomaster Boxer(Black)', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Radiomaster Empty Box With Rubber Casing', 'category': 'Charging Station', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Radiomaster Neck Strap', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Radiomaster Rp1 Nano Receiver', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Rapid Pla', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Rat Killer', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Razer Pay', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Rc Car', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Rc Car And Controller', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Rc Stick', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Rchuper', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Realme Phone', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Receiver Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Red', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Reees52 Servo Motor Red', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Rest Room Mat', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Rgb Led Light Module', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Ribbons', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Ring Light', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Rip It Black Circuit Board', 'category': 'Row-3', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Robocraze Sg90 Servo Motor Set', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Room Freshner', 'category': 'Admin Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Rough Papers', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Rpas Pilot Log Bined', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Saftey Battery Charging Instructions', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Sanddisk Driver', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Santhanam Box', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Scerwdrivers(Baku Bk-8600 Series)', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS, TOOLS ──
    {'name': 'Scissor', 'category': 'Tool Kits, Tools', 'quantity': 2, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Scissors', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, LAB ROOM, MD ROOM, TRAINING ROOM ──
    {'name': 'Screen', 'category': 'Admin Room, Lab Room, Md Room, Training Room', 'quantity': 10, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Scruber New', 'category': 'Restroom Things', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Serial Ata 6G 26Aw 4 Pin Xlr', 'category': 'Editor Draws', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Service Box', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Serving Glass', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Shoulder Strap', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Shower Box', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Silicon Gasket Box', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Silicon Vibration Dample', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Silk Pla Purple', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Simcard', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── LAB ROOM ──
    {'name': 'Simulation Rc', 'category': 'Lab Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Skyrc', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Slave Controller', 'category': 'Rpto', 'quantity': 4, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Small', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REST ROOM THING ──
    {'name': 'Small Bucket', 'category': 'Rest Room Thing', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Small Surface Light', 'category': 'Charging Station', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Smd Station', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM, TOOL KITS ──
    {'name': 'Smoke Stopper', 'category': 'Manager Room, Tool Kits', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Solder Paste', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Soldering Glass', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-5 ──
    {'name': 'Soldering Ion', 'category': 'Row-5', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Soldering Kit', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Soldering Practice Lead', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ELECTRONICS AND ELECTRICAL ──
    {'name': 'Soldering Set (New)', 'category': 'Electronics And Electrical', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Spare Tray', 'category': 'Service Rack  Last Row', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Speedy Bee Tx800', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Speedybee F7 V3 Fc', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Speedybeef405 Mini Bls 35A', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Springe With Soldering Fkux', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Stabler', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Stainless Steel Fulter Blade', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM ──
    {'name': 'Stapler', 'category': 'Admin Room, Instructor Room', 'quantity': 4, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Stapler (Big)', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Stationary Box', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Steel Box', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Steel Ruler', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Stick Position Hold', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Sticy Notes', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Stop Watch', 'category': 'Md Room', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Straight', 'category': 'Tools', 'quantity': 11, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Student Photos Bin', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM, LAB ROOM, MANAGER ROOM ──
    {'name': 'Surface Light', 'category': 'Admin Room, Lab Room, Manager Room', 'quantity': 4, 'branch': 'CDA Admin, CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Surface Mounted Led Spot Light', 'category': 'Editor Draws', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Surfexel', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Switch', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'T Motor Velox Lite F411 Fpv Fc', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'T Tool', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'T-Motor 5143S Orange', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Tapper Box', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Taranis X7 Orange', 'category': 'Remote Controller', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': 'Tbs Cross Fire Immotral T Antennba', 'category': 'Row 4', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Tbs Crossfire Nano Receiver', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW 4 ──
    {'name': 'Tbs Crossfire Nano Rx', 'category': 'Row 4', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Tbs Fusion Video Module', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Tbs Solder (Lead)', 'category': 'Tools', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Tc -79(Crystallball)', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tc 80 (Crystalball)', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Tea Filter', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Tester', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Theerinool', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Thermometer', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Toolkitrc Adjustable Powersupply', 'category': 'Charging Station', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Tools Kit', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Tower Pro Sg90 Sevo Motot Blue', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Tp Link Driver', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Tpu Black', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu Blue', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu Green', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu Purple New', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu Red', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu Skin New', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Tpu White', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RPTO ──
    {'name': 'Tranee Jacket', 'category': 'Rpto', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Transparent Ruler(15 Cm)', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Tray-7(Theory Session Items)', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Turnable Anti Skating Set', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Tweezer', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOL KITS ──
    {'name': 'Tweezers', 'category': 'Tool Kits', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Twist Drill Bits', 'category': 'Row-3', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Tyre Rubber', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Ultra Soft (Toothbrush)', 'category': 'Tools', 'quantity': 2, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MD ROOM ──
    {'name': 'Umberalaa', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Umberlla', 'category': 'Md Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Usb C Type', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Usb To B Type', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Usb To C Sm', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── EDITOR DRAWS ──
    {'name': 'Usb To C Type', 'category': 'Editor Draws', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── RESTROOM THINGS ──
    {'name': 'Usb To C Type Sm', 'category': 'Restroom Things', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── PROPELLER BOX ──
    {'name': 'Usb Type A To Type A (Male To Male-White', 'category': 'Propeller Box', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Usb Type C Small (Black)', 'category': 'Propeller Box', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── FPV DRONES ──
    {'name': 'Used Air 3S Propller', 'category': 'Fpv Drones', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Used Motor Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION ──
    {'name': 'Used Notepad', 'category': 'Charging Station', 'quantity': 12, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Velox V2207 2250 Kv', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── 3D PRINTER ──
    {'name': 'Vernier Caliper', 'category': '3D Printer', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TOOLS ──
    {'name': 'Vifly Short Saver V2 Smart Smoke Stopper', 'category': 'Tools', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Visiting Card', 'category': 'Admin Room', 'quantity': 13, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Visiting Cards', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Visting Card Box Cda', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Visting Card Cda', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Visting Cardskylynk', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Walksnail Ws M181 Gps', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Water Bottles', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'White Box', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── INSTRUCTOR ROOM, STATIONARY ──
    {'name': 'Whitener', 'category': 'Instructor Room, Stationary', 'quantity': 2, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Window Screen', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── STATIONARY ──
    {'name': 'Window Screen New', 'category': 'Stationary', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── TRAINING ROOM ──
    {'name': 'Wood Karandi', 'category': 'Training Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── CHARGING STATION, TRAINING ROOM ──
    {'name': 'Workstation Mat', 'category': 'Charging Station, Training Room', 'quantity': 3, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Xt60Male To Xt 60 Female', 'category': 'Row-3', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ADMIN ROOM ──
    {'name': 'Zero Watts Bulp', 'category': 'Admin Room', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-3 ──
    {'name': 'Zerodrag Aurora Race-X Led', 'category': 'Row-3', 'quantity': 4, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Zerodrag Nexlus1 Receiver Module', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── MANAGER ROOM ──
    {'name': 'Zerodrag Nexul S1', 'category': 'Manager Room', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Zerodrag Nexus 1 Elrs 2.4 Ghz Receiver', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Zerodrag Nexuuls01', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── ROW-2 ──
    {'name': 'Zerodrag Receiver', 'category': 'Row-2', 'quantity': 1, 'branch': 'CDA Admin', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Dji Enterprise 4E', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
    {'name': 'Wd', 'category': 'Gojan In Products', 'quantity': 1, 'branch': 'CDA Ops', 'location': '', 'description': '', 'status': 'Active', 'assetType': 'Fixed Asset'},
  ];
}