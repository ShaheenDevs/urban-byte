'use strict';

module.exports = (sequelize, DataTypes) => sequelize.define('RestaurantSetting', {
  id: { type: DataTypes.BIGINT.UNSIGNED, primaryKey: true, autoIncrement: true },
  restaurantId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: false, unique: true, field: 'restaurant_id' },
  defaultDeliveryUserId: { type: DataTypes.BIGINT.UNSIGNED, allowNull: true, field: 'default_delivery_user_id' },
  taxEnabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false, field: 'tax_enabled' },
  taxRate: { type: DataTypes.DECIMAL(7, 4), allowNull: false, defaultValue: 0, field: 'tax_rate' },
  taxInclusive: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false, field: 'tax_inclusive' },
  serviceChargeEnabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false, field: 'service_charge_enabled' },
  serviceChargeRate: { type: DataTypes.DECIMAL(7, 4), allowNull: false, defaultValue: 0, field: 'service_charge_rate' },
  discountEnabled: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true, field: 'discount_enabled' },
  maxDiscountPercent: { type: DataTypes.DECIMAL(7, 4), allowNull: false, defaultValue: 20, field: 'max_discount_percent' },
  receiptHeader: { type: DataTypes.STRING(250), allowNull: true, field: 'receipt_header' },
  receiptFooter: { type: DataTypes.STRING(500), allowNull: true, field: 'receipt_footer' },
  diningTables: { type: DataTypes.JSON, allowNull: false, defaultValue: [], field: 'dining_tables' },
  orderTypes: { type: DataTypes.JSON, allowNull: false, defaultValue: [{ key: 'dine_in', name: 'Dine In' }, { key: 'takeaway', name: 'Takeaway' }, { key: 'delivery', name: 'Delivery' }], field: 'order_types' },
  kitchenPrintGroups: { type: DataTypes.JSON, allowNull: true, field: 'kitchen_print_groups' },
}, { tableName: 'restaurant_settings', underscored: true });
