import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'storage.dart';

class RecordScreen extends StatefulWidget {
  final Room room;
  final VoidCallback onDataChanged;

  const RecordScreen({
    super.key,
    required this.room,
    required this.onDataChanged,
  });

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  // ======================================================
  // DATE HELPERS
  // ======================================================
  void _disposeControllersAfterDialog(
    List<TextEditingController> controllers,
  ) {
    // Wait for the dialog's closing animation to finish before disposing
    Future.delayed(const Duration(milliseconds: 300), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }

  DateTime _startOfMonth(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      1,
    );
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthName(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[date.month - 1];
  }

  String _money(double amount) {
    return '৳${amount.toStringAsFixed(0)}';
  }

  // ======================================================
  // CURRENT MONTH
  // ======================================================

  DateTime get _currentMonth {
    return _startOfMonth(DateTime.now());
  }

  String get _currentMonthKey {
    return _monthKey(_currentMonth);
  }

  DateTime get _nextMonth {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month + 1,
      1,
    );
  }

  // ======================================================
  // INIT
  // ======================================================

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ensureCurrentMonthRent();
      }
    });
  }

  // ======================================================
  // AUTOMATIC MONTHLY RENT
  // ======================================================

  void _ensureCurrentMonthRent({
    bool createLog = true,
  }) {
    final bool alreadyExists = widget.room.bills.any(
      (bill) =>
          bill.isRent &&
          _monthKey(bill.targetMonth) == _currentMonthKey,
    );

    if (alreadyExists) {
      return;
    }

    if (widget.room.baseRentAmount <= 0) {
      return;
    }

    final double rentAmount = widget.room.baseRentAmount;

    setState(() {
      widget.room.bills.add(
        Bill(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: 'Rent',
          amount: rentAmount,
          paidAmount: 0,
          isRent: true,
          targetMonth: _currentMonth,
        ),
      );
    });

    if (createLog) {
      widget.room.logs.insert(
        0,
        RentLog(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: DateTime.now(),
          description:
              'Monthly rent added automatically: ${_money(rentAmount)}',
        ),
      );
    }

    widget.onDataChanged();
  }

  // ======================================================
  // CURRENT MONTH BILLS
  // ======================================================

  List<Bill> get _currentBills {
    final bills = widget.room.bills
        .where(
          (bill) =>
              _monthKey(bill.targetMonth) == _currentMonthKey,
        )
        .toList();

    bills.sort(
      (a, b) {
        if (a.isRent && !b.isRent) return -1;
        if (!a.isRent && b.isRent) return 1;
        return 0;
      },
    );

    return bills;
  }

  // ======================================================
  // TOTAL DUE
  // ======================================================

  double get _totalDue {
    return _currentBills.fold(
      0.0,
      (total, bill) => total + bill.remainingAmount,
    );
  }

  // ======================================================
  // RENT DUE
  // ======================================================

  double get _currentRentDue {
    for (final bill in _currentBills) {
      if (bill.isRent) {
        return bill.remainingAmount;
      }
    }
    return 0.0;
  }

  // ======================================================
  // OTHER BILLS DUE
  // ======================================================

  double get _currentOtherBillsDue {
    return _currentBills
        .where((bill) => !bill.isRent)
        .fold(
          0.0,
          (total, bill) => total + bill.remainingAmount,
        );
  }

  // ======================================================
  // ADD LOG
  // ======================================================

  void _addLog(String description) {
    widget.room.logs.insert(
      0,
      RentLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        description: description,
      ),
    );

    widget.onDataChanged();

    if (mounted) {
      setState(() {});
    }
  }

  // ======================================================
  // FILE NAME HELPER
  // ======================================================

  String _getFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  // ======================================================
  // PICK ID DOCUMENT
  // ======================================================

  Future<String?> _pickIdDocument() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'pdf',
        ],
      );

      if (file == null || file.path == null) {
        return null;
      }

      final savedPath = await AppStorage.saveFilePermanently(
        file.path!,
      );

      return savedPath;
    } catch (e) {
      if (!mounted) {
        return null;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select ID file: $e'),
        ),
      );

      return null;
    }
  }

  // ======================================================
  // RENTER INFORMATION
  // ======================================================

  Future<void> _showRenterDetailsDialog() async {
    final nameController = TextEditingController(
      text: widget.room.renterName,
    );

    final rentController = TextEditingController(
      text: widget.room.baseRentAmount > 0
          ? widget.room.baseRentAmount.toStringAsFixed(0)
          : '',
    );

    String? selectedIdPath = widget.room.renterIdImagePath;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool hasId =
                selectedIdPath != null && selectedIdPath!.isNotEmpty;

            return AlertDialog(
              title: const Text(
                'Renter Information',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name (Optional)',
                        hintText: 'Enter renter name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: rentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent Amount',
                        hintText: 'Enter monthly rent',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasId
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasId ? Colors.green : Colors.grey.shade400,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                hasId
                                    ? Icons.verified
                                    : Icons.assignment_ind_outlined,
                                color: hasId ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'ID Document (Optional)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (hasId)
                            Text(
                              _getFileName(selectedIdPath!),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            const Text(
                              'Select an image or PDF.',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final path = await _pickIdDocument();
                                if (path == null || !mounted) return;
                                setDialogState(() {
                                  selectedIdPath = path;
                                });
                              },
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                hasId ? 'Change ID' : 'Select ID',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final rent = double.tryParse(rentController.text.trim());

                    // Removed the ID validation check here

                    if (rent == null || rent < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid monthly rent.')),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) {
      _disposeControllersAfterDialog([nameController, rentController]);
      return;
    }

    final String newName = nameController.text.trim();
    final double newRent = double.tryParse(rentController.text.trim()) ?? 0;
    final double oldRent = widget.room.baseRentAmount;

    setState(() {
      widget.room.renterName = newName;
      widget.room.baseRentAmount = newRent;
      widget.room.renterIdImagePath = selectedIdPath;
    });

    Bill? currentRentBill;
    for (final bill in widget.room.bills) {
      if (bill.isRent && _monthKey(bill.targetMonth) == _currentMonthKey) {
        currentRentBill = bill;
        break;
      }
    }

    if (currentRentBill != null) {
      final paidAmount = currentRentBill.paidAmount;
      setState(() {
        currentRentBill!.amount = newRent;
        if (paidAmount > newRent) {
          currentRentBill!.paidAmount = newRent;
        }
      });
    } else if (newRent > 0) {
      setState(() {
        widget.room.bills.add(
          Bill(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: 'Rent',
            amount: newRent,
            paidAmount: 0,
            isRent: true,
            targetMonth: _currentMonth,
          ),
        );
      });
    }

    String description = 'Renter information updated.';
    if (oldRent != newRent) {
      description += ' Monthly rent changed from ${_money(oldRent)} to ${_money(newRent)}.';
    }

    _addLog(description);
    _disposeControllersAfterDialog([nameController, rentController]);
  }
  // ======================================================
  // FIND CURRENT RENT BILL
  // ======================================================

  Bill? _getCurrentRentBill() {
    for (final bill in _currentBills) {
      if (bill.isRent) {
        return bill;
      }
    }
    return null;
  }

  // ======================================================
  // UPDATE RENT
  // ======================================================

  Future<void> _showUpdateRentDialog() async {
    final Bill? rentBill = _getCurrentRentBill();

    if (rentBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rent has been configured.'),
        ),
      );
      return;
    }

    final amountController = TextEditingController();
    String selectedOption = 'specific';

    final result = await showDialog<double?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final remaining = rentBill.remainingAmount;

            return AlertDialog(
              title: const Text(
                'Update Rent',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Rent Remaining',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _money(remaining),
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'specific',
                      groupValue: selectedOption,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedOption = value!;
                        });
                      },
                      title: const Text(
                        'Specific Amount',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Pay part of the rent'),
                    ),
                    if (selectedOption == 'specific')
                      TextField(
                        controller: amountController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount to Pay',
                          hintText: 'Enter amount',
                          prefixText: '৳ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 5),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'full',
                      groupValue: selectedOption,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedOption = value!;
                        });
                      },
                      title: const Text(
                        'Full Payment',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Pay ${_money(remaining)}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, null);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    double amount;
                    if (selectedOption == 'full') {
                      amount = remaining;
                    } else {
                      amount = double.tryParse(amountController.text.trim()) ?? 0;
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a valid amount.')),
                        );
                        return;
                      }
                      if (amount > remaining) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Amount cannot exceed ${_money(remaining)}.'),
                          ),
                        );
                        return;
                      }
                    }
                    Navigator.pop(dialogContext, amount);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update Rent'),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([amountController]);

    if (result == null || !mounted) return;

    _applyRentPayment(rentBill, result);
  }

  // ======================================================
  // APPLY RENT PAYMENT
  // ======================================================

  void _applyRentPayment(Bill rentBill, double amount) {
    setState(() {
      rentBill.paidAmount += amount;
      if (rentBill.paidAmount > rentBill.amount) {
        rentBill.paidAmount = rentBill.amount;
      }
    });

    _addLog('Rent payment received: ${_money(amount)}.');

    if (rentBill.isPaid && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rent has been fully paid.'),
        ),
      );
    }
  }

  // ======================================================
  // ADD BILL
  // ======================================================

  Future<void> _showAddBillDialog() async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String selectedMonth = 'current';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Bill',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bill Name',
                        hintText: 'Gas, Electricity, Water...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Bill Amount',
                        hintText: 'Enter amount',
                        prefixText: '৳ ',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payments),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add this bill to:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'current',
                      groupValue: selectedMonth,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMonth = value!;
                        });
                      },
                      title: Text(
                        'Current Month (${_monthName(_currentMonth)})',
                      ),
                    ),
                    RadioListTile<String>(
                      value: 'next',
                      groupValue: selectedMonth,
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMonth = value!;
                        });
                      },
                      title: Text(
                        'Next Month (${_monthName(_nextMonth)})',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, null);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final amount = double.tryParse(amountController.text.trim());

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter the bill name.')),
                      );
                      return;
                    }

                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a valid amount.')),
                      );
                      return;
                    }

                    final DateTime targetMonth = selectedMonth == 'current'
                        ? _currentMonth
                        : _nextMonth;

                    Navigator.pop(
                      dialogContext,
                      {
                        'name': name,
                        'amount': amount,
                        'targetMonth': targetMonth,
                      },
                    );
                  },
                  child: const Text('Add Bill'),
                ),
              ],
            );
          },
        );
      },
    );

    _disposeControllersAfterDialog([
      nameController,
      amountController,
    ]);

    if (result == null || !mounted) {
      return;
    }

    final String name = result['name'] as String;
    final double amount = result['amount'] as double;
    final DateTime targetMonth = result['targetMonth'] as DateTime;

    setState(() {
      widget.room.bills.add(
        Bill(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          amount: amount,
          paidAmount: 0,
          isRent: false,
          targetMonth: targetMonth,
        ),
      );
    });

    _addLog(
      'Added $name bill ${_money(amount)} for ${_monthName(targetMonth)} ${targetMonth.year}.',
    );
  }

  // ======================================================
  // EDIT BILL
  // ======================================================

  Future<void> _showEditBillDialog(Bill bill) async {
    final nameController = TextEditingController(text: bill.name);
    final amountController = TextEditingController(
      text: bill.amount.toStringAsFixed(0),
    );

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            bill.isRent ? 'Edit Rent' : 'Edit Bill',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  enabled: !bill.isRent,
                  decoration: InputDecoration(
                    labelText: 'Bill Name',
                    border: const OutlineInputBorder(),
                    helperText: bill.isRent ? 'Rent name cannot be changed.' : null,
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '৳ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Original: ${_money(bill.amount)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Paid: ${_money(bill.paidAmount)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 5),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Remaining: ${_money(bill.remainingAmount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: bill.isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!bill.isRent)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext, {'action': 'delete'});
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newAmount = double.tryParse(amountController.text.trim());

                if (newAmount == null || newAmount < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a valid amount.')),
                  );
                  return;
                }

                String newName = bill.name;

                if (!bill.isRent) {
                  newName = nameController.text.trim();
                  if (newName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bill name cannot be empty.')),
                    );
                    return;
                  }
                }

                Navigator.pop(
                  dialogContext,
                  {
                    'action': 'save',
                    'name': newName,
                    'amount': newAmount,
                  },
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    _disposeControllersAfterDialog([
      nameController,
      amountController,
    ]);

    if (result == null || !mounted) {
      return;
    }

    if (result['action'] == 'delete') {
      await _confirmDeleteBill(bill);
      return;
    }

    if (result['action'] == 'save') {
      final oldName = bill.name;
      final oldAmount = bill.amount;
      final newName = result['name'] as String;
      final newAmount = result['amount'] as double;

      setState(() {
        if (!bill.isRent) {
          bill.name = newName;
        }

        bill.amount = newAmount;

        if (bill.paidAmount > newAmount) {
          bill.paidAmount = newAmount;
        }

        if (bill.isRent) {
          widget.room.baseRentAmount = newAmount;
        }
      });

      if (bill.isRent) {
        _addLog(
          'Rent changed from ${_money(oldAmount)} to ${_money(newAmount)}.',
        );
      } else {
        _addLog(
          'Bill updated: $oldName → ${bill.name}, ${_money(oldAmount)} → ${_money(newAmount)}.',
        );
      }
    }
  }

  // ======================================================
  // CONFIRM BILL DELETE
  // ======================================================

  Future<void> _confirmDeleteBill(Bill bill) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delete Bill?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${bill.name}"?\n\n'
            'Amount: ${_money(bill.amount)}\n'
            'Month: ${_monthName(bill.targetMonth)} ${bill.targetMonth.year}\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      widget.room.bills.removeWhere((item) => item.id == bill.id);
    });

    _addLog(
      'Deleted bill: ${bill.name} ${_money(bill.amount)}.',
    );
  }

  // ======================================================
  // BILL CARD
  // ======================================================

  Widget _buildBillCard(Bill bill) {
    final bool paid = bill.isPaid;

    return GestureDetector(
      onTap: () {
        _showEditBillDialog(bill);
      },
      child: Container(
        width: 155,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: paid ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: paid ? Colors.green : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              bill.isRent ? Icons.home : Icons.receipt_long,
              size: 30,
              color: bill.isRent ? Colors.teal : Colors.blueGrey,
            ),
            const SizedBox(height: 8),
            Text(
              bill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _money(bill.remainingAmount),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: paid ? Colors.green : Colors.teal,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              paid ? 'PAID' : 'Tap to edit',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: paid ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // CLEAR WHOLE HISTORY
  // ======================================================

  Future<void> _showClearHistoryDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Clear Whole History?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: const Text(
            'This will permanently remove:\n\n'
            '• All bills\n'
            '• All rent payment records\n'
            '• All activity logs\n\n'
            'Renter name, ID and monthly rent settings will remain.\n\n'
            'The current month rent will be created again automatically.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear Everything'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      widget.room.bills.clear();
      widget.room.logs.clear();
    });

    _ensureCurrentMonthRent(createLog: false);

    widget.room.logs.insert(
      0,
      RentLog(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        description:
            'All previous bill, payment, and activity history was cleared.',
      ),
    );

    widget.onDataChanged();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All history has been cleared.'),
      ),
    );
  }

  // ======================================================
  // ID STATUS
  // ======================================================

  Widget _buildIdStatus() {
    final path = widget.room.renterIdImagePath;

    if (path == null || path.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_ind_outlined, color: Colors.grey, size: 18),
            SizedBox(width: 5),
            Text(
              'Not added',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    final bool isPdf = path.toLowerCase().endsWith('.pdf');

    return Container(
      constraints: const BoxConstraints(maxWidth: 155),
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf : Icons.image,
            color: Colors.green.shade700,
            size: 19,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              _getFileName(path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ======================================================
  // LOG ITEM
  // ======================================================

  Widget _buildLogItem(RentLog log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.history, size: 20),
        ),
        title: Text(
          log.description,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(_formatDate(log.date)),
      ),
    );
  }

  // ======================================================
  // BUILD
  // ======================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Room ${widget.room.name}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _showRenterDetailsDialog,
            tooltip: 'Renter Information',
            icon: const Icon(Icons.person),
          ),
          IconButton(
            onPressed: _showClearHistoryDialog,
            tooltip: 'Clear History',
            icon: const Icon(Icons.delete_sweep, color: Colors.red),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Name',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.room.renterName.trim().isEmpty
                              ? 'Not added'
                              : widget.room.renterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  // Look for this section inside your `build` method:
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'ID',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 5),
                        _buildIdStatus(),
                        const SizedBox(height: 2),
                        const Text(
                          'Optional', // Changed from 'Required'
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey, // Changed from Colors.red
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

              ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Date',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatDate(DateTime.now()),
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _totalDue > 0
                          ? Colors.orange.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Due',
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          child: Text(
                            _money(_totalDue),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: _totalDue > 0
                                  ? Colors.orange
                                  : Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rent Due: ${_money(_currentRentDue)}',
                  style: const TextStyle(color: Colors.black54),
                ),
                Text(
                  'Bills Due: ${_money(_currentOtherBillsDue)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bills This Month',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Tap a bill to edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 142,
              child: _currentBills.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'No bills for this month.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _currentBills.length,
                      itemBuilder: (context, index) {
                        return _buildBillCard(_currentBills[index]);
                      },
                    ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showUpdateRentDialog,
                    icon: const Icon(Icons.payments),
                    label: const Text('Update Rent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddBillDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Bills'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade100,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.room.logs.length} entries',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.room.logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'No activity yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...widget.room.logs.map(_buildLogItem),
          ],
        ),
      ),
    );
  }
}