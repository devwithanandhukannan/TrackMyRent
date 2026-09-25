# 📱 TrackMyRent — Official WhatsApp Message Templates (Meta Cloud API)

Comprehensive registry and exact message formats for approved WhatsApp message templates on the **Meta WhatsApp Business API**, configured for automated sending in **TrackMyRent**.

---

## 📋 Quick Reference: Meta Approved Template Registry

| # | Meta Template Name | Meta Template ID | Category | Language | Purpose |
|:---:|:---|:---:|:---:|:---:|:---|
| **1** | `trackmyrent_otp_verification` | `2573338346420823` | `AUTHENTICATION` / `UTILITY` | `English (en)` | 6-digit OTP verification code for login & signup |
| **2** | `month_freeze_confirmation` | `1675946917194699` | `UTILITY` | `English (en)` | Notification when membership billing is temporarily frozen |
| **3** | `membership_renewal_reminder` | `840152119154400` | `UTILITY` | `English (en)` | Expiry alert with renewal payment link |
| **4** | `tenant_welcome_message` | `2332169737525031` | `MARKETING` / `UTILITY` | `English (en)` | Welcome onboarding message for new members |
| **5** | `payment_receipt_confirmation` | `1081300614678972` | `UTILITY` | `English (en)` | Digital receipt & payment confirmation |
| **6** | `rent_fee_payment_request` | `1813194829858504` | `UTILITY` | `English (en)` | Monthly rent/fee payment request with pay button |

---

### 🔑 1. Tenant / Admin OTP Verification

* **Meta Template Name**: `trackmyrent_otp_verification`
* **Meta Template ID**: `2573338346420823`
* **Language**: `English` (`en`)
* **Category**: `AUTHENTICATION` / `UTILITY`
* **Variables**:
  * `{{1}}` : 6-digit OTP Code (e.g. `482910`)

#### Template Format:
```text
TrackMyRent Update: Your receipt is {{1}}.
Thank you,TrackMyRent
```

#### Approved Sample:
> TrackMyRent Update: Your receipt is 482910.  
> Thank you,TrackMyRent

---

### ❄️ 2. Month Freeze Confirmation

* **Meta Template Name**: `month_freeze_confirmation`
* **Meta Template ID**: `1675946917194699`
* **Language**: `English` (`en`)
* **Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member / Tenant Name (e.g. `Rahul Sharma`)
  * `{{2}}` : Month on Freeze (e.g. `October 2026`)
  * `{{3}}` : Reason / Admin Note (e.g. `Travel leave for 1 month`)

#### Template Format:
```text
Dear {{1}},

As requested, your membership billing for {{2}} has been put on freeze.
Note: {{3}}

This month's dues are waived and will not be counted as pending. Please let us know when you are ready to resume. Thank you!
```

#### Approved Sample:
> Dear Rahul Sharma,  
>  
> As requested, your membership billing for October 2026 has been put on freeze.  
> Note: Travel leave for 1 month  
>  
> This month's dues are waived and will not be counted as pending. Please let us know when you are ready to resume. Thank you!

---

### ⏰ 3. Membership Renewal Reminder

* **Meta Template Name**: `membership_renewal_reminder`
* **Meta Template ID**: `840152119154400`
* **Language**: `English` (`en`)
* **Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name (e.g. `Rahul Sharma`)
  * `{{2}}` : Plan Name (e.g. `3 Months Plan`)
  * `{{3}}` : Business / Facility Name (e.g. `FitLife Gym`)
  * `{{4}}` : Expiry Date (e.g. `30-Sep-2026`)
  * `{{5}}` : Renewal Link (e.g. `https://rzp.io/l/renewal123`)

#### Template Format:
```text
Dear {{1}},

Your {{2}} membership at {{3}} will expire on {{4}}.

To continue without interruption, please renew your plan using the link below:
{{5}}

Thank you!
```

