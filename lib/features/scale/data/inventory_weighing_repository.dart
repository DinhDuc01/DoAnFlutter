import '../../products/data/product_variant_api.dart';

abstract class InventoryWeighingRepository {
  Future<List<ProductVariantStock>> loadProductsInStock();
}

/// Loads only product variants that currently have available warehouse stock.
class ApiInventoryWeighingRepository implements InventoryWeighingRepository {
  ApiInventoryWeighingRepository({ProductVariantApi? productApi})
      : _productApi = productApi ?? ProductVariantApi();

  final ProductVariantApi _productApi;

  @override
  Future<List<ProductVariantStock>> loadProductsInStock() async {
    final products = await _productApi.activeVariantsWithStock();
    return products.where((product) => product.quantityAvailable > 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
