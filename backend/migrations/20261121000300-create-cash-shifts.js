'use strict';
module.exports={async up(q,S){
 await q.createTable('cash_shifts',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 opened_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},closed_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:true},
 opening_cash:{type:S.DECIMAL(12,2),allowNull:false},expected_cash:{type:S.DECIMAL(12,2),allowNull:true},
 actual_cash:{type:S.DECIMAL(12,2),allowNull:true},cash_variance:{type:S.DECIMAL(12,2),allowNull:true},
 status:{type:S.ENUM('open','closed'),allowNull:false,defaultValue:'open'},
 opened_at:{type:S.DATE,allowNull:false},closed_at:{type:S.DATE,allowNull:true},
 closing_notes:{type:S.STRING(500),allowNull:true},created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('cash_shifts',['restaurant_id','branch_id','status']);
 await q.addIndex('cash_shifts',['opened_by_user_id','status']);
 await q.createTable('cash_shift_entries',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 shift_id:{type:S.BIGINT.UNSIGNED,allowNull:false},entry_type:{type:S.ENUM('cash_in','cash_out','expense'),allowNull:false},
 amount:{type:S.DECIMAL(12,2),allowNull:false},description:{type:S.STRING(250),allowNull:false},
 reference:{type:S.STRING(100),allowNull:true},recorded_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('cash_shift_entries',['shift_id','entry_type']);
},async down(q){await q.dropTable('cash_shift_entries');await q.dropTable('cash_shifts');}};