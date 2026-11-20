'use strict';
module.exports={
 async up(q,D){await q.addColumn('ai_approval_requests','order_id',{type:D.BIGINT.UNSIGNED,allowNull:true,references:{model:'orders',key:'id'},onDelete:'SET NULL'});},
 async down(q){await q.removeColumn('ai_approval_requests','order_id');}
};