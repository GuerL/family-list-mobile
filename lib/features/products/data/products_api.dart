import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/app_logger.dart';
import '../../../core/network/dio_provider.dart';
import 'product_models.dart';

final productsApiProvider = Provider<ProductsApi>((ref) {
  return ProductsApi(ref.watch(dioProvider));
});

class ProductsApi {
  const ProductsApi(this._dio);

  final Dio _dio;

  Future<List<GlobalProductDto>> getGlobalProducts() async {
    appLogger.debug('Products: fetching /api/products');
    final response = await _dio.get<List<dynamic>>('/api/products');
    return _parseList(response.data, GlobalProductDto.fromJson);
  }

  Future<List<FamilyProductDto>> getFamilyProducts(int familyId) async {
    appLogger.debug('Products: fetching /api/family-products');
    final response = await _dio.get<List<dynamic>>(
      '/api/family-products',
      queryParameters: {'familyId': familyId},
    );
    return _parseList(response.data, FamilyProductDto.fromJson);
  }

  Future<List<ProductCategoryDto>> getProductCategories() async {
    appLogger.debug('Products: fetching /api/product-categories');
    final response = await _dio.get<List<dynamic>>('/api/product-categories');
    return _parseList(response.data, ProductCategoryDto.fromJson);
  }

  Future<FamilyProductDto> createFamilyProduct({
    required int familyId,
    required String label,
    String? description,
  }) async {
    appLogger.debug('Products: creating /api/family-products');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/family-products',
      data: {'familyId': familyId, 'label': label, 'description': description},
    );
    return FamilyProductDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<FamilyProductDto> updateFamilyProduct({
    required int id,
    required String label,
    String? description,
  }) async {
    appLogger.debug('Products: updating /api/family-products/$id');
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/family-products/$id',
      data: {'label': label, 'description': description},
    );
    return FamilyProductDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteFamilyProduct(int id) async {
    appLogger.debug('Products: deleting /api/family-products/$id');
    await _dio.delete<void>('/api/family-products/$id');
  }

  Future<GlobalProductDto> createGlobalProduct({
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    appLogger.debug('Products: creating /api/products');
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/products',
      data: {
        'label': label,
        'imageUrl': imageUrl,
        'productCategory': productCategory?.toJson(),
      },
    );
    return GlobalProductDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<GlobalProductDto> updateGlobalProduct({
    required int id,
    required String label,
    String? imageUrl,
    ProductCategoryDto? productCategory,
  }) async {
    appLogger.debug('Products: updating /api/products');
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/products',
      data: {
        'id': id,
        'label': label,
        'imageUrl': imageUrl,
        'productCategory': productCategory?.toJson(),
      },
    );
    return GlobalProductDto.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteGlobalProduct(int id) async {
    appLogger.debug('Products: deleting /api/products/$id');
    await _dio.delete<void>('/api/products/$id');
  }

  List<T> _parseList<T>(
    List<dynamic>? data,
    T Function(Map<String, dynamic>) parser,
  ) {
    final items = <T>[];
    for (final entry in data ?? const []) {
      if (entry is! Map<String, dynamic>) {
        appLogger.debug('Products: skipped unexpected payload entry');
        continue;
      }
      items.add(parser(entry));
    }
    return items;
  }
}
