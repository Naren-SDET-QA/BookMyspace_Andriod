import 'cms_media_asset.dart';

abstract interface class CmsMediaRepository {
  Future<List<CmsMediaAsset>> list({String query = '', int limit = 100});
  Future<CmsMediaAsset> upload(
      {required String name, required List<int> bytes});
  Future<void> delete(CmsMediaAsset asset);
}
