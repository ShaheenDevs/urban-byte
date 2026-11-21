'use strict';
module.exports=(s,D)=>s.define('Expense',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},
 branchId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'branch_id'},
 createdByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'created_by_user_id'},
 approvedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:true,field:'approved_by_user_id'},
 category:{type:D.STRING(80),allowNull:false},
 description:{type:D.STRING(500),allowNull:false},
 amount:{type:D.DECIMAL(12,2),allowNull:false},
 paymentMethod:{type:D.ENUM('cash','card','bank_transfer','easypaisa','jazzcash'),allowNull:false,field:'payment_method'},
 reference:{type:D.STRING(120),allowNull:true},
 expenseDate:{type:D.DATEONLY,allowNull:false,field:'expense_date'},
 status:{type:D.ENUM('pending','approved','rejected'),allowNull:false,defaultValue:'pending'},
 approvedAt:{type:D.DATE,allowNull:true,field:'approved_at'},
 rejectionReason:{type:D.STRING(500),allowNull:true,field:'rejection_reason'}
},{tableName:'expenses',underscored:true});