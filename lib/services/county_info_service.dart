import '../models/county_info.dart';
import 'activity_service.dart';
import 'auth_service.dart';
import 'county_settings_service.dart';
import 'database_service.dart';

/// County identity updates + optional full operational reset for a new county.
///
/// // NEW ADDITION - Delete this file to revert County Information feature.
class CountyInfoService {
  CountyInfoService(
    this._db,
    this._activity,
    this._countySettings,
  );

  final DatabaseService _db;
  final ActivityService _activity;
  final CountySettingsService _countySettings;

  CountyInfo? _cached;

  void clearCache() => _cached = null;

  Future<CountyInfo> getCountyInfo() async {
    if (_cached != null) return _cached!;
    final existing = await _db.getCountyInfo();
    if (existing != null) {
      _cached = existing;
      return existing;
    }

    // Seed from branding prefs when present, else defaults.
    final profile = await _countySettings.load();
    final seeded = CountyInfo.defaults().copyWith(
      countyName: profile.countyName.trim().isEmpty
          ? 'Garden Town County'
          : profile.countyName.trim(),
      countyAddress: profile.countyAddress.trim().isEmpty
          ? CountyInfo.defaults().countyAddress
          : profile.countyAddress.trim(),
      countyRegistrationNo: profile.countyRegNo.trim().isEmpty
          ? CountyInfo.defaults().countyRegistrationNo
          : profile.countyRegNo.trim(),
      syncStatus: 'synced',
    );
    await _db.upsertCountyInfo(seeded);
    _cached = seeded;
    return seeded;
  }

  /// Update county fields. When [isNewCounty] is true and all three fields
  /// changed, clears operational data (keeps Admin account).
  Future<CountyInfo> updateCountyInfo({
    required String countyName,
    required String countyAddress,
    required String countyRegistrationNo,
    required AuthUser admin,
    bool isNewCounty = false,
  }) async {
    if (!admin.isAdmin) {
      throw Exception('Only Admin can update county information.');
    }

    final name = countyName.trim();
    final address = countyAddress.trim();
    final reg = countyRegistrationNo.trim();
    if (name.isEmpty || address.isEmpty || reg.isEmpty) {
      throw Exception('County Name, Address, and Registration No. are required.');
    }

    final current = await getCountyInfo();
    final allFieldsChanged = current.countyName.trim() != name &&
        current.countyAddress.trim() != address &&
        current.countyRegistrationNo.trim() != reg;

    var next = current.copyWith(
      countyName: name,
      countyAddress: address,
      countyRegistrationNo: reg,
      lastUpdated: DateTime.now().toUtc(),
      updatedBy: admin.id,
      syncStatus: 'pending',
    );

    if (allFieldsChanged && isNewCounty) {
      await _db.resetCountyOperationalData();
      next = next.copyWith(
        lastResetDate: DateTime.now().toUtc(),
        resetCount: current.resetCount + 1,
        resetBy: admin.id,
      );
      await _activity.record(
        userName: admin.displayName,
        action:
            'county_reset old="${current.countyName}" new="$name" by=${admin.id}',
        captureGps: false,
      );
    } else {
      await _activity.record(
        userName: admin.displayName,
        action: 'county_info_updated name="$name"',
        captureGps: false,
      );
    }

    await _db.upsertCountyInfo(next);
    _cached = next;

    // Keep SharedPreferences branding in sync (drawer / logos).
    final profile = await _countySettings.load();
    await _countySettings.save(
      profile.copyWith(
        countyName: next.countyName,
        countyAddress: next.countyAddress,
        countyRegNo: next.countyRegistrationNo,
      ),
    );

    return next;
  }
}
