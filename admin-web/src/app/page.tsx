"use client";

import React, { useState, useEffect } from "react";
import {
  Users,
  Building2,
  Sliders,
  CheckCircle2,
  AlertCircle,
  Clock,
  Snowflake,
  Search,
  RefreshCw,
  Edit3,
  Trash2,
  ExternalLink,
  ShieldCheck,
  Save,
  Phone,
  ArrowRight,
  CreditCard,
  QrCode,
  Sparkles,
  Check,
  X,
  Send,
  Plus,
  IndianRupee,
  Layers,
  ChevronRight,
  Eye,
  EyeOff,
  Building,
  Mail,
  Calendar,
  Zap,
  HelpCircle
} from "lucide-react";

const API_BASE_URL = "http://localhost:5001/api";

interface Member {
  id: string;
  fullName: string;
  phone: string;
  organizationId: string;
  organizationName: string;
  organizationType: string;
  planName: string;
  groupName: string;
  duration: string;
  status: "PAID" | "UNPAID" | "FROZEN";
  amount: number;
  dueDate: string | null;
  latestMonthYear: string;
  joiningDate: string;
  customFields?: any;
}

interface AppSubscriptionPlan {
  id: string;
  name: string;
  price: number;
  tag?: string | null;
  description: string;
  durationMonths: number;
  whatsappCredits: number;
  isFreeTrial: boolean;
  isActive: boolean;
  sortOrder: number;
  createdAt?: string;
}

interface Organization {
  id: string;
  name: string;
  type: string;
  bankAccountNumber?: string | null;
  bankIfsc?: string | null;
  bankAccountName?: string | null;
  bankUpiId?: string | null;
  tenantRazorpayKeyId?: string | null;
  tenantRazorpayKeySecret?: string | null;
  selectedAppPlanId?: string | null;
  selectedAppPlan?: AppSubscriptionPlan | null;
  users: { id: string; name: string; email: string; phone?: string | null; role: string }[];
  subscriptionCredit?: {
    id: string;
    purchasedCredits: number;
    usedCredits: number;
    subscriptionName: string;
    expiresAt: string;
  } | null;
  _count?: { members: number; plans: number };
  createdAt?: string;
}

interface WhatsAppTemplateItem {
  id: string;
  templateId?: string;
  name?: string;
  templateType: string;
  category?: string;
  language: string;
  messageText: string;
  isActive: boolean;
}

interface SystemSettingsMap {
  RAZORPAY_KEY_ID?: string;
  RAZORPAY_KEY_SECRET?: string;
  WHATSAPP_PHONE_NUMBER_ID?: string;
  WHATSAPP_BUSINESS_ACCOUNT_ID?: string;
  WHATSAPP_ACCESS_TOKEN?: string;
  WHATSAPP_API_VERSION?: string;
  WHATSAPP_WEBHOOK_SECRET?: string;
}

