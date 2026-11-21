'use strict';
module.exports={
 async up(q,S){
  const D=S.DataTypes;
  await q.createTable('notifications',{
   id:{type:D.BIGINT.UNSIGNED,autoIncrement:true,primaryKey:true},
   restaurant_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'restaurants',key:'id'},onUpdate:'CASCADE',onDelete:'CASCADE'},
   user_id:{type:D.BIGINT.UNSIGNED,allowNull:false,references:{model:'users',key:'id'},onUpdate:'CASCADE',onDelete:'CASCADE'},
   type:{type:D.STRING(80),allowNull:false},
   title:{type:D.STRING(180),allowNull:false},
   body:{type:D.STRING(1000),allowNull:false},
   data:{type:D.JSON,allowNull:false,defaultValue:{}},
   read_at:{type:D.DATE,allowNull:true},
   created_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')},
   updated_at:{type:D.DATE,allowNull:false,defaultValue:S.literal('CURRENT_TIMESTAMP')}
  });
  await q.addIndex('notifications',['user_id','read_at','created_at'],{name:'ix_notifications_user_unread'});
  await q.addIndex('notifications',['restaurant_id','user_id','created_at'],{name:'ix_notifications_tenant_user'});
 },
 async down(q){await q.dropTable('notifications');}
};