import axios from 'axios';
import { getWhatsAppCredentials } from './systemSettingService';

/**
 * Meta Approved WhatsApp Template IDs & Names
 */
export const META_WHATSAPP_TEMPLATES = {
  OTP: {
    id: '2573338346420823',
    name: 'trackmyrent_otp_verification',
  },
  MONTH_FREEZE: {
    id: '1675946917194699',
    name: 'month_freeze_confirmation',
  },
  RENEWAL_REMINDER: {
    id: '840152119154400',
    name: 'membership_renewal_reminder',
  },
  MEMBER_WELCOME: {
    id: '2332169737525031',
    name: 'tenant_welcome_message',
  },
  PAYMENT_RECEIPT: {
    id: '1081300614678972',
    name: 'payment_receipt_confirmation',
  },
  RENT_REMINDER: {
    id: '1813194829858504',
    name: 'rent_fee_payment_request',
  },
};

const TEMPLATE_ID_TO_NAME: Record<string, string> = {
  '2573338346420823': 'trackmyrent_otp_verification',
  '1675946917194699': 'month_freeze_confirmation',
  '840152119154400': 'membership_renewal_reminder',
  '2332169737525031': 'tenant_welcome_message',
  '1081300614678972': 'payment_receipt_confirmation',
  '1813194829858504': 'rent_fee_payment_request',
  '2560343787805690': 'rent_due_reminder',
};

export const resolveTemplateName = (nameOrId: string): string => {
  return TEMPLATE_ID_TO_NAME[nameOrId] || nameOrId;
};

/**
 * Format phone number to international E.164 without '+'
 * Defaults to India (+91) if 10-digit number is provided.
 */
export const formatPhoneNumber = (phone: string): string => {
  const digits = phone.replace(/[^0-9]/g, '');
  if (digits.length === 10) {
    return `91${digits}`;
  }
  return digits;
};

/** Shared helper: POST a template message to the Meta Cloud API */
const sendTemplateMessage = async (
  formattedPhone: string,
  templateNameOrId: string,
  parameters: { type: 'text'; text: string }[],
  buttonParameters?: { type: 'text'; text: string }[]
): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const templateName = resolveTemplateName(templateNameOrId);
  const { phoneNumberId, accessToken, apiVersion } = await getWhatsAppCredentials();

  if (!phoneNumberId || !accessToken) {
    console.log(`📱 [WhatsApp Mock] Would send template "${templateName}" to +${formattedPhone} with params:`, parameters.map(p => p.text));
    return { success: true, messageId: 'mock_local_dev_id' };
  }

  const version = apiVersion || 'v20.0';
  const endpoint = `https://graph.facebook.com/${version}/${phoneNumberId}/messages`;

  const components: any[] = [
    {
      type: 'body',
      parameters,
    },
  ];

  if (buttonParameters && buttonParameters.length > 0) {
    components.push({
      type: 'button',
      sub_type: 'url',
      index: '0',
      parameters: buttonParameters,
    });
  }

  const payload = {
    messaging_product: 'whatsapp',
    to: formattedPhone,
    type: 'template',
    template: {
      name: templateName,
      language: { code: 'en' },
      components,
    },
  };

  try {
    const response = await axios.post(endpoint, payload, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      timeout: 10000,
    });
    const messageId = response.data?.messages?.[0]?.id;
    console.log(`✅ [WhatsApp] "${templateName}" sent to +${formattedPhone} (ID: ${messageId})`);
    return { success: true, messageId };
  } catch (error: any) {
    const errorDetails = error.response?.data?.error?.message || error.message;
    console.error(`❌ [WhatsApp] Failed to send "${templateName}" to +${formattedPhone}:`, errorDetails);
    return { success: false, error: errorDetails };
  }
};

/**
 * Send OTP verification code via WhatsApp Cloud API.
 * Template: trackmyrent_otp_verification
 * Variables: {{1}} = 6-digit OTP code
 */
