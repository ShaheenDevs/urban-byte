'use strict';
require('dotenv').config();
const bcrypt = require('bcryptjs');
const {
  sequelize, Restaurant, Branch, Role, Permission, MenuCategory, Product,
  ProductVariant, InventoryItem, Supplier, User
} = require('../src/models');

const PERMISSIONS = [
  ['Dashboard view','dashboard.view','dashboard'],
  ['Orders view','orders.view','orders'],['Orders manage','orders.manage','orders'],
  ['Menu view','menu.view','menu'],['Menu manage','menu.manage','menu'],
  ['Customers view','customers.view','customers'],['Customers manage','customers.manage','customers'],
  ['Payments view','payments.view','payments'],['Payments manage','payments.manage','payments'],
  ['Cash shifts view','cash_shifts.view','cash_shifts'],['Cash shifts manage','cash_shifts.manage','cash_shifts'],
  ['Expenses view','expenses.view','expenses'],['Expenses manage','expenses.manage','expenses'],
  ['Expenses approve','expenses.approve','expenses'],
  ['Inventory view','inventory.view','inventory'],['Inventory manage','inventory.manage','inventory'],
  ['Inventory adjust','inventory.adjust','inventory'],['Kitchen view','kitchen.view','kitchen'],
  ['Staff view','staff.view','staff'],['Staff manage','staff.manage','staff'],
  ['Settings manage','settings.manage','settings'],['Branches view','branches.view','branches'],
  ['Reports view','reports.view','reports'],['Printing manage','printing.manage','printing'],
  ['Delivery view','delivery.view','delivery'],['Delivery manage','delivery.manage','delivery'],
  ['Notifications view','notifications.view','notifications']
];
const ROLE_PERMISSIONS = {
 owner: PERMISSIONS.map(x=>x[1]),
 admin: PERMISSIONS.map(x=>x[1]),
 supervisor: PERMISSIONS.map(x=>x[1]).filter(k=>!['settings.manage','staff.manage'].includes(k)),
 cashier: ['dashboard.view','orders.view','orders.manage','customers.view','customers.manage','payments.view','payments.manage','cash_shifts.view','cash_shifts.manage','reports.view','printing.manage'],
 waiter: ['orders.view','orders.manage','customers.view','customers.manage','menu.view','printing.manage'],
 kitchen: ['kitchen.view','orders.view','menu.view'],
 delivery: ['delivery.view','delivery.manage','orders.view']
};
async function main() {
  await sequelize.authenticate();
  await sequelize.transaction(async transaction => {
    const [restaurant] = await Restaurant.findOrCreate({
      where:{slug:'urban-byte'},
      defaults:{name:process.env.SEED_RESTAURANT_NAME || 'Urban Byte',slug:'urban-byte',currency:'PKR',timezone:'Asia/Karachi'},
      transaction
    });
    const [branch] = await Branch.findOrCreate({
      where:{restaurantId:restaurant.id,code:'SHK'},
      defaults:{restaurantId:restaurant.id,name:'Shahkot Main Branch',code:'SHK',address:'Shahkot, Punjab, Pakistan',isActive:true},
      transaction
    });
    const permissionMap = {};
    for (const [name,permissionKey,module] of PERMISSIONS) {
      const [p] = await Permission.findOrCreate({where:{permissionKey},defaults:{name,permissionKey,module},transaction});
      permissionMap[permissionKey]=p;
    }
    for (const [slug,keys] of Object.entries(ROLE_PERMISSIONS)) {
      const [role] = await Role.findOrCreate({where:{slug},defaults:{name:slug.charAt(0).toUpperCase()+slug.slice(1),slug,description:'Urban Byte system role',isSystem:true},transaction});
      for (const key of keys) await role.addPermission(permissionMap[key],{transaction});
    }
    const categoryRows = [
      ['Pizza','pizza'],['Burgers','burgers'],['Shawarma','shawarma'],
      ['Sides & Fries','sides-fries'],['Pasta','pasta'],['Drinks','drinks']
    ];
    const categories={};
    for(let i=0;i<categoryRows.length;i++){
      const [name,slug]=categoryRows[i];
      const [item]=await MenuCategory.findOrCreate({where:{restaurantId:restaurant.id,slug},defaults:{restaurantId:restaurant.id,name,slug,sortOrder:i,isActive:true},transaction});
      categories[slug]=item;
    }
    const menu = [
      ['Cheezy Pizza','cheezy-pizza','pizza',1200],
      ['White Sauce Pizza','white-sauce-pizza','pizza',1400],
      ['Malia Boti Pizza','malia-boti-pizza','pizza',1500],
      ['Zinger Burger','zinger-burger','burgers',480],
      ['Crunch Burger','crunch-burger','burgers',420],
      ['Chicken Shawarma','chicken-shawarma','shawarma',350],
      ['Loaded Fries','loaded-fries','sides-fries',400],
      ['Alfredo Pasta','alfredo-pasta','pasta',550],
      ['Mojito Fizz','mojito-fizz','drinks',250],
      ['Regular Drink','regular-drink','drinks',100]
    ];
    for(const [name,slug,cat,price] of menu){
      const [product]=await Product.findOrCreate({where:{restaurantId:restaurant.id,slug},defaults:{restaurantId:restaurant.id,categoryId:categories[cat].id,name,slug,productType:'prepared',isAvailable:true,isActive:true},transaction});
      await ProductVariant.findOrCreate({where:{productId:product.id,name:'Regular'},defaults:{productId:product.id,name:'Regular',sku:'UB-'+slug.toUpperCase().replace(/-/g,'-'),basePrice:price,isDefault:true,isActive:true},transaction});
    }
    const ingredients=[
      ['Chicken','kg',5],['Pizza Cheese','kg',3],['Flour','kg',5],
      ['Cooking Oil','litre',3],['Potatoes','kg',5],['Burger Buns','pcs',20],
      ['Sauces','litre',2],['Packaging Boxes','pcs',25]
    ];
    for(const [name,baseUnit,threshold] of ingredients){
      await InventoryItem.findOrCreate({where:{restaurantId:restaurant.id,name},defaults:{restaurantId:restaurant.id,name,sku:'UB-INV-'+name.toUpperCase().replace(/[^A-Z0-9]+/g,'-'),itemType:'ingredient',baseUnit,lowStockThreshold:threshold,isActive:true},transaction});
    }
    for(const name of ['Local Chicken Supplier','Shahkot General Store','Beverage Distributor']){
      await Supplier.findOrCreate({where:{restaurantId:restaurant.id,name},defaults:{restaurantId:restaurant.id,name,notes:'Demo supplier record',isActive:true},transaction});
    }
    const adminEmail=process.env.SEED_ADMIN_EMAIL;
    const adminPassword=process.env.SEED_ADMIN_PASSWORD;
    if(adminEmail && adminPassword){
      if(adminPassword.length<12) throw new Error('SEED_ADMIN_PASSWORD must be at least 12 characters.');
      const [adminRole]=await Role.findOrCreate({where:{slug:'owner'},defaults:{name:'Owner',slug:'owner',description:'Restaurant owner',isSystem:true},transaction});
      const [admin]=await User.findOrCreate({
        where:{email:adminEmail.toLowerCase()},
        defaults:{restaurantId:restaurant.id,name:process.env.SEED_ADMIN_NAME||'Urban Byte Owner',email:adminEmail.toLowerCase(),passwordHash:await bcrypt.hash(adminPassword,12),isActive:true},
        transaction
      });
      if(!admin.restaurantId) await admin.update({restaurantId:restaurant.id},{transaction});
      await admin.addRole(adminRole,{transaction});
    }
    process.stdout.write('Seeded Urban Byte restaurant, Shahkot branch, permissions, roles, menu, inventory and suppliers.\n');
    if(!adminEmail || !adminPassword) process.stdout.write('No demo owner login created. Set SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD to create one securely.\n');
    process.stdout.write('Branch ID: '+branch.id+' | Restaurant ID: '+restaurant.id+'\n');
  });
}
main().catch(error=>{process.stderr.write(error.stack+'\n');process.exitCode=1;}).finally(()=>sequelize.close());
