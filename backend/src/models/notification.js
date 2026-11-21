'use strict';
module.exports=(s,D)=>s.define('Notification',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},
 userId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'user_id'},
 type:{type:D.STRING(80),allowNull:false},
 title:{type:D.STRING(180),allowNull:false},
 body:{type:D.STRING(1000),allowNull:false},
 data:{type:D.JSON,allowNull:false,defaultValue:{}},
 readAt:{type:D.DATE,allowNull:true,field:'read_at'}
},{tableName:'notifications',underscored:true});