export const sendWhatsAppOtp = async (
  phone: string,
  otp: string
): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(phone);
  const { phoneNumberId, accessToken } = await getWhatsAppCredentials();

  if (!phoneNumberId || !accessToken) {
    console.log(`\n📱 [WhatsApp Mock] OTP for +${formattedPhone}: ${otp}`);
    console.log(`ℹ️  Configure WhatsApp credentials in Admin Web Platform Settings to send real OTPs.\n`);
    return { success: true, messageId: 'mock_local_dev_id' };
  }

  return sendTemplateMessage(formattedPhone, 'trackmyrent_otp_verification', [
    { type: 'text', text: String(otp) },
  ]);
};

/**
 * Send payment receipt confirmation via WhatsApp Cloud API.
 * Template: payment_receipt_confirmation (ID: 1081300614678972)
 * Variables: {{1}}=memberName, {{2}}=amount, {{3}}=billingMonth, {{4}}=paymentMethod, {{5}}=receiptUrl, {{6}}=facilityName
 */
export const sendWhatsAppReceipt = async (params: {
  phone: string;
  memberName: string;
  billingMonth: string;
  amountPaid: number;
  paymentMethod: string;
  receiptUrl: string;
  facilityName?: string;
}): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(params.phone);
  const templateName = resolveTemplateName(process.env.WHATSAPP_RECEIPT_TEMPLATE_NAME || 'payment_receipt_confirmation');
  const facility = params.facilityName || 'TrackMyRent';

  return sendTemplateMessage(formattedPhone, templateName, [
    { type: 'text', text: params.memberName },
    { type: 'text', text: String(Math.round(params.amountPaid)) },
    { type: 'text', text: params.billingMonth },
    { type: 'text', text: params.paymentMethod },
    { type: 'text', text: params.receiptUrl },
    { type: 'text', text: facility },
  ]);
};

/**
 * Send rent / fee payment reminder via WhatsApp Cloud API.
 * Supports:
 * - rent_fee_payment_request (ID: 1813194829858504): 4 body params + pay button URL parameter
 * - rent_due_reminder (ID: 2560343787805690): 5 body params
 */
export const sendWhatsAppReminder = async (params: {
  phone: string;
  memberName: string;
  billingMonth: string;
  amount: number;
  dueDate: string;
  paymentLink?: string;
  facilityName?: string;
}): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(params.phone);
  const templateName = resolveTemplateName(process.env.WHATSAPP_REMINDER_TEMPLATE_NAME || 'rent_fee_payment_request');
  const facility = params.facilityName || 'TrackMyRent';

  if (templateName === 'rent_fee_payment_request' || templateName === '1813194829858504') {
    // Template 1813194829858504: rent_fee_payment_request
    // BODY text:
    // {{1}}=amount, {{2}}=facilityName, {{3}}=memberName, {{4}}=description
    // BUTTON: URL "https://rzp.io/l/{{1}}"
    const bodyParams = [
      { type: 'text' as const, text: String(Math.round(params.amount)) },
      { type: 'text' as const, text: facility },
      { type: 'text' as const, text: params.memberName },
      { type: 'text' as const, text: `${params.billingMonth || 'Membership Fee'} (Due: ${params.dueDate})` },
    ];

    let buttonSlug = 'pay';
    if (params.paymentLink) {
      const match = params.paymentLink.match(/(?:trackmyrent\.anandhu-kannan\.in\/pay\/|rzp\.io\/(?:l|rzp)\/|pay\/)([\w\-]+)/i);
      buttonSlug = match ? match[1] : (params.paymentLink.split('/').pop() || 'pay');
    }

    const buttonParams = [
      { type: 'text' as const, text: buttonSlug },
    ];

    const result = await sendTemplateMessage(formattedPhone, 'rent_fee_payment_request', bodyParams, buttonParams);
    if (!result.success && result.error && (result.error.includes('132001') || result.error.includes('does not exist'))) {
      // Automatic fallback to approved template rent_due_reminder with payment link included
      const facilityWithLink = params.paymentLink
        ? `${facility}. Pay: ${params.paymentLink}`
        : facility;
      return sendTemplateMessage(formattedPhone, 'rent_due_reminder', [
        { type: 'text' as const, text: params.memberName },
        { type: 'text' as const, text: String(Math.round(params.amount)) },
        { type: 'text' as const, text: params.billingMonth },
        { type: 'text' as const, text: params.dueDate },
        { type: 'text' as const, text: facilityWithLink },
      ]);
    }
    return result;
  } else {
    // Template: rent_due_reminder (ID: 2560343787805690)
    // {{1}}=name, {{2}}=amount, {{3}}=billingMonth, {{4}}=dueDate, {{5}}=facilityName + payment link
    const facilityWithLink = params.paymentLink
      ? `${facility}. Pay: ${params.paymentLink}`
      : facility;
    return sendTemplateMessage(formattedPhone, templateName, [
      { type: 'text' as const, text: params.memberName },
      { type: 'text' as const, text: String(Math.round(params.amount)) },
      { type: 'text' as const, text: params.billingMonth },
      { type: 'text' as const, text: params.dueDate },
      { type: 'text' as const, text: facilityWithLink },
    ]);
  }
};

