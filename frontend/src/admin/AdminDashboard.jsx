import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { 
  IndianRupee, Smartphone, Clock, CheckCircle2, AlertCircle, 
  Search, Filter, QrCode, Upload, Eye, UserPlus, RefreshCw, 
  Layers, ShieldAlert, Award, FileText, ChevronRight, Sparkles,
  Truck, X, MapPin, Calendar, UserCheck, User, Users, Phone, Mail, Edit3, Building, ShieldCheck, Trash2, KeyRound
} from 'lucide-react';
import { api } from '../services/api';
import PayoutModal from './PayoutModal';
import ReceiptModal from '../customer/ReceiptModal';
import CataloguePricingManager from './CataloguePricingManager';
import AdminSidebar from './AdminSidebar';
import AdminHeader from './AdminHeader';
import OperationsDashboardView from './OperationsDashboardView';
import SystemSettingsView from './SystemSettingsView';

export default function AdminDashboard({ currentUser, onNavigate, onLogout }) {
  const [activeTab, setActiveTab] = useState('dashboard'); // 'dashboard' | 'sales' | 'customers' | 'payouts' | ...
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [catalogueCounts, setCatalogueCounts] = useState({
    deviceCategories: 0,
    brands: 0,
    models: 0,
    variants: 0,
    options: 0,
    cms: 0
  });
  const [catalogueModels, setCatalogueModels] = useState([]);
  
  const [sales, setSales] = useState([]);
  const [paymentsList, setPaymentsList] = useState({ total_count: 0, total_disbursed: 0, payments: [] });
  const [conditionCategories, setConditionCategories] = useState([]);
  const [agents, setAgents] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [customerSearch, setCustomerSearch] = useState('');
  
  const [loading, setLoading] = useState(false);
  const [filterStatus, setFilterStatus] = useState('');
  const [searchQuery, setSearchQuery] = useState('');

  // Modals
  const [payoutSale, setPayoutSale] = useState(null);
  const [assignSale, setAssignSale] = useState(null);
  const [selectedAgentId, setSelectedAgentId] = useState('');
  const [pickupDate, setPickupDate] = useState('');
  const [pickupSlot, setPickupSlot] = useState('Morning (10:00 AM - 1:00 PM)');
  
  // Receipt view modal
  const [receiptData, setReceiptData] = useState(null);

  // End-to-End Tracing Modal
  const [traceSale, setTraceSale] = useState(null);
  const [traceLoading, setTraceLoading] = useState(false);

  // Edit condition option modal
  const [editingOption, setEditingOption] = useState(null);
  const [newDeductionValue, setNewDeductionValue] = useState('');

  // Agent assignment state
  const [assigningLoading, setAssigningLoading] = useState(false);
  const [successToast, setSuccessToast] = useState('');

  // Add Field Agent Modal State
  const [createAgentModalOpen, setCreateAgentModalOpen] = useState(false);
  const [newAgentName, setNewAgentName] = useState('');
  const [newAgentPhone, setNewAgentPhone] = useState('');
  const [newAgentEmail, setNewAgentEmail] = useState('');
  const [newAgentPassword, setNewAgentPassword] = useState('');
  const [creatingAgentLoading, setCreatingAgentLoading] = useState(false);
  const [agentCreateError, setAgentCreateError] = useState('');

  const handleCreateAgent = async (e) => {
    e.preventDefault();
    if (!newAgentName.trim() || !newAgentPhone.trim() || !newAgentEmail.trim() || !newAgentPassword) {
      setAgentCreateError('Please complete all fields.');
      return;
    }
    if (newAgentPhone.trim().length !== 10) {
      setAgentCreateError('Please enter a valid 10-digit mobile number.');
      return;
    }
    setCreatingAgentLoading(true);
    setAgentCreateError('');
    try {
      await api.createAgent({
        full_name: newAgentName.trim(),
        phone: newAgentPhone.trim(),
        email: newAgentEmail.trim(),
        password: newAgentPassword,
      });
      setSuccessToast(`✓ Field Agent "${newAgentName}" created successfully!`);
      setNewAgentName('');
      setNewAgentPhone('');
      setNewAgentEmail('');
      setNewAgentPassword('');
      setCreateAgentModalOpen(false);
      // Refresh agents list
      const freshAgents = await api.getAgents().catch(() => []);
      setAgents(freshAgents);
      if (freshAgents.length > 0 && !selectedAgentId) {
        setSelectedAgentId(String(freshAgents[0].id));
      }
    } catch (err) {
      setAgentCreateError(err.message || 'Failed to create field agent.');
    } finally {
      setCreatingAgentLoading(false);
    }
  };

  // Change Agent Password State
  const [agentPasswordModalOpen, setAgentPasswordModalOpen] = useState(false);
  const [selectedAgentForPassword, setSelectedAgentForPassword] = useState(null);
  const [newAgentPasswordToSet, setNewAgentPasswordToSet] = useState('');
  const [updatingAgentPasswordLoading, setUpdatingAgentPasswordLoading] = useState(false);
  const [agentPasswordError, setAgentPasswordError] = useState('');

  const handleUpdateAgentPassword = async (e) => {
    e.preventDefault();
    if (!newAgentPasswordToSet || newAgentPasswordToSet.trim().length < 6) {
      setAgentPasswordError('Password must be at least 6 characters long.');
      return;
    }
    setUpdatingAgentPasswordLoading(true);
    setAgentPasswordError('');
    try {
      await api.updateAgent(selectedAgentForPassword.id, { password: newAgentPasswordToSet.trim() });
      setSuccessToast(`✓ Password for "${selectedAgentForPassword.full_name}" updated successfully!`);
      setAgentPasswordModalOpen(false);
      setSelectedAgentForPassword(null);
      setNewAgentPasswordToSet('');
    } catch (err) {
      setAgentPasswordError(err.message || 'Failed to update agent password.');
    } finally {
      setUpdatingAgentPasswordLoading(false);
    }
  };

  // Change My Password State (Admin self-service)
  const [changeMyPasswordModalOpen, setChangeMyPasswordModalOpen] = useState(false);
  const [myOldPassword, setMyOldPassword] = useState('');
  const [myNewPassword, setMyNewPassword] = useState('');
  const [myConfirmPassword, setMyConfirmPassword] = useState('');
  const [myPasswordLoading, setMyPasswordLoading] = useState(false);
  const [myPasswordError, setMyPasswordError] = useState('');

  const handleChangeMyPassword = async (e) => {
    e.preventDefault();
    if (!myNewPassword || myNewPassword.trim().length < 6) {
      setMyPasswordError('New password must be at least 6 characters long.');
      return;
    }
    if (myNewPassword !== myConfirmPassword) {
      setMyPasswordError('New passwords do not match.');
      return;
    }
    setMyPasswordLoading(true);
    setMyPasswordError('');
    try {
      await api.changePassword({ old_password: myOldPassword, new_password: myNewPassword.trim() });
      setSuccessToast('✓ Your password has been changed successfully!');
      setChangeMyPasswordModalOpen(false);
      setMyOldPassword('');
      setMyNewPassword('');
      setMyConfirmPassword('');
    } catch (err) {
      setMyPasswordError(err.message || 'Failed to change password.');
    } finally {
      setMyPasswordLoading(false);
    }
  };

  // Customer Management Modals & Handlers
  const [createCustomerModalOpen, setCreateCustomerModalOpen] = useState(false);
  const [editingCustomer, setEditingCustomer] = useState(null);
  
  // New Customer form
  const [newCustName, setNewCustName] = useState('');
  const [newCustPhone, setNewCustPhone] = useState('');
  const [newCustEmail, setNewCustEmail] = useState('');
  const [newCustPassword, setNewCustPassword] = useState('');
  const [newCustAddress, setNewCustAddress] = useState('');
  const [newCustCity, setNewCustCity] = useState('');
  const [newCustPincode, setNewCustPincode] = useState('');
  const [newCustUpi, setNewCustUpi] = useState('');
  const [creatingCustLoading, setCreatingCustLoading] = useState(false);
  const [custError, setCustError] = useState('');

  // Edit Customer form
  const [editCustName, setEditCustName] = useState('');
  const [editCustPhone, setEditCustPhone] = useState('');
  const [editCustEmail, setEditCustEmail] = useState('');
  const [editCustAddress, setEditCustAddress] = useState('');
  const [editCustCity, setEditCustCity] = useState('');
  const [editCustPincode, setEditCustPincode] = useState('');
  const [editCustUpi, setEditCustUpi] = useState('');
  const [editCustActive, setEditCustActive] = useState(true);
  const [editCustLoading, setEditCustLoading] = useState(false);

  const handleCreateCustomer = async (e) => {
    e.preventDefault();
    if (!newCustName.trim() || !newCustPhone.trim() || !newCustEmail.trim() || !newCustPassword) {
      setCustError('Please complete required fields (Name, Phone, Email, Password).');
      return;
    }
    if (newCustPhone.trim().length !== 10) {
      setCustError('Please enter a valid 10-digit mobile number.');
      return;
    }
    setCreatingCustLoading(true);
    setCustError('');
    try {
      await api.createCustomer({
        full_name: newCustName.trim(),
        phone: newCustPhone.trim(),
        email: newCustEmail.trim(),
        password: newCustPassword,
        default_address: newCustAddress.trim(),
        city: newCustCity.trim(),
        pincode: newCustPincode.trim(),
        default_upi_id: newCustUpi.trim(),
      });
      setSuccessToast(`✓ Customer "${newCustName}" registered successfully!`);
      setNewCustName('');
      setNewCustPhone('');
      setNewCustEmail('');
      setNewCustPassword('');
      setNewCustAddress('');
      setNewCustCity('');
      setNewCustPincode('');
      setNewCustUpi('');
      setCreateCustomerModalOpen(false);
      const freshCusts = await api.getCustomers().catch(() => []);
      setCustomers(freshCusts);
    } catch (err) {
      setCustError(err.message || 'Failed to create customer account.');
    } finally {
      setCreatingCustLoading(false);
    }
  };

  const handleOpenEditCustomer = (c) => {
    setEditingCustomer(c);
    setEditCustName(c.full_name || '');
    setEditCustPhone(c.phone || '');
    setEditCustEmail(c.email || '');
    setEditCustAddress(c.default_address || '');
    setEditCustCity(c.city || '');
    setEditCustPincode(c.pincode || '');
    setEditCustUpi(c.default_upi_id || '');
    setEditCustActive(c.is_active !== false);
  };

  const handleSaveCustomer = async (e) => {
    e.preventDefault();
    if (!editingCustomer) return;
    setEditCustLoading(true);
    try {
      await api.updateCustomer(editingCustomer.id, {
        full_name: editCustName.trim(),
        phone: editCustPhone.trim(),
        email: editCustEmail.trim(),
        default_address: editCustAddress.trim(),
        city: editCustCity.trim(),
        pincode: editCustPincode.trim(),
        default_upi_id: editCustUpi.trim(),
        is_active: editCustActive,
      });
      setSuccessToast(`✓ Customer "${editCustName}" updated successfully!`);
      setEditingCustomer(null);
      const freshCusts = await api.getCustomers().catch(() => []);
      setCustomers(freshCusts);
    } catch (err) {
      alert(err.message || 'Failed to update customer');
    } finally {
      setEditCustLoading(false);
    }
  };

  const handlePromoteToAgent = async (c) => {
    if (!window.confirm(`Are you sure you want to promote customer "${c.full_name || c.phone}" to a Field Collection Agent?`)) return;
    try {
      await api.updateCustomer(c.id, { role: 'COLLECTION_AGENT' });
      setSuccessToast(`✓ ${c.full_name || c.phone} is now a Field Collection Agent!`);
      const [freshCusts, freshAgents] = await Promise.all([
        api.getCustomers().catch(() => []),
        api.getAgents().catch(() => []),
      ]);
      setCustomers(freshCusts);
      setAgents(freshAgents);
    } catch (err) {
      alert(err.message || 'Failed to promote customer');
    }
  };

  const handleToggleCustomerActive = async (c) => {
    try {
      await api.toggleCustomerActive(c.id);
      setSuccessToast(`✓ Customer account status updated!`);
      const freshCusts = await api.getCustomers().catch(() => []);
      setCustomers(freshCusts);
    } catch (err) {
      alert(err.message || 'Failed to toggle status');
    }
  };

  const handleDeleteCustomer = async (c) => {
    const custLabel = c.full_name ? `${c.full_name} (${c.phone || c.email || 'ID: #' + c.id})` : (c.phone || c.email || `Customer #${c.id}`);
    if (!window.confirm(`Are you sure you want to permanently delete customer "${custLabel}"?\n\nThis action cannot be undone.`)) {
      return;
    }
    try {
      await api.deleteCustomer(c.id);
      setSuccessToast(`✓ Customer "${c.full_name || c.phone}" deleted successfully.`);
      setCustomers(prev => prev.filter(item => item.id !== c.id));
    } catch (err) {
      alert(err.message || 'Failed to delete customer');
    }
  };

  const handleDeleteAgent = async (ag) => {
    const agentLabel = ag.full_name ? `${ag.full_name} (${ag.phone || ag.email || 'ID: #' + ag.id})` : (ag.phone || `Agent #${ag.id}`);
    if (!window.confirm(`Are you sure you want to delete Field Agent "${agentLabel}"?\n\nAny uncollected orders assigned to this agent will be returned to the unassigned queue.`)) {
      return;
    }
    try {
      await api.deleteAgent(ag.id);
      setSuccessToast(`✓ Agent "${ag.full_name || ag.phone}" removed successfully.`);
      setAgents(prev => prev.filter(item => item.id !== ag.id));
    } catch (err) {
      alert(err.message || 'Failed to delete agent');
    }
  };

  // History tab date filters
  const [historyPeriod, setHistoryPeriod] = useState('all');
  const [historyStartDate, setHistoryStartDate] = useState('');
  const [historyEndDate, setHistoryEndDate] = useState('');
  const [historyLoading, setHistoryLoading] = useState(false);

  const filterPayments = async (period = historyPeriod, start = historyStartDate, end = historyEndDate) => {
    setHistoryLoading(true);
    setHistoryPeriod(period);
    setHistoryStartDate(start);
    setHistoryEndDate(end);
    try {
      const params = {};
      if (period && period !== 'all') params.period = period;
      if (start) params.start_date = start;
      if (end) params.end_date = end;
      const data = await api.getPaymentsList(params);
      setPaymentsList(data);
    } catch (e) {
      console.error('Failed to filter payments:', e);
    } finally {
      setHistoryLoading(false);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    setLoading(true);
    try {
      const [salesData, paymentsData, catsData, agentsData, customersData, dCats, brandsData, modelsData, cmsData, optsData] = await Promise.all([
        api.getSales(),
        api.getPaymentsList().catch(() => ({ total_count: 0, total_disbursed: 0, payments: [] })),
        api.getConditionCategories().catch(() => []),
        api.getAgents().catch(() => []),
        api.getCustomers().catch(() => []),
        api.getCategories(true).catch(() => []),
        api.getBrands(true, true).catch(() => []),
        api.getModels(null, true).catch(() => []),
        api.getCMSSections().catch(() => []),
        api.getConditionOptions().catch(() => [])
      ]);
      setSales(salesData);
      setPaymentsList(paymentsData);
      setConditionCategories(catsData);
      setAgents(agentsData);
      setCustomers(customersData);
      setCatalogueModels(modelsData || []);
      setCatalogueCounts({
        deviceCategories: (dCats || []).length,
        brands: (brandsData || []).length,
        models: (modelsData || []).length,
        variants: (modelsData || []).reduce((acc, m) => acc + (m.variants?.length || 0), 0) || (modelsData || []).length,
        options: (optsData || []).length,
        cms: (cmsData || []).length
      });
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  // Metrics: Payout is strictly available ONLY after device is physically collected (OWNERSHIP_TRANSFERRED)
  const pendingInspectionsCount = sales.filter(s => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].includes(s.status)).length;
  const awaitingPayoutsCount = sales.filter(s => s.status === 'OWNERSHIP_TRANSFERRED').length;
  const completedCount = sales.filter(s => s.status === 'PAYMENT_COMPLETED').length;

  const handleOpenTraceModal = async (s) => {
    setTraceSale(s);
    setTraceLoading(true);
    try {
      const fullDetail = await api.getSaleDetail(s.id || s.sale_code);
      setTraceSale(fullDetail);
    } catch {
      // retain basic data
    } finally {
      setTraceLoading(false);
    }
  };

  const getTomorrowDateStr = () => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    return d.toISOString().split('T')[0];
  };

  const handleOpenAssignModal = (s) => {
    setAssignSale(s);
    setSelectedAgentId(s.assigned_agent ? String(s.assigned_agent) : (agents[0]?.id ? String(agents[0].id) : ''));
    const tomorrowStr = getTomorrowDateStr();
    // Default to tomorrow if pickup_date is missing or in the past/today
    const initialDate = (s.pickup_date && s.pickup_date >= tomorrowStr) ? s.pickup_date : tomorrowStr;
    setPickupDate(initialDate);
    setPickupSlot(s.pickup_slot || 'Morning (10:00 AM - 1:00 PM)');
  };

  const handleAssignPickup = async (e) => {
    e.preventDefault();
    if (!assignSale) return;
    setAssigningLoading(true);
    try {
      const targetId = assignSale.id || assignSale.sale_code;
      await api.assignPickup(targetId, {
        agent_id: selectedAgentId,
        pickup_date: pickupDate,
        pickup_slot: pickupSlot,
      });
      const code = assignSale.sale_code;
      const targetAgent = agents.find(a => String(a.id) === String(selectedAgentId));
      
      // Fast optimistic update: update table immediately
      setSales(prev => prev.map(s => s.id === assignSale.id ? {
        ...s,
        assigned_agent: selectedAgentId,
        assigned_agent_name: targetAgent ? targetAgent.full_name : (s.assigned_agent_name || 'Assigned Agent'),
        status: 'PICKUP_SCHEDULED',
        pickup_date: pickupDate,
        pickup_slot: pickupSlot
      } : s));

      setAssignSale(null);
      setSuccessToast(`✓ Pickup scheduled & assigned to ${targetAgent ? targetAgent.full_name : 'Agent'} for order ${code}!`);
      setTimeout(() => setSuccessToast(''), 3500);
      loadDashboardData();
    } catch (err) {
      alert(err.message || 'Failed to assign agent');
    } finally {
      setAssigningLoading(false);
    }
  };

  const handleShiftToTomorrow = async (saleId) => {
    try {
      await api.shiftPickupToNextDay(saleId);
      setSuccessToast('✓ Pickup successfully shifted to tomorrow!');
      setTimeout(() => setSuccessToast(''), 3500);
      loadDashboardData();
    } catch (err) {
      alert(err.message || 'Failed to shift pickup');
    }
  };

  const handleUpdateDeduction = async (e) => {
    e.preventDefault();
    if (!editingOption) return;
    try {
      await api.updateConditionOption(editingOption.id, {
        default_deduction_value: newDeductionValue
      });
      setEditingOption(null);
      loadDashboardData();
    } catch (err) {
      alert(err.message);
    }
  };

  // Filtered sales
  const filteredSales = sales.filter(s => {
    const matchesStatus = filterStatus ? s.status === filterStatus : true;
    const matchesQuery = searchQuery 
      ? s.sale_code.toLowerCase().includes(searchQuery.toLowerCase()) ||
        s.customer_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        s.customer_phone.includes(searchQuery)
      : true;
    return matchesStatus && matchesQuery;
  });

  // Sales ready for payout desk
  const payoutQueue = sales.filter(s => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].includes(s.status));

  return (
    <div className="flex h-screen w-full overflow-hidden bg-slate-50 text-slate-900 font-sans">
      
      {/* 1. Left Dark Emerald Sidebar */}
      <AdminSidebar
        currentView={activeTab}
        onSelectView={(viewId) => setActiveTab(viewId)}
        collapsed={sidebarCollapsed}
        onToggleCollapse={() => setSidebarCollapsed(!sidebarCollapsed)}
        counts={{
          sales: sales.length,
          customers: customers.length,
          awaitingPayouts: awaitingPayoutsCount,
          payments: paymentsList.total_count,
          agents: agents.length,
          deviceCategories: catalogueCounts.deviceCategories,
          brands: catalogueCounts.brands,
          models: catalogueCounts.models,
          variants: catalogueCounts.variants,
          questions: conditionCategories.length,
          deductions: catalogueCounts.options,
          cms: catalogueCounts.cms
        }}
      />

      {/* 2. Main Workspace Body */}
      <div className="flex-1 flex flex-col min-w-0 h-full overflow-hidden">
        
        {/* Sticky Top Header */}
        <AdminHeader
          currentUser={currentUser}
          onToggleSidebar={() => setSidebarCollapsed(!sidebarCollapsed)}
          onNavigateTab={onNavigate}
          onLogout={onLogout}
          onChangePassword={() => setChangeMyPasswordModalOpen(true)}
          onQuickSearchSelect={(type, item) => {
            if (type === 'sales') {
              setActiveTab('sales');
              setSearchQuery(item.sale_code || '');
            } else if (type === 'customers') {
              setActiveTab('customers');
              setCustomerSearch(item.phone || item.full_name || '');
            } else if (type === 'models') {
              setActiveTab('models');
            }
          }}
          sales={sales}
          customers={customers}
          models={catalogueModels}
        />

        {/* Scrollable Main Views Area */}
        <div className="flex-1 overflow-y-auto p-3 sm:p-6 lg:p-7 space-y-6">
          
          {successToast && (
            <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 p-3.5 rounded-2xl text-xs font-bold flex items-center gap-2 animate-fade-in shadow-xs">
              <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
              <span>{successToast}</span>
            </div>
          )}

          {/* ================= TAB 0: OPERATIONS DASHBOARD (OVERVIEW) ================= */}
          {activeTab === 'dashboard' && (
            <OperationsDashboardView
              sales={sales}
              paymentsList={paymentsList}
              customers={customers}
              models={catalogueModels}
              onNavigateView={(v) => setActiveTab(v)}
              onOpenPayout={(s) => setPayoutSale(s)}
              onAddManualSale={() => {
                if (onNavigate) onNavigate('sell');
              }}
            />
          )}

          {/* ================= TAB 1: PAYOUT DESK ================= */}
      {activeTab === 'payouts' && (
        <div className="space-y-4 animate-fade-in">
          <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 text-xs text-amber-900 flex items-start gap-3">
            <ShieldAlert className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
            <div>
              <p className="font-extrabold">Instant Manual Payout Desk:</p>
              <p className="text-amber-800 mt-0.5">
                These orders have completed physical inspection and legal handover. Click <strong>"Pay Customer & Upload Proof"</strong> to view the customer's UPI QR code / Bank details, transfer the funds from any payment app (GPay/PhonePe), and upload the Base64 proof + 12-digit UTR number.
              </p>
            </div>
          </div>

          {payoutQueue.length > 0 ? (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {payoutQueue.map((s) => (
                <div key={s.id} className="bg-white border border-slate-200 rounded-2xl p-6 shadow-sm space-y-4 hover:border-emerald-300 transition">
                  <div className="flex items-start justify-between">
                    <div>
                      <span className="font-mono text-xs font-bold bg-slate-100 text-slate-800 px-2 py-0.5 rounded">
                        {s.sale_code}
                      </span>
                      <h4 className="font-extrabold text-base text-slate-900 mt-1">
                        {s.brand_name} {s.model_name}
                      </h4>
                      <p className="text-xs text-slate-500">
                        {s.variant_details?.ram ? `${s.variant_details.ram} / ` : ''}{s.variant_details?.storage}
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="text-[11px] text-slate-400 block font-medium">Approved Payout</span>
                      <span className="text-2xl font-black text-emerald-600">
                        ₹{Number(s.final_price || s.estimated_price).toLocaleString('en-IN')}
                      </span>
                    </div>
                  </div>

                  {/* Customer info */}
                  <div className="bg-slate-50 p-3 rounded-xl text-xs space-y-1 text-slate-600">
                    <p><strong className="text-slate-800">Customer:</strong> {s.customer_name} ({s.customer_phone})</p>
                    <p>
                      <strong className="text-slate-800">Method:</strong> {s.beneficiary_type} ·{' '}
                      <span className="font-mono text-emerald-800 font-bold">
                        {s.beneficiary_upi_id || `${s.beneficiary_account_no} (${s.beneficiary_ifsc})`}
                      </span>
                    </p>
                    {s.imei_number && (
                      <p><strong className="text-slate-800">Verified IMEI:</strong> <span className="font-mono">{s.imei_number}</span></p>
                    )}
                  </div>

                  <button
                    onClick={() => setPayoutSale(s)}
                    className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold py-3 rounded-xl text-xs shadow-md shadow-emerald-600/20 transition flex items-center justify-center gap-2"
                  >
                    <QrCode className="w-4 h-4" />
                    Pay Customer & Upload Proof (UTR)
                  </button>
                </div>
              ))}
            </div>
          ) : (
            <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-400 text-xs">
              <CheckCircle2 className="w-10 h-10 text-emerald-500 mx-auto mb-2" />
              <p className="font-bold text-slate-700 text-sm">All caught up!</p>
              <p className="mt-1">No orders currently awaiting customer payout authorization.</p>
            </div>
          )}
        </div>
      )}

      {/* ================= TAB 2: ALL CUSTOMER SALES ================= */}
      {activeTab === 'sales' && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in space-y-4 p-5">
          {/* Filters, Search & Add Agent Action */}
          <div className="flex flex-col sm:flex-row gap-3 items-stretch sm:items-center justify-between">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search by Sale Code, customer name, or phone..."
                className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div className="flex items-center gap-2">
              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
              >
                <option value="">All Statuses</option>
                <option value="SUBMITTED">Submitted</option>
                <option value="PICKUP_SCHEDULED">Pickup Scheduled</option>
                <option value="FINAL_OFFER_SENT">Final Offer Sent</option>
                <option value="CUSTOMER_ACCEPTED">Offer Confirmed by Customer</option>
                <option value="OWNERSHIP_TRANSFERRED">Pickup Completed (In Custody)</option>
                <option value="PAYMENT_COMPLETED">Payment Completed (Paid)</option>
              </select>

              <button
                type="button"
                onClick={() => setCreateAgentModalOpen(true)}
                className="px-3.5 py-2 bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-extrabold rounded-xl text-xs shadow-md shadow-[#0BAA4B]/20 transition flex items-center gap-1.5 shrink-0 active:scale-98"
              >
                <UserPlus className="w-3.5 h-3.5" />
                <span>+ Add Field Agent</span>
              </button>
            </div>
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-600 font-bold uppercase tracking-wider border-y border-slate-200">
                <tr>
                  <th className="py-3 px-3">Sale ID</th>
                  <th className="py-3 px-3">Customer</th>
                  <th className="py-3 px-3">Device</th>
                  <th className="py-3 px-3">Est. / Final</th>
                  <th className="py-3 px-3">Agent</th>
                  <th className="py-3 px-3">Status</th>
                  <th className="py-3 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {filteredSales.map((s) => (
                  <tr key={s.id} className="hover:bg-slate-50 transition">
                    <td className="py-3.5 px-3 font-mono font-bold text-slate-900">
                      {s.sale_code}
                    </td>
                    <td className="py-3.5 px-3">
                      <p className="font-bold text-slate-800">{s.customer_name}</p>
                      <p className="text-slate-500 text-[11px]">{s.customer_phone}</p>
                    </td>
                    <td className="py-3.5 px-3">
                      <p className="font-semibold text-slate-800">{s.brand_name} {s.model_name}</p>
                      <p className="text-slate-500 text-[11px]">{s.storage || s.variant_details?.storage || ''}</p>
                    </td>
                    <td className="py-3.5 px-3 font-bold">
                      <span className="text-slate-900">
                        ₹{Number(s.final_price || s.estimated_price).toLocaleString('en-IN')}
                      </span>
                    </td>
                    <td className="py-3.5 px-3 text-slate-600">
                      {s.assigned_agent_name ? (
                        <span className="font-medium text-slate-800">{s.assigned_agent_name}</span>
                      ) : (
                        <span className="text-amber-600 font-medium">Unassigned</span>
                      )}
                    </td>
                    <td className="py-3.5 px-3">
                      <span className={`px-2 py-0.5 rounded-full text-[11px] font-bold ${
                        s.status === 'PAYMENT_COMPLETED' ? 'bg-emerald-100 text-emerald-800' :
                        s.status === 'FINAL_OFFER_SENT' ? 'bg-amber-100 text-amber-800' :
                        s.status === 'CUSTOMER_ACCEPTED' ? 'bg-blue-100 text-blue-800' :
                        s.status === 'OWNERSHIP_TRANSFERRED' ? 'bg-emerald-100 text-emerald-900 border border-emerald-300' :
                        'bg-slate-100 text-slate-700'
                      }`}>
                        {s.status === 'OWNERSHIP_TRANSFERRED' ? 'Pickup Completed' : s.status.replace(/_/g, ' ')}
                      </span>
                    </td>
                    <td className="py-3.5 px-3 text-right space-x-1 whitespace-nowrap">
                      <button
                        onClick={() => handleOpenTraceModal(s)}
                        className="px-2.5 py-1 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border border-indigo-200 rounded-lg text-[11px] font-bold transition"
                        title="View Complete End-to-End Tracing"
                      >
                        🔍 Trace
                      </button>
                      {['SUBMITTED', 'PICKUP_SCHEDULED'].includes(s.status) && (
                        <>
                          <button
                            onClick={() => handleOpenAssignModal(s)}
                            className="px-2.5 py-1 bg-slate-900 hover:bg-black text-white rounded-lg text-[11px] font-bold transition"
                          >
                            Schedule
                          </button>
                          <button
                            onClick={() => handleShiftToTomorrow(s.id || s.sale_code)}
                            className="px-2 py-1 bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-300 rounded-lg text-[11px] font-bold transition"
                            title="Shift this pickup to tomorrow"
                          >
                            ⏩ Next Day
                          </button>
                        </>
                      )}
                      {s.status === 'FINAL_OFFER_SENT' && (
                        <span className="inline-block px-2 py-0.5 bg-amber-100 text-amber-900 font-bold rounded-lg text-[10px]">
                          Awaiting Customer
                        </span>
                      )}
                      {s.status === 'CUSTOMER_ACCEPTED' && (
                        <span className="inline-block px-2 py-0.5 bg-blue-100 text-blue-900 font-bold rounded-lg text-[10px]">
                          Confirmed · Awaiting Collection
                        </span>
                      )}
                      {s.status === 'OWNERSHIP_TRANSFERRED' && (
                        <button
                          onClick={() => setPayoutSale(s)}
                          className="px-2.5 py-1 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-[11px] font-bold transition shadow-sm"
                        >
                          Payout
                        </button>
                      )}
                      {s.status === 'PAYMENT_COMPLETED' && (
                        <button
                          onClick={async () => {
                            const rec = await api.getPaymentReceipt(s.sale_code);
                            setReceiptData(rec);
                          }}
                          className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-800 rounded-lg text-[11px] font-bold transition"
                        >
                          Receipt
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ================= TAB 3: PHONE CATALOGUE, PRICING, VALUATION & CMS ================= */}
      {['device_categories', 'brands', 'models', 'variants', 'questionnaire', 'deductions', 'cms', 'hero_banners', 'promotions', 'pricing', 'simulator'].includes(activeTab) && (
        <CataloguePricingManager 
          initialSubTab={
            activeTab === 'pricing' ? 'brands' :
            activeTab === 'hero_banners' || activeTab === 'promotions' ? 'cms' :
            activeTab
          }
          onSubTabChange={(newSubTab) => setActiveTab(newSubTab)}
        />
      )}

      {/* ================= TAB 4: PAYOUTS HISTORY ================= */}
      {activeTab === 'history' && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in p-5 space-y-4">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Verified Payout Ledger</h3>
              <p className="text-xs text-slate-500">All bank transfers and UPI payouts uploaded with Base64 screenshot receipts.</p>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-xs font-bold bg-emerald-100 text-emerald-800 px-3 py-1.5 rounded-full">
                Disbursed: ₹{Number(paymentsList.total_disbursed).toLocaleString('en-IN')} ({paymentsList.total_count || paymentsList.payments?.length || 0} Records)
              </span>
            </div>
          </div>

          {/* Date & Period Filters */}
          <div className="flex flex-wrap items-center justify-between gap-3 p-3 bg-slate-50 rounded-xl border border-slate-200 text-xs">
            {/* Quick Period Buttons */}
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="font-bold text-slate-600 mr-1 text-[11px] uppercase tracking-wider">Period:</span>
              {[
                { key: 'all', label: 'All Time' },
                { key: 'today', label: 'Today' },
                { key: 'yesterday', label: 'Yesterday' },
                { key: 'week', label: 'This Week' },
                { key: 'month', label: 'This Month' },
              ].map((tab) => (
                <button
                  key={tab.key}
                  type="button"
                  onClick={() => filterPayments(tab.key, '', '')}
                  className={`px-3 py-1.5 rounded-lg font-bold text-xs transition ${
                    historyPeriod === tab.key && !historyStartDate
                      ? 'bg-emerald-600 text-white shadow-xs'
                      : 'bg-white border border-slate-200 text-slate-700 hover:bg-slate-100'
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </div>

            {/* Calendar Custom Range */}
            <div className="flex items-center gap-2">
              <span className="font-bold text-slate-600 text-[11px] uppercase tracking-wider">Custom:</span>
              <input
                type="date"
                value={historyStartDate}
                onChange={(e) => filterPayments('custom', e.target.value, historyEndDate)}
                className="px-2 py-1 bg-white border border-slate-300 rounded-lg text-xs font-medium"
                title="Start Date"
              />
              <span className="text-slate-400 font-bold">to</span>
              <input
                type="date"
                value={historyEndDate}
                onChange={(e) => filterPayments('custom', historyStartDate, e.target.value)}
                className="px-2 py-1 bg-white border border-slate-300 rounded-lg text-xs font-medium"
                title="End Date"
              />
              {(historyStartDate || historyEndDate || historyPeriod !== 'all') && (
                <button
                  type="button"
                  onClick={() => filterPayments('all', '', '')}
                  className="px-2.5 py-1 text-slate-500 hover:text-slate-800 font-bold text-xs underline"
                >
                  Reset
                </button>
              )}
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-slate-50 text-slate-600 font-bold uppercase tracking-wider border-y border-slate-200">
                <tr>
                  <th className="py-3 px-3">Sale ID</th>
                  <th className="py-3 px-3">Beneficiary</th>
                  <th className="py-3 px-3">Method</th>
                  <th className="py-3 px-3">Amount</th>
                  <th className="py-3 px-3">UTR Reference</th>
                  <th className="py-3 px-3">Date</th>
                  <th className="py-3 px-3 text-right">Proof</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {paymentsList.payments?.map((p) => (
                  <tr key={p.id} className="hover:bg-slate-50 transition">
                    <td className="py-3.5 px-3 font-mono font-bold text-slate-900">{p.sale_code}</td>
                    <td className="py-3.5 px-3">
                      <p className="font-bold text-slate-800">{p.beneficiary_name}</p>
                      <p className="text-slate-500 font-mono text-[11px]">{p.beneficiary_upi_id || p.beneficiary_account_no}</p>
                    </td>
                    <td className="py-3.5 px-3 font-semibold text-slate-700">{p.payment_method}</td>
                    <td className="py-3.5 px-3 font-black text-emerald-600">₹{Number(p.amount).toLocaleString('en-IN')}</td>
                    <td className="py-3.5 px-3 font-mono font-bold text-slate-800">{p.utr_number}</td>
                    <td className="py-3.5 px-3 text-slate-500">{new Date(p.paid_at).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata', dateStyle: 'medium', timeStyle: 'short' })} IST</td>
                    <td className="py-3.5 px-3 text-right">
                      <button
                        onClick={async () => {
                          const rec = await api.getPaymentReceipt(p.sale_code);
                          setReceiptData(rec);
                        }}
                        className="px-2.5 py-1 bg-slate-900 hover:bg-black text-white rounded-lg text-[11px] font-bold transition inline-flex items-center gap-1"
                      >
                        <Eye className="w-3 h-3" /> View Receipt
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* ================= TAB 5: FIELD AGENTS MANAGEMENT ================= */}
      {activeTab === 'agents' && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in p-5 sm:p-6 space-y-6">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-slate-100 pb-5">
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base sm:text-lg font-black text-slate-900">Field Collection Specialists</h3>
                <span className="text-xs font-black bg-emerald-100 text-emerald-800 px-2.5 py-0.5 rounded-full border border-emerald-200">
                  {agents.length} Active Staff
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-1">
                Manage field collection agents responsible for doorstep gadget inspection, IMEI testing, and customer handovers.
              </p>
            </div>

            <button
              onClick={() => setCreateAgentModalOpen(true)}
              className="bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-2.5 px-4 rounded-xl text-xs shadow-md shadow-[#0BAA4B]/20 transition flex items-center gap-2 active:scale-98"
            >
              <UserPlus className="w-4 h-4" />
              <span>+ Add Field Agent</span>
            </button>
          </div>

          {agents.length === 0 ? (
            <div className="bg-slate-50 border border-dashed border-slate-300 rounded-2xl p-10 text-center space-y-3">
              <div className="w-14 h-14 mx-auto rounded-2xl bg-emerald-100 text-[#087C38] flex items-center justify-center">
                <UserCheck className="w-7 h-7" />
              </div>
              <h4 className="text-sm font-bold text-slate-800">No Field Agents Configured Yet</h4>
              <p className="text-xs text-slate-500 max-w-md mx-auto">
                Create field agent accounts so you can schedule doorstep inspections and assign pickup requests across your service zones.
              </p>
              <button
                onClick={() => setCreateAgentModalOpen(true)}
                className="mt-2 inline-flex items-center gap-2 bg-[#0BAA4B] text-white px-5 py-2.5 rounded-xl font-black text-xs shadow-md hover:bg-[#087C38] transition"
              >
                <UserPlus className="w-4 h-4" />
                Create First Field Agent
              </button>
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {agents.map((ag) => {
                const assignedPickups = sales.filter(s => String(s.assigned_agent) === String(ag.id) && ['PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].includes(s.status)).length;
                return (
                  <div key={ag.id} className="border border-slate-200 rounded-2xl p-4 bg-gradient-to-br from-white to-slate-50 shadow-sm space-y-3 hover:border-emerald-300 transition">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#0BAA4B] to-[#087C38] text-white flex items-center justify-center font-black text-sm shadow-sm">
                          {ag.full_name ? ag.full_name[0].toUpperCase() : 'A'}
                        </div>
                        <div>
                          <h4 className="font-black text-sm text-slate-900">{ag.full_name}</h4>
                          <p className="text-xs text-slate-500 font-mono">{ag.phone}</p>
                        </div>
                      </div>
                      <span className="text-[10px] font-black uppercase tracking-wider bg-emerald-50 text-emerald-700 px-2 py-0.5 rounded-full border border-emerald-200">
                        Active Staff
                      </span>
                    </div>

                    <div className="text-[11px] text-slate-600 bg-white p-2.5 rounded-xl border border-slate-100 space-y-1">
                      <p className="truncate"><strong className="text-slate-700">Email:</strong> {ag.email}</p>
                      <p><strong className="text-slate-700">Role:</strong> {ag.role || 'COLLECTION_AGENT'}</p>
                      <p><strong className="text-slate-700">Active Queue:</strong> <span className="font-bold text-amber-600">{assignedPickups} Pending Pickups</span></p>
                    </div>

                    <div className="pt-2 flex items-center justify-between text-xs border-t border-slate-100">
                      <div className="flex items-center gap-1">
                        <button
                          type="button"
                          onClick={() => {
                            setSelectedAgentForPassword(ag);
                            setNewAgentPasswordToSet('');
                            setAgentPasswordError('');
                            setAgentPasswordModalOpen(true);
                          }}
                          className="text-slate-500 hover:text-amber-700 hover:bg-amber-50 px-2 py-1 rounded-lg font-bold text-[11px] transition flex items-center gap-1.5"
                          title="Reset or Change Agent Password"
                        >
                          <KeyRound className="w-3.5 h-3.5 text-amber-500" />
                          <span>Change Password</span>
                        </button>

                        <button
                          type="button"
                          onClick={() => handleDeleteAgent(ag)}
                          className="text-slate-400 hover:text-rose-600 hover:bg-rose-50 px-2 py-1 rounded-lg font-bold text-[11px] transition flex items-center gap-1"
                          title="Delete Field Agent Account"
                        >
                          <Trash2 className="w-3.5 h-3.5 text-rose-500" />
                          <span className="hidden sm:inline">Delete</span>
                        </button>
                      </div>

                      <button
                        type="button"
                        onClick={() => {
                          setActiveTab('sales');
                          setSearchQuery(ag.full_name);
                        }}
                        className="text-[#087C38] hover:underline font-bold text-[11px] flex items-center gap-1"
                      >
                        View Orders →
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* ================= TAB 6: CUSTOMER MANAGEMENT ================= */}
      {activeTab === 'customers' && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in p-5 sm:p-6 space-y-6">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-slate-100 pb-5">
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-base sm:text-lg font-black text-slate-900">Customer Directory & Accounts</h3>
                <span className="text-xs font-black bg-emerald-100 text-emerald-800 px-2.5 py-0.5 rounded-full border border-emerald-200">
                  {customers.length} Registered Clients
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-1">
                Manage registered buyback customers, inspect verified contact numbers, default doorstep addresses, and payout UPI IDs.
              </p>
            </div>

            <button
              onClick={() => setCreateCustomerModalOpen(true)}
              className="bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-2.5 px-4 rounded-xl text-xs shadow-md shadow-[#0BAA4B]/20 transition flex items-center gap-2 active:scale-98"
            >
              <UserPlus className="w-4 h-4" />
              <span>+ Add Customer</span>
            </button>
          </div>

          {/* Search bar */}
          <div className="flex items-center gap-3">
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                value={customerSearch}
                onChange={(e) => setCustomerSearch(e.target.value)}
                placeholder="Search customers by name, phone, email, city, or UPI handle..."
                className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
              />
            </div>
            {customerSearch && (
              <button
                onClick={() => setCustomerSearch('')}
                className="text-xs font-bold text-slate-500 hover:text-slate-800 px-3 py-2 bg-slate-100 rounded-xl"
              >
                Clear
              </button>
            )}
          </div>

          {/* Customers Table */}
          {customers.length === 0 ? (
            <div className="bg-slate-50 border border-dashed border-slate-300 rounded-2xl p-10 text-center space-y-3">
              <div className="w-14 h-14 mx-auto rounded-2xl bg-emerald-100 text-[#087C38] flex items-center justify-center">
                <Users className="w-7 h-7" />
              </div>
              <h4 className="text-sm font-bold text-slate-800">No Customers Registered Yet</h4>
              <p className="text-xs text-slate-500 max-w-md mx-auto">
                Customer accounts created through the mobile app, web sell portal, or manual admin entry will appear here.
              </p>
              <button
                onClick={() => setCreateCustomerModalOpen(true)}
                className="mt-2 inline-flex items-center gap-2 bg-[#0BAA4B] text-white px-5 py-2.5 rounded-xl font-black text-xs shadow-md hover:bg-[#087C38] transition"
              >
                <UserPlus className="w-4 h-4" />
                Add First Customer
              </button>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 text-slate-600 font-bold uppercase tracking-wider border-y border-slate-200">
                  <tr>
                    <th className="py-3 px-3">Customer</th>
                    <th className="py-3 px-3">Contact (Phone / Email)</th>
                    <th className="py-3 px-3">Doorstep Address</th>
                    <th className="py-3 px-3">Saved UPI ID</th>
                    <th className="py-3 px-3">Lifetime Buyback</th>
                    <th className="py-3 px-3">Status</th>
                    <th className="py-3 px-3 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {customers
                    .filter(c => {
                      if (!customerSearch) return true;
                      const q = customerSearch.toLowerCase();
                      return (c.full_name || '').toLowerCase().includes(q) ||
                             (c.phone || '').includes(q) ||
                             (c.email || '').toLowerCase().includes(q) ||
                             (c.city || '').toLowerCase().includes(q) ||
                             (c.default_upi_id || '').toLowerCase().includes(q);
                    })
                    .map((c) => (
                      <tr key={c.id} className="hover:bg-slate-50/80 transition">
                        <td className="py-3.5 px-3">
                          <div className="flex items-center gap-2.5">
                            <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-[#0BAA4B] to-[#087C38] text-white flex items-center justify-center font-black text-xs shadow-sm shrink-0">
                              {c.full_name ? c.full_name[0].toUpperCase() : 'C'}
                            </div>
                            <div>
                              <p className="font-extrabold text-slate-900 text-xs">{c.full_name || 'Anonymous Customer'}</p>
                              <span className="text-[10px] text-slate-400">ID: #{c.id} · Joined {c.created_at ? new Date(c.created_at).toLocaleDateString() : 'Recent'}</span>
                            </div>
                          </div>
                        </td>

                        <td className="py-3.5 px-3">
                          <p className="font-mono font-bold text-slate-800 text-xs">{c.phone || '—'}</p>
                          <p className="text-slate-500 text-[11px] truncate max-w-[160px]">{c.email || '—'}</p>
                        </td>

                        <td className="py-3.5 px-3 max-w-[200px]">
                          {c.default_address || c.city || c.pincode ? (
                            <div>
                              <p className="truncate text-slate-800 font-medium">{c.default_address || 'Address provided'}</p>
                              <span className="text-[10px] text-slate-400">{[c.city, c.pincode].filter(Boolean).join(' - ')}</span>
                            </div>
                          ) : (
                            <span className="text-slate-400 italic text-[11px]">No address saved</span>
                          )}
                        </td>

                        <td className="py-3.5 px-3">
                          {c.default_upi_id ? (
                            <span className="font-mono font-bold text-emerald-800 bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-lg text-[11px]">
                              {c.default_upi_id}
                            </span>
                          ) : (
                            <span className="text-slate-400 italic text-[11px]">None</span>
                          )}
                        </td>

                        <td className="py-3.5 px-3">
                          <p className="font-black text-slate-900">₹{Number(c.total_sales_value || 0).toLocaleString('en-IN')}</p>
                          <span className="text-[10px] text-slate-500 font-bold">{c.orders_count || 0} Orders</span>
                        </td>

                        <td className="py-3.5 px-3">
                          <button
                            type="button"
                            onClick={() => handleToggleCustomerActive(c)}
                            title="Click to toggle active status"
                            className={`px-2 py-0.5 rounded-full text-[10px] font-black uppercase tracking-wider border cursor-pointer transition ${
                              c.is_active !== false
                                ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100'
                                : 'bg-red-50 text-red-600 border-red-200 hover:bg-red-100'
                            }`}
                          >
                            {c.is_active !== false ? 'Active' : 'Disabled'}
                          </button>
                        </td>

                        <td className="py-3.5 px-3 text-right">
                          <div className="flex items-center justify-end gap-1.5">
                            <button
                              type="button"
                              onClick={() => {
                                setActiveTab('sales');
                                setSearchQuery(c.phone || c.full_name);
                              }}
                              className="px-2 py-1 bg-slate-100 hover:bg-slate-200 text-slate-800 rounded-lg text-[11px] font-bold transition"
                              title="View all device sales by this customer"
                            >
                              Orders
                            </button>

                            <button
                              type="button"
                              onClick={() => handleOpenEditCustomer(c)}
                              className="p-1 text-slate-600 hover:text-emerald-700 hover:bg-emerald-50 rounded-lg transition"
                              title="Edit Customer"
                            >
                              <Edit3 className="w-3.5 h-3.5" />
                            </button>

                            <button
                              type="button"
                              onClick={() => handlePromoteToAgent(c)}
                              className="px-2 py-1 bg-amber-50 hover:bg-amber-100 text-amber-800 border border-amber-200 rounded-lg text-[10px] font-extrabold transition"
                              title="Promote this customer to a Field Collection Agent"
                            >
                              Make Agent
                            </button>

                            <button
                              type="button"
                              onClick={() => handleDeleteCustomer(c)}
                              className="p-1 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                              title="Delete Customer Profile"
                            >
                              <Trash2 className="w-3.5 h-3.5 text-rose-500" />
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* ================= TAB 7: SYSTEM SETTINGS & ROLES ================= */}
      {['settings', 'roles'].includes(activeTab) && (
        <SystemSettingsView mode={activeTab} />
      )}

        </div>
      </div>

      {/* Payout Modal */}
      {payoutSale && (
        <PayoutModal
          sale={payoutSale}
          onClose={() => setPayoutSale(null)}
          onPayoutSuccess={(res) => {
            loadDashboardData();
          }}
        />
      )}

      {/* Assign Agent Modal (Fixed Portal UI) */}
      {assignSale && createPortal(
        <div 
          className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in overflow-y-auto"
          onClick={(e) => {
            if (e.target === e.currentTarget) setAssignSale(null);
          }}
        >
          <div 
            className="bg-white rounded-t-3xl sm:rounded-3xl max-w-lg w-full shadow-2xl border border-slate-100 flex flex-col max-h-[92vh] overflow-hidden animate-slide-up sm:animate-zoom-in"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Mobile Sheet Drag Handle */}
            <div className="sm:hidden pt-3 pb-1 flex justify-center">
              <div className="w-12 h-1.5 bg-slate-300 rounded-full" />
            </div>

            {/* Header */}
            <div className="px-5 sm:px-6 py-4 border-b border-slate-100 flex items-center justify-between bg-gradient-to-r from-slate-50 to-white">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-2xl bg-[#E8F8ED] text-[#087C38] flex items-center justify-center font-bold shrink-0 border border-[#0BAA4B]/20 shadow-sm">
                  <Truck className="w-5 h-5 text-[#0BAA4B]" />
                </div>
                <div>
                  <h3 className="font-extrabold text-base text-slate-900">
                    Schedule Logistics Dispatch
                  </h3>
                  <div className="flex items-center gap-2 mt-0.5">
                    <span className="font-mono text-xs font-bold text-[#087C38] bg-[#E8F8ED] px-2 py-0.5 rounded-md border border-[#0BAA4B]/20">
                      Order #{assignSale.sale_code}
                    </span>
                    <span className="text-[11px] text-slate-500 font-medium">
                      Doorstep Pickup
                    </span>
                  </div>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setAssignSale(null)}
                className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 hover:text-slate-800 flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Scrollable Body */}
            <div className="p-5 sm:p-6 overflow-y-auto space-y-4 text-xs">
              
              {/* Order Quick Context Card */}
              <div className="p-3.5 rounded-2xl bg-slate-50 border border-slate-200/80 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Smartphone className="w-4 h-4 text-[#0BAA4B]" />
                    <span className="font-extrabold text-slate-900 text-sm">
                      {assignSale.device_name || 'Device'}
                    </span>
                  </div>
                  <span className="font-black text-emerald-600 text-sm">
                    ₹{Number(assignSale.final_price || assignSale.estimated_price || 0).toLocaleString('en-IN')}
                  </span>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-1 text-[11px] text-slate-600 pt-1 border-t border-slate-200/60">
                  <div className="flex items-center gap-1.5">
                    <User className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span className="font-bold text-slate-800">{assignSale.customer_name}</span>
                    <span className="text-slate-500">({assignSale.customer_phone})</span>
                  </div>
                  {assignSale.pickup_address && (
                    <div className="flex items-center gap-1.5 truncate" title={assignSale.pickup_address}>
                      <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                      <span className="truncate">{assignSale.pickup_address}</span>
                    </div>
                  )}
                </div>
              </div>

              {/* Form */}
              <form onSubmit={handleAssignPickup} className="space-y-4">
                {/* Agent Selection */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="font-bold text-slate-700 flex items-center gap-1.5">
                      <UserCheck className="w-3.5 h-3.5 text-[#0BAA4B]" />
                      <span>Assign Field Collection Specialist</span>
                    </label>
                    <div className="flex items-center gap-2">
                      <span className="text-[10px] font-bold text-slate-500 bg-slate-100 px-2 py-0.5 rounded-full">
                        {agents.length} Staff Available
                      </span>
                      <button
                        type="button"
                        onClick={() => {
                          setAssignSale(null);
                          setCreateAgentModalOpen(true);
                        }}
                        className="text-[10px] font-extrabold text-[#087C38] bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 px-2 py-0.5 rounded-full transition flex items-center gap-1"
                      >
                        <UserPlus className="w-3 h-3" />
                        + Add Agent
                      </button>
                    </div>
                  </div>
                  <select
                    required
                    value={selectedAgentId}
                    onChange={(e) => setSelectedAgentId(e.target.value)}
                    className="w-full p-2.5 bg-white border border-slate-300 rounded-xl font-bold text-slate-800 text-xs focus:ring-2 focus:ring-[#0BAA4B] focus:border-[#0BAA4B] outline-none transition"
                  >
                    <option value="">Select Field Staff</option>
                    {agents.map((ag) => (
                      <option key={ag.id} value={ag.id}>
                        {ag.full_name} ({ag.phone})
                      </option>
                    ))}
                  </select>
                </div>

                {/* Pickup Date */}
                <div>
                  <div className="flex items-center justify-between mb-1.5">
                    <label className="font-bold text-slate-700 flex items-center gap-1.5">
                      <Calendar className="w-3.5 h-3.5 text-[#0BAA4B]" />
                      <span>Pickup Date</span>
                    </label>
                    <span className="text-[10px] font-black text-emerald-800 bg-emerald-100 px-2.5 py-0.5 rounded-full">
                      Available Tomorrow Onwards
                    </span>
                  </div>
                  <input
                    type="date"
                    required
                    min={getTomorrowDateStr()}
                    value={pickupDate}
                    onChange={(e) => {
                      const val = e.target.value;
                      const minD = getTomorrowDateStr();
                      setPickupDate(val < minD ? minD : val);
                    }}
                    className="w-full p-2.5 bg-white border border-slate-300 rounded-xl font-black text-slate-800 text-xs focus:ring-2 focus:ring-[#0BAA4B] focus:border-[#0BAA4B] outline-none transition"
                  />
                  <p className="text-[11px] text-emerald-700 font-semibold mt-1.5 flex items-center gap-1">
                    <span>⚡</span> Doorstep logistics dispatch starts from tomorrow.
                  </p>
                </div>

                {/* Time Slot */}
                <div>
                  <label className="font-bold text-slate-700 mb-1.5 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5 text-[#0BAA4B]" />
                    <span>Preferred Time Slot Window</span>
                  </label>
                  <select
                    value={pickupSlot}
                    onChange={(e) => setPickupSlot(e.target.value)}
                    className="w-full p-2.5 bg-white border border-slate-300 rounded-xl font-semibold text-slate-800 text-xs focus:ring-2 focus:ring-[#0BAA4B] focus:border-[#0BAA4B] outline-none transition"
                  >
                    <option value="Morning (10:00 AM - 1:00 PM)">🌅 Morning (10:00 AM - 1:00 PM)</option>
                    <option value="Afternoon (1:00 PM - 4:00 PM)">☀️ Afternoon (1:00 PM - 4:00 PM)</option>
                    <option value="Evening (4:00 PM - 7:30 PM)">🌇 Evening (4:00 PM - 7:30 PM)</option>
                  </select>
                </div>

                {/* Footer Buttons */}
                <div className="flex gap-2.5 pt-3 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setAssignSale(null)}
                    className="w-1/2 py-2.5 px-4 border border-slate-300 hover:bg-slate-50 text-slate-700 rounded-xl font-bold transition text-xs"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={assigningLoading}
                    className="w-1/2 bg-gradient-to-r from-[#0BAA4B] to-[#087C38] hover:from-[#087C38] hover:to-[#05632B] text-white py-2.5 px-4 rounded-xl font-extrabold transition flex items-center justify-center gap-1.5 shadow-md shadow-[#0BAA4B]/20 text-xs disabled:opacity-50"
                  >
                    {assigningLoading ? (
                      <>
                        <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                        <span>Assigning...</span>
                      </>
                    ) : (
                      <>
                        <Truck className="w-3.5 h-3.5" />
                        <span>Confirm Schedule</span>
                      </>
                    )}
                  </button>
                </div>
              </form>

            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Edit Deduction Modal */}
      {editingOption && createPortal(
        <div 
          className="fixed inset-0 z-[9999] flex items-center justify-center p-3 sm:p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in"
          onClick={(e) => {
            if (e.target === e.currentTarget) setEditingOption(null);
          }}
        >
          <div 
            className="bg-white rounded-2xl max-w-sm w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between">
              <h3 className="font-bold text-base text-slate-900">
                Update Deduction Price
              </h3>
              <button
                type="button"
                onClick={() => setEditingOption(null)}
                className="w-7 h-7 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 flex items-center justify-center"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            </div>
            <p className="text-slate-500">{editingOption.title}</p>

            <form onSubmit={handleUpdateDeduction} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Deduction Amount (INR ₹)</label>
                <input
                  type="number"
                  step="50"
                  required
                  value={newDeductionValue}
                  onChange={(e) => setNewDeductionValue(e.target.value)}
                  className="w-full p-2 border border-slate-300 rounded-xl text-base font-bold text-rose-600 focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingOption(null)}
                  className="w-1/2 border border-slate-300 py-2 rounded-xl font-bold hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-[#0BAA4B] text-white py-2 rounded-xl font-bold hover:bg-[#087C38] transition"
                >
                  Save Deduction
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* End-to-End Buyback Lifecycle Trace Modal */}
      {traceSale && createPortal(
        <div 
          className="fixed inset-0 z-[9999] flex items-center justify-center p-3 sm:p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in"
          onClick={(e) => {
            if (e.target === e.currentTarget) setTraceSale(null);
          }}
        >
          <div 
            className="bg-white rounded-2xl max-w-2xl w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div>
                <span className="text-[10px] font-black uppercase text-indigo-600 tracking-wider">Super Admin Lifecycle Audit Trace</span>
                <h3 className="font-black text-lg text-slate-900 flex items-center gap-2">
                  Order {traceSale.sale_code}
                  <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                    traceSale.status === 'PAYMENT_COMPLETED' ? 'bg-emerald-100 text-emerald-800' :
                    traceSale.status === 'OWNERSHIP_TRANSFERRED' ? 'bg-blue-100 text-blue-800' :
                    traceSale.status === 'CUSTOMER_ACCEPTED' ? 'bg-indigo-100 text-indigo-800' :
                    traceSale.status === 'FINAL_OFFER_SENT' ? 'bg-amber-100 text-amber-800' :
                    'bg-slate-100 text-slate-700'
                  }`}>
                    {traceSale.status.replace(/_/g, ' ')}
                  </span>
                </h3>
              </div>
              <button
                onClick={() => setTraceSale(null)}
                className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 hover:text-slate-800 flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* 6-Stage Visual Stepper */}
            <div className="space-y-4">
              {/* STAGE 1: Order Placement */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">1</span>
                    Order Placed & Initial Valuation
                  </h4>
                  <span className="text-[10px] text-slate-500">{traceSale.created_at_ist || 'Placed'}</span>
                </div>
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-[11px] text-slate-600 mt-2">
                  <div><strong>Customer:</strong> {traceSale.customer_name} ({traceSale.customer_phone})</div>
                  <div><strong>Device:</strong> {traceSale.brand_name} {traceSale.model_name}</div>
                  <div><strong>Address:</strong> {traceSale.pickup_address}, {traceSale.pickup_city} - {traceSale.pickup_pincode}</div>
                  <div><strong>Quoted Estimate:</strong> ₹{Number(traceSale.estimated_price).toLocaleString('en-IN')}</div>
                  <div><strong>Payout Method:</strong> {traceSale.beneficiary_type}: {traceSale.beneficiary_upi_id || traceSale.beneficiary_account_no}</div>
                </div>
              </div>

              {/* STAGE 2: Pickup Scheduled */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">2</span>
                    Doorstep Pickup Scheduled
                  </h4>
                  <span className="text-[10px] text-slate-500">{traceSale.pickup_date || 'Not Scheduled'}</span>
                </div>
                <div className="grid grid-cols-2 gap-2 text-[11px] text-slate-600 mt-2">
                  <div><strong>Assigned Agent:</strong> {traceSale.assigned_agent_name || 'Awaiting Agent'}</div>
                  <div><strong>Time Slot:</strong> {traceSale.pickup_slot || 'Morning Slot'}</div>
                </div>
              </div>

              {/* STAGE 3: Doorstep QC Inspection & Photos */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">3</span>
                    Doorstep QC Inspection & IMEI Verification
                  </h4>
                  <span className="text-[10px] text-slate-500">{traceSale.inspection ? 'Completed' : 'Pending'}</span>
                </div>
                {traceSale.inspection ? (
                  <div className="space-y-2 mt-2 text-[11px]">
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 text-slate-700">
                      <div><strong>Inspected By:</strong> {traceSale.inspection.inspector_name || 'Field Specialist'}</div>
                      <div><strong>Verified IMEI:</strong> <span className="font-mono font-bold text-indigo-700">{traceSale.inspection.verified_imei || traceSale.imei_number}</span></div>
                      <div><strong>QC Final Price:</strong> <span className="font-bold text-emerald-700">₹{Number(traceSale.inspection.suggested_final_price || traceSale.final_price).toLocaleString('en-IN')}</span></div>
                    </div>
                    {traceSale.inspection.inspector_notes && (
                      <p className="p-2 bg-white rounded-lg border border-slate-200 text-slate-600 italic">
                        "{traceSale.inspection.inspector_notes}"
                      </p>
                    )}
                    {/* QC Proof Photos */}
                    {traceSale.inspection.photos && traceSale.inspection.photos.length > 0 && (
                      <div>
                        <span className="block font-bold text-slate-700 mb-1">Physical Device Photos (Proof):</span>
                        <div className="grid grid-cols-4 gap-2">
                          {traceSale.inspection.photos.map((ph, idx) => (
                            <div key={idx} className="border border-slate-200 rounded-lg overflow-hidden bg-white p-1 text-center">
                              <img src={ph.image_base64} alt={ph.label} className="w-full h-16 object-contain rounded" />
                              <span className="text-[9px] text-slate-500 block truncate">{ph.label}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                ) : (
                  <p className="text-slate-400 italic text-[11px] mt-1">QC inspection has not yet been conducted by agent.</p>
                )}
              </div>

              {/* STAGE 4: Customer Confirmation */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">4</span>
                    Customer Price Confirmation
                  </h4>
                  <span className={`text-[10px] font-bold ${['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status) ? 'text-emerald-700' : 'text-slate-400'}`}>
                    {['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status) ? 'Confirmed ✓' : 'Awaiting Confirmation'}
                  </span>
                </div>
                <p className="text-[11px] text-slate-600 mt-1">
                  {['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status)
                    ? `Customer accepted the final buyback price of ₹${Number(traceSale.final_price || traceSale.estimated_price).toLocaleString('en-IN')}.`
                    : 'Customer has not yet reviewed / accepted the final offer price.'}
                </p>
              </div>

              {/* STAGE 5: Physical Device Collection */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">5</span>
                    Physical Device Collection & Handover
                  </h4>
                  <span className={`text-[10px] font-bold ${['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status) ? 'text-emerald-700' : 'text-slate-400'}`}>
                    {['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status) ? 'Collected ✓' : 'Pending Collection'}
                  </span>
                </div>
                <p className="text-[11px] text-slate-600 mt-1">
                  {['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(traceSale.status)
                    ? 'Device collected by agent. Physical phone is in company custody. Super Admin payout authorized.'
                    : 'Device has not been collected yet. Agent must physically collect device after customer confirmation.'}
                </p>
              </div>

              {/* STAGE 6: Super Admin Payout */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200">
                <div className="flex items-center justify-between mb-1.5">
                  <h4 className="font-bold text-slate-900 flex items-center gap-2">
                    <span className="w-5 h-5 rounded-full bg-emerald-600 text-white flex items-center justify-center text-[10px]">6</span>
                    Super Admin Instant Payout
                  </h4>
                  <span className={`text-[10px] font-bold ${traceSale.status === 'PAYMENT_COMPLETED' ? 'text-emerald-700' : 'text-slate-400'}`}>
                    {traceSale.status === 'PAYMENT_COMPLETED' ? 'Paid ✓' : 'Pending'}
                  </span>
                </div>
                {traceSale.payment || traceSale.status === 'PAYMENT_COMPLETED' ? (
                  <div className="mt-2 text-[11px] text-slate-700 space-y-1">
                    <div><strong>Paid Amount:</strong> ₹{Number(traceSale.final_price || traceSale.estimated_price).toLocaleString('en-IN')}</div>
                    {traceSale.payment && (
                      <>
                        <div><strong>UTR Number:</strong> <span className="font-mono font-bold text-emerald-800">{traceSale.payment.utr_number}</span></div>
                        <div><strong>Paid At:</strong> {traceSale.payment.paid_at}</div>
                      </>
                    )}
                  </div>
                ) : (
                  <p className="text-slate-400 italic text-[11px] mt-1">
                    {traceSale.status === 'OWNERSHIP_TRANSFERRED'
                      ? 'Device collected! Super Admin can now disburse instant payout.'
                      : 'Payout will unlock once the physical device is marked as collected.'}
                  </p>
                )}
              </div>
            </div>

            <div className="pt-2 flex justify-end">
              <button
                type="button"
                onClick={() => setTraceSale(null)}
                className="px-4 py-2 bg-slate-900 text-white rounded-xl font-bold hover:bg-black transition"
              >
                Close Trace
              </button>
            </div>
          </div>
        </div>,
        document.body
      )}

      {/* Receipt Modal */}
      {receiptData && (
        <ReceiptModal
          receiptData={receiptData}
          onClose={() => setReceiptData(null)}
        />
      )}

      {/* Create Field Agent Modal */}
      {createAgentModalOpen && createPortal(
        <div className="fixed inset-0 z-[10000] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-3xl max-w-md w-full shadow-2xl border border-slate-100 overflow-hidden animate-zoom-in">
            {/* Modal Header */}
            <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-5 flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
                  <UserPlus className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-black text-base">Add New Field Agent</h3>
                  <p className="text-[11px] text-emerald-100">Create staff login for doorstep inspection app</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setCreateAgentModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {/* Modal Form */}
            <form onSubmit={handleCreateAgent} className="p-5 space-y-4">
              {agentCreateError && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-xs text-red-700 font-bold flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0 text-red-500" />
                  <span>{agentCreateError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Full Name *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Rahul Sharma"
                  value={newAgentName}
                  onChange={(e) => setNewAgentName(e.target.value)}
                  className="w-full px-3.5 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">10-Digit Mobile Number *</label>
                <input
                  type="tel"
                  required
                  maxLength={10}
                  placeholder="e.g. 9876543210"
                  value={newAgentPhone}
                  onChange={(e) => setNewAgentPhone(e.target.value.replace(/\D/g, ''))}
                  className="w-full px-3.5 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
                <p className="text-[10px] text-slate-400 mt-1">Agent will use this mobile number to log into the field app.</p>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Official Email Address *</label>
                <input
                  type="email"
                  required
                  placeholder="e.g. rahul.agent@dolly.com"
                  value={newAgentEmail}
                  onChange={(e) => setNewAgentEmail(e.target.value)}
                  className="w-full px-3.5 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Initial Password *</label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Agent@2026"
                  value={newAgentPassword}
                  onChange={(e) => setNewAgentPassword(e.target.value)}
                  className="w-full px-3.5 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setCreateAgentModalOpen(false)}
                  className="px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creatingAgentLoading}
                  className="px-5 py-2.5 bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-extrabold rounded-xl text-xs shadow-md shadow-[#0BAA4B]/20 transition flex items-center gap-2 disabled:opacity-50 active:scale-98"
                >
                  {creatingAgentLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Creating Agent...</span>
                    </>
                  ) : (
                    <>
                      <UserPlus className="w-3.5 h-3.5" />
                      <span>Create Agent Account</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* Create Customer Modal */}
      {createCustomerModalOpen && createPortal(
        <div className="fixed inset-0 z-[10000] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-100 overflow-hidden animate-zoom-in max-h-[90vh] flex flex-col">
            <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-5 flex items-center justify-between shrink-0">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-white/20 flex items-center justify-center">
                  <UserPlus className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-black text-base">Register New Customer</h3>
                  <p className="text-[11px] text-emerald-100">Create a customer profile with contact & payout details</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setCreateCustomerModalOpen(false)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleCreateCustomer} className="p-5 overflow-y-auto space-y-3.5">
              {custError && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-xs text-red-700 font-bold flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 shrink-0 text-red-500" />
                  <span>{custError}</span>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Full Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="Customer Name"
                    value={newCustName}
                    onChange={(e) => setNewCustName(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">10-Digit Mobile *</label>
                  <input
                    type="tel"
                    required
                    maxLength={10}
                    placeholder="9876543210"
                    value={newCustPhone}
                    onChange={(e) => setNewCustPhone(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Email Address *</label>
                  <input
                    type="email"
                    required
                    placeholder="customer@email.com"
                    value={newCustEmail}
                    onChange={(e) => setNewCustEmail(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Initial Password *</label>
                  <input
                    type="text"
                    required
                    placeholder="Password"
                    value={newCustPassword}
                    onChange={(e) => setNewCustPassword(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Doorstep Address (Optional)</label>
                <input
                  type="text"
                  placeholder="House / Street / Area"
                  value={newCustAddress}
                  onChange={(e) => setNewCustAddress(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">City (Optional)</label>
                  <input
                    type="text"
                    placeholder="e.g. Bengaluru"
                    value={newCustCity}
                    onChange={(e) => setNewCustCity(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Pincode (Optional)</label>
                  <input
                    type="text"
                    maxLength={6}
                    placeholder="560001"
                    value={newCustPincode}
                    onChange={(e) => setNewCustPincode(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Default Payout UPI ID (Optional)</label>
                <input
                  type="text"
                  placeholder="e.g. customer@okhdfcbank"
                  value={newCustUpi}
                  onChange={(e) => setNewCustUpi(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setCreateCustomerModalOpen(false)}
                  className="px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={creatingCustLoading}
                  className="px-5 py-2.5 bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-extrabold rounded-xl text-xs shadow-md shadow-[#0BAA4B]/20 transition flex items-center gap-2 disabled:opacity-50 active:scale-98"
                >
                  {creatingCustLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Saving...</span>
                    </>
                  ) : (
                    <>
                      <UserPlus className="w-3.5 h-3.5" />
                      <span>Register Customer</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* Edit Customer Modal */}
      {editingCustomer && createPortal(
        <div className="fixed inset-0 z-[10000] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-3xl max-w-lg w-full shadow-2xl border border-slate-100 overflow-hidden animate-zoom-in max-h-[90vh] flex flex-col">
            <div className="bg-slate-900 text-white p-5 flex items-center justify-between shrink-0">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-white/10 flex items-center justify-center">
                  <Edit3 className="w-5 h-5 text-emerald-400" />
                </div>
                <div>
                  <h3 className="font-black text-base">Edit Customer: {editingCustomer.full_name || editingCustomer.phone}</h3>
                  <p className="text-[11px] text-slate-400">Update verified contact, address, or payment details</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setEditingCustomer(null)}
                className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveCustomer} className="p-5 overflow-y-auto space-y-3.5">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Full Name</label>
                  <input
                    type="text"
                    required
                    value={editCustName}
                    onChange={(e) => setEditCustName(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">10-Digit Mobile</label>
                  <input
                    type="tel"
                    required
                    maxLength={10}
                    value={editCustPhone}
                    onChange={(e) => setEditCustPhone(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Email Address</label>
                <input
                  type="email"
                  required
                  value={editCustEmail}
                  onChange={(e) => setEditCustEmail(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Doorstep Address</label>
                <input
                  type="text"
                  value={editCustAddress}
                  onChange={(e) => setEditCustAddress(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">City</label>
                  <input
                    type="text"
                    value={editCustCity}
                    onChange={(e) => setEditCustCity(e.target.value)}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Pincode</label>
                  <input
                    type="text"
                    maxLength={6}
                    value={editCustPincode}
                    onChange={(e) => setEditCustPincode(e.target.value.replace(/\D/g, ''))}
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Default Payout UPI ID</label>
                <input
                  type="text"
                  placeholder="e.g. mobile@upi"
                  value={editCustUpi}
                  onChange={(e) => setEditCustUpi(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="editCustActiveCheckbox"
                  checked={editCustActive}
                  onChange={(e) => setEditCustActive(e.target.checked)}
                  className="w-4 h-4 text-[#0BAA4B] rounded focus:ring-[#0BAA4B]"
                />
                <label htmlFor="editCustActiveCheckbox" className="text-xs font-bold text-slate-700">
                  Account Active (Uncheck to suspend customer login)
                </label>
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setEditingCustomer(null)}
                  className="px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={editCustLoading}
                  className="px-5 py-2.5 bg-slate-900 hover:bg-black text-white font-extrabold rounded-xl text-xs shadow-md transition flex items-center gap-2 disabled:opacity-50 active:scale-98"
                >
                  {editCustLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Saving...</span>
                    </>
                  ) : (
                    <span>Save Changes</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* ================= MODAL: CHANGE FIELD AGENT PASSWORD ================= */}
      {agentPasswordModalOpen && selectedAgentForPassword && createPortal(
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[9999] flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-white rounded-3xl shadow-2xl max-w-md w-full overflow-hidden border border-slate-200">
            <div className="px-6 py-4 bg-gradient-to-r from-amber-600 to-amber-700 text-white flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center">
                  <KeyRound className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 className="font-black text-sm">Change Agent Password</h3>
                  <p className="text-[11px] text-amber-100 font-medium">
                    {selectedAgentForPassword.full_name} ({selectedAgentForPassword.phone})
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => {
                  setAgentPasswordModalOpen(false);
                  setSelectedAgentForPassword(null);
                }}
                className="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleUpdateAgentPassword} className="p-6 space-y-4">
              {agentPasswordError && (
                <div className="p-3 bg-rose-50 border border-rose-200 text-rose-700 rounded-xl text-xs font-semibold flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{agentPasswordError}</span>
                </div>
              )}

              <div className="bg-amber-50/70 border border-amber-200/60 rounded-xl p-3 text-xs text-amber-800">
                <p>You are setting a new password for <strong>{selectedAgentForPassword.full_name}</strong>. They will use this password to log into the Dolly Agent Inspection app.</p>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">New Password *</label>
                <input
                  type="password"
                  required
                  placeholder="Min 6 characters (e.g. Secret@123)"
                  value={newAgentPasswordToSet}
                  onChange={(e) => setNewAgentPasswordToSet(e.target.value)}
                  className="w-full px-3 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-amber-500 outline-none"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => {
                    setAgentPasswordModalOpen(false);
                    setSelectedAgentForPassword(null);
                  }}
                  className="px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={updatingAgentPasswordLoading}
                  className="px-5 py-2.5 bg-gradient-to-r from-amber-600 to-amber-700 hover:brightness-105 text-white font-black rounded-xl text-xs shadow-md transition flex items-center gap-2 disabled:opacity-50 active:scale-98"
                >
                  {updatingAgentPasswordLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Updating...</span>
                    </>
                  ) : (
                    <>
                      <KeyRound className="w-3.5 h-3.5" />
                      <span>Set New Password</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

      {/* ================= MODAL: CHANGE MY PASSWORD (SELF-SERVICE) ================= */}
      {changeMyPasswordModalOpen && createPortal(
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-[9999] flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-white rounded-3xl shadow-2xl max-w-md w-full overflow-hidden border border-slate-200">
            <div className="px-6 py-4 bg-gradient-to-r from-[#087C38] to-[#0BAA4B] text-white flex items-center justify-between">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-xl bg-white/20 flex items-center justify-center">
                  <KeyRound className="w-4 h-4 text-white" />
                </div>
                <div>
                  <h3 className="font-black text-sm">Change Your Password</h3>
                  <p className="text-[11px] text-emerald-100 font-medium">Update your admin login password</p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setChangeMyPasswordModalOpen(false)}
                className="w-7 h-7 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center transition"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleChangeMyPassword} className="p-6 space-y-4">
              {myPasswordError && (
                <div className="p-3 bg-rose-50 border border-rose-200 text-rose-700 rounded-xl text-xs font-semibold flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{myPasswordError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Current Password *</label>
                <input
                  type="password"
                  required
                  placeholder="Enter current password"
                  value={myOldPassword}
                  onChange={(e) => setMyOldPassword(e.target.value)}
                  className="w-full px-3 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">New Password *</label>
                <input
                  type="password"
                  required
                  placeholder="Min 6 characters"
                  value={myNewPassword}
                  onChange={(e) => setMyNewPassword(e.target.value)}
                  className="w-full px-3 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Confirm New Password *</label>
                <input
                  type="password"
                  required
                  placeholder="Re-type new password"
                  value={myConfirmPassword}
                  onChange={(e) => setMyConfirmPassword(e.target.value)}
                  className="w-full px-3 py-2.5 border border-slate-300 rounded-xl text-xs font-semibold focus:ring-2 focus:ring-[#0BAA4B] outline-none"
                />
              </div>

              <div className="pt-3 border-t border-slate-100 flex items-center justify-end gap-2.5">
                <button
                  type="button"
                  onClick={() => setChangeMyPasswordModalOpen(false)}
                  className="px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={myPasswordLoading}
                  className="px-5 py-2.5 bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black rounded-xl text-xs shadow-md transition flex items-center gap-2 disabled:opacity-50 active:scale-98"
                >
                  {myPasswordLoading ? (
                    <>
                      <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                      <span>Saving...</span>
                    </>
                  ) : (
                    <>
                      <KeyRound className="w-3.5 h-3.5" />
                      <span>Update Password</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>,
        document.body
      )}

    </div>
  );
}
