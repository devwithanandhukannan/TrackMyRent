"use client";

import React, { useState, useEffect } from "react";
import {
  Users,
  CheckCircle,
  AlertCircle,
  Snowflake,
  IndianRupee,
  TrendingUp,
  MessageSquare,
  Plus,
  Settings,
  Layers,
  FileText,
  BarChart3,
  Calendar,
  Phone,
  Search,
  RefreshCw,
  LogOut,
  X,
  Lock,
  UserCheck,
  Save,
  Key,
  Edit3,
  Trash2,
  ToggleLeft,
  ToggleRight,
  Sparkles,
  Tag,
  ShieldCheck,
} from "lucide-react";

const API_BASE_URL = "http://localhost:5001/api";

interface Member {
  id: string;
  fullName: string;
  phone: string;
  planName: string;
  groupName: string;
  duration: string;
  status: "PAID" | "UNPAID" | "FROZEN";
  amount: number;
  latestMonthYear: string;
}

interface FinancialSummary {
  totalIncome: number;
  totalExpenses: number;
  netProfit: number;
  totalPendingDues: number;
  collectionRate: number;
}

interface Plan {
  id: string;
  name: string;
  price: number;
  durationDays: number;
  groups: { id: string; name: string }[];
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

export default function AdminDashboard() {
  // Auth state
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [loginMode, setLoginMode] = useState<"OTP" | "PASSWORD">("OTP");
  const [loginPhone, setLoginPhone] = useState("9876543210");
  const [loginOtp, setLoginOtp] = useState("123456");
  const [otpSent, setOtpSent] = useState(false);
  const [isNewUser, setIsNewUser] = useState(false);
  const [regOrgName, setRegOrgName] = useState("");
  const [regAdminName, setRegAdminName] = useState("");
  const [regOrgType, setRegOrgType] = useState("GYM");

  const [loginEmail, setLoginEmail] = useState("admin");
  const [loginPassword, setLoginPassword] = useState("admin");
  const [loginError, setLoginError] = useState("");
  const [authOrg, setAuthOrg] = useState<{ id: string; name: string; type?: string } | null>(null);

  // Tab & Filter states
  const [activeTab, setActiveTab] = useState<"members" | "plans" | "expenses" | "reports" | "custom_fields" | "app_subscription_plans" | "facilities" | "settings">("members");
  const [statusFilter, setStatusFilter] = useState<"ALL" | "PAID" | "UNPAID" | "FROZEN">("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(false);
  const [allOrgs, setAllOrgs] = useState<any[]>([]);

  // Data states
  const [summary, setSummary] = useState<FinancialSummary>({
    totalIncome: 0,
    totalExpenses: 0,
    netProfit: 0,
    totalPendingDues: 0,
    collectionRate: 100,
  });
  const [members, setMembers] = useState<Member[]>([]);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [appPlans, setAppPlans] = useState<AppSubscriptionPlan[]>([]);
  const [whatsappCredits, setWhatsappCredits] = useState<number>(100);

  // App Plan Modal state
  const [showAppPlanModal, setShowAppPlanModal] = useState(false);
  const [editingAppPlan, setEditingAppPlan] = useState<AppSubscriptionPlan | null>(null);
  const [appPlanForm, setAppPlanForm] = useState({
    name: "",
    price: 0,
    tag: "",
    description: "",
    durationMonths: 1,
    whatsappCredits: 100,
    isFreeTrial: false,
    isActive: true,
    sortOrder: 1,
  });

  // Settings state
  const [platformSettings, setPlatformSettings] = useState<SystemSettingsMap>({
    RAZORPAY_KEY_ID: "",
    RAZORPAY_KEY_SECRET: "",
    WHATSAPP_PHONE_NUMBER_ID: "",
    WHATSAPP_BUSINESS_ACCOUNT_ID: "",
    WHATSAPP_ACCESS_TOKEN: "",
    WHATSAPP_API_VERSION: "v20.0",
    WHATSAPP_WEBHOOK_SECRET: "",
  });
  const [settingsSaving, setSettingsSaving] = useState(false);
  const [settingsNotice, setSettingsNotice] = useState("");

  // WhatsApp Templates state
  const [templates, setTemplates] = useState<WhatsAppTemplateItem[]>([]);
  const [editingTemplate, setEditingTemplate] = useState<WhatsAppTemplateItem | null>(null);
  const [showTemplateModal, setShowTemplateModal] = useState(false);
  const [templateForm, setTemplateForm] = useState({
    name: "",
    templateId: "",
    templateType: "RENT_REMINDER",
    category: "UTILITY",
    language: "en",
    messageText: "",
    isActive: true,
  });

  // Add Member Modal state
  const [showAddMemberModal, setShowAddMemberModal] = useState(false);
  const [addMemberLoading, setAddMemberLoading] = useState(false);
  const [newFullName, setNewFullName] = useState("");
  const [newPhone, setNewPhone] = useState("");
  const [selectedPlanId, setSelectedPlanId] = useState("");
  const [selectedGroupId, setSelectedGroupId] = useState("");
  const [newDuration, setNewDuration] = useState("30 Days");
  const [newJoiningDate, setNewJoiningDate] = useState(new Date().toISOString().split("T")[0]);
  const [newDob, setNewDob] = useState("");
  const [newNotes, setNewNotes] = useState("");
  const [customAadhaar, setCustomAadhaar] = useState("");
  const [customAddress, setCustomAddress] = useState("");
  const [customEmergencyPhone, setCustomEmergencyPhone] = useState("");

  // Settings Modal state (WhatsApp Cloud API App ID, Token, Phone ID)
  const [showSettingsModal, setShowSettingsModal] = useState(false);
  const [settingsLoading, setSettingsLoading] = useState(false);
  const [waAppId, setWaAppId] = useState("");
  const [waPhoneId, setWaPhoneId] = useState("");
  const [waToken, setWaToken] = useState("");
  const [waBusinessId, setWaBusinessId] = useState("");

  // Check saved session on mount
  useEffect(() => {
    const savedToken = localStorage.getItem("renttrack_token");
    const savedOrg = localStorage.getItem("renttrack_org");
    if (savedToken && savedOrg) {
      setIsAuthenticated(true);
      const parsedOrg = JSON.parse(savedOrg);
      setAuthOrg(parsedOrg);
      fetchDashboardData(parsedOrg.id);
      fetchWhatsAppSettings(parsedOrg.id);
      fetchOrganizationsList();
      fetchPlatformSettings();
      fetchWhatsAppTemplates();
    }
  }, []);

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError("");
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/auth/send-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phone: loginPhone }),
      });
      const data = await res.json();
      if (!res.ok) {
        setLoginError(data.error || "Failed to send OTP");
        return;
      }
      setOtpSent(true);
      setIsNewUser(data.isNewUser || false);
      setLoginOtp(data.otp || "123456");
      if (data.existingUser) {
        setRegAdminName(data.existingUser.name || "");
        setRegOrgName(data.existingUser.orgName || "");
      }
    } catch (err) {
      setLoginError("Could not connect to backend server.");
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError("");
    setLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/auth/verify-otp`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          phone: loginPhone,
          otp: loginOtp,
          orgName: regOrgName,
          adminName: regAdminName,
          orgType: regOrgType,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setLoginError(data.error || "OTP verification failed");
        return;
      }
      localStorage.setItem("renttrack_token", data.token);
      localStorage.setItem("renttrack_org", JSON.stringify(data.organization));
      setIsAuthenticated(true);
      setAuthOrg(data.organization);
      fetchDashboardData(data.organization.id);
      fetchWhatsAppSettings(data.organization.id);
      fetchOrganizationsList();
    } catch (err) {
      setLoginError("Could not verify OTP.");
    } finally {
      setLoading(false);
    }
  };

  // Password Login handler
  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError("");
    setLoading(true);

    try {
      const res = await fetch(`${API_BASE_URL}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email: loginEmail, password: loginPassword }),
      });

      const data = await res.json();
      if (!res.ok) {
        setLoginError(data.error || "Login failed");
        return;
      }

      localStorage.setItem("renttrack_token", data.token);
      localStorage.setItem("renttrack_org", JSON.stringify(data.organization));
      setIsAuthenticated(true);
      setAuthOrg(data.organization);
      fetchDashboardData(data.organization.id);
      fetchWhatsAppSettings(data.organization.id);
      fetchOrganizationsList();
    } catch (err) {
      setLoginError("Could not connect to backend server. Make sure backend is running on port 5001.");
    } finally {
      setLoading(false);
    }
  };

  const fetchOrganizationsList = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/auth/organizations`);
      if (res.ok) {
        const data = await res.json();
        setAllOrgs(data.organizations || []);
      }
    } catch (err) {
      console.error("Failed to fetch organizations list:", err);
    }
  };

  const switchFacility = (org: any) => {
    localStorage.setItem("renttrack_org", JSON.stringify(org));
    setAuthOrg(org);
    fetchDashboardData(org.id);
    fetchWhatsAppSettings(org.id);
  };


  const handleLogout = () => {
    localStorage.removeItem("renttrack_token");
    localStorage.removeItem("renttrack_org");
    setIsAuthenticated(false);
    setAuthOrg(null);
  };

  // Fetch Dashboard data
  const fetchDashboardData = async (orgId: string) => {
    setLoading(true);
    try {
      const resSummary = await fetch(`${API_BASE_URL}/reports/summary?organizationId=${orgId}`);
      if (resSummary.ok) {
        const dataSummary = await resSummary.json();
        setSummary(dataSummary.summary);
      }

      const resMembers = await fetch(`${API_BASE_URL}/members?organizationId=${orgId}`);
      if (resMembers.ok) {
        const dataMembers = await resMembers.json();
        setMembers(dataMembers.members || []);
      }

      const resPlans = await fetch(`${API_BASE_URL}/plans?organizationId=${orgId}`);
      if (resPlans.ok) {
        const dataPlans = await resPlans.json();
        setPlans(dataPlans.plans || []);
      }

      const resCredits = await fetch(`${API_BASE_URL}/credits/${orgId}`);
      if (resCredits.ok) {
        const dataCredits = await resCredits.json();
        setWhatsappCredits(dataCredits.credits?.availableCredits ?? 100);
      }

      await fetchAppPlans();
    } catch (err) {
      console.error("API Fetch Error:", err);
    } finally {
      setLoading(false);
    }
  };

  // Fetch App Subscription Plans (Admin feature)
  const fetchAppPlans = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/app-plans?includeDisabled=true`);
      if (res.ok) {
        const data = await res.json();
        setAppPlans(data.data || []);
      }
    } catch (err) {
      console.error("Failed to fetch app plans:", err);
    }
  };

  const handleOpenCreateAppPlan = () => {
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
      sortOrder: appPlans.length + 1,
    });
    setShowAppPlanModal(true);
  };

  const handleOpenEditAppPlan = (plan: AppSubscriptionPlan) => {
    setEditingAppPlan(plan);
    setAppPlanForm({
      name: plan.name,
      price: plan.price,
      tag: plan.tag || "",
      description: plan.description,
      durationMonths: plan.durationMonths,
      whatsappCredits: plan.whatsappCredits !== undefined ? plan.whatsappCredits : 100,
      isFreeTrial: plan.isFreeTrial,
      isActive: plan.isActive,
      sortOrder: plan.sortOrder,
    });
    setShowAppPlanModal(true);
  };

  const handleSaveAppPlan = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const url = editingAppPlan
        ? `${API_BASE_URL}/app-plans/${editingAppPlan.id}`
        : `${API_BASE_URL}/app-plans`;
      const method = editingAppPlan ? "PUT" : "POST";

      const res = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(appPlanForm),
      });

      if (res.ok) {
        setShowAppPlanModal(false);
        fetchAppPlans();
      } else {
        const errData = await res.json();
        alert(errData.error || "Failed to save plan");
      }
    } catch (err) {
      alert("Error saving app subscription plan");
    }
  };

  const handleToggleAppPlan = async (id: string) => {
    try {
      const res = await fetch(`${API_BASE_URL}/app-plans/${id}/toggle`, {
        method: "PATCH",
      });
      if (res.ok) {
        fetchAppPlans();
      }
    } catch (err) {
      alert("Error toggling plan status");
    }
  };

  const handleDeleteAppPlan = async (id: string) => {
    if (!window.confirm("Are you sure you want to delete this app subscription plan?")) return;
    try {
      const res = await fetch(`${API_BASE_URL}/app-plans/${id}`, {
        method: "DELETE",
      });
      if (res.ok) {
        fetchAppPlans();
      }
    } catch (err) {
      alert("Error deleting plan");
    }
  };

  // Fetch System Settings (Platform Razorpay & Meta WhatsApp Cloud API)
  const fetchPlatformSettings = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/settings`);
      if (res.ok) {
        const data = await res.json();
        setPlatformSettings((prev) => ({ ...prev, ...(data.settings || {}) }));
      }
    } catch (err) {
      console.error("Failed to fetch platform settings:", err);
    }
  };

  const handleSavePlatformSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    setSettingsSaving(true);
    setSettingsNotice("");
    try {
      const res = await fetch(`${API_BASE_URL}/settings`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ settings: platformSettings }),
      });
      if (res.ok) {
        setSettingsNotice("Platform settings saved successfully! Keys are now live.");
        setTimeout(() => setSettingsNotice(""), 4000);
      } else {
        alert("Failed to save settings");
      }
    } catch (err) {
      alert("Error saving settings");
    } finally {
      setSettingsSaving(false);
    }
  };

  // Fetch WhatsApp Templates
  const fetchWhatsAppTemplates = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/settings/whatsapp-templates`);
      if (res.ok) {
        const data = await res.json();
        setTemplates(data.templates || []);
      }
    } catch (err) {
      console.error("Failed to fetch templates:", err);
    }
  };

  const handleOpenCreateTemplate = () => {
    setEditingTemplate(null);
    setTemplateForm({
      name: "",
      templateId: `rt_custom_${Date.now().toString().slice(-4)}`,
      templateType: "RENT_REMINDER",
      category: "UTILITY",
      language: "en",
      messageText: "Hello {{1}}, reminder that payment of ₹{{2}} is due. Pay via: {{3}}",
      isActive: true,
    });
    setShowTemplateModal(true);
  };

  const handleOpenEditTemplate = (tpl: WhatsAppTemplateItem) => {
    setEditingTemplate(tpl);
    setTemplateForm({
      name: tpl.name || "",
      templateId: tpl.templateId || "",
      templateType: tpl.templateType || "RENT_REMINDER",
      category: tpl.category || "UTILITY",
      language: tpl.language || "en",
      messageText: tpl.messageText,
      isActive: tpl.isActive,
    });
    setShowTemplateModal(true);
  };

  const handleSaveTemplate = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const url = editingTemplate
        ? `${API_BASE_URL}/settings/whatsapp-templates/${editingTemplate.id}`
        : `${API_BASE_URL}/settings/whatsapp-templates`;
      const method = editingTemplate ? "PUT" : "POST";

      const res = await fetch(url, {
        method,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(templateForm),
      });

      if (res.ok) {
        setShowTemplateModal(false);
        fetchWhatsAppTemplates();
      } else {
        const data = await res.json();
        alert(data.error || "Failed to save template");
      }
    } catch (err) {
      alert("Error saving template");
    }
  };

  const handleDeleteTemplate = async (id: string) => {
    if (!window.confirm("Are you sure you want to delete this template?")) return;
    try {
      const res = await fetch(`${API_BASE_URL}/settings/whatsapp-templates/${id}`, {
        method: "DELETE",
      });
      if (res.ok) {
        fetchWhatsAppTemplates();
      }
    } catch (err) {
      alert("Error deleting template");
    }
  };

  // Fetch WhatsApp Cloud API Settings
  const fetchWhatsAppSettings = async (orgId: string) => {
    try {
      const res = await fetch(`${API_BASE_URL}/credits/settings/${orgId}`);
      if (res.ok) {
        const data = await res.json();
        if (data.settings) {
          setWaAppId(data.settings.whatsappAppId || "");
          setWaPhoneId(data.settings.whatsappPhoneNumberId || "");
          setWaToken(data.settings.whatsappAccessToken || "");
          setWaBusinessId(data.settings.whatsappBusinessId || "");
        }
      }
    } catch (err) {
      console.error("Failed to load WhatsApp settings:", err);
    }
  };

  // Save WhatsApp Cloud API Settings
  const handleSaveSettings = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!authOrg) return;

    setSettingsLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/credits/settings/save`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          organizationId: authOrg.id,
          whatsappAppId: waAppId,
          whatsappPhoneNumberId: waPhoneId,
          whatsappAccessToken: waToken,
          whatsappBusinessId: waBusinessId,
        }),
      });

      if (res.ok) {
        alert("WhatsApp Cloud API Settings saved successfully!");
        setShowSettingsModal(false);
      } else {
        alert("Failed to save settings");
      }
    } catch (err) {
      alert("Error connecting to server");
    } finally {
      setSettingsLoading(false);
    }
  };

  // Auto-set duration when plan selected
  const handlePlanChange = (planId: string) => {
    setSelectedPlanId(planId);
    setSelectedGroupId("");
    const plan = plans.find((p) => p.id === planId);
    if (plan) {
      setNewDuration(`${plan.durationDays} Days`);
    }
  };

  // Add Member submit
  const handleAddMemberSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFullName || !newPhone || !authOrg) return;

    setAddMemberLoading(true);
    try {
      const res = await fetch(`${API_BASE_URL}/members`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          organizationId: authOrg.id,
          fullName: newFullName,
          phone: newPhone,
          planId: selectedPlanId || undefined,
          groupId: selectedGroupId || undefined,
          joiningDate: newJoiningDate,
          duration: newDuration,
          dateOfBirth: newDob || undefined,
          notes: newNotes || undefined,
          customFieldsData: {
            aadhaar: customAadhaar,
            address: customAddress,
            emergencyPhone: customEmergencyPhone,
          },
        }),
      });

      const data = await res.json();
      if (res.ok) {
        setShowAddMemberModal(false);
        setNewFullName("");
        setNewPhone("");
        setSelectedPlanId("");
        setSelectedGroupId("");
        setNewNotes("");
        setCustomAadhaar("");
        setCustomAddress("");
        setCustomEmergencyPhone("");

        fetchDashboardData(authOrg.id);

        if (window.confirm(`Member created! Would you like to send WhatsApp Welcome Message to ${newFullName}?`)) {
          window.open(`https://wa.me/${newPhone.replace(/[^0-9]/g, "")}?text=${encodeURIComponent(`Hello ${newFullName}, welcome to ${authOrg.name}!`)}`, "_blank");
        }
      } else {
        alert(data.error || "Failed to add member");
      }
    } catch (err) {
      alert("Error connecting to server");
    } finally {
      setAddMemberLoading(false);
    }
  };

  // If Not Authenticated, Render Admin Login Screen
  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-4">
        <div className="glass-panel w-full max-w-md p-8 rounded-3xl border border-slate-800 shadow-2xl space-y-6">
          <div className="text-center space-y-2">
            <div className="inline-flex bg-gradient-to-tr from-cyan-500 to-blue-600 p-3 rounded-2xl shadow-lg shadow-cyan-500/25 mb-2">
              <TrendingUp className="w-8 h-8 text-slate-950 font-bold" />
            </div>
            <h2 className="text-2xl font-bold text-white tracking-wide">RentTrack Admin</h2>
            <p className="text-xs text-slate-400">Gym, Academy, PG & Tenant Management</p>
          </div>

          {/* Login Method Tabs */}
          <div className="grid grid-cols-2 gap-1 p-1 bg-slate-900 rounded-xl border border-slate-800">
            <button
              type="button"
              onClick={() => {
                setLoginMode("OTP");
                setLoginError("");
              }}
              className={`py-2 rounded-lg text-xs font-bold transition-all ${
                loginMode === "OTP" ? "bg-cyan-500 text-slate-950 shadow-md" : "text-slate-400 hover:text-white"
              }`}
            >
              Phone OTP / Register
            </button>
            <button
              type="button"
              onClick={() => {
                setLoginMode("PASSWORD");
                setLoginError("");
              }}
              className={`py-2 rounded-lg text-xs font-bold transition-all ${
                loginMode === "PASSWORD" ? "bg-cyan-500 text-slate-950 shadow-md" : "text-slate-400 hover:text-white"
              }`}
            >
              Email & Password
            </button>
          </div>

          {loginError && (
            <div className="p-3 rounded-xl bg-rose-500/20 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{loginError}</span>
            </div>
          )}

          {loginMode === "OTP" ? (
            <form onSubmit={otpSent ? handleVerifyOtp : handleSendOtp} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1.5">Admin Mobile Number</label>
                <div className="relative">
                  <input
                    type="text"
                    disabled={otpSent}
                    value={loginPhone}
                    onChange={(e) => setLoginPhone(e.target.value)}
                    placeholder="10-digit mobile number"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-cyan-500 transition-all disabled:opacity-60"
                    required
                  />
                  {otpSent && (
                    <button
                      type="button"
                      onClick={() => {
                        setOtpSent(false);
                        setIsNewUser(false);
                      }}
                      className="absolute right-3 top-2.5 text-xs text-cyan-400 font-bold hover:underline"
                    >
                      Change
                    </button>
                  )}
                </div>
              </div>

              {otpSent && (
                <>
                  <div>
                    <div className="flex justify-between items-center mb-1.5">
                      <label className="text-xs font-semibold text-slate-400">6-Digit OTP Code</label>
                      <span className="text-[10px] bg-cyan-500/20 text-cyan-400 px-2 py-0.5 rounded font-bold">Demo OTP: 123456</span>
                    </div>
                    <input
                      type="text"
                      value={loginOtp}
                      onChange={(e) => setLoginOtp(e.target.value)}
                      placeholder="123456"
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-base text-white tracking-widest font-bold focus:outline-none focus:border-cyan-500 transition-all"
                      required
                    />
                  </div>

                  {isNewUser && (
                    <div className="p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl space-y-3">
                      <div className="text-xs font-bold text-blue-400">First-Time Facility Registration</div>
                      <div>
                        <label className="text-[11px] font-semibold text-slate-400 block mb-1">Facility / Business Name *</label>
                        <input
                          type="text"
                          value={regOrgName}
                          onChange={(e) => setRegOrgName(e.target.value)}
                          placeholder="e.g. Apex Gym & Fitness"
                          className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-cyan-500"
                          required
                        />
                      </div>
                      <div>
                        <label className="text-[11px] font-semibold text-slate-400 block mb-1">Owner / Admin Name *</label>
                        <input
                          type="text"
                          value={regAdminName}
                          onChange={(e) => setRegAdminName(e.target.value)}
                          placeholder="e.g. Alex Johnson"
                          className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-cyan-500"
                          required
                        />
                      </div>
                      <div>
                        <label className="text-[11px] font-semibold text-slate-400 block mb-1">Facility Category</label>
                        <select
                          value={regOrgType}
                          onChange={(e) => setRegOrgType(e.target.value)}
                          className="w-full bg-slate-950 border border-slate-800 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-cyan-500"
                        >
                          <option value="GYM">Gym & Fitness</option>
                          <option value="HOSTEL">Hostel & PG</option>
                          <option value="TUITION_CENTER">Tuition Centre</option>
                          <option value="RENTAL">Rental Building</option>
                          <option value="ACADEMY">Academy</option>
                        </select>
                      </div>
                    </div>
                  )}
                </>
              )}

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-slate-950 font-bold py-3 rounded-xl shadow-lg shadow-cyan-500/25 text-sm transition-all flex items-center justify-center gap-2 mt-2"
              >
                {loading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />}{" "}
                {otpSent ? (isNewUser ? "Complete Registration & Sign In" : "Verify OTP & Sign In") : "Send OTP Code"}
              </button>
            </form>
          ) : (
            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1.5">Username / Email</label>
                <input
                  type="text"
                  value={loginEmail}
                  onChange={(e) => setLoginEmail(e.target.value)}
                  placeholder="Username or Email"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-cyan-500 transition-all"
                  required
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-slate-400 block mb-1.5">Password</label>
                <input
                  type="password"
                  value={loginPassword}
                  onChange={(e) => setLoginPassword(e.target.value)}
                  placeholder="Password"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-cyan-500 transition-all"
                  required
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 hover:from-cyan-400 hover:to-blue-500 text-slate-950 font-bold py-3 rounded-xl shadow-lg shadow-cyan-500/25 text-sm transition-all flex items-center justify-center gap-2 mt-2"
              >
                {loading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Lock className="w-4 h-4" />} Sign In to Dashboard
              </button>
            </form>
          )}
        </div>
      </div>

    );
  }

  // Dashboard Main Render
  const filteredMembers = members.filter((m) => {
    const matchesStatus = statusFilter === "ALL" || m.status === statusFilter;
    const matchesSearch =
      m.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      m.phone.includes(searchQuery);
    return matchesStatus && matchesSearch;
  });

  const paidCount = members.filter((m) => m.status === "PAID").length;
  const unpaidCount = members.filter((m) => m.status === "UNPAID").length;
  const frozenCount = members.filter((m) => m.status === "FROZEN").length;

  const currentSelectedPlan = plans.find((p) => p.id === selectedPlanId);

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      {/* Top Header */}
      <header className="glass-panel sticky top-0 z-50 border-b border-slate-800 px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="bg-gradient-to-tr from-cyan-500 to-blue-600 p-2.5 rounded-xl shadow-lg shadow-cyan-500/20">
            <TrendingUp className="w-6 h-6 text-slate-950 font-bold" />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-wide text-white">{authOrg?.name || "RentTrack Admin"}</h1>
            <p className="text-xs text-slate-400">Gym, Academy, PG & Tenant Management</p>
          </div>
        </div>

        {/* Top Header Actions (Refresh, WhatsApp Settings, Add Member, Logout) */}
        <div className="flex items-center gap-3">
          <button
            onClick={() => authOrg && fetchDashboardData(authOrg.id)}
            className="p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-white transition-all"
            title="Refresh Data"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin text-cyan-400" : ""}`} />
          </button>
          
          <button
            onClick={() => setShowSettingsModal(true)}
            className="glass-card px-3.5 py-2 rounded-xl flex items-center gap-2 border border-slate-800 hover:border-slate-700 text-slate-300 hover:text-white transition-all text-xs font-semibold"
            title="WhatsApp Cloud API Settings"
          >
            <Settings className="w-4 h-4 text-cyan-400" /> Settings
          </button>

          <button
            onClick={() => setShowAddMemberModal(true)}
            className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 px-4 py-2 rounded-xl font-semibold text-xs transition-all shadow-lg shadow-cyan-500/25 flex items-center gap-2"
          >
            <Plus className="w-4 h-4" /> Add Member
          </button>

          <button
            onClick={handleLogout}
            className="p-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-400 hover:text-rose-400 transition-all"
            title="Logout"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>
      </header>

      {/* Main Container */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-6 space-y-6">
        {/* Navigation Tabs */}
        <div className="flex items-center gap-2 border-b border-slate-800 pb-3">
          <button
            onClick={() => setActiveTab("members")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "members" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <Users className="w-4 h-4" /> Members & Tenants
          </button>
          <button
            onClick={() => setActiveTab("plans")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "plans" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <Layers className="w-4 h-4" /> Plans & Groups
          </button>
          <button
            onClick={() => setActiveTab("expenses")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "expenses" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <FileText className="w-4 h-4" /> Expenses
          </button>
          <button
            onClick={() => setActiveTab("reports")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "reports" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <BarChart3 className="w-4 h-4" /> Reports & Analytics
          </button>
          <button
            onClick={() => setActiveTab("custom_fields")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "custom_fields" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <Settings className="w-4 h-4" /> Custom Fields Config
          </button>
          <button
            onClick={() => setActiveTab("app_subscription_plans")}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "app_subscription_plans" ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <Sparkles className="w-4 h-4" /> App Subscription Plans
          </button>
          <button
            onClick={() => {
              setActiveTab("facilities");
              fetchOrganizationsList();
            }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "facilities" ? "bg-cyan-500/20 text-cyan-400 border border-cyan-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <ShieldCheck className="w-4 h-4" /> Facilities / Tenants ({allOrgs.length})
          </button>
          <button
            onClick={() => {
              setActiveTab("settings");
              fetchPlatformSettings();
              fetchWhatsAppTemplates();
            }}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2 ${
              activeTab === "settings" ? "bg-amber-500/20 text-amber-400 border border-amber-500/40" : "text-slate-400 hover:text-white"
            }`}
          >
            <Settings className="w-4 h-4" /> Platform & WhatsApp Settings
          </button>
        </div>

        {/* Summary Metric Cards */}

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="glass-card p-5 rounded-2xl border border-slate-800/80 hover:border-slate-700 transition-all">
            <div className="flex justify-between items-start mb-3">
              <span className="text-slate-400 text-xs font-semibold tracking-wider uppercase">Total Members</span>
              <div className="p-2 bg-blue-500/10 text-blue-400 rounded-xl">
                <Users className="w-5 h-5" />
              </div>
            </div>
            <div className="text-2xl font-bold text-white mb-1">{members.length}</div>
            <div className="text-xs text-slate-400 flex items-center gap-2">
              <span className="text-emerald-400 font-medium">{paidCount} Paid</span> • 
              <span className="text-rose-400 font-medium">{unpaidCount} Unpaid</span>
            </div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800/80 hover:border-slate-700 transition-all">
            <div className="flex justify-between items-start mb-3">
              <span className="text-slate-400 text-xs font-semibold tracking-wider uppercase">Total Income</span>
              <div className="p-2 bg-emerald-500/10 text-emerald-400 rounded-xl">
                <IndianRupee className="w-5 h-5" />
              </div>
            </div>
            <div className="text-2xl font-bold text-emerald-400 mb-1">₹{summary.totalIncome.toLocaleString()}</div>
            <div className="text-xs text-slate-400">Actual received payments</div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800/80 hover:border-slate-700 transition-all">
            <div className="flex justify-between items-start mb-3">
              <span className="text-slate-400 text-xs font-semibold tracking-wider uppercase">Total Pending Dues</span>
              <div className="p-2 bg-rose-500/10 text-rose-400 rounded-xl">
                <AlertCircle className="w-5 h-5" />
              </div>
            </div>
            <div className="text-2xl font-bold text-rose-400 mb-1">₹{summary.totalPendingDues.toLocaleString()}</div>
            <div className="text-xs text-slate-400">Excludes {frozenCount} Frozen members</div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800/80 hover:border-slate-700 transition-all">
            <div className="flex justify-between items-start mb-3">
              <span className="text-slate-400 text-xs font-semibold tracking-wider uppercase">Collection Rate</span>
              <div className="p-2 bg-cyan-500/10 text-cyan-400 rounded-xl">
                <TrendingUp className="w-5 h-5" />
              </div>
            </div>
            <div className="text-2xl font-bold text-cyan-400 mb-1">{summary.collectionRate}%</div>
            <div className="text-xs text-slate-400">Collected ÷ Expected × 100</div>
          </div>
        </div>

        {/* Members View */}
        {activeTab === "members" && (
          <>
            {/* Status Filter & Search Header */}
            <div className="glass-card p-4 rounded-2xl border border-slate-800 flex flex-col md:flex-row justify-between items-center gap-4">
              <div className="flex items-center gap-2 w-full md:w-auto">
                <button
                  onClick={() => setStatusFilter("ALL")}
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                    statusFilter === "ALL" ? "bg-slate-800 text-white border border-slate-700" : "text-slate-400 hover:text-white"
                  }`}
                >
                  All ({members.length})
                </button>
                <button
                  onClick={() => setStatusFilter("PAID")}
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                    statusFilter === "PAID" ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30" : "text-slate-400 hover:text-white"
                  }`}
                >
                  <CheckCircle className="w-3.5 h-3.5" /> Paid ({paidCount})
                </button>
                <button
                  onClick={() => setStatusFilter("UNPAID")}
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                    statusFilter === "UNPAID" ? "bg-rose-500/20 text-rose-400 border border-rose-500/30" : "text-slate-400 hover:text-white"
                  }`}
                >
                  <AlertCircle className="w-3.5 h-3.5" /> Unpaid ({unpaidCount})
                </button>
                <button
                  onClick={() => setStatusFilter("FROZEN")}
                  className={`px-3 py-1.5 rounded-lg text-xs font-semibold transition-all flex items-center gap-1.5 ${
                    statusFilter === "FROZEN" ? "bg-cyan-500/20 text-cyan-300 border border-cyan-500/30" : "text-slate-400 hover:text-white"
                  }`}
                >
                  <Snowflake className="w-3.5 h-3.5" /> Frozen ({frozenCount})
                </button>
              </div>

              <div className="relative w-full md:w-64">
                <Search className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search member or phone..."
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl pl-9 pr-4 py-1.5 text-xs text-slate-200 focus:outline-none focus:border-cyan-500 transition-all"
                />
              </div>
            </div>

            {/* Member Table */}
            <div className="glass-card rounded-2xl border border-slate-800 overflow-hidden">
              <table className="w-full text-left text-xs text-slate-300">
                <thead className="bg-slate-900/80 text-slate-400 uppercase tracking-wider font-semibold border-b border-slate-800">
                  <tr>
                    <th className="p-4">Member Name</th>
                    <th className="p-4">Plan / Group</th>
                    <th className="p-4">Amount</th>
                    <th className="p-4">Period</th>
                    <th className="p-4">Status</th>
                    <th className="p-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filteredMembers.map((member) => (
                    <tr key={member.id} className="hover:bg-slate-900/40 transition-colors">
                      <td className="p-4 font-medium text-white">
                        <div>{member.fullName}</div>
                        <div className="text-[11px] text-slate-500 flex items-center gap-1 mt-0.5">
                          <Phone className="w-3 h-3 text-slate-400" /> {member.phone}
                        </div>
                      </td>
                      <td className="p-4">
                        <span className="bg-slate-800 px-2.5 py-1 rounded-md text-[11px] text-slate-300 font-medium">
                          {member.planName} • {member.groupName}
                        </span>
                      </td>
                      <td className="p-4 font-bold text-white">₹{member.amount}</td>
                      <td className="p-4 text-slate-400 flex items-center gap-1.5">
                        <Calendar className="w-3.5 h-3.5 text-slate-500" /> {member.latestMonthYear}
                      </td>
                      <td className="p-4">
                        {member.status === "PAID" && (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                            🟢 Paid
                          </span>
                        )}
                        {member.status === "UNPAID" && (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-rose-500/20 text-rose-400 border border-rose-500/30">
                            🔴 Unpaid
                          </span>
                        )}
                        {member.status === "FROZEN" && (
                          <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-cyan-500/20 text-cyan-300 border border-cyan-500/30">
                            ❄️ Frozen
                          </span>
                        )}
                      </td>
                      <td className="p-4 text-right space-x-2">
                        <button className="bg-slate-800 hover:bg-slate-700 text-slate-200 px-2.5 py-1 rounded-lg text-[11px] font-medium transition-all">
                          Details
                        </button>
                      </td>
                    </tr>
                  ))}
                  {filteredMembers.length === 0 && (
                    <tr>
                      <td colSpan={6} className="p-8 text-center text-slate-500 text-xs">
                        No members found. Click &quot;+ Add Member&quot; to add a new member.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </>
        )}

        {/* App Subscription Plans Management View */}
        {activeTab === "app_subscription_plans" && (
          <div className="space-y-6">
            <div className="glass-card p-6 rounded-2xl border border-slate-800 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
              <div>
                <h2 className="text-lg font-bold text-white flex items-center gap-2">
                  <Sparkles className="w-5 h-5 text-emerald-400" /> App Subscription Plans
                </h2>
                <p className="text-xs text-slate-400">
                  Configure subscription plans displayed to app users during mobile onboarding and upgrade screens.
                </p>
              </div>
              <button
                onClick={handleOpenCreateAppPlan}
                className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold px-4 py-2 rounded-xl text-xs flex items-center gap-2 transition-all shadow-lg shadow-emerald-500/20"
              >
                <Plus className="w-4 h-4" /> Add New Plan
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
              {appPlans.map((plan) => (
                <div
                  key={plan.id}
                  className={`glass-card p-5 rounded-2xl border flex flex-col justify-between transition-all ${
                    plan.isActive
                      ? "border-slate-800 hover:border-slate-700 bg-slate-900/40"
                      : "border-rose-900/30 bg-rose-950/10 opacity-70"
                  }`}
                >
                  <div className="space-y-3">
                    <div className="flex justify-between items-start gap-2">
                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="font-bold text-white text-base">{plan.name}</h3>
                          {plan.tag && (
                            <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/20 text-emerald-300 border border-emerald-500/30">
                              {plan.tag}
                            </span>
                          )}
                        </div>
                        <span className="text-[11px] text-slate-400">
                          {plan.isFreeTrial ? "30 Days Trial" : `${plan.durationMonths} Month(s)`}
                        </span>
                      </div>
                      <span
                        className={`px-2 py-0.5 rounded-md text-[10px] font-bold ${
                          plan.isActive
                            ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                            : "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                        }`}
                      >
                        {plan.isActive ? "Active" : "Disabled"}
                      </span>
                    </div>

                    <div className="py-2 border-y border-slate-800">
                      <div className="text-2xl font-black text-white">
                        {plan.price === 0 ? "Free" : `₹${plan.price}`}
                      </div>
                      <p className="text-xs text-slate-300 mt-1">{plan.description}</p>
                      <div className="flex items-center gap-1.5 mt-2.5 text-xs font-semibold text-emerald-400 bg-emerald-500/10 px-2.5 py-1.5 rounded-xl border border-emerald-500/20">
                        <MessageSquare className="w-3.5 h-3.5 text-emerald-400" />
                        <span>{plan.whatsappCredits ?? 100} WhatsApp Credits</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center justify-between pt-4 mt-4 border-t border-slate-800/60">
                    <button
                      onClick={() => handleToggleAppPlan(plan.id)}
                      className={`text-xs font-semibold px-2.5 py-1 rounded-lg border transition-all flex items-center gap-1.5 ${
                        plan.isActive
                          ? "bg-slate-800 text-slate-300 border-slate-700 hover:bg-slate-700"
                          : "bg-emerald-950/40 text-emerald-300 border-emerald-800 hover:bg-emerald-900/40"
                      }`}
                    >
                      {plan.isActive ? <ToggleRight className="w-4 h-4 text-emerald-400" /> : <ToggleLeft className="w-4 h-4 text-slate-500" />}
                      {plan.isActive ? "Disable" : "Enable"}
                    </button>

                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleOpenEditAppPlan(plan)}
                        className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 transition-all"
                        title="Edit Plan"
                      >
                        <Edit3 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => handleDeleteAppPlan(plan.id)}
                        className="p-1.5 rounded-lg bg-slate-800 hover:bg-rose-900/50 text-rose-400 transition-all"
                        title="Delete Plan"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Facilities Directory Tab Content */}
        {activeTab === "facilities" && (
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-xl font-bold text-white tracking-wide">Registered Facility Admins & Businesses</h2>
                <p className="text-xs text-slate-400 mt-1">
                  View all registered facility admins, their facility categories, payout setup, and WhatsApp credit status.
                </p>
              </div>
              <button
                onClick={fetchOrganizationsList}
                className="px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 text-xs font-semibold text-slate-300 hover:text-white transition-all flex items-center gap-1.5"
              >
                <RefreshCw className="w-3.5 h-3.5" /> Refresh List
              </button>
            </div>

            <div className="glass-panel rounded-2xl border border-slate-800 overflow-hidden shadow-xl">
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="bg-slate-900/80 border-b border-slate-800 text-slate-400 text-xs uppercase tracking-wider font-semibold">
                      <th className="p-4">Facility / Business</th>
                      <th className="p-4">Category</th>
                      <th className="p-4">Admin / Owner</th>
                      <th className="p-4">Phone Number</th>
                      <th className="p-4">Direct Payout (UPI / Bank)</th>
                      <th className="p-4">WhatsApp Credits</th>
                      <th className="p-4">Members</th>
                      <th className="p-4">Plans</th>
                      <th className="p-4 text-right">Actions</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-800/60 text-sm">
                    {allOrgs.length === 0 ? (
                      <tr>
                        <td colSpan={9} className="p-8 text-center text-slate-500 text-xs">
                          No registered facilities found.
                        </td>
                      </tr>
                    ) : (
                      allOrgs.map((org) => {
                        const adminUser = org.users?.[0];
                        const isCurrentOrg = authOrg?.id === org.id;
                        const subCredit = org.subscriptionCredit;
                        const availableCredits = subCredit ? Math.max(0, subCredit.purchasedCredits - subCredit.usedCredits) : 0;

                        return (
                          <tr key={org.id} className="hover:bg-slate-900/40 transition-all">
                            <td className="p-4 font-bold text-white flex items-center gap-2">
                              {org.name}
                              {isCurrentOrg && (
                                <span className="bg-cyan-500/20 text-cyan-400 border border-cyan-500/30 text-[10px] px-2 py-0.5 rounded-full font-bold">
                                  Current Active
                                </span>
                              )}
                            </td>
                            <td className="p-4">
                              <span className="px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-900 border border-slate-800 text-cyan-300">
                                {org.type || "GYM"}
                              </span>
                            </td>
                            <td className="p-4 font-medium text-slate-200">
                              {adminUser?.name || "Facility Admin"}
                            </td>
                            <td className="p-4 text-slate-400 text-xs font-mono">
                              {adminUser?.phone || "N/A"}
                            </td>
                            <td className="p-4 text-xs">
                              {org.bankUpiId ? (
                                <div className="space-y-0.5">
                                  <span className="text-emerald-400 font-mono bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20 block w-max">
                                    UPI: {org.bankUpiId}
                                  </span>
                                  {org.bankAccountName && (
                                    <span className="text-[10px] text-slate-400 block">{org.bankAccountName}</span>
                                  )}
                                </div>
                              ) : org.bankAccountNumber ? (
                                <span className="text-slate-300 font-mono">
                                  A/C: ****{org.bankAccountNumber.slice(-4)}
                                </span>
                              ) : (
                                <span className="text-slate-500 italic">Not configured</span>
                              )}
                            </td>
                            <td className="p-4 text-xs">
                              <span className="font-bold text-cyan-300 bg-cyan-500/10 px-2.5 py-1 rounded-lg border border-cyan-500/20">
                                {availableCredits} credits
                              </span>
                            </td>
                            <td className="p-4 text-slate-300 font-bold">
                              {org._count?.members ?? 0}
                            </td>
                            <td className="p-4 text-slate-300">
                              {org._count?.plans ?? 0}
                            </td>
                            <td className="p-4 text-right">
                              <button
                                onClick={() => switchFacility(org)}
                                disabled={isCurrentOrg}
                                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${
                                  isCurrentOrg
                                    ? "bg-slate-900 text-slate-600 cursor-not-allowed border border-slate-800"
                                    : "bg-cyan-500 hover:bg-cyan-400 text-slate-950 shadow-md shadow-cyan-500/20"
                                }`}
                              >
                                {isCurrentOrg ? "Selected" : "Switch Context"}
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
        )}

        {/* Settings & WhatsApp Templates Tab Content */}
        {activeTab === "settings" && (
          <div className="space-y-6">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
              <div>
                <h2 className="text-xl font-bold text-white tracking-wide flex items-center gap-2">
                  <Settings className="w-5 h-5 text-amber-400" /> Platform & WhatsApp Settings
                </h2>
                <p className="text-xs text-slate-400 mt-1">
                  Configure live Razorpay gateway credentials, Meta Cloud API access tokens, and customize WhatsApp message templates with editable Meta Template IDs.
                </p>
              </div>
              <div className="flex items-center gap-3">
                <button
                  onClick={() => {
                    fetchPlatformSettings();
                    fetchWhatsAppTemplates();
                  }}
                  className="px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-800 text-xs font-semibold text-slate-300 hover:text-white transition-all flex items-center gap-1.5"
                >
                  <RefreshCw className="w-3.5 h-3.5" /> Reload Settings
                </button>
              </div>
            </div>

            {settingsNotice && (
              <div className="p-3 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-emerald-400 text-xs flex items-center gap-2 animate-fade-in">
                <CheckCircle className="w-4 h-4" />
                <span>{settingsNotice}</span>
              </div>
            )}

            {/* Credentials Forms Grid */}
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              {/* Razorpay Platform Gateway Card */}
              <div className="glass-panel p-6 rounded-3xl border border-slate-800 space-y-4 shadow-xl">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="p-2 bg-blue-500/10 text-blue-400 rounded-xl">
                      <IndianRupee className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white">Platform Razorpay Credentials</h3>
                      <p className="text-[11px] text-slate-400">Used when Facility Admins purchase app subscriptions</p>
                    </div>
                  </div>
                  <span className="text-[10px] font-bold bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2 py-0.5 rounded-full">
                    Platform Gateway
                  </span>
                </div>

                <form onSubmit={handleSavePlatformSettings} className="space-y-3 text-xs">
                  <div>
                    <label className="font-semibold text-slate-300 block mb-1">Razorpay Key ID</label>
                    <input
                      type="text"
                      value={platformSettings.RAZORPAY_KEY_ID || ""}
                      onChange={(e) => setPlatformSettings({ ...platformSettings, RAZORPAY_KEY_ID: e.target.value })}
                      placeholder="rzp_live_... or rzp_test_..."
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                    />
                  </div>

                  <div>
                    <label className="font-semibold text-slate-300 block mb-1">Razorpay Key Secret</label>
                    <input
                      type="password"
                      value={platformSettings.RAZORPAY_KEY_SECRET || ""}
                      onChange={(e) => setPlatformSettings({ ...platformSettings, RAZORPAY_KEY_SECRET: e.target.value })}
                      placeholder="••••••••••••••••••••••••"
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                    />
                  </div>

                  <div className="pt-2 flex justify-end">
                    <button
                      type="submit"
                      disabled={settingsSaving}
                      className="bg-blue-600 hover:bg-blue-500 text-white font-bold px-4 py-2 rounded-xl text-xs flex items-center gap-2 transition-all shadow-md shadow-blue-600/20"
                    >
                      <Save className="w-3.5 h-3.5" /> Save Razorpay Keys
                    </button>
                  </div>
                </form>
              </div>

              {/* Meta WhatsApp Cloud API Card */}
              <div className="glass-panel p-6 rounded-3xl border border-slate-800 space-y-4 shadow-xl">
                <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="p-2 bg-emerald-500/10 text-emerald-400 rounded-xl">
                      <MessageSquare className="w-5 h-5" />
                    </div>
                    <div>
                      <h3 className="text-sm font-bold text-white">Meta WhatsApp Cloud API</h3>
                      <p className="text-[11px] text-slate-400">Official Meta Graph API configuration for messaging</p>
                    </div>
                  </div>
                  <span className="text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2 py-0.5 rounded-full">
                    Cloud API
                  </span>
                </div>

                <form onSubmit={handleSavePlatformSettings} className="space-y-3 text-xs">
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="font-semibold text-slate-300 block mb-1">Phone Number ID</label>
                      <input
                        type="text"
                        value={platformSettings.WHATSAPP_PHONE_NUMBER_ID || ""}
                        onChange={(e) => setPlatformSettings({ ...platformSettings, WHATSAPP_PHONE_NUMBER_ID: e.target.value })}
                        placeholder="e.g. 1092837465"
                        className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                      />
                    </div>
                    <div>
                      <label className="font-semibold text-slate-300 block mb-1">WABA Account ID</label>
                      <input
                        type="text"
                        value={platformSettings.WHATSAPP_BUSINESS_ACCOUNT_ID || ""}
                        onChange={(e) => setPlatformSettings({ ...platformSettings, WHATSAPP_BUSINESS_ACCOUNT_ID: e.target.value })}
                        placeholder="e.g. 9876543210"
                        className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="font-semibold text-slate-300 block mb-1">Permanent System User Access Token</label>
                    <input
                      type="password"
                      value={platformSettings.WHATSAPP_ACCESS_TOKEN || ""}
                      onChange={(e) => setPlatformSettings({ ...platformSettings, WHATSAPP_ACCESS_TOKEN: e.target.value })}
                      placeholder="EAAG... (System User Token)"
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="font-semibold text-slate-300 block mb-1">Graph API Version</label>
                      <input
                        type="text"
                        value={platformSettings.WHATSAPP_API_VERSION || "v20.0"}
                        onChange={(e) => setPlatformSettings({ ...platformSettings, WHATSAPP_API_VERSION: e.target.value })}
                        placeholder="v20.0"
                        className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                      />
                    </div>
                    <div>
                      <label className="font-semibold text-slate-300 block mb-1">Webhook Verify Token</label>
                      <input
                        type="text"
                        value={platformSettings.WHATSAPP_WEBHOOK_SECRET || ""}
                        onChange={(e) => setPlatformSettings({ ...platformSettings, WHATSAPP_WEBHOOK_SECRET: e.target.value })}
                        placeholder="webhook_secret"
                        className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-amber-500"
                      />
                    </div>
                  </div>

                  <div className="pt-2 flex justify-end">
                    <button
                      type="submit"
                      disabled={settingsSaving}
                      className="bg-emerald-600 hover:bg-emerald-500 text-white font-bold px-4 py-2 rounded-xl text-xs flex items-center gap-2 transition-all shadow-md shadow-emerald-600/20"
                    >
                      <Save className="w-3.5 h-3.5" /> Save WhatsApp Cloud API Settings
                    </button>
                  </div>
                </form>
              </div>
            </div>

            {/* WhatsApp Templates Manager */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-base font-bold text-white tracking-wide flex items-center gap-2">
                    <MessageSquare className="w-4 h-4 text-cyan-400" /> WhatsApp Message Templates ({templates.length})
                  </h3>
                  <p className="text-xs text-slate-400 mt-0.5">
                    Pre-seeded Meta approved templates. You can edit the Meta Template ID, Category, and text directly in this panel.
                  </p>
                </div>
                <button
                  onClick={handleOpenCreateTemplate}
                  className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 font-bold px-3.5 py-1.5 rounded-xl text-xs flex items-center gap-1.5 transition-all shadow-md shadow-cyan-500/20"
                >
                  <Plus className="w-3.5 h-3.5" /> Add New Template
                </button>
              </div>

              <div className="p-3 bg-amber-500/10 border border-amber-500/20 rounded-2xl text-amber-300 text-xs flex items-start gap-2.5">
                <span className="text-base">💡</span>
                <p>
                  <strong>Meta Template IDs:</strong> Currently pre-seeded with default IDs (<code className="bg-amber-950/40 px-1 py-0.5 rounded text-amber-200">rt_otp_v1</code>, <code className="bg-amber-950/40 px-1 py-0.5 rounded text-amber-200">rt_rent_reminder_v1</code>, etc.). When Meta approves your actual templates in WhatsApp Business Manager, click <strong>Edit</strong> on any template below to plug in your approved Meta Template ID without any code changes!
                </p>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {templates.map((tpl) => (
                  <div
                    key={tpl.id}
                    className="glass-card p-5 rounded-2xl border border-slate-800 hover:border-slate-700 bg-slate-900/40 flex flex-col justify-between transition-all space-y-3"
                  >
                    <div className="space-y-2.5">
                      <div className="flex justify-between items-start gap-2">
                        <div>
                          <h4 className="font-bold text-white text-sm">{tpl.name || tpl.templateType}</h4>
                          <span className="font-mono text-[11px] text-cyan-400 block mt-0.5">
                            ID: {tpl.templateId || "None"}
                          </span>
                        </div>
                        <span
                          className={`px-2 py-0.5 rounded-md text-[10px] font-bold ${
                            tpl.category === "AUTHENTICATION"
                              ? "bg-purple-500/20 text-purple-300 border border-purple-500/30"
                              : tpl.category === "MARKETING"
                              ? "bg-amber-500/20 text-amber-300 border border-amber-500/30"
                              : "bg-cyan-500/20 text-cyan-300 border border-cyan-500/30"
                          }`}
                        >
                          {tpl.category || "UTILITY"}
                        </span>
                      </div>

                      <div className="p-3 rounded-xl bg-slate-950/70 border border-slate-800/80 text-xs text-slate-300 font-mono leading-relaxed break-words">
                        {tpl.messageText}
                      </div>

                      <div className="flex items-center gap-2 text-[11px] text-slate-400">
                        <span>Language: <strong className="text-white uppercase">{tpl.language}</strong></span>
                        <span>•</span>
                        <span>Type: <strong className="text-slate-300">{tpl.templateType}</strong></span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-3 border-t border-slate-800/60">
                      <span className="text-[10px] text-emerald-400 font-semibold flex items-center gap-1">
                        <CheckCircle className="w-3 h-3" /> Ready in Browser
                      </span>
                      <div className="flex items-center gap-1.5">
                        <button
                          onClick={() => handleOpenEditTemplate(tpl)}
                          className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold flex items-center gap-1 transition-all"
                        >
                          <Edit3 className="w-3 h-3 text-cyan-400" /> Edit
                        </button>
                        <button
                          onClick={() => handleDeleteTemplate(tpl.id)}
                          className="p-1 rounded-lg bg-slate-800 hover:bg-rose-900/40 text-rose-400 transition-all"
                          title="Delete Template"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </main>


      {/* App Plan Create / Edit Modal */}
      {showAppPlanModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-md flex items-center justify-center p-4 overflow-y-auto">
          <div className="glass-panel w-full max-w-md p-6 rounded-3xl border border-slate-800 shadow-2xl space-y-4 my-8">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Sparkles className="w-5 h-5 text-emerald-400" />
                {editingAppPlan ? "Edit Subscription Plan" : "Add Subscription Plan"}
              </h3>
              <button
                onClick={() => setShowAppPlanModal(false)}
                className="p-1 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-white transition-all"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveAppPlan} className="space-y-4 text-xs">
              <div>
                <label className="font-semibold text-slate-400 block mb-1">Plan Name *</label>
                <input
                  type="text"
                  value={appPlanForm.name}
                  onChange={(e) => setAppPlanForm({ ...appPlanForm, name: e.target.value })}
                  placeholder="e.g. Free trial 30 days, Plus, Max, Max+"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Price (₹) *</label>
                  <input
                    type="number"
                    value={appPlanForm.price}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, price: parseFloat(e.target.value) || 0 })}
                    placeholder="0"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                    required
                  />
                </div>
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Tag (Optional)</label>
                  <input
                    type="text"
                    value={appPlanForm.tag}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, tag: e.target.value })}
                    placeholder="Default, Popular"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="font-semibold text-slate-400 block mb-1">Description *</label>
                <textarea
                  value={appPlanForm.description}
                  onChange={(e) => setAppPlanForm({ ...appPlanForm, description: e.target.value })}
                  placeholder="e.g. All features unlocked for one month"
                  rows={2}
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500 resize-none"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Duration (Months)</label>
                  <input
                    type="number"
                    value={appPlanForm.durationMonths}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, durationMonths: parseInt(e.target.value) || 1 })}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                    min={1}
                  />
                </div>
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Sort Order</label>
                  <input
                    type="number"
                    value={appPlanForm.sortOrder}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, sortOrder: parseInt(e.target.value) || 1 })}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="font-semibold text-slate-300 block mb-1">WhatsApp Credits (Compulsory) *</label>
                <input
                  type="number"
                  value={appPlanForm.whatsappCredits}
                  onChange={(e) => setAppPlanForm({ ...appPlanForm, whatsappCredits: parseInt(e.target.value) || 0 })}
                  placeholder="100"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-emerald-500"
                  min={0}
                  required
                />
                <span className="text-[11px] text-slate-500 block mt-1">Compulsory message credits automatically added to Tenant's balance on subscribing.</span>
              </div>

              <div className="flex items-center gap-4 pt-2">
                <label className="flex items-center gap-2 text-slate-300 font-semibold cursor-pointer">
                  <input
                    type="checkbox"
                    checked={appPlanForm.isFreeTrial}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, isFreeTrial: e.target.checked })}
                    className="rounded bg-slate-900 border-slate-800 text-emerald-500 focus:ring-0"
                  />
                  Is Free Trial
                </label>
                <label className="flex items-center gap-2 text-slate-300 font-semibold cursor-pointer">
                  <input
                    type="checkbox"
                    checked={appPlanForm.isActive}
                    onChange={(e) => setAppPlanForm({ ...appPlanForm, isActive: e.target.checked })}
                    className="rounded bg-slate-900 border-slate-800 text-emerald-500 focus:ring-0"
                  />
                  Is Active
                </label>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowAppPlanModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="bg-emerald-500 hover:bg-emerald-400 text-slate-950 px-5 py-2 rounded-xl font-bold transition-all shadow-lg shadow-emerald-500/20"
                >
                  Save Plan
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Settings Modal (WhatsApp App ID, Token, Phone ID) */}
      {showSettingsModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-md flex items-center justify-center p-4 overflow-y-auto">
          <div className="glass-panel w-full max-w-md p-6 rounded-3xl border border-slate-800 shadow-2xl space-y-4 my-8">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Settings className="w-5 h-5 text-cyan-400" /> WhatsApp Cloud API Settings
              </h3>
              <button
                onClick={() => setShowSettingsModal(false)}
                className="p-1 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-white transition-all"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveSettings} className="space-y-4 text-xs">
              <div>
                <label className="font-semibold text-slate-400 block mb-1">WhatsApp App ID</label>
                <input
                  type="text"
                  value={waAppId}
                  onChange={(e) => setWaAppId(e.target.value)}
                  placeholder="e.g. 1029384756102"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div>
                <label className="font-semibold text-slate-400 block mb-1">Phone Number ID</label>
                <input
                  type="text"
                  value={waPhoneId}
                  onChange={(e) => setWaPhoneId(e.target.value)}
                  placeholder="e.g. 10987654321"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div>
                <label className="font-semibold text-slate-400 block mb-1">Access Token / Secret</label>
                <textarea
                  value={waToken}
                  onChange={(e) => setWaToken(e.target.value)}
                  placeholder="EAAG..."
                  rows={3}
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500 resize-none font-mono text-[11px]"
                />
              </div>

              <div>
                <label className="font-semibold text-slate-400 block mb-1">WhatsApp Business Account ID</label>
                <input
                  type="text"
                  value={waBusinessId}
                  onChange={(e) => setWaBusinessId(e.target.value)}
                  placeholder="e.g. 5647382910"
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                />
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowSettingsModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={settingsLoading}
                  className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 px-5 py-2 rounded-xl font-bold transition-all shadow-lg shadow-cyan-500/25 flex items-center gap-2"
                >
                  {settingsLoading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Save className="w-4 h-4" />} Save Settings
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Member Interactive Modal */}
      {showAddMemberModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-md flex items-center justify-center p-4 overflow-y-auto">
          <div className="glass-panel w-full max-w-lg p-6 rounded-3xl border border-slate-800 shadow-2xl space-y-4 my-8">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <UserCheck className="w-5 h-5 text-cyan-400" /> Add New Member / Tenant
              </h3>
              <button
                onClick={() => setShowAddMemberModal(false)}
                className="p-1 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-white transition-all"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddMemberSubmit} className="space-y-4 text-xs">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Full Name *</label>
                  <input
                    type="text"
                    value={newFullName}
                    onChange={(e) => setNewFullName(e.target.value)}
                    placeholder="e.g. Ahmed Ali"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                    required
                  />
                </div>
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Phone Number *</label>
                  <input
                    type="text"
                    value={newPhone}
                    onChange={(e) => setNewPhone(e.target.value)}
                    placeholder="+91 9876543210"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Plan (Optional)</label>
                  <select
                    value={selectedPlanId}
                    onChange={(e) => handlePlanChange(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                  >
                    <option value="">-- No Plan (Direct Member) --</option>
                    {plans.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} (₹{p.price})
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Batch / Group (Optional)</label>
                  <select
                    value={selectedGroupId}
                    onChange={(e) => setSelectedGroupId(e.target.value)}
                    disabled={!selectedPlanId || !currentSelectedPlan?.groups?.length}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500 disabled:opacity-50"
                  >
                    <option value="">-- Direct under Plan --</option>
                    {currentSelectedPlan?.groups?.map((g) => (
                      <option key={g.id} value={g.id}>
                        {g.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Joining Date</label>
                  <input
                    type="date"
                    value={newJoiningDate}
                    onChange={(e) => setNewJoiningDate(e.target.value)}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                  />
                </div>
                <div>
                  <label className="font-semibold text-slate-400 block mb-1">Duration (Auto-filled from Plan)</label>
                  <input
                    type="text"
                    value={newDuration}
                    onChange={(e) => setNewDuration(e.target.value)}
                    placeholder="30 Days"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                  />
                </div>
              </div>

              {/* Dynamic Custom Fields */}
              <div className="border-t border-slate-800 pt-3 space-y-3">
                <span className="text-slate-400 font-bold uppercase tracking-wider text-[10px] block">Admin Dynamic Custom Fields</span>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <div>
                    <label className="font-semibold text-slate-500 block mb-1">Aadhaar Number</label>
                    <input
                      type="text"
                      value={customAadhaar}
                      onChange={(e) => setCustomAadhaar(e.target.value)}
                      placeholder="12-digit Aadhaar"
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                    />
                  </div>
                  <div>
                    <label className="font-semibold text-slate-500 block mb-1">Emergency Phone</label>
                    <input
                      type="text"
                      value={customEmergencyPhone}
                      onChange={(e) => setCustomEmergencyPhone(e.target.value)}
                      placeholder="Guardian / Contact"
                      className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                    />
                  </div>
                </div>
                <div>
                  <label className="font-semibold text-slate-500 block mb-1">Address</label>
                  <textarea
                    value={customAddress}
                    onChange={(e) => setCustomAddress(e.target.value)}
                    placeholder="Full street address..."
                    rows={2}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500 resize-none"
                  />
                </div>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowAddMemberModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={addMemberLoading}
                  className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 px-5 py-2 rounded-xl font-bold transition-all shadow-lg shadow-cyan-500/25 flex items-center gap-2"
                >
                  {addMemberLoading ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Plus className="w-4 h-4" />} Save Member
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* WhatsApp Template Create / Edit Modal */}
      {showTemplateModal && (
        <div className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-md flex items-center justify-center p-4 overflow-y-auto">
          <div className="glass-panel w-full max-w-lg p-6 rounded-3xl border border-slate-800 shadow-2xl space-y-4 my-8">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <MessageSquare className="w-5 h-5 text-cyan-400" />
                {editingTemplate ? "Edit WhatsApp Template" : "Add WhatsApp Template"}
              </h3>
              <button
                onClick={() => setShowTemplateModal(false)}
                className="p-1 rounded-lg hover:bg-slate-800 text-slate-400 hover:text-white transition-all"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveTemplate} className="space-y-3.5 text-xs">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div>
                  <label className="font-semibold text-slate-300 block mb-1">Display Name *</label>
                  <input
                    type="text"
                    value={templateForm.name}
                    onChange={(e) => setTemplateForm({ ...templateForm, name: e.target.value })}
                    placeholder="e.g. Rent Due Reminder"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                    required
                  />
                </div>
                <div>
                  <label className="font-semibold text-slate-300 block mb-1">Meta Template ID *</label>
                  <input
                    type="text"
                    value={templateForm.templateId}
                    onChange={(e) => setTemplateForm({ ...templateForm, templateId: e.target.value })}
                    placeholder="e.g. rt_rent_reminder_v1"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono focus:outline-none focus:border-cyan-500"
                    required
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                <div>
                  <label className="font-semibold text-slate-300 block mb-1">Category</label>
                  <select
                    value={templateForm.category}
                    onChange={(e) => setTemplateForm({ ...templateForm, category: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                  >
                    <option value="UTILITY">UTILITY</option>
                    <option value="AUTHENTICATION">AUTHENTICATION</option>
                    <option value="MARKETING">MARKETING</option>
                  </select>
                </div>
                <div>
                  <label className="font-semibold text-slate-300 block mb-1">Template Type</label>
                  <select
                    value={templateForm.templateType}
                    onChange={(e) => setTemplateForm({ ...templateForm, templateType: e.target.value })}
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white focus:outline-none focus:border-cyan-500"
                  >
                    <option value="RENT_REMINDER">RENT_REMINDER</option>
                    <option value="OTP">OTP</option>
                    <option value="PAYMENT_RECEIPT">PAYMENT_RECEIPT</option>
                    <option value="MEMBER_WELCOME">MEMBER_WELCOME</option>
                    <option value="RENEWAL_REMINDER">RENEWAL_REMINDER</option>
                    <option value="MONTH_FREEZE">MONTH_FREEZE</option>
                    <option value="CUSTOM">CUSTOM</option>
                  </select>
                </div>
                <div>
                  <label className="font-semibold text-slate-300 block mb-1">Language</label>
                  <input
                    type="text"
                    value={templateForm.language}
                    onChange={(e) => setTemplateForm({ ...templateForm, language: e.target.value })}
                    placeholder="en, ml"
                    className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white uppercase focus:outline-none focus:border-cyan-500"
                  />
                </div>
              </div>

              <div>
                <label className="font-semibold text-slate-300 block mb-1">Message Content / Format *</label>
                <textarea
                  value={templateForm.messageText}
                  onChange={(e) => setTemplateForm({ ...templateForm, messageText: e.target.value })}
                  placeholder="e.g. Hello {{1}}, your rent of ₹{{2}} is due on {{4}}. Pay directly via: {{5}}"
                  rows={4}
                  className="w-full bg-slate-900 border border-slate-800 rounded-xl px-3 py-2 text-white font-mono text-xs focus:outline-none focus:border-cyan-500 resize-none leading-relaxed"
                  required
                />
              </div>

              <div className="p-2.5 rounded-xl bg-slate-900/90 border border-slate-800 text-[11px] text-slate-400 space-y-1">
                <span className="font-bold text-slate-300 block">Parameter Placeholders Guide:</span>
                <p>• <code className="text-cyan-400">{"{{1}}"}</code>: Customer / Member Name</p>
                <p>• <code className="text-cyan-400">{"{{2}}"}</code>: Amount (or OTP verification code)</p>
                <p>• <code className="text-cyan-400">{"{{3}}"}</code>: Month / Period (or OTP validity duration)</p>
                <p>• <code className="text-cyan-400">{"{{4}}"}</code>: Due Date / Receipt ID</p>
                <p>• <code className="text-cyan-400">{"{{5}}"}</code>: Direct Tenant Payout Link (UPI Deep Link or Razorpay)</p>
              </div>

              <div className="flex justify-end gap-3 pt-3 border-t border-slate-800">
                <button
                  type="button"
                  onClick={() => setShowTemplateModal(false)}
                  className="px-4 py-2 rounded-xl text-slate-400 hover:text-white font-semibold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="bg-cyan-500 hover:bg-cyan-400 text-slate-950 px-5 py-2 rounded-xl font-bold transition-all shadow-lg shadow-cyan-500/20"
                >
                  Save Template
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
