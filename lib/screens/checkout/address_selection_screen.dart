import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../../config/theme.dart';
// audit batch 4 (Agent I): centralized validators for pincode + phone.
import '../../utils/validators.dart';
import '../../widgets/common_widgets.dart';

class SavedAddress {
  String label;
  String name;
  String flatHouse;
  String street;
  String city;
  String pincode;
  String phone;
  String icon;
  bool isDefault;

  SavedAddress({
    required this.label,
    required this.name,
    required this.flatHouse,
    required this.street,
    required this.city,
    required this.pincode,
    required this.phone,
    this.icon = 'home',
    this.isDefault = false,
  });

  String get fullAddress => '$flatHouse, $street, $city $pincode';

  Map<String, dynamic> toJson() => {
        'label': label,
        'name': name,
        'flatHouse': flatHouse,
        'street': street,
        'city': city,
        'pincode': pincode,
        'phone': phone,
        'icon': icon,
        'isDefault': isDefault,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        label: json['label'] ?? '',
        name: json['name'] ?? '',
        flatHouse: json['flatHouse'] ?? '',
        street: json['street'] ?? '',
        city: json['city'] ?? 'Delhi',
        pincode: json['pincode'] ?? '',
        phone: json['phone'] ?? '',
        icon: json['icon'] ?? 'home',
        isDefault: json['isDefault'] ?? false,
      );

  // For backward compat with the old Map<String, String> format
  Map<String, String> toMapCompat() => {
        'label': label,
        'address': fullAddress,
        'icon': icon,
      };
}

class AddressHelper {
  static const _key = 'housepital_saved_addresses';

  static final List<SavedAddress> _defaultAddresses = [
    SavedAddress(
      label: 'Home',
      name: 'Patient',
      flatHouse: 'B-42',
      street: 'Sector 15',
      city: 'Noida',
      pincode: '201301',
      phone: '9876543210',
      icon: 'home',
      isDefault: true,
    ),
    SavedAddress(
      label: 'Parent\'s Home',
      name: 'Patient',
      flatHouse: '12/3',
      street: 'Lajpat Nagar II',
      city: 'Delhi',
      pincode: '110024',
      phone: '9876543211',
      icon: 'family',
    ),
    SavedAddress(
      label: 'Office',
      name: 'Patient',
      flatHouse: '5th Floor, Tower B',
      street: 'Cyber City',
      city: 'Gurgaon',
      pincode: '122002',
      phone: '9876543212',
      icon: 'work',
    ),
  ];

  static Future<List<SavedAddress>> loadAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_key);
    if (str == null) {
      // Seed with defaults
      await saveAddresses(_defaultAddresses);
      return List.from(_defaultAddresses);
    }
    try {
      final List<dynamic> list = json.decode(str);
      return list
          .map((e) => SavedAddress.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return List.from(_defaultAddresses);
    }
  }

  static Future<void> saveAddresses(List<SavedAddress> addresses) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(addresses.map((a) => a.toJson()).toList()));
  }
}

class AddressSelectionScreen extends StatefulWidget {
  const AddressSelectionScreen({super.key});

  @override
  State<AddressSelectionScreen> createState() => _AddressSelectionScreenState();
}

