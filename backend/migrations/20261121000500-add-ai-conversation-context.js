'use strict';
module.exports={
 async up(q,D){await q.addColumn('ai_conversations','context',{type:D.JSON,allowNull:false,defaultValue:{}});},
 async down(q){await q.removeColumn('ai_conversations','context');}
};