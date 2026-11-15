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
      // Load sample order by default so the user sees a rich tracking interface right away!
      handleSearch('PHN-2026-001');
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
      
      {/* Search Header */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm mb-8">
        <h2 className="text-xl font-extrabold text-slate-900 mb-1">
          Track Your Phone Sale Status
        </h2>
        <p className="text-xs text-slate-500 mb-4">
          Enter your Sale Code (e.g. <span className="font-mono font-bold text-slate-700">PHN-2026-001</span> or <span className="font-mono font-bold text-slate-700">PHN-2026-PAID-01</span>) or 10-digit mobile number:
        </p>

        <form onSubmit={(e) => { e.preventDefault(); handleSearch(); }} className="flex gap-2 max-w-xl">
          <div className="relative flex-1">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3.5" />
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder="e.g. PHN-2026-001 or 9870011223"
              className="w-full pl-9 pr-3 py-2.5 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500 font-mono"
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="bg-slate-900 hover:bg-black text-white font-bold px-6 py-2.5 rounded-xl text-sm transition"
          >
            {loading ? 'Searching...' : 'Track'}
          </button>
        </form>

        {errorMsg && (
          <div className="mt-4 p-3 bg-rose-50 border border-rose-200 rounded-xl text-rose-700 text-xs font-semibold flex items-center gap-2">
            <AlertCircle className="w-4 h-4 text-rose-500 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}
      </div>

      {/* Results View */}
      {selectedSale ? (
        <div className="space-y-6 animate-fade-in">
          
          {/* Main Status Card */}
          <div className="bg-white rounded-3xl border border-slate-200 p-6 sm:p-8 shadow-sm space-y-6">
            
            {/* Top row */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-100 pb-5">
              <div>
                <div className="flex items-center gap-2">
                  <span className="font-mono text-xs font-bold bg-slate-100 text-slate-800 px-2.5 py-1 rounded-md">
                    {selectedSale.sale_code}
                  </span>
                  <span className={`text-xs font-bold px-2.5 py-1 rounded-full ${
                    selectedSale.status === 'PAYMENT_COMPLETED' 
                      ? 'bg-emerald-100 text-emerald-800 border border-emerald-200'
                      : selectedSale.status === 'FINAL_OFFER_SENT'
                      ? 'bg-amber-100 text-amber-800 border border-amber-200 animate-pulse'
                      : 'bg-sky-100 text-sky-800'
                  }`}>
                    ● {selectedSale.status.replace(/_/g, ' ')}
                  </span>
                </div>
                <h3 className="text-2xl font-black text-slate-900 mt-2">
                  {selectedSale.brand_name} {selectedSale.model_name}
                </h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  Variant: {selectedSale.variant_details?.ram ? `${selectedSale.variant_details.ram} / ` : ''}{selectedSale.variant_details?.storage}
                </p>
              </div>

              <div className="text-left sm:text-right bg-slate-50 p-4 rounded-2xl border border-slate-200 sm:border-0 sm:bg-transparent sm:p-0">
                <span className="text-xs text-slate-400 font-medium block">
                  {selectedSale.final_price ? 'Final Approved Offer:' : 'Estimated Offer:'}
                </span>
                <span className="text-3xl font-black text-emerald-600">
                  ₹{Number(selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
                </span>
                {selectedSale.final_price && selectedSale.final_price !== selectedSale.estimated_price && (
                  <span className="text-xs text-slate-400 line-through block mt-0.5">
                    Est: ₹{Number(selectedSale.estimated_price).toLocaleString('en-IN')}
                  </span>
                )}
              </div>
            </div>

            {/* Visual Stepper */}
            <div className="py-2">
              <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                {STEPS.map((s, idx) => {
                  const currentIdx = getStepIndex(selectedSale.status);
                  const isDone = currentIdx >= idx;
                  const isCurrent = currentIdx === idx;
                  return (
                    <div 
                      key={s.key} 
                      className={`p-3 rounded-xl border text-center transition ${
                        isCurrent
                          ? 'bg-emerald-50 border-emerald-500 text-emerald-900 ring-2 ring-emerald-500/20'
                          : isDone
                          ? 'bg-emerald-50/40 border-emerald-200 text-emerald-800'
                          : 'bg-slate-50 border-slate-200 text-slate-400'
                      }`}
                    >
                      <div className="flex items-center justify-center mb-1">
                        {isDone ? (
                          <CheckCircle2 className="w-4 h-4 text-emerald-600" />
                        ) : (
                          <div className="w-4 h-4 rounded-full border border-slate-300" />
                        )}
                      </div>
                      <span className="text-xs font-bold block">{s.label}</span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* ACTION BANNER: FINAL OFFER ACCEPTANCE */}
            {selectedSale.status === 'FINAL_OFFER_SENT' && (
              <div className="bg-gradient-to-r from-amber-50 to-orange-50 border-2 border-amber-300 rounded-2xl p-6 space-y-4">
                <div className="flex items-start gap-3">
                  <AlertCircle className="w-6 h-6 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <h4 className="font-extrabold text-amber-900 text-base">
                      Physical Inspection Completed: Action Required
                    </h4>
                    <p className="text-xs text-amber-800 mt-1">
                      Our field team inspected your device and calculated a final offer of{' '}
                      <strong className="text-sm font-black text-slate-900">
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
                    className="flex-1 bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold py-3 rounded-xl text-sm shadow transition flex items-center justify-center gap-2"
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
              <div className="bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-2xl p-6 shadow-lg space-y-3">
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
                    className="w-full sm:w-auto bg-white hover:bg-slate-100 text-slate-900 font-extrabold px-6 py-2.5 rounded-xl text-xs shadow transition flex items-center justify-center gap-2"
                  >
                    <FileText className="w-4 h-4 text-emerald-600" />
                    {loadingReceipt ? 'Loading Receipt...' : 'View Payment Proof & Official Receipt'}
                  </button>
                </div>
              </div>
            )}

            {/* Information Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs pt-2">
              
              {/* Pickup & Agent Details */}
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200 space-y-3">
                <h5 className="font-bold text-slate-900 flex items-center gap-2 text-xs">
                  <MapPin className="w-4 h-4 text-emerald-600" /> Doorstep Collection Details
                </h5>
                <div className="space-y-1.5 text-slate-600">
                  <p><span className="text-slate-400">Address:</span> {selectedSale.pickup_address}, {selectedSale.pickup_city} - {selectedSale.pickup_pincode}</p>
                  <p><span className="text-slate-400">Time Slot:</span> {selectedSale.pickup_slot}</p>
                  <p><span className="text-slate-400">Assigned Agent:</span> <strong className="text-slate-800">{selectedSale.assigned_agent_name || 'Assigning field staff...'}</strong></p>
                </div>
              </div>

              {/* Payout Destination */}
              <div className="bg-slate-50 p-5 rounded-2xl border border-slate-200 space-y-3">
                <h5 className="font-bold text-slate-900 flex items-center gap-2 text-xs">
                  <IndianRupee className="w-4 h-4 text-emerald-600" /> Payout Destination
                </h5>
                <div className="space-y-1.5 text-slate-600">
                  <p><span className="text-slate-400">Payee Name:</span> {selectedSale.beneficiary_name}</p>
                  {selectedSale.beneficiary_type === 'UPI' ? (
                    <p><span className="text-slate-400">UPI ID:</span> <strong className="font-mono text-slate-800">{selectedSale.beneficiary_upi_id}</strong></p>
                  ) : (
                    <p><span className="text-slate-400">Bank Details:</span> <strong className="font-mono text-slate-800">{selectedSale.beneficiary_account_no} ({selectedSale.beneficiary_ifsc})</strong></p>
                  )}
                  <p><span className="text-slate-400">Device IMEI:</span> <strong className="font-mono text-slate-800">{selectedSale.imei_number || 'Verifying during pickup'}</strong></p>
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
