'use strict';
module.exports=(s,D)=>s.define('PrinterDevice',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},branchId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'branch_id'},
 name:{type:D.STRING(120),allowNull:false},connectionType:{type:D.ENUM('network','usb','bluetooth','windows_bridge'),allowNull:false,field:'connection_type'},
 paperWidth:{type:D.ENUM('58mm','80mm'),allowNull:false,defaultValue:'80mm',field:'paper_width'},
 address:{type:D.STRING(255),allowNull:true},deviceIdentifier:{type:D.STRING(255),allowNull:true,field:'device_identifier'},
 purpose:{type:D.ENUM('receipt','kitchen','both'),allowNull:false,defaultValue:'both'},
 isActive:{type:D.BOOLEAN,allowNull:false,defaultValue:true,field:'is_active'}
},{tableName:'printer_devices',underscored:true});