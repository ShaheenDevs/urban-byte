'use strict';
module.exports=(s,D)=>s.define('PrintJob',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},branchId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'branch_id'},
 printerId:{type:D.BIGINT.UNSIGNED,allowNull:true,field:'printer_id'},orderId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'order_id'},
 jobType:{type:D.ENUM('receipt','kitchen_ticket'),allowNull:false,field:'job_type'},
 status:{type:D.ENUM('queued','printing','printed','failed'),allowNull:false,defaultValue:'queued'},
 payload:{type:D.JSON,allowNull:false},renderedText:{type:D.TEXT,allowNull:false,field:'rendered_text'},
 attempts:{type:D.INTEGER.UNSIGNED,allowNull:false,defaultValue:0},lastError:{type:D.STRING(500),allowNull:true,field:'last_error'},
 requestedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'requested_by_user_id'},printedAt:{type:D.DATE,allowNull:true,field:'printed_at'}
},{tableName:'print_jobs',underscored:true});