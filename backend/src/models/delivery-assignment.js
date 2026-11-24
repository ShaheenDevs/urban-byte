'use strict';
module.exports=(s,D)=>{
 const M=s.define('DeliveryAssignment',{
  id:{type:D.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true},
  restaurantId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'restaurant_id'},
  branchId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'branch_id'},
  orderId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'order_id'},
  deliveryUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'delivery_user_id'},
  assignedByUserId:{type:D.BIGINT.UNSIGNED,allowNull:false,field:'assigned_by_user_id'},
  status:{type:D.ENUM('assigned','picked_up','out_for_delivery','delivered','cancelled'),allowNull:false,defaultValue:'assigned'},
  assignedAt:{type:D.DATE,allowNull:false,field:'assigned_at'},pickedUpAt:{type:D.DATE,allowNull:true,field:'picked_up_at'},
  outForDeliveryAt:{type:D.DATE,allowNull:true,field:'out_for_delivery_at'},deliveredAt:{type:D.DATE,allowNull:true,field:'delivered_at'},
  codAmount:{type:D.DECIMAL(12,2),allowNull:false,defaultValue:0,field:'cod_amount'},
  codCollected:{type:D.BOOLEAN,allowNull:false,defaultValue:false,field:'cod_collected'},
  codCollectedAt:{type:D.DATE,allowNull:true,field:'cod_collected_at'},codSettlementId:{type:D.BIGINT.UNSIGNED,allowNull:true,field:'cod_settlement_id'},deliveryNote:{type:D.STRING(500),allowNull:true,field:'delivery_note'}
 },{tableName:'delivery_assignments',underscored:true});
 M.associate=models=>{M.belongsTo(models.Order,{foreignKey:'orderId',as:'order'});M.belongsTo(models.User,{foreignKey:'deliveryUserId',as:'deliveryUser'});M.belongsTo(models.User,{foreignKey:'assignedByUserId',as:'assignedBy'});M.belongsTo(models.DeliveryCashSettlement,{foreignKey:'codSettlementId',as:'codSettlement'});};
 return M;
};