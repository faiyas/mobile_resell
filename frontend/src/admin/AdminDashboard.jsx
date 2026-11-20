import React, { useState, useEffect } from 'react';
import { 
  IndianRupee, Smartphone, Clock, CheckCircle2, AlertCircle, 
  Search, Filter, QrCode, Upload, Eye, UserPlus, RefreshCw, 
  Layers, ShieldAlert, Award, FileText, ChevronRight, Sparkles 
} from 'lucide-react';
import { api } from '../services/api';
import PayoutModal from './PayoutModal';
import ReceiptModal from '../customer/ReceiptModal';
import CataloguePricingManager from './CataloguePricingManager';

export default function AdminDashboard({ currentUser }) {
  const [activeTab, setActiveTab] = useState('payouts'); // 'payouts' | 'sales' | 'pricing' | 'history'
  
  const [sales, setSales] = useState([]);
  const [paymentsList, setPaymentsList] = useState({ total_count: 0, total_disbursed: 0, payments: [] });
  const [conditionCategories, setConditionCategories] = useState([]);
  const [agents, setAgents] = useState([]);
  
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

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    setLoading(true);
    try {
      const [salesData, paymentsData, catsData, agentsData] = await Promise.all([
        api.getSales(),
        api.getPaymentsList().catch(() => ({ total_count: 0, total_disbursed: 0, payments: [] })),
        api.getConditionCategories(),
        api.getAgents().catch(() => []),
      ]);
      setSales(salesData);
      setPaymentsList(paymentsData);
      setConditionCategories(catsData);
      setAgents(agentsData);
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
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-8 animate-fade-in">
      
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-gradient-to-r from-[#087C38] via-[#0BAA4B] to-[#0D4722] text-white p-5 sm:p-8 rounded-3xl shadow-xl">
        <div>
          <span className="text-[10px] sm:text-[11px] font-bold uppercase tracking-wider text-[#E8F8ED] bg-white/20 border border-white/20 px-2.5 py-0.5 rounded-full inline-block">
            Super Admin Control Center · 1103 RECELL Platform
          </span>
          <h1 className="text-xl sm:text-3xl font-black mt-2">
            Operations & Dynamic CMS Desk
          </h1>
          <p className="text-[11px] sm:text-xs text-[#E8F8ED] mt-1">
            Dynamic homepage builder, questionnaire steps, pricing deductions, agent assignments & UPI/Bank payouts.
          </p>
        </div>

        <button
          onClick={loadDashboardData}
          disabled={loading}
          className="flex items-center justify-center gap-2 bg-white/10 hover:bg-white/20 text-white text-xs font-bold px-4 py-2.5 rounded-xl border border-white/20 transition w-full sm:w-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-white' : ''}`} />
          {loading ? 'Refreshing...' : 'Refresh Data'}
        </button>
      </div>

      {successToast && (
        <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 p-3.5 rounded-2xl text-xs font-bold flex items-center gap-2 animate-fade-in shadow-sm">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{successToast}</span>
        </div>
      )}

      {/* Metrics Row (Glassmorphic Green & White) */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
        
        <div className="glass-card glass-card-hover p-3.5 sm:p-5 rounded-2xl flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-[#7B8980] uppercase tracking-wider">Today's Sales</span>
          <p className="text-2xl sm:text-3xl font-black text-[#17251C] mt-1">{sales.length}</p>
          <span className="text-[10px] sm:text-[11px] text-[#7B8980] font-medium mt-1 truncate">All submissions</span>
        </div>

        <div className="glass-card glass-card-hover p-3.5 sm:p-5 rounded-2xl flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-amber-600 uppercase tracking-wider">Pending Pickup</span>
          <p className="text-2xl sm:text-3xl font-black text-amber-600 mt-1">{pendingInspectionsCount}</p>
          <span className="text-[10px] sm:text-[11px] text-amber-700 font-medium mt-1 truncate">Awaiting collection</span>
        </div>

        <div className="glass-card glass-card-hover p-3.5 sm:p-5 rounded-2xl bg-[#E8F8ED]/70 border-[#0BAA4B]/30 flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-[#087C38] uppercase tracking-wider">Awaiting Payout</span>
          <p className="text-2xl sm:text-3xl font-black text-[#0BAA4B] mt-1">{awaitingPayoutsCount}</p>
          <span className="text-[10px] sm:text-[11px] text-[#087C38] font-semibold mt-1 truncate">Ready for QR scan</span>
        </div>

        <div className="glass-card glass-card-hover p-3.5 sm:p-5 rounded-2xl flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-[#7B8980] uppercase tracking-wider">Total Payouts</span>
          <p className="text-xl sm:text-3xl font-black text-[#17251C] mt-1 truncate">
            ₹{Number(paymentsList.total_disbursed).toLocaleString('en-IN')}
          </p>
          <span className="text-[10px] sm:text-[11px] text-[#7B8980] font-medium mt-1 truncate">
            {paymentsList.total_count} verified sales
          </span>
        </div>

      </div>

      {/* Navigation Tabs (Glassmorphic) */}
      <div className="glass-panel rounded-2xl p-1.5 flex gap-1 overflow-x-auto scrollbar-none shadow-sm">
        <button
          onClick={() => setActiveTab('payouts')}
          className={`py-2 px-4 rounded-xl text-xs font-extrabold transition shrink-0 flex items-center gap-1.5 ${
            activeTab === 'payouts'
              ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/20'
              : 'text-[#7B8980] hover:bg-white/60 hover:text-[#17251C]'
          }`}
        >
          <IndianRupee className="w-3.5 h-3.5" />
          Payout Desk ({payoutQueue.length})
        </button>

        <button
          onClick={() => setActiveTab('sales')}
          className={`py-2 px-4 rounded-xl text-xs font-extrabold transition shrink-0 flex items-center gap-1.5 ${
            activeTab === 'sales'
              ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/20'
              : 'text-[#7B8980] hover:bg-white/60 hover:text-[#17251C]'
          }`}
        >
          <Smartphone className="w-3.5 h-3.5" />
          Customer Sales ({sales.length})
        </button>

        <button
          onClick={() => setActiveTab('pricing')}
          className={`py-2 px-4 rounded-xl text-xs font-extrabold transition shrink-0 flex items-center gap-1.5 ${
            activeTab === 'pricing'
              ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/20'
              : 'text-[#7B8980] hover:bg-white/60 hover:text-[#17251C]'
          }`}
        >
          <Layers className="w-3.5 h-3.5" />
          Phone Catalogue & Pricing
          <span className="text-[9px] bg-white/20 text-white px-1.5 py-0.2 rounded font-bold uppercase tracking-wider">
            New
          </span>
        </button>

        <button
          onClick={() => setActiveTab('history')}
          className={`py-2 px-4 rounded-xl text-xs font-extrabold transition shrink-0 flex items-center gap-1.5 ${
            activeTab === 'history'
              ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/20'
              : 'text-[#7B8980] hover:bg-white/60 hover:text-[#17251C]'
          }`}
        >
          <CheckCircle2 className="w-3.5 h-3.5" />
          Payout History ({paymentsList.total_count})
        </button>
      </div>

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
          {/* Filters */}
          <div className="flex flex-col sm:flex-row gap-3">
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

            <select
              value={filterStatus}
              onChange={(e) => setFilterStatus(e.target.value)}
              className="px-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
            >
              <option value="">All Statuses</option>
              <option value="SUBMITTED">Submitted</option>
              <option value="PICKUP_SCHEDULED">Pickup Scheduled</option>
              <option value="INSPECTION_COMPLETED">Inspection Completed</option>
              <option value="FINAL_OFFER_SENT">Final Offer Sent</option>
              <option value="OWNERSHIP_TRANSFERRED">Ownership Transferred</option>
              <option value="PAYMENT_COMPLETED">Payment Completed (Paid)</option>
            </select>
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
                        s.status === 'OWNERSHIP_TRANSFERRED' ? 'bg-indigo-100 text-indigo-800' :
                        'bg-slate-100 text-slate-700'
                      }`}>
                        {s.status.replace(/_/g, ' ')}
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

      {/* ================= TAB 3: PHONE CATALOGUE & PRICING ================= */}
      {activeTab === 'pricing' && (
        <CataloguePricingManager />
      )}

      {/* ================= TAB 4: PAYOUTS HISTORY ================= */}
      {activeTab === 'history' && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden animate-fade-in p-5 space-y-4">
          <div className="flex justify-between items-center">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Verified Payout Ledger</h3>
              <p className="text-xs text-slate-500">All bank transfers and UPI payouts uploaded with Base64 screenshot receipts.</p>
            </div>
            <span className="text-xs font-bold bg-emerald-100 text-emerald-800 px-3 py-1 rounded-full">
              Total: ₹{Number(paymentsList.total_disbursed).toLocaleString('en-IN')}
            </span>
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

      {/* Assign Agent Modal */}
      {assignSale && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-bold text-base text-slate-900">
              Schedule Pickup for {assignSale.sale_code}
            </h3>
            
            <form onSubmit={handleAssignPickup} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Assign Collection Agent</label>
                <select
                  required
                  value={selectedAgentId}
                  onChange={(e) => setSelectedAgentId(e.target.value)}
                  className="w-full p-2 border border-slate-300 rounded-xl"
                >
                  <option value="">Select Field Staff</option>
                  {agents.map((ag) => (
                    <option key={ag.id} value={ag.id}>{ag.full_name} ({ag.phone})</option>
                  ))}
                </select>
              </div>

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block font-bold text-slate-700">Pickup Date</label>
                  <span className="text-[11px] font-bold text-emerald-800 bg-emerald-100 px-2 py-0.5 rounded-full">
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
                  className="w-full p-2 border border-slate-300 rounded-xl font-bold"
                />
                <p className="text-[11px] text-emerald-700 font-medium mt-1">
                  ⚡ Doorstep logistics dispatch starts from tomorrow.
                </p>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Time Slot</label>
                <select
                  value={pickupSlot}
                  onChange={(e) => setPickupSlot(e.target.value)}
                  className="w-full p-2 border border-slate-300 rounded-xl"
                >
                  <option value="Morning (10:00 AM - 1:00 PM)">Morning (10:00 AM - 1:00 PM)</option>
                  <option value="Afternoon (1:00 PM - 4:00 PM)">Afternoon (1:00 PM - 4:00 PM)</option>
                  <option value="Evening (4:00 PM - 7:30 PM)">Evening (4:00 PM - 7:30 PM)</option>
                </select>
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setAssignSale(null)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={assigningLoading}
                  className="w-1/2 bg-slate-900 text-white py-2.5 rounded-xl font-bold hover:bg-black transition flex items-center justify-center gap-1.5"
                >
                  {assigningLoading ? 'Assigning Agent...' : 'Confirm Schedule'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Edit Deduction Modal */}
      {editingOption && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-sm w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-bold text-base text-slate-900">
              Update Deduction Price
            </h3>
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
                  className="w-full p-2 border border-slate-300 rounded-xl text-base font-bold text-rose-600"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingOption(null)}
                  className="w-1/2 border border-slate-300 py-2 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-emerald-600 text-white py-2 rounded-xl font-bold hover:bg-emerald-700"
                >
                  Save Deduction
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* End-to-End Buyback Lifecycle Trace Modal */}
      {traceSale && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
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
                className="text-slate-400 hover:text-slate-700 text-lg font-bold p-1"
              >
                ✕
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
        </div>
      )}

      {/* Receipt Modal */}
      {receiptData && (
        <ReceiptModal
          receiptData={receiptData}
          onClose={() => setReceiptData(null)}
        />
      )}

    </div>
  );
}
