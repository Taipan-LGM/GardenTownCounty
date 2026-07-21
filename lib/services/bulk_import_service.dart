import '../core/exceptions/duplicate_exception.dart';
import '../models/member.dart';
import 'database_service.dart';
import 'member_duplicate_service.dart';
import 'sa_id_validator.dart';

class ImportError {
  const ImportError({
    required this.row,
    required this.field,
    required this.message,
  });

  final int row;
  final String field;
  final String message;
}

class ImportResult {
  const ImportResult({
    required this.total,
    required this.saved,
    required this.errors,
  });

  final int total;
  final int saved;
  final List<ImportError> errors;

  bool get hasErrors => errors.isNotEmpty;
}

/// Bulk member import with duplicate checking (file + DB).
class BulkImportService {
  BulkImportService(this._db, this._duplicates);

  final DatabaseService _db;
  final MemberDuplicateService _duplicates;

  Future<ImportResult> importMembers(List<Map<String, dynamic>> data) async {
    final validMembers = <Member>[];
    final errors = <ImportError>[];
    final processedSaIds = <String>{};
    final processedGlobalRecords = <String>{};

    for (var i = 0; i < data.length; i++) {
      final item = data[i];
      final rowNumber = i + 2; // 1-based; header is row 1

      try {
        final saId = item['saId']?.toString().trim() ?? '';
        final saErr = SaIdValidator.validate(saId);
        if (saErr != null) {
          errors.add(ImportError(row: rowNumber, field: 'saId', message: saErr));
          continue;
        }

        final globalRecord = item['globalRecordNo']?.toString().trim() ?? '';
        final grErr = GlobalRecordValidator.validate(globalRecord);
        if (grErr != null) {
          errors.add(
            ImportError(row: rowNumber, field: 'globalRecordNo', message: grErr),
          );
          continue;
        }

        if (processedSaIds.contains(saId)) {
          errors.add(
            ImportError(
              row: rowNumber,
              field: 'saId',
              message: 'Duplicate SA ID in import file',
            ),
          );
          continue;
        }
        if (processedGlobalRecords.contains(globalRecord)) {
          errors.add(
            ImportError(
              row: rowNumber,
              field: 'globalRecordNo',
              message: 'Duplicate Global Record in import file',
            ),
          );
          continue;
        }

        if (await _db.checkSaIdExists(saId)) {
          errors.add(
            ImportError(
              row: rowNumber,
              field: 'saId',
              message: 'SA ID already exists in database',
            ),
          );
          continue;
        }
        if (await _db.checkGlobalRecordExists(globalRecord)) {
          errors.add(
            ImportError(
              row: rowNumber,
              field: 'globalRecordNo',
              message: 'Global Record No. already exists in database',
            ),
          );
          continue;
        }

        final member = Member.create(
          saId: saId,
          globalRecordNo: globalRecord,
          memberName: item['memberName']?.toString().trim() ?? '',
          surname: item['surname']?.toString().trim() ?? '',
          address: item['address']?.toString().trim() ?? '',
          suburb: item['suburb']?.toString().trim() ?? '',
          townCity: item['townCity']?.toString().trim() ?? '',
          postalCode: item['postalCode']?.toString().trim() ?? '',
          contactNo1: item['contactNo1']?.toString().trim() ?? '',
          contactNo2: item['contactNo2']?.toString().trim() ?? '',
          emailAddress: item['emailAddress']?.toString().trim() ?? '',
          comment: item['comment']?.toString().trim() ?? '',
        );

        if (member.memberName.isEmpty || member.surname.isEmpty) {
          errors.add(
            ImportError(
              row: rowNumber,
              field: 'name',
              message: 'Member Name and Surname are required',
            ),
          );
          continue;
        }

        validMembers.add(member);
        processedSaIds.add(saId);
        processedGlobalRecords.add(globalRecord);
      } catch (e) {
        errors.add(
          ImportError(row: rowNumber, field: 'general', message: e.toString()),
        );
      }
    }

    var saved = 0;
    for (final member in validMembers) {
      try {
        await _duplicates.assertUnique(member);
        await _db.upsertMember(member);
        saved++;
      } on DuplicateException catch (e) {
        errors.add(
          ImportError(row: -1, field: e.field ?? 'database', message: e.message),
        );
      } catch (e) {
        errors.add(
          ImportError(row: -1, field: 'database', message: 'Failed to save: $e'),
        );
      }
    }

    return ImportResult(total: data.length, saved: saved, errors: errors);
  }
}
