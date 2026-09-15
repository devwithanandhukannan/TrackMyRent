# 📱 RentTrack — Official WhatsApp Message Templates (Meta Cloud API)

Comprehensive guide and exact message formats for submitting and approving WhatsApp message templates on the **Meta WhatsApp Business API**, as well as using them inside **RentTrack**.

---

### 🔑 1. Admin Login OTP Template

* **Purpose**: One-time password sent when a facility administrator signs in or registers via phone number.
* **Meta Category**: `AUTHENTICATION`
* **Variables**:
  * `{{1}}` : 6-digit OTP Code
  * `{{2}}` : Validity duration in minutes (e.g., 5)
* **Message Format**:

> Your RentTrack verification code is **{{1}}**.  
> This code is valid for **{{2}}** minutes. For security reasons, do not share this OTP with anyone.  
> 
> — RentTrack Secure Login

---

### 💰 2. Rent / Fee Due Reminder (with Razorpay UPI Link)

* **Purpose**: Sent before or on the due date to remind members or tenants of upcoming/overdue rent with an embedded payment link.
* **Meta Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member / Tenant Name
  * `{{2}}` : Billing Month (e.g., October 2026)
  * `{{3}}` : Amount Due (e.g., 1,500)
  * `{{4}}` : Payment Due Date (e.g., 05 Oct 2026)
  * `{{5}}` : Razorpay Payment Link (e.g., `https://rzp.io/i/xxxxxx`)
* **Message Format**:

> Hello **{{1}}**,  
> 
> This is a friendly reminder that your fee/rent of **₹{{3}}** for **{{2}}** is due on **{{4}}**.  
> 
> You can make a fast and secure payment using Google Pay, PhonePe, Paytm, or Cards via the link below:  
> 👉 **{{5}}**  
> 
> Your official receipt will be generated automatically upon payment. Thank you!

---

### 📄 3. Payment Confirmation & Digital Receipt

* **Purpose**: Sent immediately after a payment is received (online through Razorpay or recorded manually in cash).
* **Meta Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member / Tenant Name
  * `{{2}}` : Billing Month
  * `{{3}}` : Amount Paid
  * `{{4}}` : Payment Method (e.g., UPI, Card, Cash)
  * `{{5}}` : Digital Receipt Download Link
* **Message Format**:

> Dear **{{1}}**,  
> 
> We have successfully received your payment of **₹{{3}}** for **{{2}}** via **{{4}}**.  
> 
> 📄 Click the link below to view and download your official digital receipt:  
> 👉 **{{5}}**  
> 
> Thank you for choosing RentTrack!

---

### 👋 4. Member / Tenant Welcome Message

* **Purpose**: Sent automatically when an administrator registers a new member or tenant in the facility.
* **Meta Category**: `MARKETING` / `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name
  * `{{2}}` : Facility / Business Name
  * `{{3}}` : Plan / Batch Name
  * `{{4}}` : Joining Date
  * `{{5}}` : Monthly Payment Due Day (e.g., 5th of every month)
* **Message Format**:

> Hello **{{1}}**,  
> 
> Welcome to **{{2}}**!  
> Your membership plan (**{{3}}**) is active starting from **{{4}}**.  
> Your monthly payment due date is the **{{5}}** of each month.  
> 
> Feel free to reach out if you have any questions. We are glad to have you with us!

---

### ⏰ 5. Membership Renewal Reminder

* **Purpose**: Sent 3 to 5 days before a term plan expires (e.g., 30-day, 3-month, or annual plan).
* **Meta Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name
  * `{{2}}` : Facility Name
  * `{{3}}` : Plan Name
  * `{{4}}` : Expiry Date
  * `{{5}}` : Renewal Payment Link
* **Message Format**:

> Dear **{{1}}**,  
> 
> Your **{{3}}** membership at **{{2}}** will expire on **{{4}}**.  
> 
> To continue without interruption, please renew your plan using the link below:  
> 👉 **{{5}}**  
> 
> Thank you!

---

### ❄️ 6. Month Freeze Confirmation

* **Purpose**: Sent when a member requests a temporary hold / freeze for a month due to vacation, injury, or travel.
* **Meta Category**: `UTILITY`
* **Variables**:
  * `{{1}}` : Member Name
  * `{{2}}` : Frozen Month
  * `{{3}}` : Reason / Admin Notes
* **Message Format**:

> Dear **{{1}}**,  
> 
> As requested, your membership billing for **{{2}}** has been put on freeze (Freeze ❄️).  
> Note: **{{3}}**  
> 
> This month's dues are waived and will not be counted as pending. Please let us know when you are ready to resume. Thank you!
