'use strict';
module.exports=(s,D)=>s.define('CashShiftEntry',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 shiftId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'shift_id'},
 entryType:{type:D.ENUM('cash_in','cash_out','expense'),allowNull:false,field:'entry_type'},
 amount:{type:D.DECIMAL(12,2),allowNull:false},description:{type:D.STRING(250),allowNull:false},
 reference:{type:D.STRING(100),allowNull:true},recordedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'recorded_by_user_id'}
},{tableName:'cash_shift_entries',underscored:true});