export default function AdminDashboard() {
  // Sidebar active tab: "users" | "tenants" | "settings"
  const [activeTab, setActiveTab] = useState<"users" | "tenants" | "settings">("users");

  // Data states
  const [members, setMembers] = useState<Member[]>([]);
  const [organizations, setOrganizations] = useState<Organization[]>([]);
  const [appPlans, setAppPlans] = useState<AppSubscriptionPlan[]>([]);
  const [templates, setTemplates] = useState<WhatsAppTemplateItem[]>([]);
  const [systemSettings, setSystemSettings] = useState<SystemSettingsMap>({});

  // Loading & notification states
  const [loading, setLoading] = useState<boolean>(true);
  const [savingSettings, setSavingSettings] = useState<boolean>(false);
  const [savingAppPlan, setSavingAppPlan] = useState<boolean>(false);
  const [toastMessage, setToastMessage] = useState<{ text: string; type: "success" | "error" } | null>(null);

  // Search & Filters for End Users Tab
  const [userSearch, setUserSearch] = useState<string>("");
  const [selectedTenantFilter, setSelectedTenantFilter] = useState<string>("ALL");
  const [userStatusFilter, setUserStatusFilter] = useState<"ALL" | "DUE_SOON" | "OVERDUE" | "PAID" | "FROZEN">("ALL");

  // Search for Tenants Tab
  const [tenantSearch, setTenantSearch] = useState<string>("");

  // Modals
  const [selectedMemberModal, setSelectedMemberModal] = useState<Member | null>(null);
  const [assignPlanModalOrg, setAssignPlanModalOrg] = useState<Organization | null>(null);
  const [selectedPlanToAssign, setSelectedPlanToAssign] = useState<string>("");
  const [showAppPlanModal, setShowAppPlanModal] = useState<boolean>(false);
  const [editingAppPlan, setEditingAppPlan] = useState<AppSubscriptionPlan | null>(null);
  const [showTemplateModal, setShowTemplateModal] = useState<boolean>(false);
  const [editingTemplate, setEditingTemplate] = useState<WhatsAppTemplateItem | null>(null);

  // Password visibility toggles for settings
  const [showRazorpaySecret, setShowRazorpaySecret] = useState<boolean>(false);
  const [showWaToken, setShowWaToken] = useState<boolean>(false);

  // New / Edit App Subscription Plan Form State
  const [appPlanForm, setAppPlanForm] = useState({
    name: "",
    price: 0,
    tag: "",
    description: "",
    durationMonths: 1,
    whatsappCredits: 100,
    isFreeTrial: false,
    isActive: true,
  });

  // New / Edit Template Form State
  const [templateForm, setTemplateForm] = useState({
    name: "",
    templateId: "",
    templateType: "REMINDER",
    category: "UTILITY",
    language: "en",
    messageText: "",
    isActive: true,
  });

  const showToast = (text: string, type: "success" | "error" = "success") => {
    setToastMessage({ text, type });
    setTimeout(() => setToastMessage(null), 3500);
  };

  // Fetch all data
  const fetchData = async () => {
    setLoading(true);
    try {
      const [membersRes, orgsRes, plansRes, templatesRes, settingsRes] = await Promise.all([
        fetch(`${API_BASE_URL}/members`),
        fetch(`${API_BASE_URL}/auth/organizations`),
        fetch(`${API_BASE_URL}/app-plans`),
        fetch(`${API_BASE_URL}/settings/whatsapp-templates`),
        fetch(`${API_BASE_URL}/settings`),
      ]);

      if (membersRes.ok) {
        const data = await membersRes.json();
        setMembers(data.members || []);
      }
      if (orgsRes.ok) {
        const data = await orgsRes.json();
        setOrganizations(data.organizations || []);
      }
      if (plansRes.ok) {
        const data = await plansRes.json();
        setAppPlans(data.data || []);
      }
      if (templatesRes.ok) {
        const data = await templatesRes.json();
        setTemplates(data.templates || []);
      }
      if (settingsRes.ok) {
        const data = await settingsRes.json();
        setSystemSettings(data.settings || {});
      }
    } catch (err) {
      console.error("Failed to load platform data:", err);
      showToast("Error connecting to backend API", "error");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  // Compute Days Left / Expiration info for End Users
  const getDaysLeftInfo = (dueDateStr: string | null, status: string) => {
    if (status === "FROZEN") {
      return {
        days: 0,
        badgeClass: "bg-sky-50 text-sky-700 border-sky-200",
        label: "Frozen ❄️",
        isOverdue: false,
        isDueSoon: false,
      };
    }
    if (status === "PAID") {
      return {
        days: 0,
        badgeClass: "bg-emerald-50 text-emerald-700 border-emerald-200",
        label: "Paid in Full",
        isOverdue: false,
        isDueSoon: false,
      };
    }
    if (!dueDateStr) {
      return {
        days: 0,
        badgeClass: "bg-slate-50 text-slate-600 border-slate-200",
        label: "No Schedule",
        isOverdue: false,
        isDueSoon: false,
      };
    }

    const due = new Date(dueDateStr);
    const now = new Date();
    due.setHours(0, 0, 0, 0);
    now.setHours(0, 0, 0, 0);
    const diffTime = due.getTime() - now.getTime();
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays < 0) {
      const overdueDays = Math.abs(diffDays);
      return {
        days: diffDays,
        badgeClass: "bg-rose-50 text-rose-700 border-rose-200 font-semibold",
        label: `Overdue by ${overdueDays} day${overdueDays === 1 ? "" : "s"}`,
        isOverdue: true,
        isDueSoon: false,
      };
    } else if (diffDays === 0) {
      return {
        days: 0,
        badgeClass: "bg-amber-50 text-amber-700 border-amber-200 font-semibold",
        label: "Due Today",
        isOverdue: false,
        isDueSoon: true,
      };
    } else if (diffDays <= 7) {
      return {
        days: diffDays,
        badgeClass: "bg-amber-50 text-amber-700 border-amber-200 font-semibold",
        label: `Due in ${diffDays} day${diffDays === 1 ? "" : "s"}`,
        isOverdue: false,
        isDueSoon: true,
      };
    } else {
      return {
        days: diffDays,
        badgeClass: "bg-blue-50 text-blue-700 border-blue-200",
        label: `Due in ${diffDays} days`,
        isOverdue: false,
        isDueSoon: false,
      };
    }
  };

  // Filtered End Users
  const filteredMembers = members.filter((m) => {
    // Tenant filter
    if (selectedTenantFilter !== "ALL" && m.organizationId !== selectedTenantFilter) {
      return false;
    }

    // Search filter
    if (userSearch.trim()) {
      const query = userSearch.toLowerCase();
      const matchName = m.fullName.toLowerCase().includes(query);
      const matchPhone = m.phone.toLowerCase().includes(query);
      const matchOrg = m.organizationName.toLowerCase().includes(query);
      const matchPlan = m.planName.toLowerCase().includes(query);
      if (!matchName && !matchPhone && !matchOrg && !matchPlan) return false;
    }

    // Status filter
    const daysInfo = getDaysLeftInfo(m.dueDate, m.status);
    if (userStatusFilter === "PAID") return m.status === "PAID";
    if (userStatusFilter === "FROZEN") return m.status === "FROZEN";
    if (userStatusFilter === "OVERDUE") return m.status === "UNPAID" && daysInfo.isOverdue;
    if (userStatusFilter === "DUE_SOON") return m.status === "UNPAID" && daysInfo.isDueSoon;

    return true;
  });

  // Filtered Tenants
  const filteredOrganizations = organizations.filter((org) => {
    if (!tenantSearch.trim()) return true;
    const q = tenantSearch.toLowerCase();
    const matchName = org.name.toLowerCase().includes(q);
    const matchOwner = org.users.some(
      (u) => (u.name && u.name.toLowerCase().includes(q)) || (u.phone && u.phone.includes(q))
    );
    const matchUpi = org.bankUpiId && org.bankUpiId.toLowerCase().includes(q);
    return matchName || matchOwner || matchUpi;
  });

  // Calculate high-level stats
  const totalOutstanding = members
    .filter((m) => m.status === "UNPAID")
    .reduce((sum, m) => sum + (m.amount || 0), 0);
  const totalPaidMembers = members.filter((m) => m.status === "PAID").length;
  const totalOverdueMembers = members.filter((m) => {
    if (m.status !== "UNPAID") return false;
    return getDaysLeftInfo(m.dueDate, m.status).isOverdue;
  }).length;
  const totalDueSoonMembers = members.filter((m) => {
    if (m.status !== "UNPAID") return false;
    return getDaysLeftInfo(m.dueDate, m.status).isDueSoon;
  }).length;

  // Save Settings handler
  const handleSaveSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingSettings(true);
    try {
      const res = await fetch(`${API_BASE_URL}/settings`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ settings: systemSettings }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        showToast("Platform & WhatsApp settings saved successfully!");
      } else {
        showToast(data.error || "Failed to save settings", "error");
      }
    } catch (err) {
      showToast("Error updating settings", "error");
    } finally {
      setSavingSettings(false);
    }
  };

  // Update Template ID inline
  const handleUpdateTemplateId = async (id: string, newTemplateId: string) => {
    try {
      const res = await fetch(`${API_BASE_URL}/settings/whatsapp-templates/${id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ templateId: newTemplateId }),
      });
      if (res.ok) {
        showToast("Meta Template ID updated successfully!");
        setTemplates((prev) =>
          prev.map((t) => (t.id === id ? { ...t, templateId: newTemplateId } : t))
        );
      } else {
        showToast("Failed to update template ID", "error");
      }
    } catch (err) {
      showToast("Error updating template ID", "error");
    }
  };

  // Assign Plan to Tenant
  const handleAssignPlan = async () => {
    if (!assignPlanModalOrg || !selectedPlanToAssign) return;
    try {
      const res = await fetch(
        `${API_BASE_URL}/auth/organization/${assignPlanModalOrg.id}/subscribe-app-plan`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ appPlanId: selectedPlanToAssign }),
        }
      );
      const data = await res.json();
      if (res.ok && data.success) {
        showToast(`Assigned plan to ${assignPlanModalOrg.name}!`);
        setAssignPlanModalOrg(null);
        fetchData();
      } else {
        showToast(data.error || "Failed to assign plan", "error");
      }
    } catch (err) {
      showToast("Error assigning plan", "error");
    }
  };

  // Save / Create App Plan
  const handleSaveAppPlan = async (e: React.FormEvent) => {
    e.preventDefault();
    if (appPlanForm.whatsappCredits === undefined || appPlanForm.whatsappCredits === null) {
      showToast("WhatsApp Credits is compulsory", "error");
      return;
    }
    setSavingAppPlan(true);
    try {
      const method = editingAppPlan ? "PUT" : "POST";
      const url = editingAppPlan
        ? `${API_BASE_URL}/app-plans/${editingAppPlan.id}`
        : `${API_BASE_URL}/app-plans`;

      const res = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(appPlanForm),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        showToast(editingAppPlan ? "Plan updated!" : "New plan created!");
        setShowAppPlanModal(false);
        setEditingAppPlan(null);
        fetchData();
      } else {
        showToast(data.error || "Failed to save plan", "error");
      }
    } catch (err) {
      showToast("Error saving plan", "error");
    } finally {
      setSavingAppPlan(false);
    }
  };

  // Send WhatsApp Reminder from Web Admin
  const handleSendReminder = async (member: Member) => {
    try {
      const res = await fetch(`${API_BASE_URL}/payments/send-reminder`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          memberId: member.id,
          organizationId: member.organizationId,
        }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        showToast(
          `Reminder sent! Direct UPI link created. Balance: ${data.remainingCredits ?? "Active"} credits`
        );
        fetchData();
      } else {
        showToast(data.error || "Failed to send reminder", "error");
      }
    } catch (err) {
      showToast("Error sending reminder", "error");
    }
  };

  return (
    <div className="flex min-h-screen bg-[#F8FAFC] text-slate-900 font-sans">
      {/* Toast Notification */}
      {toastMessage && (
        <div
          className={`fixed top-6 right-6 z-50 flex items-center gap-3 px-5 py-3.5 rounded-xl shadow-lg border text-sm font-medium transition-all transform animate-in slide-in-from-top-3 ${
            toastMessage.type === "success"
              ? "bg-emerald-50 text-emerald-800 border-emerald-200"
              : "bg-rose-50 text-rose-800 border-rose-200"
          }`}
        >
          {toastMessage.type === "success" ? (
            <CheckCircle2 className="w-5 h-5 text-emerald-600 flex-shrink-0" />
          ) : (
            <AlertCircle className="w-5 h-5 text-rose-600 flex-shrink-0" />
          )}
          <span>{toastMessage.text}</span>
          <button onClick={() => setToastMessage(null)} className="ml-2 hover:opacity-75">
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* ──────────────────────────────────────────────────────────────────────────
          LEFT SIDEBAR (White Theme, Crisp Borders, Focused Navigation)
      ────────────────────────────────────────────────────────────────────────── */}
      <aside className="w-72 bg-white border-r border-slate-200 flex flex-col justify-between fixed inset-y-0 left-0 z-30 shadow-sm">
        <div>
          {/* Brand Header */}
          <div className="px-6 py-6 border-b border-slate-100 flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-600 to-indigo-600 flex items-center justify-center text-white shadow-md shadow-blue-500/20">
              <Building2 className="w-5 h-5" />
            </div>
            <div>
              <h1 className="font-bold text-base text-slate-900 tracking-tight flex items-center gap-1.5">
                TrackMyRent
                <span className="text-[10px] uppercase font-extrabold px-1.5 py-0.5 rounded bg-blue-100 text-blue-700">
                  Admin
                </span>
              </h1>
              <p className="text-xs text-slate-500">Platform Control Center</p>
            </div>
          </div>

          {/* Navigation Items (Only 3 Options Requested) */}
          <nav className="p-4 space-y-2">
            <div className="px-3 pb-2 text-[11px] font-bold uppercase tracking-wider text-slate-400">
              Platform Navigation
            </div>

            {/* OPTION 1: End Users Data */}
            <button
              onClick={() => setActiveTab("users")}
              className={`w-full flex items-center justify-between px-3.5 py-3 rounded-xl text-left transition-all duration-150 ${
                activeTab === "users"
                  ? "bg-blue-50 text-blue-700 font-semibold shadow-xs border border-blue-100"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                    activeTab === "users"
                      ? "bg-blue-600 text-white shadow-xs"
                      : "bg-slate-100 text-slate-500"
                  }`}
                >
                  <Users className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-sm">End Users Data</div>
                  <div className="text-[11px] text-slate-400 font-normal">
                    Customers, dues & days left
                  </div>
                </div>
              </div>
              <span className="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-medium">
                {members.length}
              </span>
            </button>

            {/* OPTION 2: Tenants & Subscriptions */}
            <button
              onClick={() => setActiveTab("tenants")}
              className={`w-full flex items-center justify-between px-3.5 py-3 rounded-xl text-left transition-all duration-150 ${
                activeTab === "tenants"
                  ? "bg-blue-50 text-blue-700 font-semibold shadow-xs border border-blue-100"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                    activeTab === "tenants"
                      ? "bg-blue-600 text-white shadow-xs"
                      : "bg-slate-100 text-slate-500"
                  }`}
                >
                  <Building2 className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-sm">Tenants & Plans</div>
                  <div className="text-[11px] text-slate-400 font-normal">
                    Facilities & subscriptions
                  </div>
                </div>
              </div>
              <span className="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 font-medium">
                {organizations.length}
              </span>
            </button>

            {/* OPTION 3: Platform & WhatsApp Settings */}
            <button
              onClick={() => setActiveTab("settings")}
              className={`w-full flex items-center justify-between px-3.5 py-3 rounded-xl text-left transition-all duration-150 ${
                activeTab === "settings"
                  ? "bg-blue-50 text-blue-700 font-semibold shadow-xs border border-blue-100"
                  : "text-slate-600 hover:bg-slate-50 hover:text-slate-900"
              }`}
            >
              <div className="flex items-center gap-3">
                <div
                  className={`w-8 h-8 rounded-lg flex items-center justify-center ${
                    activeTab === "settings"
                      ? "bg-blue-600 text-white shadow-xs"
                      : "bg-slate-100 text-slate-500"
                  }`}
                >
                  <Sliders className="w-4 h-4" />
                </div>
                <div>
                  <div className="text-sm">Platform Settings</div>
                  <div className="text-[11px] text-slate-400 font-normal">
                    WhatsApp & Razorpay keys
                  </div>
                </div>
              </div>
              <div className="w-2 h-2 rounded-full bg-emerald-500"></div>
            </button>
          </nav>
        </div>

        {/* Sidebar Footer */}
        <div className="p-4 border-t border-slate-100 bg-slate-50/50">
          <div className="flex items-center gap-3 px-2 py-2">
            <div className="w-9 h-9 rounded-full bg-indigo-100 text-indigo-700 font-bold flex items-center justify-center text-xs">
              SA
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-semibold text-slate-800 truncate">Platform Super Admin</p>
              <p className="text-[11px] text-slate-500 truncate">admin@trackmyrent.app</p>
            </div>
          </div>
        </div>
      </aside>

      {/* ──────────────────────────────────────────────────────────────────────────
          MAIN CONTENT AREA (Offset by 72 = 288px)
      ────────────────────────────────────────────────────────────────────────── */}
      <main className="ml-72 flex-1 p-8 min-h-screen">
        {/* Top Action & Status Bar */}
        <header className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 pb-6 mb-6 border-b border-slate-200">
          <div>
            <h2 className="text-2xl font-bold text-slate-900 tracking-tight">
              {activeTab === "users" && "End Users & Payment Schedules"}
              {activeTab === "tenants" && "Tenants (Facilities) & Subscription Plans"}
              {activeTab === "settings" && "Platform & Meta WhatsApp Settings"}
            </h2>
            <p className="text-sm text-slate-500 mt-0.5">
              {activeTab === "users" &&
                "Track all end-user customers across tenants, their active plans, and days left to pay."}
              {activeTab === "tenants" &&
                "Manage all registered facility tenants, direct payout accounts, and platform subscription tiers."}
              {activeTab === "settings" &&
                "Live configure platform Razorpay credentials and Meta WhatsApp Cloud API templates."}
            </p>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={fetchData}
              disabled={loading}
              className="flex items-center gap-2 px-3.5 py-2 bg-white border border-slate-200 text-slate-700 rounded-xl hover:bg-slate-50 transition shadow-xs text-sm font-medium"
            >
              <RefreshCw className={`w-4 h-4 text-slate-500 ${loading ? "animate-spin" : ""}`} />
              <span>Refresh</span>
            </button>

            <div className="flex items-center gap-2 px-3 py-1.5 bg-emerald-50 border border-emerald-200 text-emerald-700 rounded-xl text-xs font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              <span>Backend API Live</span>
            </div>
          </div>
        </header>

        {/* ────────────────────────────────────────────────────────────────────────
            TAB 1: END USERS DATA (CUSTOMERS, TENANT ASSOCIATION & EXPIRATION)
        ──────────────────────────────────────────────────────────────────────── */}
        {activeTab === "users" && (
          <div className="space-y-6 animate-in fade-in duration-200">
            {/* KPI Metric Summary Cards */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">Total End Users</span>
                  <Users className="w-5 h-5 text-blue-600" />
                </div>
                <div className="text-2xl font-bold text-slate-900">{members.length}</div>
                <div className="text-xs text-slate-500 mt-1 flex items-center gap-1.5">
                  <span className="text-emerald-600 font-medium">{totalPaidMembers} Paid</span>
                  <span>•</span>
                  <span className="text-rose-600 font-medium">
                    {members.length - totalPaidMembers} Pending
                  </span>
                </div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">Overdue Dues</span>
                  <AlertCircle className="w-5 h-5 text-rose-600" />
                </div>
                <div className="text-2xl font-bold text-rose-600">{totalOverdueMembers}</div>
                <div className="text-xs text-slate-500 mt-1">Payment deadline passed</div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">Due Within 7 Days</span>
                  <Clock className="w-5 h-5 text-amber-600" />
                </div>
                <div className="text-2xl font-bold text-amber-600">{totalDueSoonMembers}</div>
                <div className="text-xs text-slate-500 mt-1">Require immediate WhatsApp reminder</div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">Total Unpaid Amount</span>
                  <IndianRupee className="w-5 h-5 text-emerald-600" />
                </div>
                <div className="text-2xl font-bold text-slate-900">
                  ₹{totalOutstanding.toLocaleString("en-IN")}
                </div>
                <div className="text-xs text-slate-500 mt-1">Directly payable to tenants</div>
              </div>
            </div>

            {/* Filters and Controls */}
            <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-xs flex flex-col md:flex-row items-center justify-between gap-4">
              {/* Search Bar */}
              <div className="relative w-full md:w-80">
                <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  placeholder="Search user, phone, or tenant..."
                  value={userSearch}
                  onChange={(e) => setUserSearch(e.target.value)}
                  className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white text-slate-800"
                />
              </div>

              {/* Filter Tabs & Tenant Selector */}
              <div className="flex flex-wrap items-center gap-2 w-full md:w-auto justify-end">
                {/* Tenant Filter Dropdown */}
                <select
                  value={selectedTenantFilter}
                  onChange={(e) => setSelectedTenantFilter(e.target.value)}
                  className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium text-slate-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option value="ALL">🏢 All Tenants / Facilities</option>
                  {organizations.map((org) => (
                    <option key={org.id} value={org.id}>
                      {org.name}
                    </option>
                  ))}
                </select>

                {/* Status Pills */}
                <div className="inline-flex bg-slate-100 p-1 rounded-xl text-xs font-medium">
                  <button
                    onClick={() => setUserStatusFilter("ALL")}
                    className={`px-3 py-1.5 rounded-lg transition ${
                      userStatusFilter === "ALL"
                        ? "bg-white text-slate-900 shadow-xs font-semibold"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    All ({members.length})
                  </button>
                  <button
                    onClick={() => setUserStatusFilter("DUE_SOON")}
                    className={`px-3 py-1.5 rounded-lg transition ${
                      userStatusFilter === "DUE_SOON"
                        ? "bg-white text-amber-700 shadow-xs font-semibold"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    Due Soon
                  </button>
                  <button
                    onClick={() => setUserStatusFilter("OVERDUE")}
                    className={`px-3 py-1.5 rounded-lg transition ${
                      userStatusFilter === "OVERDUE"
                        ? "bg-white text-rose-700 shadow-xs font-semibold"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    Overdue
                  </button>
                  <button
                    onClick={() => setUserStatusFilter("PAID")}
                    className={`px-3 py-1.5 rounded-lg transition ${
                      userStatusFilter === "PAID"
                        ? "bg-white text-emerald-700 shadow-xs font-semibold"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    Paid
                  </button>
                  <button
                    onClick={() => setUserStatusFilter("FROZEN")}
                    className={`px-3 py-1.5 rounded-lg transition ${
                      userStatusFilter === "FROZEN"
                        ? "bg-white text-sky-700 shadow-xs font-semibold"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    Frozen
                  </button>
                </div>
              </div>
            </div>

            {/* End Users Data Table */}
            <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-50/75 border-b border-slate-200 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                      <th className="py-3.5 px-5">Customer / End User</th>
                      <th className="py-3.5 px-5">Under Which Tenant</th>
                      <th className="py-3.5 px-5">Membership Plan</th>
                      <th className="py-3.5 px-5">Amount Due</th>
                      <th className="py-3.5 px-5">Expire / Days Left</th>
                      <th className="py-3.5 px-5 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 text-sm">
                    {filteredMembers.length === 0 ? (
                      <tr>
                        <td colSpan={6} className="py-12 text-center text-slate-400 text-sm">
                          No end users found matching the selected criteria.
                        </td>
                      </tr>
                    ) : (
                      filteredMembers.map((member) => {
                        const daysInfo = getDaysLeftInfo(member.dueDate, member.status);
                        return (
                          <tr key={member.id} className="hover:bg-slate-50/80 transition-colors">
                            {/* Customer Name & Phone */}
                            <td className="py-4 px-5">
                              <div className="font-semibold text-slate-900">{member.fullName}</div>
                              <div className="flex items-center gap-1.5 text-xs text-slate-500 mt-0.5">
                                <Phone className="w-3 h-3 text-slate-400" />
                                <span>{member.phone}</span>
                              </div>
                            </td>

                            {/* Tenant Association */}
                            <td className="py-4 px-5">
                              <div className="flex items-center gap-2">
                                <span className="w-2 h-2 rounded-full bg-blue-600"></span>
                                <span className="font-medium text-slate-800">
                                  {member.organizationName}
                                </span>
                              </div>
                              <span className="text-[11px] text-slate-400 ml-4">
                                {member.organizationType || "FACILITY"}
                              </span>
                            </td>

                            {/* Plan Name & Group */}
                            <td className="py-4 px-5">
                              <div className="text-slate-800 font-medium">{member.planName}</div>
                              <div className="text-xs text-slate-400">{member.groupName}</div>
                            </td>

                            {/* Amount */}
                            <td className="py-4 px-5">
                              <div className="font-bold text-slate-900">
                                ₹{member.amount.toLocaleString("en-IN")}
                              </div>
                              <div className="text-xs text-slate-400">
                                Cycle: {member.latestMonthYear}
                              </div>
                            </td>

                            {/* Expire / Days Left to Pay */}
                            <td className="py-4 px-5">
                              <div className="flex flex-col items-start gap-1">
                                <span
                                  className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs border ${daysInfo.badgeClass}`}
                                >
                                  {daysInfo.isOverdue && <AlertCircle className="w-3.5 h-3.5" />}
                                  {daysInfo.isDueSoon && <Clock className="w-3.5 h-3.5" />}
                                  {member.status === "PAID" && (
                                    <CheckCircle2 className="w-3.5 h-3.5" />
                                  )}
                                  {member.status === "FROZEN" && (
                                    <Snowflake className="w-3.5 h-3.5" />
                                  )}
                                  <span>{daysInfo.label}</span>
                                </span>

                                {member.dueDate && (
                                  <span className="text-[11px] text-slate-400">
                                    Due: {new Date(member.dueDate).toLocaleDateString("en-IN", {
                                      day: "numeric",
                                      month: "short",
                                      year: "numeric",
                                    })}
                                  </span>
                                )}
                              </div>
                            </td>

                            {/* Actions */}
                            <td className="py-4 px-5 text-right">
                              <div className="flex items-center justify-end gap-2">
                                <button
                                  onClick={() => setSelectedMemberModal(member)}
                                  className="px-2.5 py-1.5 text-xs font-medium bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg transition"
                                  title="View User Details"
                                >
                                  Details
                                </button>

                                {member.status === "UNPAID" && (
                                  <button
                                    onClick={() => handleSendReminder(member)}
                                    className="flex items-center gap-1 px-2.5 py-1.5 text-xs font-semibold bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 rounded-lg transition shadow-2xs"
                                    title="Send Automated WhatsApp Reminder with Direct UPI Link"
                                  >
                                    <Send className="w-3 h-3" />
                                    <span>Remind</span>
                                  </button>
                                )}
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* ────────────────────────────────────────────────────────────────────────
            TAB 2: TENANTS (FACILITIES) & SUBSCRIPTION PLANS
        ──────────────────────────────────────────────────────────────────────── */}
        {activeTab === "tenants" && (
          <div className="space-y-8 animate-in fade-in duration-200">
            {/* Tenant Overview Stats */}
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    Total Facilities / Tenants
                  </span>
                  <Building2 className="w-5 h-5 text-blue-600" />
                </div>
                <div className="text-2xl font-bold text-slate-900">{organizations.length}</div>
                <div className="text-xs text-slate-500 mt-1">Gyms, Hostels & PGs</div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    Subscribed Facilities
                  </span>
                  <ShieldCheck className="w-5 h-5 text-emerald-600" />
                </div>
                <div className="text-2xl font-bold text-emerald-600">
                  {organizations.filter((o) => o.selectedAppPlanId || o.subscriptionCredit).length}
                </div>
                <div className="text-xs text-slate-500 mt-1">Active app subscriptions</div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    App Subscription Plans
                  </span>
                  <Layers className="w-5 h-5 text-indigo-600" />
                </div>
                <div className="text-2xl font-bold text-slate-900">{appPlans.length}</div>
                <div className="text-xs text-slate-500 mt-1">Available for tenants</div>
              </div>

              <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
                <div className="flex items-center justify-between text-slate-500 mb-2">
                  <span className="text-xs font-semibold uppercase tracking-wider">
                    Direct Payout Configured
                  </span>
                  <QrCode className="w-5 h-5 text-amber-600" />
                </div>
                <div className="text-2xl font-bold text-slate-900">
                  {organizations.filter((o) => o.bankUpiId).length}
                </div>
                <div className="text-xs text-slate-500 mt-1">Tenants with UPI payout enabled</div>
              </div>
            </div>

            {/* SECTION 1: All Tenants / Facilities Table */}
            <div className="space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                  <h3 className="text-lg font-bold text-slate-900 tracking-tight">
                    Registered Facilities & Direct Payout Details
                  </h3>
                  <p className="text-xs text-slate-500">
                    Each tenant uses the mobile app to manage their members and collect payments
                    directly via UPI.
                  </p>
                </div>

                <div className="relative w-full sm:w-72">
                  <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Search facility or owner..."
                    value={tenantSearch}
                    onChange={(e) => setTenantSearch(e.target.value)}
                    className="w-full pl-9 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 text-slate-800"
                  />
                </div>
              </div>

              <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
                <div className="overflow-x-auto">
                  <table className="w-full text-left border-collapse">
                    <thead>
                      <tr className="bg-slate-50/75 border-b border-slate-200 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                        <th className="py-3.5 px-5">Facility / Tenant Name</th>
                        <th className="py-3.5 px-5">Admin / Contact</th>
                        <th className="py-3.5 px-5">Direct Payout Account (UPI)</th>
                        <th className="py-3.5 px-5">Subscription Plan</th>
                        <th className="py-3.5 px-5">WhatsApp Credits</th>
                        <th className="py-3.5 px-5 text-right">Actions</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100 text-sm">
                      {filteredOrganizations.length === 0 ? (
                        <tr>
                          <td colSpan={6} className="py-10 text-center text-slate-400 text-sm">
                            No facilities found.
                          </td>
                        </tr>
                      ) : (
                        filteredOrganizations.map((org) => {
                          const primaryUser = org.users[0];
                          const credits = org.subscriptionCredit;
                          const availableCredits = credits
                            ? Math.max(0, credits.purchasedCredits - credits.usedCredits)
                            : 0;

                          return (
                            <tr key={org.id} className="hover:bg-slate-50/80 transition-colors">
                              {/* Tenant Name & Type */}
                              <td className="py-4 px-5">
                                <div className="font-semibold text-slate-900">{org.name}</div>
                                <div className="flex items-center gap-2 mt-0.5">
                                  <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded bg-slate-100 text-slate-600">
                                    {org.type}
                                  </span>
                                  <span className="text-xs text-slate-400">
                                    {org._count?.members || 0} members
                                  </span>
                                </div>
                              </td>

                              {/* Owner Contact */}
                              <td className="py-4 px-5">
                                {primaryUser ? (
                                  <div>
                                    <div className="font-medium text-slate-800">
                                      {primaryUser.name || "Administrator"}
                                    </div>
                                    <div className="text-xs text-slate-500">
                                      {primaryUser.phone || primaryUser.email}
                                    </div>
                                  </div>
                                ) : (
                                  <span className="text-xs text-slate-400 italic">No admin user</span>
                                )}
                              </td>

                              {/* Direct UPI Payout */}
                              <td className="py-4 px-5">
                                {org.bankUpiId ? (
                                  <div>
                                    <div className="flex items-center gap-1.5 font-mono text-xs font-semibold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-md border border-emerald-200 w-fit">
                                      <QrCode className="w-3.5 h-3.5 text-emerald-600" />
                                      <span>{org.bankUpiId}</span>
                                    </div>
                                    {org.bankAccountName && (
                                      <div className="text-[11px] text-slate-400 mt-1">
                                        Name: {org.bankAccountName}
                                      </div>
                                    )}
                                  </div>
                                ) : (
                                  <span className="text-xs text-amber-600 font-medium flex items-center gap-1">
                                    <AlertCircle className="w-3.5 h-3.5" />
                                    Not Set (Pending Setup)
                                  </span>
                                )}
                              </td>

                              {/* Active Subscription Plan */}
                              <td className="py-4 px-5">
                                {org.selectedAppPlan ? (
                                  <div>
                                    <span className="inline-flex items-center gap-1 font-semibold text-xs px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 border border-blue-200">
                                      <Zap className="w-3 h-3 text-blue-600" />
                                      {org.selectedAppPlan.name}
                                    </span>
                                    <div className="text-[11px] text-slate-500 mt-1">
                                      ₹{org.selectedAppPlan.price} / {org.selectedAppPlan.durationMonths}m
                                    </div>
                                  </div>
                                ) : credits ? (
                                  <span className="inline-flex items-center text-xs font-semibold px-2.5 py-1 rounded-full bg-slate-100 text-slate-700">
                                    {credits.subscriptionName || "Plus Trial"}
                                  </span>
                                ) : (
                                  <span className="text-xs text-slate-400 italic">No Active Plan</span>
                                )}
                              </td>

                              {/* WhatsApp Credits Balance */}
                              <td className="py-4 px-5">
                                <div className="flex items-center gap-2">
                                  <div className="w-7 h-7 rounded-lg bg-emerald-100 text-emerald-700 flex items-center justify-center font-bold text-xs">
                                    {availableCredits}
                                  </div>
                                  <div className="text-xs text-slate-500">
                                    <div>Credits Remaining</div>
                                    <div className="text-[10px] text-slate-400">
                                      Used: {credits?.usedCredits || 0}
                                    </div>
                                  </div>
                                </div>
                              </td>

                              {/* Action: Assign / Change Plan */}
                              <td className="py-4 px-5 text-right">
                                <button
                                  onClick={() => {
                                    setAssignPlanModalOrg(org);
                                    setSelectedPlanToAssign(org.selectedAppPlanId || "");
                                  }}
                                  className="px-3 py-1.5 text-xs font-semibold bg-blue-50 hover:bg-blue-100 text-blue-700 border border-blue-200 rounded-lg transition"
                                >
                                  Assign Plan
                                </button>
                              </td>
                            </tr>
                          );
                        })
                      )}
                    </tbody>
                  </table>
                </div>
              </div>
            </div>

            {/* SECTION 2: Platform App Subscription Plans Config */}
            <div className="pt-6 border-t border-slate-200 space-y-4">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
                <div>
                  <h3 className="text-lg font-bold text-slate-900 tracking-tight">
                    Platform App Subscription Plans
                  </h3>
                  <p className="text-xs text-slate-500">
                    Pricing tiers for mobile app users (tenants). Each subscription plan includes
                    compulsory WhatsApp credits.
                  </p>
                </div>

                <button
                  onClick={() => {
                    setEditingAppPlan(null);
                    setAppPlanForm({
                      name: "",
                      price: 0,
                      tag: "",
                      description: "",
                      durationMonths: 1,
                      whatsappCredits: 100,
                      isFreeTrial: false,
                      isActive: true,
                    });
                    setShowAppPlanModal(true);
                  }}
                  className="flex items-center gap-2 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-semibold transition shadow-sm"
                >
                  <Plus className="w-4 h-4" />
                  <span>Create Subscription Plan</span>
                </button>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
                {appPlans.map((plan) => (
                  <div
                    key={plan.id}
                    className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs flex flex-col justify-between relative hover:border-slate-300 transition"
                  >
                    {plan.tag && (
                      <span className="absolute top-5 right-5 text-[10px] uppercase font-extrabold px-2 py-0.5 rounded-full bg-blue-100 text-blue-700">
                        {plan.tag}
                      </span>
                    )}

                    <div>
                      <h4 className="text-lg font-bold text-slate-900">{plan.name}</h4>
                      <p className="text-xs text-slate-500 mt-1 min-h-[32px]">{plan.description}</p>

                      <div className="my-5 pb-5 border-b border-slate-100">
                        <div className="flex items-baseline gap-1">
                          <span className="text-3xl font-extrabold text-slate-900">₹{plan.price}</span>
                          <span className="text-xs text-slate-400">
                            / {plan.durationMonths} {plan.durationMonths === 1 ? "month" : "months"}
                          </span>
                        </div>
                      </div>

                      <div className="space-y-2.5 text-xs text-slate-600">
                        <div className="flex items-center gap-2 font-semibold text-emerald-700 bg-emerald-50 px-3 py-2 rounded-xl border border-emerald-200">
                          <Sparkles className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                          <span>{plan.whatsappCredits} WhatsApp Credits Included</span>
                        </div>
                        <div className="flex items-center gap-2 text-slate-600 px-1">
                          <Check className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                          <span>Full mobile facility admin app access</span>
                        </div>
                        <div className="flex items-center gap-2 text-slate-600 px-1">
                          <Check className="w-4 h-4 text-emerald-600 flex-shrink-0" />
                          <span>Direct UPI customer reminders & receipts</span>
                        </div>
                      </div>
                    </div>

                    <div className="mt-6 pt-4 border-t border-slate-100 flex items-center justify-between">
                      <span
                        className={`text-xs font-semibold px-2 py-0.5 rounded ${
                          plan.isActive ? "bg-emerald-100 text-emerald-800" : "bg-slate-100 text-slate-500"
                        }`}
                      >
                        {plan.isActive ? "Active Plan" : "Draft"}
                      </span>

                      <button
                        onClick={() => {
                          setEditingAppPlan(plan);
                          setAppPlanForm({
                            name: plan.name,
                            price: plan.price,
                            tag: plan.tag || "",
                            description: plan.description,
                            durationMonths: plan.durationMonths,
                            whatsappCredits: plan.whatsappCredits,
                            isFreeTrial: plan.isFreeTrial,
                            isActive: plan.isActive,
                          });
                          setShowAppPlanModal(true);
                        }}
                        className="p-2 text-slate-400 hover:text-slate-800 hover:bg-slate-100 rounded-lg transition"
                        title="Edit Plan"
                      >
                        <Edit3 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* ────────────────────────────────────────────────────────────────────────
            TAB 3: PLATFORM & WHATSAPP SETTINGS
        ──────────────────────────────────────────────────────────────────────── */}
        {activeTab === "settings" && (
          <div className="space-y-8 animate-in fade-in duration-200 max-w-5xl">
            {/* Form for System Settings */}
            <form onSubmit={handleSaveSettings} className="space-y-8">
              {/* Card 1: Platform Razorpay Credentials */}
              <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs space-y-5">
                <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center font-bold">
                      <CreditCard className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="text-base font-bold text-slate-900">
                        Platform Razorpay Gateway Credentials
                      </h3>
                      <p className="text-xs text-slate-500">
                        Used for collecting Tenant App Subscriptions (e.g. Starter & Pro subscription fees).
                      </p>
                    </div>
                  </div>

                  <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                    Live Active
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                      Platform Razorpay Key ID
                    </label>
                    <input
                      type="text"
                      value={systemSettings.RAZORPAY_KEY_ID || ""}
                      onChange={(e) =>
                        setSystemSettings({ ...systemSettings, RAZORPAY_KEY_ID: e.target.value })
                      }
                      placeholder="Enter Razorpay Key ID"
                      className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-slate-800"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                      Platform Razorpay Key Secret
                    </label>
                    <div className="relative">
                      <input
                        type={showRazorpaySecret ? "text" : "password"}
                        value={systemSettings.RAZORPAY_KEY_SECRET || ""}
                        onChange={(e) =>
                          setSystemSettings({ ...systemSettings, RAZORPAY_KEY_SECRET: e.target.value })
                        }
                        placeholder="Enter Razorpay Key Secret"
                        className="w-full pl-3.5 pr-10 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-slate-800"
                      />
                      <button
                        type="button"
                        onClick={() => setShowRazorpaySecret(!showRazorpaySecret)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      >
                        {showRazorpaySecret ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>
                </div>
              </div>

              {/* Card 2: Meta WhatsApp Cloud API Settings */}
              <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs space-y-5">
                <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-600 flex items-center justify-center font-bold">
                      <Send className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="text-base font-bold text-slate-900">
                        Meta WhatsApp Cloud API Configuration
                      </h3>
                      <p className="text-xs text-slate-500">
                        Official Meta Cloud API credentials used for sending OTPs, rent reminders, and receipts.
                      </p>
                    </div>
                  </div>

                  <span className="text-xs font-semibold px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                    Meta Graph v20.0
                  </span>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                      WhatsApp Phone Number ID
                    </label>
                    <input
                      type="text"
                      value={systemSettings.WHATSAPP_PHONE_NUMBER_ID || ""}
                      onChange={(e) =>
                        setSystemSettings({
                          ...systemSettings,
                          WHATSAPP_PHONE_NUMBER_ID: e.target.value,
                        })
                      }
                      placeholder="Enter WhatsApp Phone Number ID"
                      className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-slate-800"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                      WhatsApp Business Account ID (WABA ID)
                    </label>
                    <input
                      type="text"
                      value={systemSettings.WHATSAPP_BUSINESS_ACCOUNT_ID || ""}
                      onChange={(e) =>
                        setSystemSettings({
                          ...systemSettings,
                          WHATSAPP_BUSINESS_ACCOUNT_ID: e.target.value,
                        })
                      }
                      placeholder="Enter WhatsApp Business Account ID"
                      className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-slate-800"
                    />
                  </div>

                  <div className="md:col-span-2">
                    <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                      Meta Permanent System User Access Token
                    </label>
                    <div className="relative">
                      <input
                        type={showWaToken ? "text" : "password"}
                        value={systemSettings.WHATSAPP_ACCESS_TOKEN || ""}
                        onChange={(e) =>
                          setSystemSettings({
                            ...systemSettings,
                            WHATSAPP_ACCESS_TOKEN: e.target.value,
                          })
                        }
                        placeholder="Paste Permanent System User Access Token"
                        className="w-full pl-3.5 pr-10 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 font-mono text-slate-800"
                      />
                      <button
                        type="button"
                        onClick={() => setShowWaToken(!showWaToken)}
                        className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                      >
                        {showWaToken ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                      </button>
                    </div>
                  </div>
                </div>

                <div className="flex justify-end pt-2">
                  <button
                    type="submit"
                    disabled={savingSettings}
                    className="flex items-center gap-2 px-5 py-2.5 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-xl text-sm transition shadow-sm"
                  >
                    <Save className="w-4 h-4" />
                    <span>{savingSettings ? "Saving Settings..." : "Save Credentials"}</span>
                  </button>
                </div>
              </div>
            </form>

            {/* Card 3: WhatsApp Templates Manager (Editable Meta IDs) */}
            <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-xs space-y-5">
              <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 pb-4 border-b border-slate-100">
                <div>
                  <h3 className="text-base font-bold text-slate-900">
                    Meta WhatsApp Templates Manager
                  </h3>
                  <p className="text-xs text-slate-500">
                    Pre-seeded templates. When Meta approves your templates, paste your approved Meta
                    Template IDs below and save directly without touching any code!
                  </p>
                </div>

                <button
                  onClick={() => {
                    setEditingTemplate(null);
                    setTemplateForm({
                      name: "",
                      templateId: "",
                      templateType: "REMINDER",
                      category: "UTILITY",
                      language: "en",
                      messageText: "",
                      isActive: true,
                    });
                    setShowTemplateModal(true);
                  }}
                  className="flex items-center gap-1.5 px-3.5 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl text-xs font-semibold transition"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Add Template</span>
                </button>
              </div>

              <div className="space-y-3">
                {templates.map((tpl) => (
                  <div
                    key={tpl.id}
                    className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 hover:bg-white hover:shadow-xs transition space-y-3"
                  >
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                      <div className="flex items-center gap-2.5">
                        <span className="font-bold text-sm text-slate-900">{tpl.name}</span>
                        <span className="text-[10px] font-bold uppercase px-2 py-0.5 rounded bg-blue-100 text-blue-700">
                          {tpl.category || "UTILITY"}
                        </span>
                        <span className="text-[10px] uppercase px-1.5 py-0.5 rounded bg-slate-200 text-slate-700 font-medium">
                          {tpl.language}
                        </span>
                      </div>

                      {/* Meta Template ID with Inline Edit */}
                      <div className="flex items-center gap-2">
                        <label className="text-xs text-slate-500 font-medium">Meta Template ID:</label>
                        <input
                          type="text"
                          defaultValue={tpl.templateId || ""}
                          onBlur={(e) => {
                            if (e.target.value !== tpl.templateId) {
                              handleUpdateTemplateId(tpl.id, e.target.value);
                            }
                          }}
                          className="px-2.5 py-1 bg-white border border-slate-300 rounded-lg text-xs font-mono text-slate-800 focus:outline-none focus:ring-2 focus:ring-blue-500 w-48"
                          placeholder="Enter Meta Template ID"
                        />
                      </div>
                    </div>

                    <div className="text-xs text-slate-600 bg-white p-3 rounded-lg border border-slate-200 font-sans leading-relaxed">
                      {tpl.messageText}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </main>

      {/* ──────────────────────────────────────────────────────────────────────────
          MODAL: Assign Subscription Plan to Facility Tenant
      ────────────────────────────────────────────────────────────────────────── */}
      {assignPlanModalOrg && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-slate-200 space-y-5 animate-in zoom-in-95">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <h3 className="font-bold text-base text-slate-900">
                Assign Subscription Plan
              </h3>
              <button
                onClick={() => setAssignPlanModalOrg(null)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div>
              <p className="text-xs text-slate-500 mb-3">
                Select a platform subscription tier for{" "}
                <span className="font-semibold text-slate-800">{assignPlanModalOrg.name}</span>.
                Compulsory WhatsApp credits will be credited to their account.
              </p>

              <label className="block text-xs font-semibold text-slate-700 mb-1.5">
                Available Subscription Plans
              </label>
              <select
                value={selectedPlanToAssign}
                onChange={(e) => setSelectedPlanToAssign(e.target.value)}
                className="w-full px-3.5 py-2.5 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 text-slate-800"
              >
                <option value="">-- Choose Plan --</option>
                {appPlans.map((plan) => (
                  <option key={plan.id} value={plan.id}>
                    {plan.name} (₹{plan.price} / {plan.durationMonths}m) • {plan.whatsappCredits} Credits
                  </option>
                ))}
              </select>
            </div>

            <div className="flex justify-end gap-2 pt-3 border-t border-slate-100">
              <button
                onClick={() => setAssignPlanModalOrg(null)}
                className="px-4 py-2 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                onClick={handleAssignPlan}
                disabled={!selectedPlanToAssign}
                className="px-4 py-2 text-xs font-bold bg-blue-600 hover:bg-blue-700 disabled:opacity-50 text-white rounded-xl shadow-xs"
              >
                Confirm Assignment
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ──────────────────────────────────────────────────────────────────────────
          MODAL: Create / Edit Platform App Subscription Plan
      ────────────────────────────────────────────────────────────────────────── */}
      {showAppPlanModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-xl border border-slate-200 space-y-5 animate-in zoom-in-95">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <h3 className="font-bold text-base text-slate-900">
                {editingAppPlan ? "Edit Subscription Plan" : "Create Subscription Plan"}
              </h3>
              <button
                onClick={() => setShowAppPlanModal(false)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveAppPlan} className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div className="col-span-2">
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Plan Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={appPlanForm.name}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, name: e.target.value })}
                    placeholder="e.g. Starter Plan, Pro Annual"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Price (₹) *
                  </label>
                  <input
                    type="number"
                    min="0"
                    required
                    value={appPlanForm.price}
                    onChange={(e) =>
                      setAppPlanForm({ ...appPlanForm, price: Number(e.target.value) })
                    }
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Duration (Months) *
                  </label>
                  <input
                    type="number"
                    min="1"
                    required
                    value={appPlanForm.durationMonths}
                    onChange={(e) =>
                      setAppPlanForm({ ...appPlanForm, durationMonths: Number(e.target.value) })
                    }
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                {/* COMPULSORY WHATSAPP CREDITS */}
                <div className="col-span-2">
                  <label className="block text-xs font-bold text-emerald-800 mb-1 flex items-center justify-between">
                    <span>WhatsApp Credits Quota * (Compulsory)</span>
                    <span className="text-[10px] font-normal text-emerald-600">
                      Required for automated messages
                    </span>
                  </label>
                  <input
                    type="number"
                    min="0"
                    required
                    value={appPlanForm.whatsappCredits}
                    onChange={(e) =>
                      setAppPlanForm({ ...appPlanForm, whatsappCredits: Number(e.target.value) })
                    }
                    placeholder="e.g. 100, 500, 1500"
                    className="w-full px-3 py-2 bg-emerald-50/50 border border-emerald-300 rounded-xl text-sm font-semibold text-emerald-900 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>

                <div className="col-span-2">
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Badge / Tag (Optional)
                  </label>
                  <input
                    type="text"
                    value={appPlanForm.tag}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, tag: e.target.value })}
                    placeholder="e.g. Most Popular, Default, Special"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>

                <div className="col-span-2">
                  <label className="block text-xs font-semibold text-slate-700 mb-1">
                    Description *
                  </label>
                  <textarea
                    required
                    rows={2}
                    value={appPlanForm.description}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, description: e.target.value })}
                    placeholder="Brief description of features included in this plan..."
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-2 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setShowAppPlanModal(false)}
                  className="px-4 py-2 text-xs font-medium text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={savingAppPlan}
                  className="px-4 py-2 text-xs font-bold bg-blue-600 hover:bg-blue-700 text-white rounded-xl shadow-xs"
                >
                  {savingAppPlan ? "Saving..." : "Save Plan"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ──────────────────────────────────────────────────────────────────────────
          MODAL: Member Details Quick View
      ────────────────────────────────────────────────────────────────────────── */}
      {selectedMemberModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/50 backdrop-blur-xs flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-xl border border-slate-200 space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <h3 className="font-bold text-base text-slate-900">Customer Profile</h3>
              <button
                onClick={() => setSelectedMemberModal(null)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3 text-xs">
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Customer Name</span>
                <span className="font-bold text-slate-900">{selectedMemberModal.fullName}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Phone Number</span>
                <span className="font-mono text-slate-800">{selectedMemberModal.phone}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Associated Tenant</span>
                <span className="font-semibold text-blue-700">
                  {selectedMemberModal.organizationName}
                </span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Membership Plan</span>
                <span className="text-slate-800">{selectedMemberModal.planName}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Assigned Batch / Group</span>
                <span className="text-slate-800">{selectedMemberModal.groupName}</span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Amount Due</span>
                <span className="font-bold text-slate-900 text-sm">
                  ₹{selectedMemberModal.amount}
                </span>
              </div>
              <div className="flex justify-between py-1.5 border-b border-slate-50">
                <span className="text-slate-500 font-medium">Schedule Expiration</span>
                <span className="font-semibold text-slate-800">
                  {getDaysLeftInfo(selectedMemberModal.dueDate, selectedMemberModal.status).label}
                </span>
              </div>
            </div>

            <div className="pt-3 border-t border-slate-100 flex justify-end">
              <button
                onClick={() => setSelectedMemberModal(null)}
                className="px-4 py-2 text-xs font-semibold bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
