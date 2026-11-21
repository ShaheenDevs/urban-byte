'use strict';
module.exports={async up(q,S){
 await q.createTable('expenses',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 created_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},approved_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:true},
 category:{type:S.STRING(80),allowNull:false},description:{type:S.STRING(500),allowNull:false},
 amount:{type:S.DECIMAL(12,2),allowNull:false},payment_method:{type:S.ENUM('cash','card','bank_transfer','easypaisa','jazzcash'),allowNull:false},
 reference:{type:S.STRING(120),allowNull:true},expense_date:{type:S.DATEONLY,allowNull:false},
 status:{type:S.ENUM('pending','approved','rejected'),allowNull:false,defaultValue:'pending'},
 approved_at:{type:S.DATE,allowNull:true},rejection_reason:{type:S.STRING(500),allowNull:true},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('expenses',['restaurant_id','branch_id','expense_date']);
 await q.addIndex('expenses',['restaurant_id','status']);
},async down(q){await q.dropTable('expenses');}};