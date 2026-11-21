'use strict';
module.exports=(s,D)=>s.define('PurchasePayment',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},
 purchaseId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'purchase_id'},
 supplierId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'supplier_id'},
 amount:{type:D.DECIMAL(12,2),allowNull:false},
 method:{type:D.ENUM('cash','bank_transfer','easypaisa','jazzcash','card'),allowNull:false},
 reference:{type:D.STRING(120),allowNull:true},
 notes:{type:D.STRING(500),allowNull:true},
 recordedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'recorded_by_user_id'}
},{tableName:'purchase_payments',underscored:true});