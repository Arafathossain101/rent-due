import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ======================================================
// RENT LOG
// ======================================================

class RentLog {
  String id;
  DateTime date;
  String description;

  RentLog({
    required this.id,
    required this.date,
    required this.description,
  });

  // ----------------------------------------------------
  // TO JSON
  // ----------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
    };
  }

  // ----------------------------------------------------
  // FROM JSON
  // ----------------------------------------------------

  factory RentLog.fromJson(
    Map<String, dynamic> json,
  ) {
    return RentLog(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(
            json['date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      description:
          json['description']?.toString() ?? '',
    );
  }
}

// ======================================================
// BILL
// ======================================================
//
// A Bill can represent:
//
// 1. Monthly rent
// 2. Gas
// 3. Electricity
// 4. Water
// 5. Internet
// 6. Utility
// 7. Any other bill
//
// paidAmount allows partial payment.
//
// Example:
//
// amount      = 5000
// paidAmount  = 2000
// remaining  = 3000
//
// ======================================================

class Bill {
  String id;
  String name;

  // Original/current bill amount.
  double amount;

  // Amount already paid toward this bill.
  double paidAmount;

  // true  = Rent
  // false = Normal bill
  bool isRent;

  // Month to which this bill belongs.
  DateTime targetMonth;

  Bill({
    required this.id,
    required this.name,
    required this.amount,
    this.paidAmount = 0.0,
    this.isRent = false,
    required this.targetMonth,
  });

  // ====================================================
  // REMAINING AMOUNT
  // ====================================================

  double get remainingAmount {
    final double remaining =
        amount - paidAmount;

    if (remaining < 0) {
      return 0.0;
    }

    return remaining;
  }

  // ====================================================
  // PAID STATUS
  // ====================================================

  bool get isPaid {
    return remainingAmount <= 0.0;
  }

  // ====================================================
  // TO JSON
  // ====================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'paidAmount': paidAmount,
      'isRent': isRent,
      'targetMonth':
          targetMonth.toIso8601String(),

      // Kept for compatibility with old data.
      'isPaid': isPaid,
    };
  }

  // ====================================================
  // FROM JSON
  // ====================================================

  factory Bill.fromJson(
    Map<String, dynamic> json,
  ) {
    final double amount =
        (json['amount'] as num?)?.toDouble() ??
            0.0;

    // --------------------------------------------------
    // NEW FORMAT
    // --------------------------------------------------

    final double paidAmount =
        (json['paidAmount'] as num?)?.toDouble() ??
            // ------------------------------------------------
            // OLD FORMAT
            // ------------------------------------------------
            // If an older saved bill used:
            //
            // isPaid: true
            //
            // we consider its entire amount paid.
            ((json['isPaid'] == true)
                ? amount
                : 0.0);

    final String name =
        json['name']?.toString() ?? 'Bill';

    final bool isRent =
        json['isRent'] == true ||
        name.toLowerCase().trim() == 'rent';

    final DateTime targetMonth =
        DateTime.tryParse(
              json['targetMonth']?.toString() ??
                  '',
            ) ??
            DateTime.now();

    return Bill(
      id: json['id']?.toString() ?? '',
      name: name,
      amount: amount,
      paidAmount: paidAmount,
      isRent: isRent,
      targetMonth: targetMonth,
    );
  }
}

// ======================================================
// ROOM
// ======================================================

class Room {
  String id;
  String name;

  // Room image.
  String? imagePath;

  // Optional renter name.
  String renterName;

  // Required ID document.
  //
  // Can be:
  // - JPG
  // - JPEG
  // - PNG
  // - WEBP
  // - PDF
  //
  String? renterIdImagePath;

  // Monthly recurring rent.
  double baseRentAmount;

  // All rent + utility bills for all months.
  List<Bill> bills;

  // Activity/history log.
  List<RentLog> logs;

  Room({
    required this.id,
    required this.name,
    this.imagePath,
    this.renterName = '',
    this.renterIdImagePath,
    this.baseRentAmount = 0.0,
    List<Bill>? bills,
    List<RentLog>? logs,
  })  : bills = bills ?? [],
        logs = logs ?? [];

  // ====================================================
  // TO JSON
  // ====================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,

      'renterName': renterName,
      'renterIdImagePath':
          renterIdImagePath,

      'baseRentAmount':
          baseRentAmount,

      'bills': bills
          .map(
            (bill) => bill.toJson(),
          )
          .toList(),

      'logs': logs
          .map(
            (log) => log.toJson(),
          )
          .toList(),
    };
  }

  // ====================================================
  // FROM JSON
  // ====================================================

  factory Room.fromJson(
    Map<String, dynamic> json,
  ) {
    // --------------------------------------------------
    // BILLS
    // --------------------------------------------------

    List<Bill> loadedBills = [];

    final dynamic billsData =
        json['bills'];

    if (billsData is List) {
      loadedBills = billsData
          .whereType<Map>()
          .map(
            (bill) => Bill.fromJson(
              Map<String, dynamic>.from(
                bill,
              ),
            ),
          )
          .toList();
    }

    // --------------------------------------------------
    // LOGS
    // --------------------------------------------------

    List<RentLog> loadedLogs = [];

    final dynamic logsData =
        json['logs'];

    if (logsData is List) {
      loadedLogs = logsData
          .whereType<Map>()
          .map(
            (log) => RentLog.fromJson(
              Map<String, dynamic>.from(
                log,
              ),
            ),
          )
          .toList();
    }

    return Room(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath:
          json['imagePath']?.toString(),

      renterName:
          json['renterName']?.toString() ?? '',

      renterIdImagePath:
          json['renterIdImagePath']
              ?.toString(),

      baseRentAmount:
          (json['baseRentAmount'] as num?)
                  ?.toDouble() ??
              0.0,

      bills: loadedBills,
      logs: loadedLogs,
    );
  }
}

