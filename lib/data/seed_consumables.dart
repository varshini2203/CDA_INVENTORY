// lib/data/seed_consumables.dart
//
// 722 Consumable items parsed from Consumables_CDA__1_.xlsx
// (auto-classified from the CDA Admin / CDA Ops inventory spreadsheets).
// Feed into Firestore via ConsumableService.seedConsumables()

class SeedConsumables {
  SeedConsumables._();

  static final List<Map<String, dynamic>> items = [
    // ── MD ROOM ──
    {'name': '100 Gsm A4 Sheet Bundle', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': '1000Uf35V', 'category': 'Row-3', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '100Uf10V', 'category': 'Row-3', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '10Cm 2 Pin Jst', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': '15 Inch Props', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': '2 Cell Battery', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': '2 Pin Usb Power Cable', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': '2.44 Ghz Ufl T -Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── DAMAGED BATTERY BOX ──
    {'name': '2S Battery', 'category': 'Damaged Battery Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': '2S Battery Lion-2 Xt30', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': '2S Li Ion Battery', 'category': 'Charging Station', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': '2S Lion Battery-4 Xt60', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': '3 Pin Adpter Cable', 'category': 'Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': '3D Print For Propeller Guard Section', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '3S Balance Lead', 'category': 'Row-2', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': '3S Lion Battery', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': '4700Uf50V', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '470Uf 25V', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '470Uf 35V', 'category': 'Row-3', 'quantity': 18, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': '4Leaf Clover Fpv Antenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': '4S Lion Battery', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': '4S Charging Balance Lead', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': '5.8 Ghz Wifi Antenna', 'category': 'Row-3', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': '5.8G 2Dbi Dipole Ufl Omni Antenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '5.8Ghz Antenna', 'category': 'Row 4', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': '5.8Ghz Fpv Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': '5.8Ghz Omni Fpv Antenna', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': '560Uf35V', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '5S Balance Lead', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '6S Balance Lead', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION, MANAGER ROOM ──
    {'name': '6S Charging Balance Lead', 'category': 'Charging Station, Manager Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': '7S Balance Lead', 'category': 'Row-3', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': '85 Gsm A4 Sheet Bundle', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'A3 Display Book Pocket', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'A4 Bundle New', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'A4 Bundle Opened', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'A4 Bundle Used', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'A4 Display Book Pocket', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'A4 Sheet Bundle', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'A4 Sheet Cotton Box', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Accounting File 26', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Accounts Book New', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Accounts Kaviyamam', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Accounts Peticash Note', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Ads Sheet', 'category': 'Editor Draws', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Aircraft E&E Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Aircraft Instrument Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Allen Hex Screws', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Alligator Clips', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Aluminium Standoff 35Mm', 'category': 'Row-3', 'quantity': 41, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Amazon Basics Usb Type C To Micro -B 2.0 Cable', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Amazon Packing Tape 48Mm', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Anabond', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Analog Double Antenna Googles', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Antenna', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ONFIELD, ROW 4, ROW-3 ──
    {'name': 'Antenna Box', 'category': 'Onfield, Row 4, Row-3', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Antiskid Pad Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Aparasa Eraser', 'category': 'Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Aparasa Pencil', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Apsara Eraser', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Attendance Record Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Azima Mam Note', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'B Type Cable', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Balance Lead 4S', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Balance Lead 6S', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Balck Marker', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Balck Masking Tape', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Ballon Packet', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Baloon Pump', 'category': 'Restroom Things', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Banana Plug Or Pin Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Banana Plug Or Pin Male', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Banana Plug To Dc Female Dc Power Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Bank Vocher Box File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Batteries', 'category': 'Charging Station', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Battery', 'category': 'Rpto', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Battery Box', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Battery Charging Cable Box', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Battery Charging Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Battery Charging Logbook 79Tc', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Battery Charging Logbook 80Tc', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Battery Compartment Housiong', 'category': 'Service Rack(Fourthrow)', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Battery Plate Roll', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Battery Silicon Antiskid Pad', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Battery Sleeve Small Roll', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RPTO ──
    {'name': 'Battery Station Logbook Rpas', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Battery Sticker', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS, ROW-2 ──
    {'name': 'Battery Strap', 'category': 'Gojan In Products, Row-2', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Battery Wirs Black&Red', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Battery With Hub', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-5 ──
    {'name': 'Big Heat Sheink Roll Black', 'category': 'Row-5', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Big Heat Shrinkroll Blue', 'category': 'Row-5', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Big Wires', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Bill Box File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Bills Leaf File', 'category': 'Admin Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Black Eva Pouch', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Black Marker', 'category': 'Training Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Black Pen', 'category': 'Admin Room', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Black Pen Pentonic', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Blank Sticker Roll', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Blue Ball Point Pen', 'category': 'Tools', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Blue Marker', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM ──
    {'name': 'Blue Pen', 'category': 'Admin Room, Instructor Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Bl`Ue Pen', 'category': 'Admin Room', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Bnc Male Connector', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Books-', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM, LAB ROOM, TRAINING ROOM ──
    {'name': 'Bottle', 'category': 'Admin Room, Lab Room, Training Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── MD ROOM, STATIONARY ──
    {'name': 'Box File', 'category': 'Md Room, Stationary', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Broom Stick', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Broomstick', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Brown Sheet Roll', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Brush', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Bubble Courier Bags 25.5 Mm', 'category': 'Charging Station', 'quantity': 38, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Bubble Courier Bags Large', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Bubble Mat', 'category': 'Training Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Bucket With Mug', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Bulb', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Business Team Matenote Books', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Butterfly Glue', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Button Empty File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Button File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Button File Blue', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Button File New', 'category': 'Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Button File Old', 'category': 'Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'C To Ip Cable', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Cable Clip', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Cable Protector', 'category': 'Propeller Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Cables', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Caddx Osd Controller', 'category': 'Service Rack(Fourthrow)', 'quantity': 11, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Caddx Remote Control Board Osd', 'category': 'Service Rack(Fourthrow)', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Caddx Vista Vtx Unit', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Carbon Fibre 2 Blade Propeller', 'category': 'Row-3', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Cardboard', 'category': 'Service Rack  Last Row', 'quantity': 332, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Cash Pouch', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Cash Voucher Box File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CORRIDOR THINGS ──
    {'name': 'Cat Food Plate', 'category': 'Corridor Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Accountable Manager File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Certificate Of Conformity File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Form D2&D3 File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Form-5 File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Cda Janet File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Lease Agreement File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Master &Slave File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Cda Note', 'category': 'Admin Room', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Organization Details File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Rpto Instructor Details File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Cello Tape', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Ceramic Cup & Saucer', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Ceramic Plate', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM, MD ROOM ──
    {'name': 'Certificate Bundle', 'category': 'Manager Room, Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Certificate File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Chrolide Safepower Battery(Wastage)', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Civil Aircraft Inspection Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Civil Aviation Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── REST ROOM THING ──
    {'name': 'Cleaning Liquid', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Clear Wrap Cover 10Mm', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Clear Wrap Cover 25Mm', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, RESTROOM THINGS ──
    {'name': 'Clip', 'category': 'Admin Room, Restroom Things', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Clips', 'category': 'Admin Room', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Coauxial Antenna Cable', 'category': 'Row 4', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Cup', 'category': 'Training Room', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'D 8K Cable', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Damage O3 Antenna', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Damaged Balance Lead', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Damaged Propeller Bag', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Damaged Propellers', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Darwin 3S Battery', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': 'Desktop Power Cable (3 Pin)', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Dettol', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dettol Foaming Handwash', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Diamond Needle File', 'category': 'Tools', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Digital Mulimeter Cable', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Diner Knife', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Display Book Pocket-', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Dji Cable Lightining To Type C', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Dji Cables', 'category': 'Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Dji Google Pouch', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Dji Mavic Shoulder Bag', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dji Mavic Shoulder Bag 1', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dji Mavic Shoulder Bag 2', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dji Mini Bag', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Dji Phantom Propeller Grey', 'category': 'Row-3', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dji Phantom Propeller White', 'category': 'Row-3', 'quantity': 9, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Dji Tb50 Intelligent Flight Battery', 'category': 'Charging Station', 'quantity': 9, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Document With Bag( Pie)', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Documents At Pink File', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Dogcom Buldge Battery', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Doms Blue Ball Point Pen-4 Box', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Doms Red Pen', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY, TOOL KITS ──
    {'name': 'Double Side Tape', 'category': 'Stationary, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Duracell Aa Battery', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Duster', 'category': 'Training Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Eachine Et526 5.8 Ghz Vtx', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Electrical Liquid Tape', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Electrical Technology Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Electronic Cleaning Solution Ipa', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Elrs 2.4 Ghz T-Antenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Employee Record File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Empty Cover Box', 'category': 'Row 4', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Enginering Graphics Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Enroll Form File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM ──
    {'name': 'Eraser', 'category': 'Admin Room, Instructor Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Eva Perfume', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, MD ROOM ──
    {'name': 'Exam Pad', 'category': 'Admin Room, Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Exam Pad Hv', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Exam Pad Transparent', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Expo Enquiry Forms', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Expo Pamplets Hyd', 'category': 'Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Extra Connecting Wires', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Extra Nuts And Bolds', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Feedback Card Set', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Feedback Student File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Fevi Kiwick', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Fevicol', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── INSTRUCTOR ROOM, STATIONARY, TOOLS ──
    {'name': 'Fevistick', 'category': 'Instructor Room, Stationary, Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── REST ROOM THING ──
    {'name': 'Fiber Brush', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Field File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Field Water Bottle', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'File Set', 'category': 'Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Flair Ball Point Pen', 'category': 'Md Room', 'quantity': 8, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Flask', 'category': 'Training Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Flim Roll', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── REST ROOM THING ──
    {'name': 'Floor Broom', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Flyfish Rc Titanium Hex Screws Driver', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CORRIDOR THINGS ──
    {'name': 'Foam Board', 'category': 'Corridor Things', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Foam Boards', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Forexx Osd Controller', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Fork Spoon', 'category': 'Training Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Foxeer Lollipop 3 5.8 Ghz Omni Stubby Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Foxeer Oreo 5.8 Ghz Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Fpv Antenna Lolipop 4 Plus', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Fragile Handle Tape', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Furious Fpv Patch Race 5.8Ghz Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Garbage Bag Roll', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── HOUSEKEEPING SUPPLIES ──
    {'name': 'Garbage Bag Used', 'category': 'Housekeeping Supplies', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Garbage Cover', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Garbage Cover Roll', 'category': 'Restroom Things', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Generic Tap Wire Connectors', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Geprc Battery Strap 20X 220', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Geprc Rad Mini 5.8 G Vtx', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Glass Cleaner Liquid', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Grease Box', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Green Courier Cover', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gstr 1&2B Box File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gstr 3B Leaf File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gstr1 Leaf File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Half Pencil', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Handwash', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Harpic Bottle', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Hdmi Cable With Ethernet', 'category': 'Editor Draws', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-5 ──
    {'name': 'Heat Shrink Box', 'category': 'Row-5', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Heat Shrink Box 2', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Heat Shrink Box 3', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Heat Shrink Box1', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Heat Shrink Tubing', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'High Discharge Lipo Battery 2605Mah', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Highliter', 'category': 'Admin Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Hot Glue Gun', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Hq Prop Dt90Mm', 'category': 'Propeller Box', 'quantity': 9, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Hurricane 51466V2 Propeller Set', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Hv Personal Bag', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Id Card Cover', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Id Card Ropes', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Iflight Double Antenna Googles', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Iflight Pad', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Insulation Tape Black', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Insulation Yellow Tape', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Invelop Cover 15 Cmm Bundle', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Invelop Covers New Bundle 28 Cm', 'category': 'Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Invoice Box File', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-5 ──
    {'name': 'J Hook Bolt', 'category': 'Row-5', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Jp Sir Bill File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Jst -Xh 2 Pin Connector', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst -Xh 6 Pin Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst 10 Pin Connecter', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Jst 6S Balance Lead', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Jst Micro 3 Pin', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Sh 8 Pin Cablejst Xh 2 Pin Connecter Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst To Usb Cable Connector', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 3 Pin', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 4 Pin Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 4 Pin Double Side', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 4 Pin One Sided With Clip', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 6 Pin Cable Femal;E', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 6 Pin Cable Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Jst Xh 6 Pin Connector', 'category': 'Row-3', 'quantity': 60, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Kavya Mam Note', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, TOOL KITS, TRAINING ROOM ──
    {'name': 'Knife', 'category': 'Admin Room, Tool Kits, Training Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Knurled Aluminium Standoff', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Lable Sticker-1 Roll', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── LAB ROOM ──
    {'name': 'Landing Pad', 'category': 'Lab Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Large Nuts &Bolds', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Large Screws', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'Laundry Bag', 'category': 'Service Rack  Last Row', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Leaf File A4 Bundle', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Leaf File With Documents', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Leaf Steel Plate', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Lemon Sanitizer Phenoyl', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Light Mounting Clip', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Lion Battery', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Lipo Battery Cells', 'category': 'Row-3', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Lipo Battery Pouch', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── DAMAGED BATTERY BOX ──
    {'name': 'Lipo Damaged Battery', 'category': 'Damaged Battery Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Lipo Safe Fire Proof Bag', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Lizel Bottle', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Locktite 271', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Lollipop Fpv Antenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Long Size Note', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Long Term Pending Student Attendence File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── NAVIN KIT ──
    {'name': 'Lower Pro Bag', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M1.5X10', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M1.6', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M1.6X8', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2 Lock Nut', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2.5X6', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'M2X1.9', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3, TOOL KITS ──
    {'name': 'M2X12', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    {'name': 'M2X16', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M2X18', 'category': 'Row-3', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2X20', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2X5', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2X6', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3, TOOL KITS ──
    {'name': 'M2X7', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    {'name': 'M2X8', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M3', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3, TOOL KITS ──
    {'name': 'M3X10', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M3X12', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3, TOOL KITS ──
    {'name': 'M3X16', 'category': 'Row-3, Tool Kits', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'M3X20', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3, TOOL KITS ──
    {'name': 'M3X30', 'category': 'Row-3, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'M3X5', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'M3X7', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M3X8', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M5 Washer', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Manual Box', 'category': 'Row 4', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Marker Green', 'category': 'Training Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Marker Ink', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Marker Permanent Blue', 'category': 'Md Room', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Masking Tape', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Masking Tape Set-12 Rolls', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── DAMAGED BATTERY BOX ──
    {'name': 'Mavic Pro Battery', 'category': 'Damaged Battery Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Measuring Tape', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Medimix Handwash', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Mini Stamp', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Mini Wire Scratch Wire Brush Set Nylon Brass', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Mmcz 90 Degree Linear Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Model T Flight Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Mohammed Sathak Workshop File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Motherboard Spacer Standoff', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Mug', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Multi Colored Copper Wire', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Napthenel Balls Pocket', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'New Cda Notebook', 'category': 'Md Room', 'quantity': 11, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'New Notebook Long Size', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'New Service Note', 'category': 'Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Nippo Aa Battery', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Nsmall Size Accounts Note', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Nylon Hex Standoff M3', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'O4 Pro Module Mounting Screw', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RESTROOM THINGS ──
    {'name': 'Odonil Box', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Office Document File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Oil Bottle', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Old Box File', 'category': 'Md Room', 'quantity': 13, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Old Button File With Documents', 'category': 'Admin Room', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Old Expo Forms File Hv', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Old Leaf File', 'category': 'Md Room', 'quantity': 8, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Old Log Book Unused', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE RACK  LAST ROW ──
    {'name': 'One Shoulder Bag', 'category': 'Service Rack  Last Row', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Onfield Old Bag', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Ongoing Student File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Otg Dji Data Cable', 'category': 'Service Rack(Fourthrow)', 'quantity': 8, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY, TOOL KITS ──
    {'name': 'Packing Tape', 'category': 'Stationary, Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Pagoda-2 5.8Ghz Omnidirctional Antenna', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM, STATIONARY ──
    {'name': 'Pamplets', 'category': 'Md Room, Stationary', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Paper Clip', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TRAINING ROOM ──
    {'name': 'Paper Cup', 'category': 'Training Room', 'quantity': 33, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Paper Label 160 Gsm', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Paper Label 162 Gsm', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Paper Plate', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Paper Tape', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Parryware Solution', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── 3D PRINTER ──
    {'name': 'Pen Driver', 'category': '3D Printer', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Pen Knife', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Pencil', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Pencil Box-1 (8Nos.)', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Perfora Brush Head', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Permanent Marker', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Permanent Marker (Blue)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Permanet Marker', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Pf&Esi File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION, DAMAGED BATTERY BOX ──
    {'name': 'Phantom Battery', 'category': 'Charging Station, Damaged Battery Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Plastic 2 Blade Propeller Black &Yellow', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Plastic Brush', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Plastic Brush Red', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Plastic Eyelet Ringsd With Washer', 'category': 'Row-3', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Plastic Sealinf Cover Case With Screw', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Plate', 'category': 'Training Room', 'quantity': 12, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Portronics Konnect L 1.2 M Cable (Grey)', 'category': 'Propeller Box', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Practice Soldering Lead', 'category': 'Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Practise Soldering Lead-2 Roll', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Propeller', 'category': 'Charging Station', 'quantity': 12, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Propeller T90 Ducted', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-5 ──
    {'name': 'Pteg Empty Roll', 'category': 'Row-5', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Pvt Expense Voucher Note', 'category': 'Md Room', 'quantity': 27, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Question Paper File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Radiomaster Pocket Pouch', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Ramraj Cover', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── LAB ROOM ──
    {'name': 'Rc Car , Remote, Battery', 'category': 'Lab Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Receipt Note', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Receipt Note Uesed', 'category': 'Md Room', 'quantity': 12, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Receipt Voucher File', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Red Double Side Tape', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM ──
    {'name': 'Red Pen', 'category': 'Admin Room, Instructor Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Red Tape', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Refil Toners', 'category': 'Md Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Rgb Cable', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Rhcp 5.8Ghz Antenna 65Mm', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Ribbon Wire', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Rin Bottle', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Rock Landing Pad', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Roll', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Rorito Pen (Black)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Rpas Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Rpto Batch 1 File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Rpto Batch 3 File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Rpto Batch2 File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── RPTO ──
    {'name': 'Rpto Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Rpto Stamp', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Rpto Student Logbook', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Rubber Flayt Washer Box', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Sales Stock Invoice Punching File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Salt Paper', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Sanitary Pad Pocket', 'category': 'Restroom Things', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Sanitizer Bottle', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Sarpner Doms', 'category': 'Md Room', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Sata Data Cable Iii', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Screw', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Screw Box', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Screw Organiger 3D Print', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Scribbling Book', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Service Book', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM ──
    {'name': 'Sharpner', 'category': 'Admin Room, Instructor Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Shockproof Sponge Pad', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Shop Theory Book', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': 'Short Type C Cable', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING ──
    {'name': 'Silicon Broom', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Silicon Brouchers With Button File', 'category': 'Md Room', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Silicon Brush', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Silicon Double Side Tape Green', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Silicon Oil Bottle', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Sim Card Kavya Amam Accounts', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Simulation Record', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Skylynk Expense Voucher Note ( Bank And Peety Cash )', 'category': 'Md Room', 'quantity': 76, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Sma Connector', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Sma Connectors', 'category': 'Row 4', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Sma Female 90 Degree Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Sma Female Connector', 'category': 'Service Rack(Fourthrow)', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Sma Female To Mmcx Male (Right Angle) Rf Rg316 Pigtail Jumber Cable', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Sma Female To Ufl Pigtailantenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Sma Male Connector', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Sma Plig To Sma Jack', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Small Note Cda Printed', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Small Wire Connectors', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'Small Wires', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Soft Brush', 'category': 'Tools', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Soldering Flux', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Soldering Flux Paste', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Soldering Lead', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Soldering Practice Wire Small', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-2 ──
    {'name': 'Soldering Practise Wire Box', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Soldering Practice Wire Large', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── EDITOR DRAWS ──
    {'name': 'Sony Oem 3.5Mm Aux Audio Cable F', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Spare Propeller Box', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Spigen C To Lighting Cable', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TRAINING ROOM ──
    {'name': 'Spoon', 'category': 'Training Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Spray Oil Bottle', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Stamp', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Stapler Pin', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Stapler Pin (Big)', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Stapler Pin (Small)- 2 Box', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Stapler Pin Big', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Stapler Pin Box', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Stapler Pin Small', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Stapler Pins', 'category': 'Md Room', 'quantity': 16, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Steel Bottle', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Stick File Un Used', 'category': 'Md Room', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Sticker Box', 'category': 'Row 4', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, MD ROOM ──
    {'name': 'Sticky Notes', 'category': 'Admin Room, Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Sticky Notes Pad Hv', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Student Assesment Punching File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Student Id Card Tag', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Student Training Record', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Studevt Pen', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Sugar Box With Spoon', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'T Mount Race Wire', 'category': 'Row-3', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'T Plug Femaleto Dc Jack Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'T- Motor Ft200 5.8Ghz Vtx', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'T-Dipole Antenna', 'category': 'Row 4', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'T-Plug (Female Connector) To Male Dc Barrel Plug Connector', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'T-Plug Female To Alligator Clip', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'T-Plug To Jst Connector', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Tape Tray', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Tata Salt', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Tbs Solder Lead', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Tbs Unifybpro 5G8 Linear Antenna', 'category': 'Row 4', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Tbs White Noise Fpv Race Wire Mini Circuit Board', 'category': 'Row-3', 'quantity': 15, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Thankyou Cover Bindle', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Thin Red&Black Wires Box', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Tiffin Box', 'category': 'Training Room', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Tissue Paper Bundle', 'category': 'Charging Station', 'quantity': 9, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, STATIONARY ──
    {'name': 'Tissue Set', 'category': 'Admin Room, Stationary', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── REST ROOM THING ──
    {'name': 'Toilet Cleaning Brush', 'category': 'Rest Room Thing', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'Toner', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Tripad Plate', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CORRIDOR THINGS, LAB ROOM ──
    {'name': 'Tube Light', 'category': 'Corridor Things, Lab Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── MD ROOM, REST ROOM THING, TRAINING ROOM ──
    {'name': 'Tubelight', 'category': 'Md Room, Rest Room Thing, Training Room', 'quantity': 8, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── TRAINING ROOM ──
    {'name': 'Tumbler', 'category': 'Training Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Turmeric And Kumkum Box', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2, SERVICE RACK(FOURTHROW) ──
    {'name': 'Ufl Connector', 'category': 'Row-2, Service Rack(Fourthrow)', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Un Used Box File', 'category': 'Md Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Unomax Pen Blue', 'category': 'Md Room', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Unused Receipt Notes', 'category': 'Md Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Usb 2.0 A To Mini 5 Pin B Cable', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Usb 2.0 A To Mini 5 Pin B Cable (Small)', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── EDITOR DRAWS ──
    {'name': 'Usb Cable 2', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Usb To B Type Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Usb To C Cable', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Usb To Dc Charging Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── PROPELLER BOX ──
    {'name': 'Usb Type B Cable (Black)', 'category': 'Propeller Box', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Usb Type B Cable (White)', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Usb Type C Cable (Black)', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Usb Type C Cable (White)', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Velgro File', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Vim Bars', 'category': 'Restroom Things', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── REST ROOM THING, RESTROOM THINGS ──
    {'name': 'Vim Liquid', 'category': 'Rest Room Thing, Restroom Things', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Voucher Box Files', 'category': 'Admin Room', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Vtx', 'category': 'Service Rack(Fourthrow)', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Walking Form File', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': 'Wall Anchor Screws With Mount', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Wall Anchor With Screws', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RESTROOM THINGS ──
    {'name': 'Washing Brush', 'category': 'Restroom Things', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Watch Batteries', 'category': 'Row-3', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': 'Water Can Cover', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'White Grease', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'White Masking Tape', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MD ROOM ──
    {'name': 'White Sticker Roll', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Whitner', 'category': 'Admin Room', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Whitner Camlin', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Wire Cuttetr', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Wire Stripper Pye-950', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Wires Black', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Wires Red', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Wondern Brown Tape 48Mm', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Wondern Transparent Tape 48Mm', 'category': 'Charging Station', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ONFIELD ──
    {'name': 'Wood Landing Pad With Foam', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TRAINING ROOM ──
    {'name': 'Wooden Fork One Cover', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── STATIONARY ──
    {'name': 'Woody Black Ball Point Pen', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Woody Black Pen', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Woody Blue Ball Point Pen', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ONFIELD ──
    {'name': 'Working Battery Lipo 6S', 'category': 'Onfield', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Working O3 Antenna', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Writing Pad', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Xt30 Female', 'category': 'Row-3', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM, ROW-3 ──
    {'name': 'Xt30 Male', 'category': 'Manager Room, Row-3', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Xt30 Male With Wire', 'category': 'Row-3', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Xt30 Male&Female', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Xt60 - Xt90 Parallel Connrctor Cable', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Xt60 Connector Box', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM, ROW-3 ──
    {'name': 'Xt60 Female', 'category': 'Manager Room, Row-3', 'quantity': 10, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Xt60 Female With Wire', 'category': 'Row-3', 'quantity': 10, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Xt60 Male', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── CHARGING STATION ──
    {'name': 'Xt60 Male Bullet Connector To Male Dc', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Xt60 Male To Aux Cable', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Xt60 Male To B Type', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Xt60 Male To Female', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Xt60 Male To Xt30', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Xt60 Male To Xt30 Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Xt60 Male With Wire', 'category': 'Row-3', 'quantity': 27, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Xt60 To Dcmale To Jack Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Xt90Male To Xt60 Female', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MD ROOM ──
    {'name': 'Yellow File', 'category': 'Md Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Zip Tag Large Packet', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Zip Tag Small Packet', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW 4 ──
    {'name': 'Zip Tie 3.6X150Mm Black', 'category': 'Row 4', 'quantity': 92, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Zip Tie Small (Pocket)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW 4 ──
    {'name': 'Ziptie 300M White', 'category': 'Row 4', 'quantity': 43, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Ziptie 4.8X400 Mm Black', 'category': 'Row 4', 'quantity': 42, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Ziptie 400Mmx3.6 White', 'category': 'Row 4', 'quantity': 57, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE &DELIVERY IN ──
    {'name': 'Drawin 3S Battery', 'category': 'Service &Delivery In', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'Iflight Bag', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'Skyzone Cobra Sd Fpv Googles Cable', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': '(Flat Head)Screw Driver (Black)', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '(Yamato)Mini Diagonal Nipper Wire Cutter', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': '18650 Battery Holder', 'category': 'Charging Station', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': '2 In 1 Screw Driver', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '32 In 1 Screw Driver Toolset With Magnetic Holderv', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '3D Print 4S Battery Holder', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': '3S Drone Liion Battery', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': '4S Battery Holder', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Adapter With Cable', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Av Adapter Cable', 'category': 'Row-3', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Camera Lens Pouch', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Capacitor Holder', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Cda Drone Insurance File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Drone Invoice File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Drone Maintenance File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cda Simulator Details File', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── STATIONARY ──
    {'name': 'Cutter Knife 18Mm', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cutter Knife 9Mm', 'category': 'Stationary', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Dji Fpv V2 Goggles Antenna (Dual Band)', 'category': 'Service Rack(Fourthrow)', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Dji O3 Aoir Unit Coaxial Camera Cable', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Head Screw Driver Mini', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Hrethik Drone Kit With Shoulder Bag', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Jst To D C 2.5 Adapter Charging Cable', 'category': 'Row-3', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Motor Wire Holder', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADMIN ROOM, EDITOR DRAWS, LAB ROOM, TRAINING ROOM ──
    {'name': 'Mouse Pad', 'category': 'Admin Room, Editor Draws, Lab Room, Training Room', 'quantity': 10, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── ADMIN ROOM ──
    {'name': 'Mouse Pad New', 'category': 'Admin Room', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── INSTRUCTOR ROOM ──
    {'name': 'Mouse With Pad', 'category': 'Instructor Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'O3 Camera Screw', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'O3 Vtx Damaged Antenna Holder', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Paper Cutter Knife', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': 'Pen Holder', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM, INSTRUCTOR ROOM, MANAGER ROOM ──
    {'name': 'Pen Stand', 'category': 'Admin Room, Instructor Room, Manager Room', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin, CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Propeller Adapter', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Propeller Adapter Holder', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOL KITS ──
    {'name': 'Propeller Wrench', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Screw Driver', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Small Vtx And Camera Box', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Speedy Bee U Fl To Sma Female Pigtail Adapter Cable', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'Star Screw Driver Black', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Star Screw Driver Red', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Tc Drone Propeller-2 Set', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Wire Cutter', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'Wire Stripper &Cutting Plier Vcablepulling', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Wire Stripping Plier(Taparia)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '(0#+)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '(1#-)', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '1.5-1Yox40Mm', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '1.5Mm', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '1.5X40Mm', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '15 Degree', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': '2.0Mm', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '2.5Mm', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ADMIN ROOM ──
    {'name': '25', 'category': 'Admin Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TRAINING ROOM ──
    {'name': '31 Small Tray', 'category': 'Training Room', 'quantity': 33, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': '3D Print Box', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '3S', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '40 Degree', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': '4214 380Kv', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': '470 Uf 50V', 'category': 'Row-3', 'quantity': 6, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '4S', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── NAVIN KIT ──
    {'name': '4S Lihv', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': '5050 Bn Orange', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '5050 Bn Red', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': '5X4.3X3R Blue', 'category': 'Propeller Box', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-2 ──
    {'name': '6S', 'category': 'Row-2', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── NAVIN KIT ──
    {'name': '6S Mck Lipo', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': '8.0 Box', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── FPV DRONES ──
    {'name': 'Air 3S', 'category': 'Fpv Drones', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TRAINING ROOM ──
    {'name': 'Bucket 1', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Bucket 2', 'category': 'Training Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── MANAGER ROOM ──
    {'name': 'Caddx Ratel2', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── NAVIN KIT ──
    {'name': 'Cinelog 25 V2', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Cinelog 35 V2', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': 'Dalpdrop 3528', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Dji 5043', 'category': 'Propeller Box', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE &DELIVERY IN ──
    {'name': 'Dji O4 Air Unit', 'category': 'Service &Delivery In', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── NAVIN KIT ──
    {'name': 'Dji Osmo 5 Pro', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── EDITOR DRAWS ──
    {'name': 'Drf Iec C13', 'category': 'Editor Draws', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'E28 2G4M27Sx', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── MANAGER ROOM ──
    {'name': 'Eco 60A F405', 'category': 'Manager Room', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Esp32-S3', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': 'Gemfam 5152 Red', 'category': 'Propeller Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan 45Mm', 'category': 'Propeller Box', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan 5144 Red', 'category': 'Propeller Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan 51466', 'category': 'Propeller Box', 'quantity': 5, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan 5152', 'category': 'Propeller Box', 'quantity': 4, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan D 90', 'category': 'Propeller Box', 'quantity': 15, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Gemfan D63 Grey', 'category': 'Propeller Box', 'quantity': 7, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Geprc 1960Kv', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Geprc V2 Stack', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Gps M10', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'H 1.5', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'H2.0', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'H2.5', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Hota D6 Pro', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Hota F6', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── NAVIN KIT ──
    {'name': 'Hota F6 Pro', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── PROPELLER BOX ──
    {'name': 'Hq S5X4X3', 'category': 'Propeller Box', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── FPV DRONES ──
    {'name': 'Inspire 2', 'category': 'Fpv Drones', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── REMOTE CONTROLLER ──
    {'name': 'Jumper Mode 3', 'category': 'Remote Controller', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Jumper T15', 'category': 'Remote Controller', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'M2 X6', 'category': 'Tool Kits', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ROW-3 ──
    {'name': 'M2X 1.9', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2X 5.5', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'M2X 8', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── FPV DRONES ──
    {'name': 'Matrice 4E', 'category': 'Fpv Drones', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── DAMAGED BATTERY BOX ──
    {'name': 'Mavic 2', 'category': 'Damaged Battery Box', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Mavic 3', 'category': 'Damaged Battery Box', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Mt7681 X Wifi', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── CHARGING STATION ──
    {'name': 'Nd 16 Filter', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Nd 4 Filter', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Nd 8 Filter', 'category': 'Charging Station', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── NAVIN KIT ──
    {'name': 'O3 Ndfilter', 'category': 'Navin Kit', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── FPV DRONES ──
    {'name': 'Pave O4 Lite', 'category': 'Fpv Drones', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Seeker 5', 'category': 'Fpv Drones', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── ADDITIONAL DRONE SPARE ──
    {'name': 'Seeker 5 Spare', 'category': 'Additional Drone Spare', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOLS ──
    {'name': 'T5', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'T6', 'category': 'Tools', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── RPTO ──
    {'name': 'Tc-82(Mgr)', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    {'name': 'Tc-83(Mgr)', 'category': 'Rpto', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── TOOL KITS ──
    {'name': 'Tester1', 'category': 'Tool Kits', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'Tx12', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SERVICE RACK(FOURTHROW) ──
    {'name': 'Wc0Hr2601 Wifi', 'category': 'Service Rack(Fourthrow)', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── TOOLS ──
    {'name': 'Ws06', 'category': 'Tools', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Wso5', 'category': 'Tools', 'quantity': 2, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── SIMULTION TRANSMITTER(ROW-1) ──
    {'name': 'X7 Taranis', 'category': 'Simultion Transmitter(Row-1)', 'quantity': 3, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── ROW-3 ──
    {'name': 'Xt 60 Male', 'category': 'Row-3', 'quantity': 113, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    {'name': 'Xt60 To T-Plug', 'category': 'Row-3', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Admin'},
    // ── GOJAN IN PRODUCTS ──
    {'name': 'Xt60-Xt90', 'category': 'Gojan In Products', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
    // ── SERVICE &DELIVERY IN ──
    {'name': 'Xt60-Xt30', 'category': 'Service &Delivery In', 'quantity': 1, 'unit': '', 'minStock': 0, 'notes': 'CDA Ops'},
  ];
}