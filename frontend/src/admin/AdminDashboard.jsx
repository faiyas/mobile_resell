import React, { useState, useEffect } from 'react';
import { 
  IndianRupee, Smartphone, Clock, CheckCircle2, AlertCircle, 
  Search, Filter, QrCode, Upload, Eye, UserPlus, RefreshCw, 
  Layers, ShieldAlert, Award, FileText, ChevronRight 
} from 'lucide-react';
import { api } from '../services/api';
import PayoutModal from './PayoutModal';
import ReceiptModal from '../customer/ReceiptModal';

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

  // Edit condition option modal
  const [editingOption, setEditingOption] = useState(null);
  const [newDeductionValue, setNewDeductionValue] = useState('');

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

  // Metrics
  const pendingInspectionsCount = sales.filter(s => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].includes(s.status)).length;
  const awaitingPayoutsCount = sales.filter(s => ['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].includes(s.status)).length;
  const completedCount = sales.filter(s => s.status === 'PAYMENT_COMPLETED').length;

  const handleAssignPickup = async (e) => {
    e.preventDefault();
    if (!assignSale) return;
    try {
      await api.assignPickup(assignSale.id, {
        agent_id: selectedAgentId,
        pickup_date: pickupDate,
        pickup_slot: pickupSlot,
      });
      setAssignSale(null);
      loadDashboardData();
    } catch (err) {
      alert(err.message);
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
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-900 text-white p-5 sm:p-8 rounded-3xl shadow-xl">
        <div>
          <span className="text-[10px] sm:text-[11px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-500/10 border border-emerald-500/20 px-2 py-0.5 rounded">
            Super Admin Control Center
          </span>
          <h1 className="text-xl sm:text-3xl font-black mt-2">
            Mobile Buyback Operations Desk
          </h1>
          <p className="text-[11px] sm:text-xs text-slate-400 mt-1">
            Manage device valuations, assign pickup agents, and authorize UPI / Bank payouts with Base64 proof.
          </p>
        </div>

        <button
          onClick={loadDashboardData}
          disabled={loading}
          className="flex items-center justify-center gap-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold px-4 py-2.5 rounded-xl border border-slate-700 transition w-full sm:w-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-emerald-400' : ''}`} />
          {loading ? 'Refreshing...' : 'Refresh Data'}
        </button>
      </div>

      {/* Metrics Row (Optimized for 2-column mobile screens like iPhone SE) */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-2.5 sm:gap-4">
        
        <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider">Today's Sales</span>
          <p className="text-2xl sm:text-3xl font-black text-slate-900 mt-1">{sales.length}</p>
          <span className="text-[10px] sm:text-[11px] text-slate-500 font-medium mt-1 truncate">All submissions</span>
        </div>

        <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-amber-600 uppercase tracking-wider">Pending Pickup</span>
          <p className="text-2xl sm:text-3xl font-black text-amber-600 mt-1">{pendingInspectionsCount}</p>
          <span className="text-[10px] sm:text-[11px] text-amber-700 font-medium mt-1 truncate">Awaiting collection</span>
        </div>

        <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-emerald-200 bg-emerald-50/40 shadow-sm flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-emerald-700 uppercase tracking-wider">Awaiting Payout</span>
          <p className="text-2xl sm:text-3xl font-black text-emerald-600 mt-1">{awaitingPayoutsCount}</p>
          <span className="text-[10px] sm:text-[11px] text-emerald-700 font-semibold mt-1 truncate">Ready for QR scan</span>
        </div>

        <div className="bg-white p-3.5 sm:p-5 rounded-2xl border border-slate-200 shadow-sm flex flex-col justify-between">
          <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase tracking-wider">Total Payouts</span>
          <p className="text-xl sm:text-3xl font-black text-slate-900 mt-1 truncate">
            ₹{Number(paymentsList.total_disbursed).toLocaleString('en-IN')}
          </p>
          <span className="text-[10px] sm:text-[11px] text-slate-500 font-medium mt-1 truncate">
            {paymentsList.total_count} verified sales
          </span>
        </div>

      </div>

      {/* Navigation Tabs (Smooth horizontal swipe on mobile) */}
      <div className="flex border-b border-slate-200 gap-1 overflow-x-auto pb-1 -mx-2 px-2 scrollbar-none">
        <button
          onClick={() => setActiveTab('payouts')}
          className={`pb-2.5 px-3.5 text-xs font-extrabold transition border-b-2 shrink-0 flex items-center gap-1.5 ${
            activeTab === 'payouts'
              ? 'border-emerald-600 text-emerald-700'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <IndianRupee className="w-3.5 h-3.5" />
          Payout Desk ({payoutQueue.length})
        </button>

        <button
          onClick={() => setActiveTab('sales')}
          className={`pb-2.5 px-3.5 text-xs font-extrabold transition border-b-2 shrink-0 flex items-center gap-1.5 ${
            activeTab === 'sales'
              ? 'border-emerald-600 text-emerald-700'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Smartphone className="w-3.5 h-3.5" />
          Customer Sales ({sales.length})
        </button>

        <button
          onClick={() => setActiveTab('pricing')}
          className={`pb-2.5 px-3.5 text-xs font-extrabold transition border-b-2 shrink-0 flex items-center gap-1.5 ${
            activeTab === 'pricing'
              ? 'border-emerald-600 text-emerald-700'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Layers className="w-3.5 h-3.5" />
          Pricing Rules
        </button>

        <button
          onClick={() => setActiveTab('history')}
          className={`pb-2.5 px-3.5 text-xs font-extrabold transition border-b-2 shrink-0 flex items-center gap-1.5 ${
            activeTab === 'history'
              ? 'border-emerald-600 text-emerald-700'
              : 'border-transparent text-slate-500 hover:text-slate-800'
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
                      <p className="text-slate-500 text-[11px]">{s.variant_details?.storage}</p>
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
                    <td className="py-3.5 px-3 text-right space-x-1">
                      {['SUBMITTED', 'PICKUP_SCHEDULED'].includes(s.status) && (
                        <button
                          onClick={() => setAssignSale(s)}
                          className="px-2.5 py-1 bg-slate-900 hover:bg-black text-white rounded-lg text-[11px] font-bold transition"
                        >
                          Schedule
                        </button>
                      )}
                      {['OWNERSHIP_TRANSFERRED', 'CUSTOMER_ACCEPTED'].includes(s.status) && (
                        <button
                          onClick={() => setPayoutSale(s)}
                          className="px-2.5 py-1 bg-emerald-600 hover:bg-emerald-700 text-white rounded-lg text-[11px] font-bold transition"
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

      {/* ================= TAB 3: PRICING ENGINE ================= */}
      {activeTab === 'pricing' && (
        <div className="space-y-6 animate-fade-in">
          <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">
                Condition Deductions & Valuation Engine
              </h3>
              <p className="text-xs text-slate-500">
                Configure default rupee deductions applied when a customer ticks a defect during self-assessment.
              </p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {conditionCategories.map((cat) => (
                <div key={cat.id} className="border border-slate-200 rounded-xl p-4 bg-slate-50 space-y-3">
                  <h4 className="font-extrabold text-slate-900 text-xs flex items-center justify-between">
                    <span>{cat.name}</span>
                    <span className="text-[10px] text-slate-400 font-normal">{cat.options?.length || 0} rules</span>
                  </h4>

                  <div className="space-y-2">
                    {cat.options?.map((opt) => (
                      <div key={opt.id} className="bg-white p-2.5 rounded-lg border border-slate-200 flex items-center justify-between text-xs">
                        <div>
                          <p className="font-bold text-slate-800">{opt.title}</p>
                          <span className="text-[10px] text-slate-400 font-mono">{opt.code}</span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="font-extrabold text-rose-600 text-xs">
                            -₹{Number(opt.default_deduction_value).toLocaleString('en-IN')}
                          </span>
                          <button
                            onClick={() => {
                              setEditingOption(opt);
                              setNewDeductionValue(opt.default_deduction_value);
                            }}
                            className="text-[11px] font-bold text-slate-600 hover:text-emerald-600 px-2 py-0.5 border border-slate-200 rounded hover:bg-slate-50"
                          >
                            Edit
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
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
                    <td className="py-3.5 px-3 text-slate-500">{new Date(p.paid_at).toLocaleDateString()}</td>
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
                <label className="block font-bold text-slate-700 mb-1">Pickup Date</label>
                <input
                  type="date"
                  required
                  value={pickupDate}
                  onChange={(e) => setPickupDate(e.target.value)}
                  className="w-full p-2 border border-slate-300 rounded-xl"
                />
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
                  className="w-1/2 border border-slate-300 py-2 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-slate-900 text-white py-2 rounded-xl font-bold hover:bg-black"
                >
                  Confirm Schedule
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
