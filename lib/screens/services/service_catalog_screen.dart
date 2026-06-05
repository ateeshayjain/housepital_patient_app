// audit batch 4 (Agent K): split into tabs/, cards/, sheets/, widgets/, data/
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/app_localizations.dart';
import '../../utils/permissions.dart';
import 'data/catalog_seeds.dart';
import 'tabs/consultations_tab.dart';
import 'tabs/diagnostics_tab.dart';
import 'tabs/equipment_tab.dart';
import 'tabs/lab_tests_tab.dart';
import 'tabs/manpower_tab.dart';
import 'tabs/packages_tab.dart';
import 'widgets/permission_dialogs.dart';

// Re-export the shared role-gating helpers so existing imports of this file
// (which used to define them locally) keep working.
// audit batch 4 (Agent K): the canonical definitions live in
// `widgets/permission_dialogs.dart` — they're surfaced here for backwards
// compatibility because they were originally top-level in this file.
export 'widgets/permission_dialogs.dart' show showRequestBookingStub, showViewOnlyToast;

/// Top-level catalog screen — owns the AppBar, the 7-tab TabBar, search
/// state and the shared `_navigateToService` permission gate. Individual
/// tab content lives in `tabs/*.dart`.
class ServiceCatalogScreen extends StatefulWidget {
  const ServiceCatalogScreen({super.key});

  /// Global key to allow switching sub-tabs from anywhere (e.g. home screen).
  static final GlobalKey<_ServiceCatalogScreenState> catalogKey =
      GlobalKey<_ServiceCatalogScreenState>();

  /// Switch to a specific sub-tab by index.
  /// 0=Manpower, 1=Equipment, 2=Consultations, 3=Visits, 4=Diagnostics, 5=Lab Tests, 6=Packages
  static void switchToSubTab(int index) {
    catalogKey.currentState?.switchSubTab(index);
  }

  @override
  State<ServiceCatalogScreen> createState() => _ServiceCatalogScreenState();
}

class _ServiceCatalogScreenState extends State<ServiceCatalogScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  late final TabController _tabController;

  void switchSubTab(int index) {
    if (index >= 0 && index < _tabController.length) {
      _tabController.animateTo(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<ServiceItem> _filterBySearch(List<ServiceItem> services) {
    if (_searchQuery.isEmpty) return services;
    final q = _searchQuery.toLowerCase();
    return services.where((s) {
      return s.name.toLowerCase().contains(q) ||
          (s.nameHi?.toLowerCase().contains(q) ?? false) ||
          (s.description?.toLowerCase().contains(q) ?? false) ||
          (s.descriptionHi?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('book_services')),
        actions: [
          Consumer<CartProvider>(
            builder: (ctx, cart, _) {
              final count = cart.itemCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_outlined),
                    onPressed: () => Navigator.pushNamed(ctx, '/cart'),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: HousepitalColors.orange,
          unselectedLabelColor: HousepitalColors.greyLight,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: HousepitalColors.orange,
          indicatorWeight: 3,
          dividerColor: HousepitalColors.divider,
          tabs: const [
            Tab(text: 'Manpower'),
            Tab(text: 'Equipment'),
            Tab(text: 'Consultations'),
            Tab(text: 'Visits'),
            Tab(text: 'Diagnostics'),
            Tab(text: 'Lab Tests'),
            Tab(text: 'Packages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ManpowerTab(
            services: manpowerServices,
            iconMap: catalogIconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          const EquipmentTab(),
          ConsultationsTab(
            services: consultationServices,
            iconMap: catalogIconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          ConsultationsTab(
            services: visitServices,
            iconMap: catalogIconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          DiagnosticsTab(
            services: diagnosticServices,
            iconMap: catalogIconMap,
            searchQuery: _searchQuery,
            searchController: _searchController,
            searchFocusNode: _searchFocusNode,
            onSearchChanged: _onSearchChanged,
            filterBySearch: _filterBySearch,
            onNavigate: _navigateToService,
          ),
          LabTestsTab(
            packageServices: labServices,
            iconMap: catalogIconMap,
            onNavigateService: _navigateToService,
          ),
          const PackagesTab(),
        ],
      ),
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
  }

  void _navigateToService(BuildContext context, ServiceItem service) {
    // Permission gate — primary contacts go straight through; everyone else
    // either gets the "request booking" stub or a read-only nudge.
    final role = context.read<AppProvider>().currentUserRole;
    if (!canUserPerform(role, UserAction.book)) {
      if (canUserPerform(role, UserAction.requestBooking)) {
        showRequestBookingStub(context, service.name);
      } else {
        showViewOnlyToast(context);
      }
      return;
    }
    if (service.isInstant) {
      Navigator.pushNamed(context, '/service-booking', arguments: service);
    } else {
      Navigator.pushNamed(context, '/assessment-request', arguments: service);
    }
  }
}