#### Approved Sample:
> Dear Rahul Sharma,  
>  
> Your 3 Months Plan membership at FitLife Gym will expire on 30-Sep-2026.  
>  
> To continue without interruption, please renew your plan using the link below:  
> https://rzp.io/l/renewal123  
>  
> Thank you!

---

### 👋 4. Tenant / Member Welcome Message

* **Meta Template Name**: `tenant_welcome_message`
* **Meta Template ID**: `2332169737525031`
* **Language**: `English` (`en`)
* **Category**: `MARKETING` / `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name (e.g. `Rahul Sharma`)
  * `{{2}}` : Facility / Academy Name (e.g. `Apex Academy`)
  * `{{3}}` : Plan / Batch Name (e.g. `Regular Batch`)
  * `{{4}}` : Joining / Activation Date (e.g. `21-Sep-2026`)
  * `{{5}}` : Monthly Due Date (e.g. `5th`)

#### Template Format:
```text
Hello {{1}},

Welcome to {{2}}!
Your membership plan ({{3}}) is active starting from {{4}}.
Your monthly payment due date is the {{5}} of each month.

Feel free to reach out if you have any questions. We are glad to have you with us!
```

#### Approved Sample:
> Hello Rahul Sharma,  
>  
> Welcome to Apex Academy!  
> Your membership plan (Regular Batch) is active starting from 21-Sep-2026.  
> Your monthly payment due date is the 5th of each month.  
>  
> Feel free to reach out if you have any questions. We are glad to have you with us!

---

### 📄 5. Payment Receipt Confirmation

* **Meta Template Name**: `payment_receipt_confirmation`
* **Meta Template ID**: `1081300614678972`
* **Language**: `English` (`en`)
* **Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name (e.g. `Rahul Sharma`)
  * `{{2}}` : Billing Month / Period (e.g. `October 2026`)
  * `{{3}}` : Amount Paid in ₹ (e.g. `1000`)
  * `{{4}}` : Payment Method (e.g. `UPI`)
  * `{{5}}` : Official Receipt URL (e.g. `https://trackmyrent.app/receipt/REC1024`)
  * `{{6}}` : Business / Facility Name (e.g. `FitLife Fitness & Gym!`)

#### Template Format:
```text
Dear {{1}},

We have successfully received your payment of ₹{{3}} for {{2}} via {{4}}.

Click the link below to view and download your official digital receipt:
{{5}}

Thank you for choosing {{6}}. 
Have an amazing day!
```

#### Approved Sample:
> Dear Rahul Sharma,  
>  
> We have successfully received your payment of ₹1000 for October 2026 via UPI.  
>  
> Click the link below to view and download your official digital receipt:  
> https://trackmyrent.app/receipt/REC1024  
>  
> Thank you for choosing FitLife Fitness & Gym!.   
> Have an amazing day!

---

### 💰 6. Rent / Fee Payment Request

* **Meta Template Name**: `rent_fee_payment_request`
* **Meta Template ID**: `1813194829858504`
* **Language**: `English` (`en`)
* **Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Amount in ₹ (e.g. `1000`)
  * `{{2}}` : Facility / Business Name (e.g. `Natyakshetra`)
  * `{{3}}` : Member / Student Name (e.g. `Niranjana`)
  * `{{4}}` : Description / Batch (e.g. `Regular Batch`)
* **Buttons / Action**:
  * Quick Reply / URL Button: `pay`

#### Template Format:
```text
Hello there,
You have received a fee payment request of ₹{{1}} from {{2}}.

Payment details:
Name: {{3}}
Description: {{4}}

Tap below to securely complete the payment.
If already paid, kindly ignore.
```

#### Approved Sample:
> Hello there,  
> You have received a fee payment request of ₹1000 from Natyakshetra.  
>  
> Payment details:  
> Name: Niranjana  
> Description: Regular Batch  
>  
> Tap below to securely complete the payment.  
> If already paid, kindly ignore.  
>  
> 🔘 **[pay]**
