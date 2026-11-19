import React, { useState, useEffect } from 'react';
import { 
  Search, Smartphone, MapPin, Calendar, Clock, CheckCircle2, 
  XCircle, AlertCircle, FileText, IndianRupee, ShieldCheck, ChevronRight, Eye 
} from 'lucide-react';
import { api } from '../services/api';
import ReceiptModal from './ReceiptModal';

export default function TrackOrder({ initialSaleCode, currentUser }) {
  const [query, setQuery] = useState(initialSaleCode || '');
  const [salesList, setSalesList] = useState([]);
  const [selectedSale, setSelectedSale] = useState(null);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  
  // Receipt modal state
  const [receiptData, setReceiptData] = useState(null);
  const [loadingReceipt, setLoadingReceipt] = useState(false);

  // If initialSaleCode provided, search immediately
  useEffect(() => {
    if (initialSaleCode) {
      handleSearch(initialSaleCode);
    } else if (currentUser) {
      loadMySales();
    } else {
      handleSearch('XP2610008753');
    }
  }, [initialSaleCode, currentUser]);

  const loadMySales = async () => {
    setLoading(true);
    try {
      const data = await api.getSales();
      setSalesList(data);
      if (data.length > 0) setSelectedSale(data[0]);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (codeToSearch = query) => {
    const q = (codeToSearch || '').trim();
    if (!q) return;

    setLoading(true);
    setErrorMsg('');
    try {
      const isPhone = /^[0-9]{10}$/.test(q);
      const data = await api.getSales(isPhone ? { phone: q } : { sale_code: q });
      
      if (Array.isArray(data) && data.length > 0) {
        setSalesList(data);
        setSelectedSale(data[0]);
      } else if (data && data.id) {
        setSalesList([data]);
        setSelectedSale(data);
      } else {
        setSalesList([]);
        setSelectedSale(null);
        setErrorMsg(`No buyback orders found matching "${q}". Check your Order ID or phone number.`);
      }
    } catch (err) {
      setErrorMsg(err.message || 'Error searching for order');
    } finally {
      setLoading(false);
    }
  };

  const handleAcceptOffer = async (saleId) => {
    try {
      await api.acceptOffer(saleId);
      // Refresh
      const updated = await api.getSaleDetail(saleId);
      setSelectedSale(updated);
      setSalesList(salesList.map(s => s.id === updated.id ? updated : s));
    } catch (e) {
      alert(e.message);
    }
  };

  const handleRejectOffer = async (saleId) => {
    if (!window.confirm("Are you sure you want to reject this offer? Your phone will be returned safely to your address.")) return;
    try {
      await api.rejectOffer(saleId);
      const updated = await api.getSaleDetail(saleId);
      setSelectedSale(updated);
      setSalesList(salesList.map(s => s.id === updated.id ? updated : s));
    } catch (e) {
      alert(e.message);
    }
  };

  const handleViewReceipt = async (saleCode) => {
    setLoadingReceipt(true);
    try {
      const data = await api.getPaymentReceipt(saleCode);
      setReceiptData(data);
    } catch (err) {
      alert(err.message || 'Payment receipt not available yet');
    } finally {
      setLoadingReceipt(false);
    }
  };

  // Status step configuration
  const STEPS = [
    { key: 'SUBMITTED', label: 'Request Submitted' },
    { key: 'PICKUP_SCHEDULED', label: 'Pickup Scheduled' },
    { key: 'INSPECTION_PENDING', label: 'Device Inspection' },
    { key: 'FINAL_OFFER_SENT', label: 'Final Offer' },
    { key: 'PAYMENT_COMPLETED', label: 'Payout Disbursed' },
  ];

  const getStepIndex = (status) => {
    switch (status) {
      case 'SUBMITTED': return 0;
      case 'PICKUP_SCHEDULED': return 1;
      case 'PICKED_UP':
      case 'INSPECTION_PENDING':
      case 'INSPECTION_COMPLETED': return 2;
      case 'FINAL_OFFER_SENT':
      case 'CUSTOMER_ACCEPTED':
      case 'OWNERSHIP_TRANSFERRED':
      case 'PAYMENT_PENDING': return 3;
      case 'PAYMENT_COMPLETED': return 4;
      default: return 0;
    }
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      
      {/* Search Header Glass Panel */}
      <div className="glass-panel rounded-3xl p-6 sm:p-7 shadow-sm mb-8">
        <h2 className="text-xl font-extrabold text-[#17251C] mb-1">
          Track Your 1103 RECELL Order Status
        </h2>
        <p className="text-xs text-[#7B8980] mb-4">
          Enter your Order ID (e.g. <span className="font-mono font-bold text-[#0BAA4B]">XP2610008753</span>) or 10-digit mobile number:
        </p>

        <form onSubmit={(e) => { e.preventDefault(); handleSearch(); }} className="flex gap-2 max-w-xl">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-[#7B8980] absolute left-3.5 top-3.5" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="e.g. XP2610008753 or 9870011223"
              className="w-full pl-10 pr-3 py-2.5 glass-input rounded-xl text-sm focus:outline-none font-mono"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-bold px-6 py-2.5 rounded-xl text-sm transition shadow-md shadow-[#0BAA4B]/20"
          >
            {loading ? 'Searching...' : 'Track'}
          </button>
        </form>

        {errorMsg && (
          <div className="mt-4 p-3 bg-rose-50/90 border border-rose-200 rounded-xl text-rose-700 text-xs font-semibold flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}
      </div>

      {/* Results View */}
      {salesList.length > 1 && (
        <div className="mb-4">
          <p className="text-[11px] font-extrabold text-[#7B8980] uppercase tracking-wider mb-2">
            Select Order to Track ({salesList.length} found):
          </p>
          <div className="flex gap-2 overflow-x-auto pb-2 scrollbar-none">
            {salesList.map((s) => (
              <button
                key={s.id}
                type="button"
                onClick={() => setSelectedSale(s)}
                className={`px-3 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition flex items-center gap-2 shrink-0 ${
                  selectedSale?.id === s.id
                    ? 'bg-[#0BAA4B] text-white shadow-md'
                    : 'glass-card text-[#17251C] hover:bg-white'
                }`}
              >
                <span className="font-mono">{s.sale_code}</span>
                <span className="text-[11px] opacity-80">{s.brand_name} {s.model_name}</span>
                <span className={`text-[10px] px-1.5 py-0.5 rounded font-bold ${
                  s.status === 'PAYMENT_COMPLETED' ? 'bg-white/20 text-white' :
                  s.status === 'FINAL_OFFER_SENT' ? 'bg-amber-100 text-amber-800' :
                  'bg-white/30 text-white'
                }`}>
                  {s.status === 'PAYMENT_COMPLETED' ? 'PAID' : s.status.replace(/_/g, ' ')}
                </span>
              </button>
            ))}
          </div>
        </div>
      )}

      {selectedSale ? (
        <div className="space-y-6 animate-fade-in">
          
          {/* Main Status Glass Panel */}
          <div className="glass-panel rounded-3xl p-6 sm:p-8 shadow-sm space-y-6">
            
            {/* Top row */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-white/80 pb-5">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs font-bold bg-[#E8F8ED] text-[#087C38] px-2.5 py-1 rounded-md border border-[#0BAA4B]/20">
                    {selectedSale.sale_code}
                  </span>
                  <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${
                    selectedSale.status === 'PAYMENT_COMPLETED' 
                      ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                      : selectedSale.status === 'FINAL_OFFER_SENT'
                      ? 'bg-amber-100 text-amber-800 border border-amber-200 animate-pulse'
                      : 'bg-emerald-50 text-emerald-800 border border-emerald-200'
                  }`}>
                    ● {selectedSale.status.replace(/_/g, ' ')}
                  </span>
                </div>
                <h3 className="text-2xl font-black text-[#17251C] mt-2">
                  {selectedSale.brand_name} {selectedSale.model_name}
                </h3>
                <p className="text-xs text-[#7B8980] mt-0.5">
                  Variant: {selectedSale.variant_details?.ram ? `${selectedSale.variant_details.ram} / ` : ''}{selectedSale.variant_details?.storage}
                </p>
              </div>

              <div className="text-left sm:text-right glass-card p-4 rounded-2xl border border-white/80 sm:bg-transparent sm:p-0 sm:border-0 sm:shadow-none">
                <span className="text-xs text-[#7B8980] font-medium block">
                  {selectedSale.final_price ? 'Final Approved Offer:' : 'Estimated Offer:'}
                </span>
                <span className="text-3xl font-black text-[#0BAA4B]">
                  ₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
                </span>
                {selectedSale.final_price && selectedSale.final_price !== selectedSale.estimated_price && (
                  <span className="text-xs text-[#7B8980] line-through block mt-0.5">
                    Est: ₹{Number(selectedSale.estimated_price).toLocaleString('en-IN')}
                  </span>
                )}
              </div>
            </div>

            {/* Visual Stepper (Responsive 5-Step Progress) */}
            <div className="py-2">
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                {STEPS.map((s, idx) => {
                  const currentIdx = getStepIndex(selectedSale.status);
                  const isDone = currentIdx >= idx;
                  const isCurrent = currentIdx === idx;
                  const isLastOdd = idx === 4;
                  return (
                    <div 
                      key={s.key} 
                      className={`p-2.5 sm:p-3 rounded-2xl border text-center transition ${
                        isLastOdd ? 'col-span-2 sm:col-span-1' : ''
                      } ${
                        isCurrent
                          ? 'bg-[#E8F8ED] border-[#0BAA4B] text-[#087C38] ring-2 ring-[#0BAA4B]/20 shadow-sm'
                          : isDone
                          ? 'bg-emerald-50/70 border-emerald-200 text-[#087C38]'
                          : 'glass-card border-white/60 text-slate-400'
                      }`}
                    >
                      <div className="flex items-center justify-center mb-1">
                        {isDone ? (
                          <CheckCircle2 className="w-4 h-4 text-[#0BAA4B]" />
                        ) : (
                          <div className="w-4 h-4 rounded-full border border-slate-300" />
                        )}
                      </div>
                      <span className="text-[11px] sm:text-xs font-bold block">{s.label}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* ACTION BANNER: FINAL OFFER ACCEPTANCE */}
            {selectedSale.status === 'FINAL_OFFER_SENT' && (
              <div className="glass-card bg-amber-50/80 border-2 border-amber-300 rounded-2xl p-6 space-y-4">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-6 h-6 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <h4 className="font-extrabold text-amber-900 text-base">
                      Physical Inspection Completed: Action Required
                    </h4>
                    <p className="text-xs text-amber-800 mt-1">
                      Our field team inspected your device and calculated a final offer of{' '}
                      <strong className="text-sm font-black text-[#17251C]">
                        ₹{Number(selectedSale.final_price).toLocaleString('en-IN')}
                      </strong>.
                      {selectedSale.inspection?.inspector_notes && (
                        <span className="block mt-1 italic text-slate-700 font-medium">
                          Inspection Note: "{selectedSale.inspection.inspector_notes}"
                        </span>
                      )}
                    </p>
                  </div>
                </div>

                <div className="flex flex-col sm:flex-row gap-3 pt-2">
                  <button
                    onClick={() => handleAcceptOffer(selectedSale.id)}
                    className="flex-1 bg-[#0BAA4B] hover:bg-[#087C38] text-white font-extrabold py-3 rounded-xl text-sm shadow transition flex items-center justify-center gap-2"
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    Accept ₹{Number(selectedSale.final_price).toLocaleString('en-IN')} & Release Payment
                  </button>
                  <button
                    onClick={() => handleRejectOffer(selectedSale.id)}
                    className="border border-rose-300 hover:bg-rose-50 text-rose-700 font-bold py-3 px-6 rounded-xl text-sm transition"
                  >
                    Reject Offer (Return Device)
                  </button>
                </div>
              </div>
            )}

            {/* SUCCESS BANNER: PAID */}
            {selectedSale.status === 'PAYMENT_COMPLETED' && (
              <div className="bg-gradient-to-r from-[#0BAA4B] to-[#087C38] text-white rounded-2xl p-6 shadow-lg space-y-3 border border-white/20">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center">
                      <CheckCircle2 className="w-6 h-6 text-white" />
                    </div>
                    <div>
                      <h4 className="font-black text-lg">Payment Disbursed Successfully!</h4>
                      <p className="text-xs text-emerald-100">
                        Funds have been sent to your {selectedSale.beneficiary_type === 'UPI' ? 'UPI ID' : 'Bank Account'}.
                      </p>
                    </div>
                  </div>
                  <span className="font-mono text-xl font-black bg-black/20 px-3 py-1.5 rounded-xl">
                    ₹{Number(selectedSale.final_price).toLocaleString('en-IN')}
                  </span>
                </div>

                {selectedSale.payment && (
                  <div className="bg-white/10 rounded-xl p-3 text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2 border border-white/20">
                    <div>
                      <span className="text-emerald-100">Bank Reference (UTR):</span>{' '}
                      <strong className="font-mono text-white font-bold">{selectedSale.payment.utr_number}</strong>
                    </div>
                    <div>
                      <span className="text-emerald-100">Paid Via:</span>{' '}
                      <strong className="text-white">{selectedSale.payment.payment_method}</strong>
                    </div>
                  </div>
                )}

                <div className="pt-2">
                  <button
                    onClick={() => handleViewReceipt(selectedSale.sale_code)}
                    disabled={loadingReceipt}
                    className="w-full sm:w-auto bg-white hover:bg-slate-100 text-[#17251C] font-extrabold px-6 py-2.5 rounded-xl text-xs shadow transition flex items-center justify-center gap-2"
                  >
                    <FileText className="w-4 h-4 text-[#0BAA4B]" />
                    {loadingReceipt ? 'Loading Receipt...' : 'View Payment Proof & Official Receipt'}
                  </button>
                </div>
              </div>
            )}

            {/* Information Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs pt-2">
              
              {/* Pickup & Agent Details */}
              <div className="glass-card p-5 rounded-2xl space-y-3">
                <h5 className="font-bold text-[#17251C] flex items-center gap-2 text-xs">
                  <MapPin className="w-4 h-4 text-[#0BAA4B]" /> Doorstep Collection Details
                </h5>
                <div className="space-y-1.5 text-[#7B8980]">
                  <p><span className="text-[#7B8980]/80">Address:</span> {selectedSale.pickup_address}, {selectedSale.pickup_city} - {selectedSale.pickup_pincode}</p>
                  <p><span className="text-[#7B8980]/80">Pickup Slot:</span> {selectedSale.pickup_date ? `${selectedSale.pickup_date} · ` : ''}{selectedSale.pickup_slot} (IST)</p>
                  {selectedSale.created_at_ist && (
                    <p><span className="text-[#7B8980]/80">Booked On:</span> {selectedSale.created_at_ist}</p>
                  )}
                  {selectedSale.is_overdue && (
                    <p className="text-rose-600 font-bold bg-rose-50 p-2 rounded-lg border border-rose-200">
                      ⚠️ Pickup Window Passed · Rescheduling or agent is en route (IST)
                    </p>
                  )}
                  <p><span className="text-[#7B8980]/80">Assigned Agent:</span> <strong className="text-[#17251C]">{selectedSale.assigned_agent_name || 'Assigning field staff...'}</strong></p>
                </div>
              </div>

              {/* Payout Destination */}
              <div className="glass-card p-5 rounded-2xl space-y-3">
                <h5 className="font-bold text-[#17251C] flex items-center gap-2 text-xs">
                  <IndianRupee className="w-4 h-4 text-[#0BAA4B]" /> Payout Destination
                </h5>
                <div className="space-y-1.5 text-[#7B8980]">
                  <p><span className="text-[#7B8980]/80">Payee Name:</span> {selectedSale.beneficiary_name}</p>
                  {selectedSale.beneficiary_type === 'UPI' ? (
                    <p><span className="text-[#7B8980]/80">UPI ID:</span> <strong className="font-mono text-[#17251C]">{selectedSale.beneficiary_upi_id}</strong></p>
                  ) : (
                    <p><span className="text-[#7B8980]/80">Bank Details:</span> <strong className="font-mono text-[#17251C]">{selectedSale.beneficiary_account_no} ({selectedSale.beneficiary_ifsc})</strong></p>
                  )}
                  <p><span className="text-[#7B8980]/80">Device IMEI:</span> <strong className="font-mono text-[#17251C]">{selectedSale.imei_number || 'Verifying during pickup'}</strong></p>
                </div>
              </div>

            </div>

          </div>
        </div>
      ) : null}

      {/* Official Printable Receipt Modal */}
      {receiptData && (
        <ReceiptModal 
          receiptData={receiptData} 
          onClose={() => setReceiptData(null)} 
        />
      )}

    </div>
  );
}
