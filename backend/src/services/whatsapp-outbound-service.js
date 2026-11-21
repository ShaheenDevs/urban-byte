'use strict';
const {whatsappPhoneNumberId,whatsappAccessToken,whatsappGraphVersion}=require('../config/env');
const {WhatsappOutboundMessage,AiConversation,AiMessage}=require('../models');
function error(message,status=400,code='WHATSAPP_ERROR'){const e=new Error(message);e.statusCode=status;e.code=code;return e;}
async function sendText(restaurantId,conversationId,input={}){
 if(!whatsappPhoneNumberId||!whatsappAccessToken)throw error('WhatsApp Cloud API credentials are not configured.',503,'WHATSAPP_NOT_CONFIGURED');
 const conversation=await AiConversation.findOne({where:{id:Number(conversationId),restaurantId}});
 if(!conversation)throw error('Conversation not found.',404,'CONVERSATION_NOT_FOUND');
 const to=String(conversation.customerPhone||'').replace(/[^0-9]/g,'');
 if(to.length<8||to.length>15)throw error('Conversation has no valid customer phone number.');
 const body=typeof input.text==='string'?input.text.trim():'';
 if(!body||body.length>4096)throw error('Message must contain 1 to 4096 characters.');
 const record=await WhatsappOutboundMessage.create({restaurantId,conversationId:conversation.id,recipientPhone:to,messageType:'text',content:body,deliveryStatus:'queued'});
 try{
  const response=await fetch('https://graph.facebook.com/'+whatsappGraphVersion+'/'+whatsappPhoneNumberId+'/messages',{method:'POST',headers:{Authorization:'Bearer '+whatsappAccessToken,'Content-Type':'application/json'},body:JSON.stringify({messaging_product:'whatsapp',recipient_type:'individual',to,type:'text',text:{preview_url:false,body}})});
  const data=await response.json().catch(()=>({}));
  if(!response.ok){const reason=String(data?.error?.message||'WhatsApp provider rejected the message.').slice(0,500);await record.update({deliveryStatus:'failed',providerError:reason});throw error(reason,502,'WHATSAPP_PROVIDER_ERROR');}
  const providerId=data?.messages?.[0]?.id;
  if(!providerId)throw error('WhatsApp provider response did not include a message ID.',502,'WHATSAPP_INVALID_RESPONSE');
  await record.update({providerMessageId:providerId,deliveryStatus:'sent',sentAt:new Date()});
  await AiMessage.create({conversationId:conversation.id,senderType:'staff',content:body,metadata:{channel:'whatsapp',direction:'outbound',providerMessageId:providerId}});
  return record;
 }catch(e){if(record.deliveryStatus==='queued')await record.update({deliveryStatus:'failed',providerError:String(e.message||e).slice(0,500)});throw e;}
}
async function updateDeliveryStatuses(statuses=[]){let updated=0;for(const status of statuses){const providerId=String(status.id||'');const state=String(status.status||'');if(!providerId||!['sent','delivered','read','failed'].includes(state))continue;const record=await WhatsappOutboundMessage.findOne({where:{providerMessageId:providerId}});if(!record)continue;const patch={deliveryStatus:state};if(state==='delivered')patch.deliveredAt=status.timestamp?new Date(Number(status.timestamp)*1000):new Date();if(state==='read')patch.readAt=status.timestamp?new Date(Number(status.timestamp)*1000):new Date();if(state==='failed')patch.providerError=String(status.errors?.[0]?.title||status.errors?.[0]?.message||'Delivery failed').slice(0,500);await record.update(patch);updated++;}return updated;}
module.exports={sendText,updateDeliveryStatuses};