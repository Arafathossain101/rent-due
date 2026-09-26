import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'stories_screen.dart';
import 'storage.dart';

void main() {
  runApp(const RentApp());
}

// ======================================================
// APP
// ======================================================

class RentApp extends StatelessWidget {
  const RentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rent Record',

      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),

      home: const SplashScreen(),
    );
  }
}

// ======================================================
// SPLASH SCREEN
// ======================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    Future.delayed(
      const Duration(seconds: 3),
      () {
        if (!mounted) {
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const HomeScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Image.asset(
              'assets/rent is due.jpg',
              height: 300,
              fit: BoxFit.contain,
            ),

            const SizedBox(height: 30),

            const Text(
              'Loading your records...',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// HOME SCREEN
// ======================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();

  List<House> houses = [];

  bool isDeleteMode = false;

  bool isLoading = true;

  // ======================================================
  // INIT
  // ======================================================

  @override
  void initState() {
    super.initState();

    _loadSavedData();
  }

  // ======================================================
  // LOAD DATA
  // ======================================================

  Future<void> _loadSavedData() async {
    try {
      final savedHouses =
          await AppStorage.loadHouses();

      if (!mounted) {
        return;
      }

      setState(() {
        houses = savedHouses;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not load saved data: $e',
          ),
        ),
      );
    }
  }

  // ======================================================
  // SAVE DATA
  // ======================================================

  Future<void> _saveData() async {
    try {
      await AppStorage.saveHouses(
        houses,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not save data: $e',
          ),
        ),
      );
    }
  }

  // ======================================================
  // ADD HOUSE
  // ======================================================

  Future<void> _showAddHouseDialog() async {
    final TextEditingController
        nameController =
        TextEditingController();

    final TextEditingController
        storiesController =
        TextEditingController();

    String? selectedTempImagePath;

    await showDialog(
      context: context,
      barrierDismissible: false,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setStateDialog,
          ) {
            return AlertDialog(
              title: const Text(
                'Add a New House',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              content:
                  SingleChildScrollView(
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    // HOUSE NAME
                    TextField(
                      controller:
                          nameController,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Name of the House',
                        border:
                            OutlineInputBorder(),
                      ),

                      style:
                          const TextStyle(
                        fontSize: 22,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // STORIES
                    TextField(
                      controller:
                          storiesController,

                      keyboardType:
                          TextInputType.number,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Number of Stories',
                        border:
                            OutlineInputBorder(),
                      ),

                      style:
                          const TextStyle(
                        fontSize: 22,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // PICK HOUSE IMAGE
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final XFile? image =
                              await _picker.pickImage(
                            source:
                                ImageSource.gallery,
                            imageQuality: 85,
                          );

                          if (image == null) {
                            return;
                          }

                          setStateDialog(() {
                            selectedTempImagePath =
                                image.path;
                          });
                        } catch (e) {
                          if (!mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not select image: $e',
                              ),
                            ),
                          );
                        }
                      },

                      icon: const Icon(
                        Icons.photo_library,
                        size: 30,
                      ),

                      label: const Text(
                        'Pick a Picture',
                        style:
                            TextStyle(
                          fontSize: 20,
                        ),
                      ),

                      style:
                          ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    if (selectedTempImagePath !=
                        null)
                      const Text(
                        'Picture selected!',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              actions: [
                // CANCEL
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                    );
                  },

                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 22,
                      color: Colors.grey,
                    ),
                  ),
                ),

                // SAVE HOUSE
                ElevatedButton(
                  onPressed: () async {
                    final name =
                        nameController.text
                            .trim();

                    final stories =
                        int.tryParse(
                      storiesController
                          .text
                          .trim(),
                    );

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter the house name.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (stories == null ||
                        stories < 1) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Enter a valid number of stories.',
                          ),
                        ),
                      );
                      return;
                    }

                    try {
                      // --------------------------------
                      // SAVE IMAGE PERMANENTLY
                      // --------------------------------

                      String?
                          permanentImagePath;

                      if (selectedTempImagePath !=
                          null) {
                        permanentImagePath =
                            await AppStorage
                                .saveImagePermanently(
                          selectedTempImagePath!,
                        );
                      }

                      // --------------------------------
                      // CREATE FLOORS
                      // --------------------------------

                      final List<Floor>
                          initialFloors = [];

                      for (
                        int i = 1;
                        i <= stories;
                        i++
                      ) {
                        initialFloors.add(
                          Floor(
                            floorNumber: i,
                            rooms: [],
                          ),
                        );
                      }

                      // --------------------------------
                      // CREATE HOUSE
                      // --------------------------------

                      final newHouse =
                          House(
                        id: DateTime.now()
                            .microsecondsSinceEpoch
                            .toString(),

                        name: name,

                        numberOfStories:
                            stories,

                        imagePath:
                            permanentImagePath,

                        floors:
                            initialFloors,
                      );

                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        houses.add(
                          newHouse,
                        );
                      });

                      await _saveData();

                      if (!mounted) {
                        return;
                      }

                      Navigator.pop(
                        dialogContext,
                      );
                    } catch (e) {
                      if (!mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not save house: $e',
                          ),
                        ),
                      );
                    }
                  },

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.teal,
                    foregroundColor:
                        Colors.white,
                  ),

                  child: const Text(
                    'Save House',
                    style:
                        TextStyle(
                      fontSize: 22,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

  Future.delayed(const Duration(milliseconds: 300), () {
  nameController.dispose();
  storiesController.dispose();
});

  }

  // ======================================================
  // CHANGE HOUSE IMAGE
  // ======================================================
  //
  // Long pressing a house card calls this.
  // ======================================================

  Future<void> _changeHouseImage(
    House house,
  ) async {
    try {
      final XFile? image =
          await _picker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) {
        return;
      }

      // Save the selected image permanently.
      final String permanentPath =
          await AppStorage
              .saveImagePermanently(
        image.path,
      );

      if (!mounted) {
        return;
      }

      // Update house.
      setState(() {
        house.imagePath =
            permanentPath;
      });

      // Save updated house data.
      await _saveData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'House image updated successfully.',
          ),
          duration:
              Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not change house image: $e',
          ),
        ),
      );
    }
  }

  // ======================================================
  // CONFIRM DELETE HOUSE
  // ======================================================

  Future<void> _confirmDeleteDialog(
    int index,
  ) async {
    final house = houses[index];

    final bool? confirmed =
        await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete House?',
            style: TextStyle(
              fontSize: 28,
              color: Colors.red,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          content: Text(
            'Are you sure you want to remove '
            '${house.name}?\n\n'
            'All floors, rooms and rent records '
            'belonging to this house will be '
            'removed from the saved house list.',
            style:
                const TextStyle(
              fontSize: 19,
            ),
          ),

          actions: [
            // CANCEL
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },

              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 22,
                ),
              ),
            ),

            // DELETE
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    Colors.red,
                foregroundColor:
                    Colors.white,
              ),

              child: const Text(
                'Yes, Delete',
                style:
                    TextStyle(
                  fontSize: 22,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      houses.removeAt(index);

      if (houses.isEmpty) {
        isDeleteMode = false;
      }
    });

    await _saveData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          '${house.name} deleted.',
        ),
      ),
    );
  }

  // ======================================================
  // HOUSE CARD
  // ======================================================

  Widget _buildHouseCard(
    House house,
    int index,
  ) {
    return GestureDetector(
      // ==================================================
      // NORMAL TAP
      // ==================================================

      onTap: () {
        if (isDeleteMode) {
          // In delete mode:
          // tap = delete confirmation
          _confirmDeleteDialog(index);

          return;
        }

        // Normal mode:
        // tap = open StoriesScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StoriesScreen(
              house: house,

              onHouseUpdated:
                  _saveData,
            ),
          ),
        ).then((_) {
          if (!mounted) {
            return;
          }

          setState(() {});
        });
      },

      // ==================================================
      // LONG PRESS
      // ==================================================
      //
      // Long press = change house image.
      //
      // Disabled in delete mode so the two actions
      // don't interfere with each other.
      // ==================================================

      onLongPress: isDeleteMode
          ? null
          : () {
              _changeHouseImage(
                house,
              );
            },

      child: Container(
        width: 300,

        margin:
            const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            20,
          ),

          border: Border.all(
            color: isDeleteMode
                ? Colors.red
                : Colors.grey.shade300,

            width: 3,
          ),

          boxShadow: [
            BoxShadow(
              color:
                  Colors.grey.withOpacity(
                0.3,
              ),

              spreadRadius: 2,

              blurRadius: 10,

              offset:
                  const Offset(0, 5),
            ),
          ],
        ),

        child: Stack(
          children: [
            // ==========================================
            // HOUSE CARD CONTENT
            // ==========================================

            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,

              children: [
                // --------------------------------------
                // HOUSE NAME
                // --------------------------------------

                Padding(
                  padding:
                      const EdgeInsets.all(
                    15,
                  ),

                  child: Text(
                    house.name,

                    textAlign:
                        TextAlign.center,

                    maxLines: 1,

                    overflow:
                        TextOverflow.ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 28,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),

                const Divider(
                  thickness: 2,
                ),

                // --------------------------------------
                // HOUSE IMAGE
                // --------------------------------------

                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius
                            .only(
                      bottomLeft:
                          Radius.circular(
                        17,
                      ),
                      bottomRight:
                          Radius.circular(
                        17,
                      ),
                    ),

                    child:
                        house.imagePath !=
                                null &&
                            house.imagePath!
                                .isNotEmpty
                        ? Image.file(
                            File(
                              house.imagePath!,
                            ),

                            fit:
                                BoxFit.cover,

                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return _buildNoHouseImage();
                            },
                          )
                        : _buildNoHouseImage(),
                  ),
                ),
              ],
            ),

            // ==========================================
            // DELETE MODE OVERLAY
            // ==========================================

            if (isDeleteMode)
              Positioned.fill(
                child: Container(
                  decoration:
                      BoxDecoration(
                    color: Colors.red
                        .withOpacity(
                      0.4,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                  ),

                  child:
                      const Center(
                    child: Icon(
                      Icons
                          .delete_forever,
                      size: 100,
                      color:
                          Colors.white,
                    ),
                  ),
                ),
              ),

            // ==========================================
            // LONG-PRESS HINT
            // ==========================================
            //
            // Only shown in normal mode when the
            // house has an image.
            // ==========================================

            if (!isDeleteMode)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),

                  decoration:
                      BoxDecoration(
                    color: Colors.black
                        .withOpacity(
                      0.45,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      8,
                    ),
                  ),

                  child:
                      const Row(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [
                      Icon(
                        Icons.touch_app,
                        color:
                            Colors.white,
                        size: 15,
                      ),

                      SizedBox(
                        width: 4,
                      ),

                      Text(
                        'Long press to change',
                        style:
                            TextStyle(
                          color:
                              Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // NO IMAGE PLACEHOLDER
  // ======================================================

  Widget _buildNoHouseImage() {
    return Container(
      color: Colors.grey.shade200,

      child: const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.home,
              size: 100,
              color: Colors.grey,
            ),

            SizedBox(height: 8),

            Text(
              'No house picture',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      // ==================================================
      // APP BAR
      // ==================================================

      appBar: AppBar(
        title: const Text(
          'My Properties',

          style: TextStyle(
            fontSize: 28,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        backgroundColor:
            Theme.of(context)
                .colorScheme
                .inversePrimary,
      ),

      // ==================================================
      // BODY
      // ==================================================

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 20,
            ),

            // ==========================================
            // HOUSE LIST
            // ==========================================

            Expanded(
              child: houses.isEmpty
                  ? const Center(
                      child: Text(
                        'No houses yet.\n'
                        'Tap "Add" below.',

                        textAlign:
                            TextAlign.center,

                        style: TextStyle(
                          fontSize: 24,
                          color:
                              Colors.grey,
                        ),
                      ),
                    )

                  : ListView.builder(
                      scrollDirection:
                          Axis.horizontal,

                      itemCount:
                          houses.length,

                      itemBuilder:
                          (context, index) {
                        return _buildHouseCard(
                          houses[index],
                          index,
                        );
                      },
                    ),
            ),

            // ==========================================
            // BOTTOM BUTTONS
            // ==========================================

            Padding(
              padding:
                  const EdgeInsets.all(
                15.0,
              ),

              child: Row(
                children: [
                  // ADD
                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          _showAddHouseDialog,

                      icon:
                          const Icon(
                        Icons.add,
                        size: 28,
                      ),

                      label:
                          const Text(
                        'Add',
                        style:
                            TextStyle(
                          fontSize: 20,
                        ),
                      ),

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            Colors.green
                                .shade100,

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  // DELETE
                  Expanded(
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          houses.isEmpty
                              ? null
                              : () {
                                  setState(() {
                                    isDeleteMode =
                                        !isDeleteMode;
                                  });
                                },

                      icon:
                          const Icon(
                        Icons.delete,
                        size: 28,
                      ),

                      label: Text(
                        isDeleteMode
                            ? 'Done'
                            : 'Delete',

                        style:
                            const TextStyle(
                          fontSize: 20,
                        ),
                      ),

                      style:
                          ElevatedButton
                              .styleFrom(
                        backgroundColor:
                            isDeleteMode
                                ? Colors
                                    .red
                                    .shade200
                                : Colors
                                    .red
                                    .shade50,

                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}