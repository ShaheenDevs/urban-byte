'use strict';
module.exports=(s,D)=>s.define('Payment',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},
 branchId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'branch_id'},
 orderId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'order_id'},
 method:{type:D.ENUM('cash','card','easypaisa','jazzcash','bank_transfer','cod'),allowNull:false},
 status:{type:D.ENUM('pending','verified','failed','refunded'),allowNull:false,defaultValue:'pending'},
 amount:{type:D.DECIMAL(12,2),allowNull:false},reference:{type:D.STRING(120),allowNull:true},
 recordedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'recorded_by_user_id'},
 verifiedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:true,field:'verified_by_user_id'},
 verifiedAt:{type:D.DATE,allowNull:true,field:'verified_at'},notes:{type:D.STRING(500),allowNull:true}
},{tableName:'payments',underscored:true});