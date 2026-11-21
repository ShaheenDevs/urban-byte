'use strict';
module.exports={async up(q,S){
 await q.createTable('purchase_payments',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 purchase_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 supplier_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 amount:{type:S.DECIMAL(12,2),allowNull:false},
 method:{type:S.ENUM('cash','bank_transfer','easypaisa','jazzcash','card'),allowNull:false},
 reference:{type:S.STRING(120),allowNull:true},notes:{type:S.STRING(500),allowNull:true},
 recorded_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('purchase_payments',['restaurant_id','supplier_id','created_at']);
 await q.addIndex('purchase_payments',['purchase_id']);
},async down(q){await q.dropTable('purchase_payments');}};