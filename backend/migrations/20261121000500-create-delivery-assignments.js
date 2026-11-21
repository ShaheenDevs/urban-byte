'use strict';
module.exports={
 async up(q,S){
  await q.createTable('delivery_assignments',{
   id:{type:S.BIGINT.UNSIGNED,primaryKey:true,autoIncrement:true,allowNull:false},
   restaurant_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
   branch_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
   order_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
   delivery_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
   assigned_by_user_id:{type:S.BIGINT.UNSIGNED,allowNull:false},
   status:{type:S.ENUM('assigned','picked_up','out_for_delivery','delivered','cancelled'),allowNull:false,defaultValue:'assigned'},
   assigned_at:{type:S.DATE,allowNull:false},
   picked_up_at:{type:S.DATE,allowNull:true},
   out_for_delivery_at:{type:S.DATE,allowNull:true},
   delivered_at:{type:S.DATE,allowNull:true},
   cod_amount:{type:S.DECIMAL(12,2),allowNull:false,defaultValue:0},
   cod_collected:{type:S.BOOLEAN,allowNull:false,defaultValue:false},
   cod_collected_at:{type:S.DATE,allowNull:true},
   delivery_note:{type:S.STRING(500),allowNull:true},
   created_at:{type:S.DATE,allowNull:false},updated_at:{type:S.DATE,allowNull:false}
  });
  await q.addIndex('delivery_assignments',['restaurant_id','delivery_user_id','status']);
  await q.addIndex('delivery_assignments',['restaurant_id','order_id'],{unique:true});
 },
 async down(q){await q.dropTable('delivery_assignments');}
};