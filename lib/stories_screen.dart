import 'dart:io';
import 'record_screen.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'storage.dart';

// ======================================================
// STORIES SCREEN
// ======================================================

class StoriesScreen extends StatefulWidget {
  final House house;

  // Used by main.dart to save the updated house data
  final VoidCallback onHouseUpdated;

  const StoriesScreen({
    super.key,
    required this.house,
    required this.onHouseUpdated,
  });

  @override
  State<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends State<StoriesScreen> {
  final ImagePicker _picker = ImagePicker();

  // ======================================================
  // ORDINAL NUMBER
  // ======================================================

  String _getOrdinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) {
      return '${number}th';
    }

    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  // ======================================================
  // ADD ROOM
  // ======================================================

  void _addRoom(int floorIndex) {
    final floor = widget.house.floors[floorIndex];

    setState(() {
      final nextRoomNumber = floor.rooms.length + 1;

      // Examples:
      // Floor 1 -> 101, 102, 103 ... 109, 110, 111
      // Floor 2 -> 201, 202, 203 ... 209, 210, 211
      final roomName =
          '${floor.floorNumber}${nextRoomNumber.toString().padLeft(2, '0')}';

      floor.rooms.add(
        Room(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: roomName,
        ),
      );
    });

    // Save changes to phone storage
    widget.onHouseUpdated();
  }

  // ======================================================
  // REMOVE LAST ROOM WITH CONFIRMATION
  // ======================================================

