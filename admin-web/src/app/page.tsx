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
  isFreeTrial: boolean;
  isActive: boolean;
  sortOrder: number;
}

export default function AdminDashboard() {
  // Auth state
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [loginEmail, setLoginEmail] = useState("admin");
  const [loginPassword, setLoginPassword] = useState("admin");
  const [loginError, setLoginError] = useState("");
  const [authOrg, setAuthOrg] = useState<{ id: string; name: string } | null>(null);

  // Tab & Filter states
  const [activeTab, setActiveTab] = useState<"members" | "plans" | "expenses" | "reports" | "custom_fields" | "app_subscription_plans">("members");
  const [statusFilter, setStatusFilter] = useState<"ALL" | "PAID" | "UNPAID" | "FROZEN">("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const [loading, setLoading] = useState(false);

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
    isFreeTrial: false,
    isActive: true,
    sortOrder: 1,
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
    }
  }, []);

  // Login handler
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
    } catch (err) {
      setLoginError("Could not connect to backend server. Make sure backend is running on port 5001.");
    } finally {
      setLoading(false);
    }
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

          <form onSubmit={handleLogin} className="space-y-4">
            {loginError && (
              <div className="p-3 rounded-xl bg-rose-500/20 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{loginError}</span>
              </div>
            )}

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
    </div>
  );
}
