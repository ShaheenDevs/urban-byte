import 'package:flutter_test/flutter_test.dart';
import 'package:urban_byte/models/inventory_item.dart';

void main() {
  group('InventoryItem', () {
    test('parses API item fields including decimal-safe base unit', () {
      final item = InventoryItem.fromJson({
        'id': 12,
        'name': 'Chicken Breast',
        'itemType': 'ingredient',
        'baseUnit': 'g',
        'sku': 'CHK-01',
      });
      expect(item.id, '12');
      expect(item.name, 'Chicken Breast');
      expect(item.itemType, 'ingredient');
      expect(item.unit, 'g');
      expect(item.sku, 'CHK-01');
    });
  });

  group('BranchStockEntry', () {
    test('parses nested stock and low stock flag', () {
      final entry = BranchStockEntry.fromJson({
        'item': {
          'id': 5,
          'name': 'Cheese',
          'itemType': 'ingredient',
          'baseUnit': 'g'
        },
        'stock': {'quantity': '250.500', 'reorderLevel': '300.000'},
        'lowStock': true,
      });
      expect(entry.item.name, 'Cheese');
      expect(entry.quantity, 250.5);
      expect(entry.reorderLevel, 300);
      expect(entry.lowStock, isTrue);
    });

    test('uses safe defaults for missing nested values', () {
      final entry = BranchStockEntry.fromJson({});
      expect(entry.quantity, 0);
      expect(entry.reorderLevel, 0);
      expect(entry.lowStock, isFalse);
    });
  });

  test('parses branch identifiers returned as integers', () {
    final branch =
        RestaurantBranch.fromJson({'id': 3, 'name': 'Shahkot', 'code': 'SHK'});
    expect(branch.id, '3');
    expect(branch.name, 'Shahkot');
  });
}
