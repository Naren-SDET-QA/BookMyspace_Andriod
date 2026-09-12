import 'package:bookmyspace/features/location/domain/pin_code_location.dart';
import 'package:bookmyspace/features/location/infrastructure/india_post_pin_code_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateIndianPin', () {
    test('rejects empty and non 6-digit values', () {
      expect(validateIndianPin(''), isNotNull);
      expect(validateIndianPin('12345'), isNotNull);
      expect(validateIndianPin('012345'), isNotNull);
      expect(validateIndianPin('500081'), isNull);
    });
  });

  group('IndiaPostPinCodeRepository parsing', () {
    test('parses a successful India Post payload', () {
      final result = IndiaPostPinCodeRepository.parseIndiaPostBody(
        [
          {
            'Message': 'Number of pincode(s) found:1',
            'Status': 'Success',
            'PostOffice': [
              {
                'Name': 'Madhapur',
                'District': 'Hyderabad',
                'Block': 'Serilingampally',
                'State': 'Telangana',
                'Pincode': '500081',
              },
            ],
          },
        ],
        '500081',
      );
      expect(result.status, PinLookupStatus.success);
      expect(result.offices, isNotEmpty);
      expect(result.offices.first.city, 'Madhapur');
      expect(result.offices.first.district, 'Hyderabad');
      expect(result.offices.first.state, 'Telangana');
      expect(
        result.offices.first.hierarchy.map((item) => item.$1).toList(),
        containsAll(['State', 'District', 'Mandal / Taluk', 'City / Area', 'PIN']),
      );
    });

    test('returns empty when the PIN has no offices', () {
      final result = IndiaPostPinCodeRepository.parseIndiaPostBody(
        [
          {
            'Message': 'No records',
            'Status': 'Error',
            'PostOffice': null,
          },
        ],
        '111111',
      );
      expect(result.status, PinLookupStatus.empty);
    });

    test('returns error for unexpected payloads', () {
      final result = IndiaPostPinCodeRepository.parseIndiaPostBody(
        {'bad': true},
        '500081',
      );
      expect(result.status, PinLookupStatus.error);
    });

    test('edge function payload maps offices', () {
      final result = IndiaPostPinCodeRepository.parseLookupPayload(
        {
          'status': 'success',
          'offices': [
            {
              'name': 'Banjara Hills',
              'district': 'Hyderabad',
              'state': 'Telangana',
              'pincode': '500034',
            },
          ],
        },
        '500034',
      );
      expect(result.isSuccess, isTrue);
      expect(result.offices.first.displayLabel, contains('Banjara Hills'));
    });
  });
}
