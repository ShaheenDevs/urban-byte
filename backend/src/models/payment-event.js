'use strict';
module.exports=(s,D)=>s.define('PaymentEvent',{
 id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
 paymentId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'payment_id'},
 eventType:{type:D.STRING(40),allowNull:false,field:'event_type'},
 actorUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'actor_user_id'},
 notes:{type:D.STRING(500),allowNull:true}
},{tableName:'payment_events',underscored:true});