// ======================================================
// FLOOR
// ======================================================

class Floor {
  int floorNumber;
  List<Room> rooms;

  Floor({
    required this.floorNumber,
    required this.rooms,
  });

  // ====================================================
  // TO JSON
  // ====================================================

  Map<String, dynamic> toJson() {
    return {
      'floorNumber': floorNumber,
      'rooms': rooms
          .map(
            (room) => room.toJson(),
          )
          .toList(),
    };
  }

  // ====================================================
  // FROM JSON
  // ====================================================

  factory Floor.fromJson(
    Map<String, dynamic> json,
  ) {
    List<Room> loadedRooms = [];

    final dynamic roomsData =
        json['rooms'];

    if (roomsData is List) {
      loadedRooms = roomsData
          .whereType<Map>()
          .map(
            (room) => Room.fromJson(
              Map<String, dynamic>.from(
                room,
              ),
            ),
          )
          .toList();
    }

    return Floor(
      floorNumber:
          (json['floorNumber'] as num?)
                  ?.toInt() ??
              1,
      rooms: loadedRooms,
    );
  }
}

// ======================================================
// HOUSE
// ======================================================

class House {
  String id;
  String name;
  String? imagePath;

  int numberOfStories;

  List<Floor> floors;

  House({
    required this.id,
    required this.name,
    this.imagePath,
    required this.numberOfStories,
    required this.floors,
  });

  // ====================================================
  // TO JSON
  // ====================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'numberOfStories':
          numberOfStories,

      'floors': floors
          .map(
            (floor) => floor.toJson(),
          )
          .toList(),
    };
  }

  // ====================================================
  // FROM JSON
  // ====================================================

  factory House.fromJson(
    Map<String, dynamic> json,
  ) {
    List<Floor> loadedFloors = [];

    final dynamic floorsData =
        json['floors'];

    if (floorsData is List) {
      loadedFloors = floorsData
          .whereType<Map>()
          .map(
            (floor) => Floor.fromJson(
              Map<String, dynamic>.from(
                floor,
              ),
            ),
          )
          .toList();
    }

    return House(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      imagePath:
          json['imagePath']?.toString(),

      numberOfStories:
          (json['numberOfStories'] as num?)
                  ?.toInt() ??
              loadedFloors.length,

      floors: loadedFloors,
    );
  }
}

// ======================================================
// STORAGE MANAGER
// ======================================================

class AppStorage {
  // ====================================================
  // SAVE IMAGE PERMANENTLY
  // ====================================================
  //
  // Kept because your StoriesScreen already uses:
  //
  // AppStorage.saveImagePermanently(...)
  //
  // ====================================================

  static Future<String> saveImagePermanently(
    String tempPath,
  ) async {
    return saveFilePermanently(
      tempPath,
    );
  }

  // ====================================================
  // SAVE ANY FILE PERMANENTLY
  // ====================================================
  //
  // Used for:
  //
  // - Room image
  // - House image
  // - Renter ID image
  // - Renter ID PDF
  //
  // ====================================================

  static Future<String> saveFilePermanently(
    String tempPath,
  ) async {
    final Directory directory =
        await getApplicationDocumentsDirectory();

    final String originalFileName =
        p.basename(tempPath);

    final String uniqueFileName =
        '${DateTime.now().microsecondsSinceEpoch}'
        '_$originalFileName';

    final String destination =
        p.join(
      directory.path,
      uniqueFileName,
    );

    final File sourceFile =
        File(tempPath);

    if (!await sourceFile.exists()) {
      throw Exception(
        'Source file does not exist.',
      );
    }

    final File savedFile =
        await sourceFile.copy(
      destination,
    );

    return savedFile.path;
  }

  // ====================================================
  // SAVE HOUSES
  // ====================================================

  static Future<void> saveHouses(
    List<House> houses,
  ) async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    final List<Map<String, dynamic>>
        data = houses
            .map(
              (house) =>
                  house.toJson(),
            )
            .toList();

    final String encodedData =
        jsonEncode(data);

    await prefs.setString(
      'my_rent_data',
      encodedData,
    );
  }

  // ====================================================
  // LOAD HOUSES
  // ====================================================

  static Future<List<House>>
      loadHouses() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    final String? encodedData =
        prefs.getString(
      'my_rent_data',
    );

    if (encodedData == null ||
        encodedData.trim().isEmpty) {
      return [];
    }

    try {
      final dynamic decoded =
          jsonDecode(encodedData);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => House.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          )
          .toList();
    } catch (e) {
      // If the stored JSON is corrupted,
      // don't crash the application.
      return [];
    }
  }

  // ====================================================
  // CLEAR ALL SAVED DATA
  // ====================================================
  //
  // Optional helper. This is separate from the
  // RecordScreen "Clear History" button.
  //
  // This deletes ALL houses from SharedPreferences.
  //
  // ====================================================

  static Future<void> clearAllHouses() async {
    final SharedPreferences prefs =
        await SharedPreferences
            .getInstance();

    await prefs.remove(
      'my_rent_data',
    );
  }
}