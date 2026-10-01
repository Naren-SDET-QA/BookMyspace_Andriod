import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyspace/features/cms/domain/catalog_content.dart';
import 'package:bookmyspace/features/cms/domain/cms_localized_text.dart';
import 'package:bookmyspace/features/cms/presentation/owner_facility_controller.dart';
import 'package:bookmyspace/features/venue_sections/domain/venue_section.dart';
import 'package:bookmyspace/features/venue_sections/domain/venue_section_repository.dart';

const type =
    VenueSectionType(id: 'type', key: 'owner_facilities', name: 'Facilities');
const facility = CatalogFacilityType(
    key: 'my-space', title: CmsLocalizedText(base: 'My space'));

class FakeSections implements VenueSectionRepository {
  VenueSection? row;
  bool fail = false;
  bool loseInsertResponse = false;
  int inserts = 0;
  int publishes = 0;
  @override
  Future<List<VenueSectionType>> sectionTypes() async => [type];
  @override
  Future<List<VenueSection>> ownerVenueSections(String venueId) async =>
      [if (row != null) row!];
  @override
  Future<VenueSection> addSection(
      {required String venueId, required VenueSectionType type}) async {
    inserts++;
    row = VenueSection(
        id: 'row', venueId: venueId, sectionTypeId: type.id, type: type);
    if (loseInsertResponse) {
      loseInsertResponse = false;
      throw Exception('offline');
    }
    return row!;
  }

  @override
  Future<VenueSection> updateSection(VenueSection section) async {
    if (fail) throw Exception('offline');
    return row = section;
  }

  @override
  Future<Map<String, dynamic>> publish(String venueId) async {
    publishes++;
    if (fail) throw Exception('denied');
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> publishSection(
          String venueId, String sectionId) =>
      publish(venueId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('invalid names block persistence without losing the working copy',
      () async {
    final repo = FakeSections();
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(const CatalogContent([CatalogFacilityType(key: 'empty')]));
    expect(await c.save(), false);
    expect(repo.inserts, 0);
    expect(c.dirty, true);
    expect(c.error, 'Enter a title.');
  });
  test('successful publication saves the current draft first', () async {
    final repo = FakeSections();
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(const CatalogContent([facility]));
    expect(await c.publish(), true);
    expect(repo.row!.content, 'My space');
    expect(repo.publishes, 1);
    expect(c.dirty, false);
  });
  test('disabling every facility hides the section without deleting its draft',
      () async {
    final repo = FakeSections();
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(CatalogContent([facility.copyWith(enabled: false)]));
    expect(await c.save(), true);
    expect(repo.row!.isEnabled, false);
    expect(repo.row!.content, isEmpty);
    expect(repo.row!.config['facility_types'], hasLength(1));
  });
  test('empty owner draft never imports global catalog defaults', () async {
    final c = OwnerFacilityController(FakeSections(), 'venue');
    await c.load();
    expect(c.content.facilityTypes, isEmpty);
  });
  test('failed save keeps edits and retry saves the full hierarchy', () async {
    final repo = FakeSections();
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(const CatalogContent([facility]));
    repo.fail = true;
    expect(await c.save(), false);
    expect(c.dirty, true);
    expect(c.content.facilityTypes.single.title.base, 'My space');
    repo.fail = false;
    expect(await c.save(), true);
    expect(c.dirty, false);
    final reopened = OwnerFacilityController(repo, 'venue');
    await reopened.load();
    expect(reopened.content.facilityTypes.length, 1);
    expect(reopened.content.facilityTypes.single.key, 'my-space');
  });
  test('lost insert response does not create another container on retry',
      () async {
    final repo = FakeSections()..loseInsertResponse = true;
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(const CatalogContent([facility]));
    expect(await c.save(), false);
    expect(await c.save(), true);
    expect(repo.inserts, 1);
  });
  test('publishing never runs after save failure and denial is not success',
      () async {
    final repo = FakeSections();
    final c = OwnerFacilityController(repo, 'venue');
    await c.load();
    c.edit(const CatalogContent([facility]));
    repo.fail = true;
    expect(await c.publish(), false);
    expect(repo.publishes, 0);
    repo.fail = false;
    await c.save();
    repo.fail = true;
    expect(await c.publish(), false);
    expect(c.error, isNotNull);
  });
  test('disabled descendants are absent from published summary', () {
    final c = OwnerFacilityController(FakeSections(), 'venue');
    c.edit(CatalogContent([
      facility.copyWith(sections: [
        const CatalogSection(
            key: 'on',
            title: CmsLocalizedText(base: 'Visible'),
            subsections: [
              CatalogSubsection(
                  key: 'off',
                  title: CmsLocalizedText(base: 'Hidden'),
                  enabled: false),
            ]),
      ])
    ]));
    expect(c.summary, contains('Visible'));
    expect(c.summary, isNot(contains('Hidden')));
  });
}