class _AddressSelectionScreenState extends State<AddressSelectionScreen> {
  List<SavedAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await AddressHelper.loadAddresses();
    if (mounted) setState(() { _addresses = list; _isLoading = false; });
  }

  Future<void> _save() async {
    await AddressHelper.saveAddresses(_addresses);
  }

  void _setDefault(int index) {
    setState(() {
      for (int i = 0; i < _addresses.length; i++) {
        _addresses[i].isDefault = i == index;
      }
    });
    _save();
  }

  Future<void> _deleteAddress(int index) async {
    final addr = _addresses[index];
    final confirmed = await confirmDestructiveAction(
      context,
      title: 'Delete this address?',
      message:
          '"${addr.label}" (${addr.flatHouse}, ${addr.street}) will be removed from your saved addresses.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      final wasDefault = _addresses[index].isDefault;
      _addresses.removeAt(index);
      if (wasDefault && _addresses.isNotEmpty) {
        _addresses[0].isDefault = true;
      }
    });
    _save();
  }

  void _openAddEditForm({SavedAddress? existing, int? editIndex}) async {
    final result = await Navigator.push<SavedAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressFormScreen(existing: existing),
      ),
    );
    if (result != null) {
      setState(() {
        if (editIndex != null) {
          result.isDefault = _addresses[editIndex].isDefault;
          _addresses[editIndex] = result;
        } else {
          if (_addresses.isEmpty) result.isDefault = true;
          _addresses.add(result);
        }
      });
      _save();
    }
  }

  // audit batch 4 (Agent L): Shimmer skeleton — 3 address cards approximating
  // the post-load layout so the screen settles rather than popping in.
  Widget _buildSkeleton() {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    Widget bar({double width = double.infinity, double height = 14}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: HousepitalColors.greyLighter,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 10),
                  bar(width: 100, height: 14),
                ],
              ),
              const SizedBox(height: 12),
              bar(width: double.infinity, height: 12),
              const SizedBox(height: 6),
              bar(width: 220, height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Addresses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openAddEditForm(),
            tooltip: 'Add New Address',
          ),
        ],
      ),
      // audit batch 4 (Agent L): Apple P5 — replace bare spinner with a
      // Shimmer skeleton matching the saved-address card layout.
      body: _isLoading
          ? _buildSkeleton()
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 64, color: HousepitalColors.greyLight),
                      const SizedBox(height: 16),
                      const Text('No saved addresses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEditForm(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Address'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: addr.isDefault ? HousepitalColors.orange : HousepitalColors.divider,
                          width: addr.isDefault ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                addr.icon == 'home'
                                    ? Icons.home_outlined
                                    : addr.icon == 'work'
                                        ? Icons.business_outlined
                                        : Icons.family_restroom_outlined,
                                size: 18,
                                color: HousepitalColors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(addr.label,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              if (addr.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: HousepitalColors.orangeLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Default',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: HousepitalColors.orange)),
                                ),
                              ],
                              const Spacer(),
                              PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') {
                                    _openAddEditForm(existing: addr, editIndex: index);
                                  } else if (v == 'default') {
                                    _setDefault(index);
                                  } else if (v == 'delete') {
                                    _deleteAddress(index);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  if (!addr.isDefault)
                                    const PopupMenuItem(value: 'default', child: Text('Set as Default')),
                                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: HousepitalColors.error))),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(addr.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 2),
                          Text(addr.fullAddress,
                              style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
                          const SizedBox(height: 2),
                          Text('Phone: ${addr.phone}',
                              style: const TextStyle(fontSize: 12, color: HousepitalColors.greyLight)),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _openAddEditForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add New'),
              backgroundColor: HousepitalColors.orange,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  ADDRESS FORM SCREEN
// ═══════════════════════════════════════════════════════════════

class _AddressFormScreen extends StatefulWidget {
  final SavedAddress? existing;
  const _AddressFormScreen({this.existing});

  @override
  State<_AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<_AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _nameController;
  late TextEditingController _flatController;
  late TextEditingController _streetController;
  late TextEditingController _pincodeController;
  late TextEditingController _phoneController;
  String _city = 'Delhi';
  String _icon = 'home';

  static const _cities = ['Delhi', 'Faridabad', 'Gurgaon', 'Noida', 'Ghaziabad'];
  static const _iconOptions = ['home', 'work', 'family'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _labelController = TextEditingController(text: e?.label ?? '');
    _nameController = TextEditingController(text: e?.name ?? '');
    _flatController = TextEditingController(text: e?.flatHouse ?? '');
    _streetController = TextEditingController(text: e?.street ?? '');
    _pincodeController = TextEditingController(text: e?.pincode ?? '');
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _city = e?.city ?? 'Delhi';
    if (!_cities.contains(_city)) _city = 'Delhi';
    _icon = e?.icon ?? 'home';
  }

  @override
  void dispose() {
    _labelController.dispose();
    _nameController.dispose();
    _flatController.dispose();
    _streetController.dispose();
    _pincodeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      SavedAddress(
        label: _labelController.text.trim(),
        name: _nameController.text.trim(),
        flatHouse: _flatController.text.trim(),
        street: _streetController.text.trim(),
        city: _city,
        pincode: _pincodeController.text.trim(),
        phone: _phoneController.text.trim(),
        icon: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Address' : 'Add New Address')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // audit batch 4 (Agent I): onUserInteraction so the user sees
          // pincode/phone errors as soon as they type, not only on submit.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Label type chips
              const Text('Address Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: _iconOptions.map((ic) {
                  final label = ic == 'home' ? 'Home' : ic == 'work' ? 'Office' : 'Family';
                  final iconData = ic == 'home' ? Icons.home_outlined : ic == 'work' ? Icons.business_outlined : Icons.family_restroom_outlined;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconData, size: 16, color: _icon == ic ? HousepitalColors.orange : HousepitalColors.grey),
                          const SizedBox(width: 4),
                          Text(label),
                        ],
                      ),
                      selected: _icon == ic,
                      selectedColor: HousepitalColors.orangeLight,
                      onSelected: (_) => setState(() {
                        _icon = ic;
                        if (_labelController.text.isEmpty || ['Home', 'Office', 'Family'].contains(_labelController.text)) {
                          _labelController.text = label;
                        }
                      }),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label (e.g. Home, Office)'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Contact Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _flatController,
                decoration: const InputDecoration(labelText: 'Flat / House No. / Building'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Street / Area / Colony'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _city,
                decoration: const InputDecoration(labelText: 'City'),
                items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { if (v != null) setState(() => _city = v); },
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _pincodeController,
                decoration: const InputDecoration(labelText: 'Pincode'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                // audit batch 4 (Agent I): centralized pincode validator.
                validator: Validators.pincode,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                // audit batch 4 (Agent I): was length < 10 (accepted 5-digit
                // garbage, landlines). Now enforces TRAI 6-9 prefix via
                // Validators.indianMobile.
                validator: Validators.indianMobile,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(isEdit ? 'Update Address' : 'Save Address'),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
