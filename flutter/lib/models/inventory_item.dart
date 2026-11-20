class InventoryItem {
  const InventoryItem({required this.id, required this.name, required this.itemType, required this.unit, this.sku});
  final String id;
  final String name;
  final String itemType;
  final String unit;
  final String? sku;
  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: '${json['id']}', name: json['name'] as String? ?? 'Unnamed item',
    itemType: json['itemType'] as String? ?? 'ingredient',
    unit: json['baseUnit'] as String? ?? '', sku: json['sku'] as String?,
  );
}
class BranchStockEntry {
  const BranchStockEntry({required this.item, required this.quantity, required this.reorderLevel, required this.lowStock});
  final InventoryItem item;
  final double quantity;
  final double reorderLevel;
  final bool lowStock;
  factory BranchStockEntry.fromJson(Map<String, dynamic> json) {
    final itemJson = json['item'] as Map<String, dynamic>? ?? const {};
    final stockJson = json['stock'] as Map<String, dynamic>? ?? const {};
    return BranchStockEntry(
      item: InventoryItem.fromJson(itemJson),
      quantity: double.tryParse('${stockJson['quantity']}') ?? 0,
      reorderLevel: double.tryParse('${stockJson['reorderLevel']}') ?? 0,
      lowStock: json['lowStock'] == true,
    );
  }
}
