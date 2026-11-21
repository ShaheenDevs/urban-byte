'use strict';
module.exports={async up(q,S){
 await q.createTable('printer_devices',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 name:{type:S.STRING(120),allowNull:false},connection_type:{type:S.ENUM('network','usb','bluetooth','windows_bridge'),allowNull:false},
 paper_width:{type:S.ENUM('58mm','80mm'),allowNull:false,defaultValue:'80mm'},
 address:{type:S.STRING(255),allowNull:true},device_identifier:{type:S.STRING(255),allowNull:true},
 purpose:{type:S.ENUM('receipt','kitchen','both'),allowNull:false,defaultValue:'both'},
 is_active:{type:S.BOOLEAN,allowNull:false,defaultValue:true},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('printer_devices',['restaurant_id','branch_id','is_active']);
 await q.createTable('print_jobs',{
 id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
 restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 printer_id:{type:S.BIGINT.UNSIGNED,allowNull:true},order_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
 job_type:{type:S.ENUM('receipt','kitchen_ticket'),allowNull:false},
 status:{type:S.ENUM('queued','printing','printed','failed'),allowNull:false,defaultValue:'queued'},
 payload:{type:S.JSON,allowNull:false},rendered_text:{type:S.TEXT,allowNull:false},
 attempts:{type:S.INTEGER.UNSIGNED,allowNull:false,defaultValue:0},last_error:{type:S.STRING(500),allowNull:true},
 requested_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},printed_at:{type:S.DATE,allowNull:true},
 created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
 });
 await q.addIndex('print_jobs',['restaurant_id','branch_id','status']);
 await q.addIndex('print_jobs',['restaurant_id','order_id','job_type']);
},async down(q){await q.dropTable('print_jobs');await q.dropTable('printer_devices');}};