'use strict';
module.exports={async up(q,S){
 await q.createTable('payments',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},order_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 method:{type:S.ENUM('cash','card','easypaisa','jazzcash','bank_transfer','cod'),allowNull:false},
 status:{type:S.ENUM('pending','verified','failed','refunded'),allowNull:false,defaultValue:'pending'},
 amount:{type:S.DECIMAL(12,2),allowNull:false},reference:{type:S.STRING(120),allowNull:true},
 recorded_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},verified_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:true},
 verified_at:{type:S.DATE,allowNull:true},notes:{type:S.STRING(500),allowNull:true},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('payments',['restaurant_id','order_id']);
 await q.addIndex('payments',['restaurant_id','branch_id','status']);
 await q.createTable('payment_events',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 payment_id:{type:S.BIGINT.UNSIGNED,allowNull:false},event_type:{type:S.STRING(40),allowNull:false},
 actor_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},notes:{type:S.STRING(500),allowNull:true},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
},async down(q){await q.dropTable('payment_events');await q.dropTable('payments');}};