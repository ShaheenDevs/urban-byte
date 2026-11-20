'use strict';
function error(message,status=409,code='INVALID_ORDER_TRANSITION'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
const transitions={placed:['confirmed','cancelled'],confirmed:['preparing','cancelled'],preparing:['ready'],ready:['out_for_delivery','completed'],out_for_delivery:['completed'],completed:[],cancelled:[]};
function validateTransition(from,to){if(!transitions[from]?.includes(to))throw error('Order cannot move from '+from+' to '+to+'.');}
module.exports={transitions,validateTransition};