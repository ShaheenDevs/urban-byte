'use strict';
require('dotenv').config();
const bcrypt=require('bcryptjs');
const {validateEnv}=require('../src/config/env');
const {sequelize,User,Role,Restaurant,Branch}=require('../src/models');
async function main(){
 validateEnv();
 const {ADMIN_NAME,ADMIN_EMAIL,ADMIN_PHONE,ADMIN_PASSWORD}=process.env;
 if(!ADMIN_NAME||(!ADMIN_EMAIL&&!ADMIN_PHONE)||!ADMIN_PASSWORD||ADMIN_PASSWORD.length<12)throw new Error('Set ADMIN_NAME, ADMIN_EMAIL or ADMIN_PHONE, and ADMIN_PASSWORD (minimum 12 characters) in backend/.env.');
 await sequelize.authenticate();
 const existing=await User.findOne({where:ADMIN_EMAIL?{email:ADMIN_EMAIL.toLowerCase()}:{phone:ADMIN_PHONE}});
 if(existing)throw new Error('An account with this admin email/phone already exists.');
 const role=await Role.findOne({where:{slug:'admin'}});
 if(!role)throw new Error('System roles are missing. Run npm run db:seed first.');
 const user=await sequelize.transaction(async transaction=>{
  let restaurant=await Restaurant.findOne({where:{slug:'urban-byte'},transaction});
  if(!restaurant)restaurant=await Restaurant.create({name:'Urban Byte',slug:'urban-byte',currency:'PKR',timezone:'Asia/Karachi'},{transaction});
  const branch=await Branch.findOne({where:{restaurantId:restaurant.id,code:'SHK'},transaction});
  if(!branch)await Branch.create({restaurantId:restaurant.id,name:'Shahkot',code:'SHK'},{transaction});
  const created=await User.create({restaurantId:restaurant.id,name:ADMIN_NAME,email:ADMIN_EMAIL?ADMIN_EMAIL.toLowerCase():null,phone:ADMIN_PHONE||null,passwordHash:await bcrypt.hash(ADMIN_PASSWORD,12)},{transaction});
  await created.addRole(role,{transaction});return created;
 });
 process.stdout.write(`Admin account created (user id: ${user.id}).\n`);
}
main().catch(e=>{process.stderr.write(`${e.message}\n`);process.exitCode=1;}).finally(async()=>sequelize.close());