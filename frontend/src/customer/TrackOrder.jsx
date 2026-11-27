import React, { useState, useEffect } from 'react';
import { 
  Search, Smartphone, MapPin, Calendar, Clock, CheckCircle2, 
  XCircle, AlertCircle, FileText, IndianRupee, ShieldCheck, ChevronRight, 
  ArrowLeft, Share2, PhoneCall, RefreshCw, Filter, PackageCheck, Truck,
  Copy, Check, ZoomIn
} from 'lucide-react';
import { api } from '../services/api';
import ReceiptModal from './ReceiptModal';
import ImageZoomModal from '../components/ImageZoomModal';

export default function TrackOrder({ initialSaleCode, currentUser }) {
  const [query, setQuery] = useState(initialSaleCode || '');
  const [salesList, setSalesList] = useState([]);
  const [selectedSale, setSelectedSale] = useState(null);
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [activeFilter, setActiveFilter] = useState('ALL');
  
  // Receipt modal state
  const [receiptData, setReceiptData] = useState(null);
  const [loadingReceipt, setLoadingReceipt] = useState(false);

  // Zoom lightbox state
  const [zoomViewer, setZoomViewer] = useState(null);
  const [copiedKey, setCopiedKey] = useState(null);

  // Order cancellation state
  const [cancelModalOpen, setCancelModalOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState('');
  const [cancelling, setCancelling] = useState(false);

  const isCancellable = selectedSale && [
    'SUBMITTED', 'PICKUP_SCHEDULED', 'INSPECTION_PENDING', 'FINAL_OFFER_SENT'
  ].includes(selectedSale.status);

  const handleCancelOrder = async () => {
    if (!selectedSale) return;
    setCancelling(true);
    try {
      await api.cancelOrder(selectedSale.id, { reason: cancelReason });
      const updated = await api.getSaleDetail(selectedSale.id);
      setSelectedSale(updated);
      setSalesList(salesList.map(s => s.id === updated.id ? updated : s));
      setCancelModalOpen(false);
      setCancelReason('');
      alert('Your selling order has been cancelled successfully.');
    } catch (e) {
      alert(e.message || 'Failed to cancel order.');
    } finally {
      setCancelling(false);
    }
  };

  // If initialSaleCode provided, search immediately
  useEffect(() => {
    if (initialSaleCode) {
      handleSearch(initialSaleCode);
    } else if (currentUser) {
      loadMySales();
    } else {
      setSelectedSale(null);
    }
  }, [initialSaleCode, currentUser]);

  const loadMySales = async () => {
    setLoading(true);
    try {
      const data = await api.getSales();
      const list = Array.isArray(data) ? data : (data?.results || []);
      setSalesList(list);
      // If exactly 1 order, open it directly; if multiple, start in Amazon-style list view
      if (list.length === 1 && !selectedSale) {
        setSelectedSale(list[0]);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (codeToSearch = query) => {
    const q = (codeToSearch || '').trim();
    if (!q) {
      if (currentUser) loadMySales();
      return;
    }

    setLoading(true);
    setErrorMsg('');
    try {
      const isPhone = /^[0-9]{10}$/.test(q);
      const data = await api.getSales(isPhone ? { phone: q } : { sale_code: q });
      
      const list = Array.isArray(data) ? data : (data?.id ? [data] : []);
      if (list.length > 0) {
        setSalesList(list);
        if (list.length === 1) {
          setSelectedSale(list[0]);
        } else {
          setSelectedSale(null); // Let customer browse the matching orders list
        }
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
      const updated = await api.getSaleDetail(saleId);
      setSelectedSale(updated);
      setSalesList(salesList.map(s => s.id === updated.id ? updated : s));
    } catch (e) {
      alert(e.message);
    }
  };

  const handleRejectOffer = async (saleId) => {
    if (!window.confirm("Are you sure you want to decline this final offer? Your phone will be returned safely.")) return;
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

  // 6-Milestone Lifecycle
  const STEPS = [
    { key: 'SUBMITTED', label: '1. Request Placed', desc: 'Device details & pickup address registered' },
    { key: 'PICKUP_SCHEDULED', label: '2. Pickup Scheduled', desc: 'Doorstep pickup slot confirmed' },
    { key: 'INSPECTION_PENDING', label: '3. Doorstep QC', desc: 'Field specialist verifies hardware & screen' },
    { key: 'FINAL_OFFER_SENT', label: '4. Offer Confirmed', desc: 'Customer accepts final valuation' },
    { key: 'OWNERSHIP_TRANSFERRED', label: '5. Device Handover', desc: 'Custody transferred to Dolly' },
    { key: 'PAYMENT_COMPLETED', label: '6. Payout Disbursed', desc: 'Direct UPI / IMPS funds credited' },
  ];

  const getStepIndex = (status) => {
    switch (status) {
      case 'SUBMITTED': return 0;
      case 'PICKUP_SCHEDULED': return 1;
      case 'PICKED_UP':
      case 'INSPECTION_PENDING':
      case 'INSPECTION_COMPLETED': return 2;
      case 'FINAL_OFFER_SENT': return 3;
      case 'CUSTOMER_ACCEPTED': return 3;
      case 'OWNERSHIP_TRANSFERRED':
      case 'PAYMENT_PENDING': return 4;
      case 'PAYMENT_COMPLETED': return 5;
      default: return 0;
    }
  };

  // Filter orders by tab
  const filteredSales = salesList.filter(s => {
    if (activeFilter === 'SCHEDULED') return ['SUBMITTED', 'PICKUP_SCHEDULED'].includes(s.status);
    if (activeFilter === 'INSPECTION') return ['INSPECTION_PENDING', 'FINAL_OFFER_SENT', 'CUSTOMER_ACCEPTED'].includes(s.status);
    if (activeFilter === 'PAID') return ['OWNERSHIP_TRANSFERRED', 'PAYMENT_COMPLETED'].includes(s.status);
    if (activeFilter === 'CANCELLED') return s.status === 'CANCELLED';
    return true; // 'ALL'
  });

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      
      {/* Search Header Glass Panel */}
      <div className="glass-panel rounded-3xl p-6 sm:p-7 shadow-sm mb-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-3">
          <div>
            <h2 className="text-xl sm:text-2xl font-black text-[#17251C]">
              {selectedSale ? 'Order Details & Real-Time Tracking' : 'Your Buyback Orders'}
            </h2>
            <p className="text-xs text-[#7B8980] mt-0.5">
              {selectedSale 
                ? `Order #${selectedSale.sale_code} · Dolly Doorstep Service`
                : 'Track, manage, and inspect all your device sell orders in one place'}
            </p>
          </div>
          {selectedSale && (
            <button
              onClick={() => setSelectedSale(null)}
              className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-white/80 hover:bg-white text-xs font-bold text-slate-700 border border-slate-200 shadow-xs transition shrink-0"
            >
              <ArrowLeft className="w-3.5 h-3.5 text-[#0BAA4B]" />
              View All Orders ({salesList.length})
            </button>
          )}
        </div>

        {/* Search input bar */}
        <form onSubmit={(e) => { e.preventDefault(); handleSearch(); }} className="flex gap-2 max-w-xl">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-[#7B8980] absolute left-3.5 top-3.5" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="Search by Order ID (e.g. PHN-2026-22245B) or 10-digit mobile..."
              className="w-full pl-10 pr-3 py-2.5 glass-input rounded-xl text-xs sm:text-sm focus:outline-none font-mono"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-bold px-5 sm:px-6 py-2.5 rounded-xl text-xs sm:text-sm transition shadow-md shadow-[#0BAA4B]/20 shrink-0"
          >
            {loading ? 'Searching...' : 'Track'}
          </button>
        </form>

        {errorMsg && (
          <div className="mt-3 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-medium flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}
      </div>

      {/* ========================================================= */}
      {/* VIEW A: AMAZON-STYLE "YOUR ORDERS" LIST SCREEN            */}
      {/* ========================================================= */}
      {!selectedSale && (
        <div className="space-y-5 animate-fade-in">
          
          {/* Amazon-style Filter Chips */}
          <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
            {[
              { id: 'ALL', label: `All Orders (${salesList.length})` },
              { id: 'SCHEDULED', label: 'Scheduled Pickups' },
              { id: 'INSPECTION', label: 'Under QC / Inspection' },
              { id: 'PAID', label: 'Paid / Completed' },
              { id: 'CANCELLED', label: 'Cancelled' },
            ].map((f) => (
              <button
                key={f.id}
                type="button"
                onClick={() => setActiveFilter(f.id)}
                className={`px-4 py-2 rounded-xl text-xs font-bold whitespace-nowrap transition flex items-center gap-1.5 ${
                  activeFilter === f.id
                    ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/20'
                    : 'glass-card text-slate-700 hover:bg-white border border-slate-200'
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>

          {/* Orders Card Grid / List */}
          {filteredSales.length === 0 ? (
            <div className="glass-panel rounded-3xl p-12 text-center space-y-3">
              <div className="w-14 h-14 mx-auto rounded-full bg-emerald-50 border border-emerald-200 flex items-center justify-center text-[#0BAA4B]">
                <PackageCheck className="w-7 h-7" />
              </div>
              <h3 className="font-extrabold text-slate-800 text-base">
                {salesList.length === 0 ? 'No Buyback Orders Found' : 'No Orders In This Category'}
              </h3>
              <p className="text-xs text-slate-500 max-w-sm mx-auto">
                {salesList.length === 0 
                  ? 'Sell your old phone, tablet, or laptop at guaranteed doorstep prices.' 
                  : 'Try selecting "All Orders" to view your full order history.'}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredSales.map((sale) => {
                const isPaid = sale.status === 'PAYMENT_COMPLETED';
                const isCancelled = sale.status === 'CANCELLED';
                const isReview = sale.status === 'FINAL_OFFER_SENT';

                return (
                  <div
                    key={sale.id}
                    onClick={() => setSelectedSale(sale)}
                    className="glass-card rounded-2xl sm:rounded-3xl border border-white/80 hover:border-[#0BAA4B]/40 hover:shadow-lg transition-all duration-200 cursor-pointer overflow-hidden group bg-white/70"
                  >
                    {/* Top Amazon Card Header */}
                    <div className="bg-slate-50/80 px-5 sm:px-6 py-3 border-b border-slate-200/60 flex flex-wrap items-center justify-between gap-3 text-xs">
                      <div className="flex items-center gap-4 text-slate-500">
                        <div>
                          <span className="block text-[10px] uppercase font-bold text-slate-400">Order Placed</span>
                          <span className="font-medium text-slate-700">{sale.created_at_ist || sale.pickup_date || 'Recent'}</span>
                        </div>
                        <div className="hidden sm:block">
                          <span className="block text-[10px] uppercase font-bold text-slate-400">Total Payout</span>
                          <span className="font-bold text-[#0BAA4B]">₹{Number(sale.final_price || sale.estimated_price).toLocaleString('en-IN')}</span>
                        </div>
                        <div>
                          <span className="block text-[10px] uppercase font-bold text-slate-400">Ship To</span>
                          <span className="font-medium text-slate-700">{sale.pickup_city || 'Doorstep Pickup'}</span>
                        </div>
                      </div>

                      <div className="flex items-center gap-2">
                        <span className="font-mono text-[11px] font-bold text-slate-600 bg-white px-2.5 py-1 rounded-md border border-slate-200">
                          #{sale.sale_code}
                        </span>
                        <span className={`text-[11px] font-bold px-2.5 py-0.5 rounded-full ${
                          isCancelled ? 'bg-rose-100 text-rose-800' :
                          isPaid ? 'bg-emerald-100 text-emerald-800' :
                          isReview ? 'bg-amber-100 text-amber-800 animate-pulse' :
                          'bg-emerald-50 text-emerald-800 border border-emerald-200'
                        }`}>
                          ● {sale.status.replace(/_/g, ' ')}
                        </span>
                      </div>
                    </div>

                    {/* Main Card Body */}
                    <div className="p-5 sm:p-6 flex flex-col sm:flex-row sm:items-center justify-between gap-5">
                      <div className="flex items-start gap-4">
                        <div className="w-16 h-16 sm:w-20 sm:h-20 rounded-2xl bg-gradient-to-br from-emerald-50 to-emerald-100 border border-emerald-200 flex items-center justify-center shrink-0 text-[#0BAA4B] shadow-xs group-hover:scale-105 transition-transform">
                          <Smartphone className="w-8 h-8 sm:w-10 sm:h-10" />
                        </div>
                        <div className="space-y-1">
                          <h4 className="text-base sm:text-lg font-black text-[#17251C] group-hover:text-[#0BAA4B] transition-colors">
                            {sale.brand_name} {sale.model_name}
                          </h4>
                          <p className="text-xs text-slate-500 font-medium">
                            Variant: {sale.variant_details?.storage || 'Standard'}{sale.variant_details?.ram ? ` · ${sale.variant_details.ram} RAM` : ''}
                          </p>
                          <div className="flex flex-wrap items-center gap-2 pt-1 text-[11px]">
                            <span className="inline-flex items-center gap-1 text-slate-600">
                              <Calendar className="w-3.5 h-3.5 text-[#0BAA4B]" />
                              Pickup: {sale.pickup_date || 'Today'} ({sale.pickup_slot || 'Morning'})
                            </span>
                            {sale.assigned_agent_name && (
                              <span className="text-emerald-700 font-bold bg-emerald-50 px-2 py-0.5 rounded-md">
                                Agent: {sale.assigned_agent_name}
                              </span>
                            )}
                          </div>
                        </div>
                      </div>

                      {/* Right Action Pill */}
                      <div className="flex items-center justify-between sm:justify-end gap-3 pt-3 sm:pt-0 border-t sm:border-t-0 border-slate-100">
                        <div className="sm:text-right">
                          <span className="text-[10px] uppercase font-bold text-slate-400 block sm:hidden">Payout Amount</span>
                          <span className="text-xl font-black text-[#0BAA4B]">
                            ₹{Number(sale.final_price || sale.estimated_price).toLocaleString('en-IN')}
                          </span>
                        </div>
                        <button
                          type="button"
                          className="px-4 py-2.5 rounded-xl bg-slate-900 group-hover:bg-[#0BAA4B] text-white text-xs font-bold shadow transition-all flex items-center gap-1 shrink-0"
                        >
                          <span>Track & Details</span>
                          <ChevronRight className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* ========================================================= */}
      {/* VIEW B: AMAZON-STYLE ORDER DETAILS & LIVE TRACKING SCREEN */}
      {/* ========================================================= */}
      {selectedSale && (
        <div className="space-y-6 animate-fade-in">
          
          {/* Amazon-style Status Header Card */}
          <div className="glass-panel rounded-3xl p-6 sm:p-7 shadow-sm border border-white/80 space-y-4">
            
            {/* Top row status */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-100">
              <div className="space-y-1">
                <span className="text-xs font-extrabold uppercase tracking-wider text-[#0BAA4B] block">
                  {selectedSale.status === 'PAYMENT_COMPLETED' ? '✓ Completed & Disbursed' :
                   selectedSale.status === 'CANCELLED' ? '✕ Order Cancelled' :
                   'Doorstep Pickup Scheduled'}
                </span>
                <h3 className="text-2xl font-black text-[#17251C]">
                  {selectedSale.status === 'PAYMENT_COMPLETED'
                    ? `Paid ₹${Number(selectedSale.final_price).toLocaleString('en-IN')}`
                    : selectedSale.status === 'CANCELLED'
                    ? 'Selling Order Cancelled'
                    : `${selectedSale.pickup_date || 'Today'} · ${selectedSale.pickup_slot || 'Doorstep Pickup'}`}
                </h3>
                <p className="text-xs text-slate-600">
                  {selectedSale.status === 'PAYMENT_COMPLETED'
                    ? `Payment credited to ${selectedSale.beneficiary_type === 'UPI' ? selectedSale.beneficiary_upi_id : selectedSale.beneficiary_account_no}`
                    : `Specialist assigned to collect device at ${selectedSale.pickup_city || 'your address'}`}
                </p>
              </div>

              {/* Action Buttons Header */}
              <div className="flex flex-wrap items-center gap-2">
                {isCancellable && (
                  <button
                    type="button"
                    onClick={() => setCancelModalOpen(true)}
                    className="px-3 py-2 rounded-xl text-xs font-bold text-rose-600 bg-rose-50 hover:bg-rose-100 border border-rose-200 transition flex items-center gap-1.5"
                  >
                    <XCircle className="w-3.5 h-3.5" />
                    Cancel Order
                  </button>
                )}
                {selectedSale.status === 'PAYMENT_COMPLETED' && (
                  <button
                    onClick={() => handleViewReceipt(selectedSale.sale_code)}
                    disabled={loadingReceipt}
                    className="px-4 py-2 rounded-xl text-xs font-bold bg-[#0BAA4B] hover:bg-[#087C38] text-white shadow transition flex items-center gap-1.5"
                  >
                    <FileText className="w-3.5 h-3.5" />
                    {loadingReceipt ? 'Loading...' : 'Download Invoice'}
                  </button>
                )}
              </div>
            </div>

            {/* Device Item Card (Amazon Screenshot 2 style) */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-2xl bg-white/60 border border-slate-100">
              <div className="flex items-center gap-4">
                <div className="w-16 h-16 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-center text-[#0BAA4B] shrink-0">
                  <Smartphone className="w-8 h-8" />
                </div>
                <div>
                  <h4 className="font-black text-slate-800 text-base">
                    {selectedSale.brand_name} {selectedSale.model_name}
                  </h4>
                  <p className="text-xs text-slate-500">
                    Storage: {selectedSale.variant_details?.storage || 'Standard'} {selectedSale.variant_details?.ram ? `· ${selectedSale.variant_details.ram} RAM` : ''}
                  </p>
                  <span className="text-sm font-black text-[#0BAA4B] block mt-0.5">
                    ₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              <div className="flex items-center gap-2 text-xs">
                <span className="font-mono bg-slate-100 px-3 py-1.5 rounded-lg text-slate-600 font-bold border border-slate-200">
                  #{selectedSale.sale_code}
                </span>
              </div>
            </div>

            {/* In-App Cash Handover Verification OTP Card (ONLY for Cash on Pickup / COD) */}
            {['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING'].includes(selectedSale.status) &&
             selectedSale.beneficiary_type === 'CASH' &&
             selectedSale.cash_handover_otp && (
              <div className="p-5 rounded-2xl bg-gradient-to-r from-emerald-50 to-teal-50 border-2 border-[#0BAA4B] text-center space-y-2">
                <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-100 text-[#0BAA4B] font-extrabold text-xs">
                  <ShieldCheck className="w-4 h-4" /> Cash Handover Verification
                </div>
                <p className="text-xs text-slate-600 max-w-md mx-auto">
                  Collect <strong className="text-slate-800">₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}</strong> in physical cash from the agent. Once counted, share this 4-digit code with the agent:
                </p>
                <div className="inline-block px-6 py-2 rounded-xl bg-white border border-emerald-300 shadow-sm">
                  <span className="font-mono text-3xl font-black tracking-widest text-[#0BAA4B]">
                    {selectedSale.cash_handover_otp || '----'}
                  </span>
                </div>
                <p className="text-[10px] text-slate-400 font-medium">
                  🔒 Do not share this code before receiving cash in your hand.
                </p>
              </div>
            )}

            {/* Online Transfer Info Card (For UPI & Bank Transfer) */}
            {['CUSTOMER_ACCEPTED', 'OWNERSHIP_TRANSFERRED', 'PAYMENT_PENDING'].includes(selectedSale.status) &&
             selectedSale.beneficiary_type !== 'CASH' && (
              <div className="p-4 rounded-2xl bg-blue-50 border border-blue-200 text-xs text-blue-900 flex items-start gap-3">
                <div className="p-2 rounded-xl bg-blue-100 text-blue-700 shrink-0">
                  <IndianRupee className="w-4 h-4" />
                </div>
                <div>
                  <h4 className="font-extrabold text-blue-950">
                    {selectedSale.beneficiary_type === 'BANK' ? 'Direct Bank Transfer (IMPS/NEFT)' : 'Instant Online UPI Transfer'}
                  </h4>
                  <p className="text-blue-800 text-[11px] mt-0.5 leading-relaxed">
                    Doorstep physical inspection verified. Super Admin payout desk will release <strong>₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}</strong> directly to your registered {selectedSale.beneficiary_type === 'BANK' ? 'Bank Account' : 'UPI ID'}.
                  </p>
                </div>
              </div>
            )}

            {/* Stepper Timeline (Amazon Screenshot 3 style) */}
            <div className="pt-2">
              <h5 className="text-xs font-black uppercase tracking-wider text-slate-400 mb-3 flex items-center gap-1.5">
                <Truck className="w-3.5 h-3.5 text-[#0BAA4B]" /> Live Pickup Journey
              </h5>

              <div className="space-y-4 relative pl-4 border-l-2 border-emerald-200 ml-3">
                {STEPS.map((s, idx) => {
                  const currentIdx = getStepIndex(selectedSale.status);
                  const isDone = currentIdx >= idx;
                  const isCurrent = currentIdx === idx;

                  return (
                    <div key={s.key} className="relative group">
                      {/* Stepper indicator circle */}
                      <div className={`absolute -left-[25px] top-0 w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold border-2 transition-all ${
                        isDone 
                          ? 'bg-[#0BAA4B] border-[#0BAA4B] text-white shadow-xs'
                          : 'bg-white border-slate-300 text-slate-400'
                      }`}>
                        {isDone ? '✓' : idx + 1}
                      </div>

                      <div className="pl-2">
                        <div className="flex items-center gap-2">
                          <span className={`text-xs font-extrabold ${
                            isCurrent ? 'text-[#0BAA4B]' : isDone ? 'text-slate-800' : 'text-slate-400'
                          }`}>
                            {s.label}
                          </span>
                          {isCurrent && (
                            <span className="text-[10px] font-bold bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full animate-pulse">
                              In Progress
                            </span>
                          )}
                        </div>
                        <p className="text-[11px] text-slate-500 mt-0.5">
                          {s.desc}
                        </p>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

          </div>

          {/* Amazon-style "Order Summary" Ledger Card */}
          <div className="glass-panel rounded-3xl p-6 sm:p-7 shadow-sm border border-white/80 space-y-4">
            <h4 className="text-sm font-black uppercase tracking-wider text-[#17251C]">
              Order Summary & Financial Ledger
            </h4>

            <div className="space-y-2 text-xs border-b border-slate-100 pb-4">
              <div className="flex justify-between text-slate-600">
                <span>Base Device Valuation:</span>
                <span className="font-bold text-slate-800">
                  ₹{Number(selectedSale.estimated_price).toLocaleString('en-IN')}
                </span>
              </div>
              {selectedSale.final_price && selectedSale.final_price !== selectedSale.estimated_price && (
                <div className="flex justify-between text-rose-600">
                  <span>Inspection Condition Adjustments:</span>
                  <span className="font-bold font-mono">
                    -₹{Number(selectedSale.estimated_price - selectedSale.final_price).toLocaleString('en-IN')}
                  </span>
                </div>
              )}
              <div className="flex justify-between text-slate-600">
                <span>Doorstep Inspection & Pickup:</span>
                <span className="font-bold text-emerald-600 uppercase text-[11px]">Free Service</span>
              </div>
            </div>

            {/* Grand Total */}
            <div className="flex justify-between items-center pt-1 text-sm">
              <span className="font-black text-slate-900">Final Payout Amount:</span>
              <span className="text-2xl font-black text-[#0BAA4B]">
                ₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
              </span>
            </div>

            {/* Payout Details & Bank Proof */}
            <div className={`p-4 rounded-2xl border text-xs space-y-2.5 ${selectedSale.payment || selectedSale.status === 'PAYMENT_COMPLETED' ? 'bg-emerald-50/70 border-emerald-300' : 'bg-slate-50 border-slate-200'}`}>
              <div className="flex items-center justify-between pb-1 border-b border-emerald-200/60">
                <span className="font-extrabold text-[#17251C] flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4 text-emerald-600" />
                  {selectedSale.payment || selectedSale.status === 'PAYMENT_COMPLETED' ? 'Payout Disbursed (Paid)' : 'Payout Destination'}
                </span>
                <span className="font-black text-emerald-700 text-sm">
                  ₹{Number(selectedSale.payment?.amount || selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
                </span>
              </div>

              <div className="flex items-center justify-between">
                <span className="text-slate-500">Payout Mode:</span>
                <strong className="text-slate-800 font-mono font-bold">{selectedSale.beneficiary_type || 'UPI'}</strong>
              </div>

              <div className="flex items-center justify-between">
                <span className="text-slate-500">Beneficiary UPI ID:</span>
                <div className="flex items-center gap-1.5">
                  <strong className="text-slate-900 font-mono font-bold">
                    {selectedSale.beneficiary_upi_id || (selectedSale.beneficiary_type === 'UPI' ? selectedSale.beneficiary_upi_id : selectedSale.beneficiary_account_no) || 'Not provided'}
                  </strong>
                  {selectedSale.beneficiary_upi_id && (
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(selectedSale.beneficiary_upi_id);
                        setCopiedKey('upi');
                        setTimeout(() => setCopiedKey(null), 2000);
                      }}
                      className="text-slate-400 hover:text-emerald-600 p-0.5 rounded transition"
                      title="Copy UPI ID"
                    >
                      {copiedKey === 'upi' ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                  )}
                </div>
              </div>

              {selectedSale.payment?.utr_number && (
                <div className="flex items-center justify-between pt-1 border-t border-emerald-200/50">
                  <span className="text-emerald-800 font-bold">Bank Reference (UTR):</span>
                  <div className="flex items-center gap-1.5">
                    <strong className="text-emerald-900 font-mono font-bold">{selectedSale.payment.utr_number}</strong>
                    <button
                      onClick={() => {
                        navigator.clipboard.writeText(selectedSale.payment.utr_number);
                        setCopiedKey('utr');
                        setTimeout(() => setCopiedKey(null), 2000);
                      }}
                      className="text-emerald-600 hover:text-emerald-800 p-0.5 rounded transition"
                      title="Copy UTR Number"
                    >
                      {copiedKey === 'utr' ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                  </div>
                </div>
              )}

              {/* Payout Proof Screenshot Preview */}
              {selectedSale.payment?.payment_proof_base64 && (
                <div className="pt-2 border-t border-emerald-200/60">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-emerald-900 font-bold text-[11px]">Official Bank Transfer Proof:</span>
                    <button
                      onClick={() => setZoomViewer({
                        images: [{ image_base64: selectedSale.payment.payment_proof_base64, label: `Bank Transfer Proof • UTR ${selectedSale.payment.utr_number || ''}` }],
                        initialIndex: 0
                      })}
                      className="text-[11px] font-bold text-emerald-700 hover:text-emerald-900 flex items-center gap-1 underline"
                    >
                      <ZoomIn className="w-3 h-3" /> View Fullscreen
                    </button>
                  </div>
                  <div
                    onClick={() => setZoomViewer({
                      images: [{ image_base64: selectedSale.payment.payment_proof_base64, label: `Bank Transfer Proof • UTR ${selectedSale.payment.utr_number || ''}` }],
                      initialIndex: 0
                    })}
                    className="relative rounded-xl overflow-hidden cursor-pointer group border border-emerald-300 max-h-48 bg-black/5"
                  >
                    <img
                      src={selectedSale.payment.payment_proof_base64}
                      alt="Bank Transfer Proof"
                      className="w-full h-40 object-cover object-top group-hover:scale-105 transition duration-200"
                    />
                    <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 transition flex items-center justify-center text-white font-bold text-xs gap-1.5">
                      <ZoomIn className="w-4 h-4" /> Tap to Zoom Receipt
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Action Banner: Final Offer Acceptance */}
          {selectedSale.status === 'FINAL_OFFER_SENT' && (
            <div className="glass-card bg-amber-50/80 border-2 border-amber-300 rounded-2xl p-6 space-y-4">
              <div className="flex items-start gap-3">
                <AlertCircle className="w-6 h-6 text-amber-600 shrink-0 mt-0.5" />
                <div>
                  <h4 className="font-extrabold text-amber-900 text-base">
                    {selectedSale.admin_notes?.includes('Admin updated final price')
                      ? 'Admin Revised Final Offer: Action Required'
                      : 'Physical Inspection Completed: Action Required'}
                  </h4>
                  <p className="text-xs text-amber-800 mt-1">
                    {selectedSale.admin_notes?.includes('Admin updated final price')
                      ? 'Our admin team updated your final buyback offer to '
                      : 'Our field agent tested your device and offered '}
                    <strong className="text-sm font-black text-[#17251C]">
                      ₹{Number(selectedSale.final_price).toLocaleString('en-IN')}
                    </strong>. Accept to receive instant payment directly to your account.
                  </p>
                  {selectedSale.admin_notes && (
                    <p className="text-[11px] text-amber-900 bg-white/70 border border-amber-200 rounded-lg px-2.5 py-1.5 mt-2 font-medium whitespace-pre-line">
                      {selectedSale.admin_notes}
                    </p>
                  )}
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
                  Decline Offer
                </button>
              </div>
            </div>
          )}

          {/* Doorstep Address Card */}
          <div className="glass-panel rounded-3xl p-6 shadow-sm border border-white/80 text-xs space-y-2">
            <h5 className="font-bold text-[#17251C] flex items-center gap-2">
              <MapPin className="w-4 h-4 text-[#0BAA4B]" /> Doorstep Pickup Location
            </h5>
            <p className="text-slate-600">
              {selectedSale.pickup_address}, {selectedSale.pickup_city} - {selectedSale.pickup_pincode}
            </p>
            <p className="text-slate-500">
              Assigned Field Specialist: <strong className="text-slate-800">{selectedSale.assigned_agent_name || 'Assigning soon...'}</strong>
            </p>
          </div>

        </div>
      )}

      {/* Official Printable Receipt Modal */}
      {receiptData && (
        <ReceiptModal 
          receiptData={receiptData} 
          onClose={() => setReceiptData(null)} 
        />
      )}

      {/* Cancel Order Confirmation Modal */}
      {cancelModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
          <div className="bg-white rounded-3xl max-w-md w-full p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2 text-rose-600 font-black text-base">
                <XCircle className="w-5 h-5" />
                Cancel Selling Order
              </div>
              <button 
                onClick={() => setCancelModalOpen(false)} 
                className="text-slate-400 hover:text-slate-600 p-1 text-sm font-bold"
              >
                ✕
              </button>
            </div>

            <p className="text-xs text-slate-600 leading-relaxed">
              Are you sure you want to cancel the doorstep pickup for your <strong className="text-slate-900">{selectedSale?.brand_name} {selectedSale?.model_name}</strong>?
            </p>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Reason for cancellation (optional):</label>
              <select 
                value={cancelReason}
                onChange={(e) => setCancelReason(e.target.value)}
                className="w-full text-xs border border-slate-200 rounded-xl p-2.5 bg-slate-50 focus:outline-none focus:ring-2 focus:ring-emerald-500 font-medium"
              >
                <option value="">Select a reason...</option>
                <option value="Changed my mind">Changed my mind</option>
                <option value="Price didn't match expectation">Price didn't match expectation</option>
                <option value="Decided to keep or gift device">Decided to keep or gift device</option>
                <option value="Device repaired or sold elsewhere">Device repaired or sold elsewhere</option>
                <option value="Wrong details entered">Wrong details entered</option>
                <option value="Other">Other</option>
              </select>
            </div>

            <div className="flex gap-2.5 pt-2">
              <button
                type="button"
                onClick={() => setCancelModalOpen(false)}
                className="flex-1 py-2.5 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 hover:bg-slate-50 transition"
              >
                Keep Order
              </button>
              <button
                type="button"
                disabled={cancelling}
                onClick={handleCancelOrder}
                className="flex-1 py-2.5 bg-rose-600 hover:bg-rose-700 text-white rounded-xl text-xs font-bold shadow-md transition disabled:opacity-50"
              >
                {cancelling ? 'Cancelling...' : 'Confirm Cancellation'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Zoomable Image Lightbox Modal */}
      {zoomViewer && (
        <ImageZoomModal
          images={zoomViewer.images}
          initialIndex={zoomViewer.initialIndex || 0}
          onClose={() => setZoomViewer(null)}
        />
      )}

    </div>
  );
}