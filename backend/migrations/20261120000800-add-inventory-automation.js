'use strict';
module.exports={async up(q,S){const D=S.DataTypes;
await q.addColumn('branches','inventory_auto_deduct',{type:D.BOOLEAN,allowNull:false,defaultValue:false});
await q.addColumn('orders','inventory_deducted_at',{type:D.DATE,allowNull:true});
},async down(q){await q.removeColumn('branch_stock','reorder_level');await q.removeColumn('orders','inventory_deducted_at');await q.removeColumn('branches','inventory_auto_deduct');}};