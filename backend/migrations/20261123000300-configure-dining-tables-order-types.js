'use strict';
module.exports = {
 async up(queryInterface, Sequelize) {
  await queryInterface.addColumn('restaurant_settings','dining_tables',{type:Sequelize.JSON,allowNull:false,defaultValue:[]});
  await queryInterface.addColumn('restaurant_settings','order_types',{type:Sequelize.JSON,allowNull:false,defaultValue:[{key:'dine_in',name:'Dine In'},{key:'takeaway',name:'Takeaway'},{key:'delivery',name:'Delivery'}]});
  await queryInterface.changeColumn('orders','order_type',{type:Sequelize.STRING(40),allowNull:false});
 },
 async down(queryInterface, Sequelize) {
  await queryInterface.changeColumn('orders','order_type',{type:Sequelize.ENUM('dine_in','takeaway','delivery'),allowNull:false});
  await queryInterface.removeColumn('restaurant_settings','order_types');
  await queryInterface.removeColumn('restaurant_settings','dining_tables');
 }
};