/**
 * Send month freeze confirmation via WhatsApp Cloud API.
 * Template: month_freeze_confirmation (ID: 1675946917194699)
 * Variables: {{1}}=memberName, {{2}}=frozenMonth, {{3}}=reason/notes
 */
export const sendWhatsAppFreezeConfirmation = async (params: {
  phone: string;
  memberName: string;
  frozenMonth: string;
  notes?: string;
}): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(params.phone);
  const templateName = process.env.WHATSAPP_FREEZE_TEMPLATE_NAME || 'month_freeze_confirmation';
  return sendTemplateMessage(formattedPhone, templateName, [
    { type: 'text', text: params.memberName },
    { type: 'text', text: params.frozenMonth },
    { type: 'text', text: params.notes || 'Temporarily placed on freeze as requested' },
  ]);
};

/**
 * Send member welcome onboarding message via WhatsApp Cloud API.
 * Template: tenant_welcome_message (ID: 2332169737525031)
 * Variables: {{1}}=memberName, {{2}}=facilityName, {{3}}=planName, {{4}}=joiningDate, {{5}}=dueDay
 */
export const sendWhatsAppWelcomeMessage = async (params: {
  phone: string;
  memberName: string;
  facilityName: string;
  planName: string;
  joiningDate: string;
  dueDay: string;
}): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(params.phone);
  const templateName = process.env.WHATSAPP_WELCOME_TEMPLATE_NAME || 'tenant_welcome_message';
  return sendTemplateMessage(formattedPhone, templateName, [
    { type: 'text', text: params.memberName },
    { type: 'text', text: params.facilityName },
    { type: 'text', text: params.planName },
    { type: 'text', text: params.joiningDate },
    { type: 'text', text: params.dueDay },
  ]);
};

/**
 * Send membership / plan renewal reminder via WhatsApp Cloud API.
 * Template: membership_renewal_reminder (ID: 840152119154400)
 * Variables: {{1}}=memberName, {{2}}=planName, {{3}}=facilityName, {{4}}=expiryDate, {{5}}=renewalLink
 */
export const sendWhatsAppRenewalReminder = async (params: {
  phone: string;
  memberName: string;
  planName: string;
  facilityName: string;
  expiryDate: string;
  renewalLink: string;
}): Promise<{ success: boolean; messageId?: string; error?: string }> => {
  const formattedPhone = formatPhoneNumber(params.phone);
  const templateName = process.env.WHATSAPP_RENEWAL_TEMPLATE_NAME || 'membership_renewal_reminder';
  return sendTemplateMessage(formattedPhone, templateName, [
    { type: 'text', text: params.memberName },
    { type: 'text', text: params.planName },
    { type: 'text', text: params.facilityName },
    { type: 'text', text: params.expiryDate },
    { type: 'text', text: params.renewalLink },
  ]);
};