  Future<void> _removeRoom(int floorIndex) async {
    final floor = widget.house.floors[floorIndex];

    // Nothing to delete
    if (floor.rooms.isEmpty) {
      return;
    }

    // Get the last room before showing the popup
    final room = floor.rooms.last;

    // --------------------------------------------------
    // CONFIRMATION POPUP
    // --------------------------------------------------

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Delete Room?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          content: Text(
            'Are you sure you want to delete Room ${room.name}?\n\n'
            'This will remove the room from this floor.',
          ),

          actions: [
            // CANCEL
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

            // DELETE
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    // --------------------------------------------------
    // DELETE AFTER CONFIRMATION
    // --------------------------------------------------

    if (confirmDelete == true && mounted) {
      setState(() {
        floor.rooms.removeLast();
      });

      // Save changes to phone storage
      widget.onHouseUpdated();

      // Show confirmation message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Room ${room.name} deleted.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ======================================================
  // PICK ROOM IMAGE
  // ======================================================

  Future<void> _pickRoomImage(
    int floorIndex,
    int roomIndex,
  ) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null || !mounted) {
        return;
      }

      // --------------------------------------------------
      // COPY IMAGE TO PERMANENT APP STORAGE
      // --------------------------------------------------

      final String permanentPath =
          await AppStorage.saveImagePermanently(image.path);

      if (!mounted) {
        return;
      }

      // --------------------------------------------------
      // UPDATE ROOM IMAGE
      // --------------------------------------------------

      setState(() {
        widget.house.floors[floorIndex].rooms[roomIndex].imagePath =
            permanentPath;
      });

      // Save updated data
      widget.onHouseUpdated();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select image: $e',
          ),
        ),
      );
    }
  }

  // ======================================================
  // BUILD SCREEN
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.house.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            Theme.of(context).colorScheme.inversePrimary,
      ),

      body: SafeArea(
        child: widget.house.floors.isEmpty
            ? const Center(
                child: Text(
                  'No stories found.',
                  style: TextStyle(
                    fontSize: 24,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: widget.house.floors.length,
                itemBuilder: (context, floorIndex) {
                  return _buildFloorRow(floorIndex);
                },
              ),
      ),
    );
  }

  // ======================================================
  // FLOOR ROW
  // ======================================================

  Widget _buildFloorRow(int floorIndex) {
    final floor = widget.house.floors[floorIndex];

    return Container(
      // Reduced height
      height: 220,

      margin: const EdgeInsets.symmetric(
        vertical: 8,
      ),

      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: const Border(
          bottom: BorderSide(
            color: Colors.grey,
            width: 1.5,
          ),
        ),
      ),

      child: Row(
        children: [
          // ==================================================
          // LEFT FLOOR PANEL
          // ==================================================

          Container(
            // Reduced width from 140 -> 110
            width: 110,

            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(
              color: Colors.teal.shade50,

              border: const Border(
                right: BorderSide(
                  color: Colors.grey,
                  width: 1.5,
                ),
              ),
            ),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,

              children: [
                // ------------------------------------------------
                // FLOOR NUMBER
                // ------------------------------------------------

                Text(
                  '${_getOrdinal(floor.floorNumber)}\nFloor',

                  textAlign: TextAlign.center,

                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------
                // REMOVE + ADD BUTTONS
                // ------------------------------------------------

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    // REMOVE BUTTON
                    InkWell(
                      onTap: () => _removeRoom(floorIndex),

                      borderRadius: BorderRadius.circular(50),

                      child: Container(
                        padding: const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.remove,
                          size: 24,
                          color: Colors.red,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ADD BUTTON
                    InkWell(
                      onTap: () => _addRoom(floorIndex),

                      borderRadius: BorderRadius.circular(50),

                      child: Container(
                        padding: const EdgeInsets.all(6),

                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                        ),

                        child: const Icon(
                          Icons.add,
                          size: 24,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ------------------------------------------------
                // ROOM COUNT
                // ------------------------------------------------

                Text(
                  '${floor.rooms.length} Rooms',

                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // RIGHT ROOM PANEL
          // ==================================================

          Expanded(
            child: floor.rooms.isEmpty
                ? const Center(
                    child: Text(
                      'Tap (+) to add rooms',

                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,

                    itemCount: floor.rooms.length,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),

                    itemBuilder: (
                      context,
                      roomIndex,
                    ) {
                      return _buildRoomCard(
                        floorIndex,
                        roomIndex,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // ROOM CARD
  // ======================================================

  Widget _buildRoomCard(
    int floorIndex,
    int roomIndex,
  ) {
    final room =
        widget.house.floors[floorIndex].rooms[roomIndex];

    return GestureDetector(
      onTap: () {
        // Navigate to the Record Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecordScreen(
              room: room,
              onDataChanged: widget.onHouseUpdated, // Keep saving data up the chain!
            ),
          ),
        ).then((_) {
          setState(() {}); // Refresh the door when returning, just in case
        });
      },
      onLongPress: () => _pickRoomImage(floorIndex, roomIndex),
      

      child: Container(
        // Increased width from 130 -> 155
        width: 155,

        margin: const EdgeInsets.only(
          right: 15,
        ),

        decoration: BoxDecoration(
          color: Colors.brown.shade200,

          borderRadius: BorderRadius.circular(10),

          border: Border.all(
            color: Colors.brown.shade800,
            width: 3,
          ),

          // ==================================================
          // ROOM IMAGE
          // ==================================================

          image: room.imagePath != null
              ? DecorationImage(
                  image: FileImage(
                    File(room.imagePath!),
                  ),
                  fit: BoxFit.cover,
                )
              : null,

          // ==================================================
          // ROOM CARD SHADOW
          // ==================================================

          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.45),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(
                3,
                3,
              ),
            ),
          ],
        ),

        // ==================================================
        // ROOM NUMBER
        // ==================================================

        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),

            decoration: BoxDecoration(
              // More transparent so the image remains visible
              color: Colors.white.withOpacity(0.40),

              borderRadius: BorderRadius.circular(6),

              border: Border.all(
                color: Colors.white.withOpacity(0.50),
                width: 1,
              ),

              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 3,
                  offset: const Offset(
                    0,
                    1,
                  ),
                ),
              ],
            ),

            child: Text(
              // Example:
              // 101
              // 102
              // 103
              room.name,

              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
