// test/providers/my_care_provider_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/providers/my_care_provider.dart';
import 'package:housepital_patient/models/my_care_models.dart';

import 'mock_api_service.dart';

// ── Fixture helpers ──────────────────────────────────────────────────────────

ActiveService _makeService({String id = 's1', String name = 'Care Package'}) {
  return ActiveService(
    id: id,
    name: name,
    serviceCategory: 'care_package',
    status: 'active',
    startDate: DateTime(2025, 1, 1),
    totalDays: 30,
    consumedDays: 10,
    deploymentIds: ['d1'],
  );
}

HealthManager _makeHealthManager() {
  return HealthManager(
    id: 'hm1',
    staffId: 'staff1',
    name: 'Dr. Priya',
    phone: '+919999999999',
    availableFrom: '08:00',
    availableTo: '20:00',
  );
}

ServiceDetail _makeServiceDetail() {
  return ServiceDetail(service: _makeService());
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockApiService mock;
  late MyCareProvider provider;

  setUp(() {
    mock = MockApiService();
    provider = MyCareProvider(mock);
  });

  group('MyCareProvider — loadMyCareData', () {
    test('success: sets activeServices and healthManager, clears error, sets lastFetchedAt',
        () async {
      mock.activeServicesResult = [_makeService()];
      mock.healthManagerResult = _makeHealthManager();

      await provider.loadMyCareData('patient1');

      expect(provider.activeServices, hasLength(1));
      expect(provider.activeServices.first.id, 's1');
      expect(provider.healthManager, isNotNull);
      expect(provider.healthManager!.name, 'Dr. Priya');
      expect(provider.error, isNull);
      expect(provider.isStale, isFalse);
    });

    test('success with no health manager: healthManager is null', () async {
      mock.activeServicesResult = [_makeService()];
      mock.healthManagerResult = null;

      await provider.loadMyCareData('patient1');

      expect(provider.activeServices, hasLength(1));
      expect(provider.healthManager, isNull);
      expect(provider.error, isNull);
    });

    test('ApiException: sets error message, activeServices stays empty', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Unauthorized';

      await provider.loadMyCareData('patient1');

      expect(provider.error, 'Unauthorized');
      expect(provider.activeServices, isEmpty);
      expect(provider.healthManager, isNull);
    });

    test('generic error: sets "Failed to load care data"', () async {
      mock.shouldThrowGenericError = true;

      await provider.loadMyCareData('patient1');

      expect(provider.error, 'Failed to load care data');
      expect(provider.activeServices, isEmpty);
    });

    test('isLoading is true during load and false after', () async {
      final loadingStates = <bool>[];

      // Listen for changes
      provider.addListener(() => loadingStates.add(provider.isLoading));

      mock.activeServicesResult = [_makeService()];
      await provider.loadMyCareData('patient1');

      // First notification: isLoading = true; second: isLoading = false
      expect(loadingStates, containsAllInOrder([true, false]));
      expect(provider.isLoading, isFalse);
    });

    test('isLoading is false after error', () async {
      mock.shouldThrowApiException = true;
      await provider.loadMyCareData('patient1');

      expect(provider.isLoading, isFalse);
    });

    test('error is cleared on subsequent successful load', () async {
      mock.shouldThrowApiException = true;
      await provider.loadMyCareData('patient1');
      expect(provider.error, isNotNull);

      mock.shouldThrowApiException = false;
      mock.activeServicesResult = [_makeService()];
      await provider.loadMyCareData('patient1');

      expect(provider.error, isNull);
    });
  });

  group('MyCareProvider — loadServiceDetail', () {
    test('success: sets selectedServiceDetail', () async {
      mock.serviceDetailResult = _makeServiceDetail();

      await provider.loadServiceDetail('d1');

      expect(provider.selectedServiceDetail, isNotNull);
      expect(provider.selectedServiceDetail!.service.id, 's1');
      expect(provider.detailError, isNull);
    });

    test('ApiException: sets detailError, selectedServiceDetail stays null', () async {
      mock.shouldThrowApiException = true;
      mock.apiExceptionMessage = 'Not found';

      await provider.loadServiceDetail('d99');

      expect(provider.detailError, 'Not found');
      expect(provider.selectedServiceDetail, isNull);
    });

    test('generic error: sets "Failed to load service detail"', () async {
      mock.shouldThrowGenericError = true;

      await provider.loadServiceDetail('d1');

      expect(provider.detailError, 'Failed to load service detail');
      expect(provider.selectedServiceDetail, isNull);
    });

    test('isDetailLoading is true during load and false after success', () async {
      final loadingStates = <bool>[];
      provider.addListener(() => loadingStates.add(provider.isDetailLoading));

      mock.serviceDetailResult = _makeServiceDetail();
      await provider.loadServiceDetail('d1');

      expect(loadingStates, containsAllInOrder([true, false]));
      expect(provider.isDetailLoading, isFalse);
    });

    test('isDetailLoading is false after error', () async {
      mock.shouldThrowApiException = true;
      await provider.loadServiceDetail('d1');

      expect(provider.isDetailLoading, isFalse);
    });

    test('clears previous selectedServiceDetail before loading new one', () async {
      // First load succeeds
      mock.serviceDetailResult = _makeServiceDetail();
      await provider.loadServiceDetail('d1');
      expect(provider.selectedServiceDetail, isNotNull);

      // Second load fails — selectedServiceDetail should be null while loading
      mock.serviceDetailResult = null;
      mock.shouldThrowApiException = true;
      await provider.loadServiceDetail('d2');

      expect(provider.selectedServiceDetail, isNull);
    });
  });

  group('MyCareProvider — computed properties', () {
    test('isStale is true initially (no data loaded yet)', () {
      expect(provider.isStale, isTrue);
    });

    test('isStale is false immediately after a successful load', () async {
      mock.activeServicesResult = [_makeService()];
      await provider.loadMyCareData('patient1');

      expect(provider.isStale, isFalse);
    });

    test('hasActiveServices is false initially', () {
      expect(provider.hasActiveServices, isFalse);
    });

    test('hasActiveServices is true after load with services', () async {
      mock.activeServicesResult = [_makeService()];
      await provider.loadMyCareData('patient1');

      expect(provider.hasActiveServices, isTrue);
    });

    test('hasActiveServices is false after load with empty list', () async {
      mock.activeServicesResult = [];
      await provider.loadMyCareData('patient1');

      expect(provider.hasActiveServices, isFalse);
    });
  });

  group('MyCareProvider — refresh', () {
    test('refresh delegates to loadMyCareData (call count increments)', () async {
      mock.activeServicesResult = [_makeService()];

      await provider.refresh('patient1');

      // getActiveServices + getHealthManager should each have been called once
      expect(mock.getActiveServicesCalls, 1);
      expect(mock.getHealthManagerCalls, 1);
    });

    test('refresh re-fetches data on each call', () async {
      mock.activeServicesResult = [_makeService()];
      await provider.refresh('patient1');
      await provider.refresh('patient1');

      expect(mock.getActiveServicesCalls, 2);
    });

    test('refresh passes correct patientId to api', () async {
      mock.activeServicesResult = [];
      await provider.refresh('patient42');

      expect(mock.lastPatientId, 'patient42');
    });
  });
}
