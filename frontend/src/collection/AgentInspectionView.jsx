import React, { useState, useEffect, useRef } from 'react';
import { 
  Smartphone, ShieldCheck, Camera, Check, AlertCircle, 
  MapPin, Clock, ArrowRight, UserCheck, Lock, Upload, 
  CheckCircle2, RefreshCw, X, FileText, ChevronDown, ChevronUp, AlertTriangle
} from 'lucide-react';
import { api } from '../services/api';
import { fileToBase64 } from '../utils/imageCompressor';

export default function AgentInspectionView({ currentUser }) {
  const [assignedSales, setAssignedSales] = useState([]);
  const [selectedSale, setSelectedSale] = useState(null);
  const [saleDetails, setSaleDetails] = useState(null);
  const [loading, setLoading] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);

  // Inspection form state
  const [switchesOn, setSwitchesOn] = useState(true);
  const [screenWorking, setScreenWorking] = useState(true);
  const [screenGlassBroken, setScreenGlassBroken] = useState(false);
  const [touchWorking, setTouchWorking] = useState(true);
  const [cameraWorking, setCameraWorking] = useState(true);
  const [batteryHealthy, setBatteryHealthy] = useState(true);
  const [bodyCondition, setBodyCondition] = useState('GOOD');
  
  // Security locks & IMEI
  const [cloudLocksRemoved, setCloudLocksRemoved] = useState(true);
  const [verifiedImei, setVerifiedImei] = useState('');
  const [customerIdVerified, setCustomerIdVerified] = useState(true);

  // Photos (Base64)
  const [photos, setPhotos] = useState([]);
  const [suggestedFinalPrice, setSuggestedFinalPrice] = useState('');
  const [inspectorNotes, setInspectorNotes] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [feedback, setFeedback] = useState(null); // { type: 'success' | 'error', message: string, status: string }
  const [formError, setFormError] = useState('');
  const [showCustomerAnswers, setShowCustomerAnswers] = useState(true);

  const feedbackRef = useRef(null);

  useEffect(() => {
    loadAssignedSales();
  }, []);

  const loadAssignedSales = async (preserveSelectedId = null) => {
    setLoading(true);
    try {
      const data = await api.getSales();
      // Auto-prioritize in Indian Standard Time (IST): Overdue missed pickups first
      const sorted = [...data].sort((a, b) => {
        if (a.is_overdue && !b.is_overdue) return -1;
        if (!a.is_overdue && b.is_overdue) return 1;
        return 0;
      });
      setAssignedSales(sorted);
      if (sorted.length > 0) {
        const target = preserveSelectedId 
          ? sorted.find(s => s.id === preserveSelectedId) || sorted[0]
          : (selectedSale ? sorted.find(s => s.id === selectedSale.id) || sorted[0] : sorted[0]);
        selectOrderForInspection(target);
      } else {
        setSelectedSale(null);
        setSaleDetails(null);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const selectOrderForInspection = async (sale) => {
    if (!sale) return;
    setSelectedSale(sale);
    setSuggestedFinalPrice(sale.final_price || sale.estimated_price);
    setVerifiedImei(sale.imei_number || '');
    setFeedback(null);
    setPhotos([]);

    // Fetch full order details including customer's self-reported conditions & existing inspection
    setLoadingDetail(true);
    try {
      const detail = await (api.getSaleByCode ? api.getSaleByCode(sale.sale_code) : api.getSaleDetail(sale.sale_code || sale.id));
      setSaleDetails(detail);
      
      if (detail.inspection) {
        // Pre-populate with existing inspection data
        const insp = detail.inspection;
        setSwitchesOn(Boolean(insp.switches_on));
        setScreenWorking(Boolean(insp.screen_working));
        setScreenGlassBroken(Boolean(insp.screen_glass_broken));
        setTouchWorking(Boolean(insp.touch_working));
        setCameraWorking(Boolean(insp.camera_working));
        setBatteryHealthy(Boolean(insp.battery_healthy));
        setBodyCondition(insp.body_condition || 'GOOD');
        setCloudLocksRemoved(Boolean(insp.cloud_locks_removed));
        setCustomerIdVerified(Boolean(insp.customer_id_verified));
        if (insp.verified_imei) setVerifiedImei(insp.verified_imei);
        setSuggestedFinalPrice(detail.final_price || insp.suggested_final_price || sale.estimated_price);
        if (insp.inspector_notes) setInspectorNotes(insp.inspector_notes);
        if (insp.photos && Array.isArray(insp.photos)) {
          setPhotos(insp.photos.map(p => ({ label: p.label, image_base64: p.image_base64 })));
        }
      } else {
        // Reset to default pass state
        setSwitchesOn(true);
        setScreenWorking(true);
        setScreenGlassBroken(false);
        setTouchWorking(true);
        setCameraWorking(true);
        setBatteryHealthy(true);
        setBodyCondition('GOOD');
        setCloudLocksRemoved(true);
        setCustomerIdVerified(true);
        setInspectorNotes('');
        setPhotos([]);
      }
    } catch (err) {
      console.error("Error loading order detail:", err);
    } finally {
      setLoadingDetail(false);
    }
  };

  const handlePhotoUpload = async (e, label) => {
    const file = e.target.files[0];
    if (!file) return;

    try {
      const base64 = await fileToBase64(file, 1000, 0.7);
      setPhotos(prev => [...prev, { label, image_base64: base64 }]);
    } catch (err) {
      alert("Failed to process photo: " + err.message);
    }
    // Reset file input
    e.target.value = '';
  };

  const removePhoto = (index) => {
    setPhotos(prev => prev.filter((_, idx) => idx !== index));
  };

  const handleSubmitInspection = async (e) => {
    e.preventDefault();
    if (!selectedSale) return;
    setFormError('');

    if (!cloudLocksRemoved) {
      setFormError("CRITICAL REQUIREMENT: Apple iCloud or Google FRP account MUST be signed out and device factory reset before proceeding!");
      setTimeout(() => feedbackRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 50);
      return;
    }

    if (!verifiedImei.trim() || verifiedImei.trim().length < 8) {
      setFormError("Please enter the verified 15-digit device IMEI number (dial *#06# on phone keypad).");
      setTimeout(() => feedbackRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 50);
      return;
    }

    if (!suggestedFinalPrice || Number(suggestedFinalPrice) <= 0) {
      setFormError("Please enter a valid final buyback price.");
      setTimeout(() => feedbackRef.current?.scrollIntoView({ behavior: 'smooth', block: 'center' }), 50);
      return;
    }

    setSubmitting(true);
    setFeedback(null);

    try {
      const payload = {
        sale_id: selectedSale.id,
        switches_on: switchesOn,
        screen_working: screenWorking,
        screen_glass_broken: screenGlassBroken,
        touch_working: touchWorking,
        camera_working: cameraWorking,
        battery_healthy: batteryHealthy,
        body_condition: bodyCondition,
        cloud_locks_removed: cloudLocksRemoved,
        imei_verified: true,
        verified_imei: verifiedImei.trim(),
        customer_id_verified: customerIdVerified,
        suggested_final_price: suggestedFinalPrice,
        inspector_notes: inspectorNotes,
        photos: photos,
      };

      const res = await api.recordInspection(payload);
      const newStatus = res.sale_status || (
        Number(suggestedFinalPrice) === Number(selectedSale.estimated_price)
          ? 'OWNERSHIP_TRANSFERRED' 
          : 'FINAL_OFFER_SENT'
      );

      // Instant local reflection in state
      const updatedSale = {
        ...selectedSale,
        status: newStatus,
        final_price: suggestedFinalPrice,
        imei_number: verifiedImei.trim(),
        has_inspection: true,
      };

      setSelectedSale(updatedSale);
      setAssignedSales(prev => prev.map(s => s.id === selectedSale.id ? { ...s, ...updatedSale } : s));

      setFeedback({
        type: 'success',
        status: newStatus,
        message: newStatus === 'OWNERSHIP_TRANSFERRED'
          ? `✓ Inspection Recorded! Price matches estimate (₹${Number(suggestedFinalPrice).toLocaleString('en-IN')}). Device handover complete · Ownership transferred to 1103 RECELL. Ready for Admin Payout Disbursal.`
          : `✓ Inspection Submitted! Revised offer of ₹${Number(suggestedFinalPrice).toLocaleString('en-IN')} sent to customer. Status updated to FINAL OFFER SENT.`
      });

      // Smooth scroll to feedback for clear mobile visibility
      setTimeout(() => {
        if (feedbackRef.current) {
          feedbackRef.current.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
      }, 100);

      // Silently refresh list from server in background
      api.getSales().then(freshData => {
        if (freshData) setAssignedSales(freshData);
      }).catch(console.error);

    } catch (err) {
      setFeedback({
        type: 'error',
        message: err.message || 'Failed to submit inspection. Please check device data and retry.'
      });
    } finally {
      setSubmitting(false);
    }
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'OWNERSHIP_TRANSFERRED':
        return <span className="text-[10px] font-extrabold uppercase bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full inline-flex items-center gap-1">✓ Handover Done</span>;
      case 'FINAL_OFFER_SENT':
        return <span className="text-[10px] font-extrabold uppercase bg-amber-100 text-amber-800 px-2 py-0.5 rounded-full inline-flex items-center gap-1">⏳ Offer Sent</span>;
      case 'PAYMENT_PROCESSED':
        return <span className="text-[10px] font-extrabold uppercase bg-purple-100 text-purple-800 px-2 py-0.5 rounded-full inline-flex items-center gap-1">💰 Paid</span>;
      case 'PICKUP_ASSIGNED':
        return <span className="text-[10px] font-extrabold uppercase bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full inline-flex items-center gap-1">🛵 Assigned</span>;
      case 'FINAL_OFFER_REJECTED':
        return <span className="text-[10px] font-extrabold uppercase bg-rose-100 text-rose-800 px-2 py-0.5 rounded-full inline-flex items-center gap-1">✕ Rejected</span>;
      default:
        return <span className="text-[10px] font-extrabold uppercase bg-slate-100 text-slate-700 px-2 py-0.5 rounded-full">{status?.replace(/_/g, ' ') || 'Pending'}</span>;
    }
  };

  return (
    <div className="max-w-5xl mx-auto px-2 sm:px-4 py-3 sm:py-6 space-y-3 sm:space-y-6 pb-32 md:pb-12">
      
      {/* Top Header Card */}
      <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-3.5 sm:p-5 rounded-2xl sm:rounded-3xl shadow-lg flex items-center justify-between">
        <div className="min-w-0 pr-2">
          <div className="flex items-center gap-1.5 flex-wrap">
            <span className="text-[9px] sm:text-[10px] font-black uppercase tracking-wider text-emerald-200 bg-white/10 border border-white/20 px-2 py-0.5 rounded-lg">
              Dolly Field Agent
            </span>
            <span className="text-[9px] sm:text-[10px] text-emerald-100">
              {assignedSales.length} {assignedSales.length === 1 ? 'Pickup' : 'Pickups'} In Queue
            </span>
          </div>
          <h2 className="text-base sm:text-2xl font-black mt-1 truncate">
            Doorstep Device Inspection & Handover
          </h2>
          <p className="text-[10px] sm:text-xs text-[#E8F8ED] truncate">
            Assigned Agent: <strong className="text-white">{currentUser?.full_name || 'Pickup Specialist'}</strong>
          </p>
        </div>

        <button
          onClick={() => loadAssignedSales(selectedSale?.id)}
          disabled={loading}
          title="Refresh assigned queue"
          className="p-2 sm:p-2.5 rounded-xl bg-white/15 hover:bg-white/25 border border-white/20 text-white transition shrink-0 active:scale-95"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin text-emerald-300' : ''}`} />
        </button>
      </div>

      {/* MOBILE QUEUE SELECTOR (Horizontal scroll on mobile <md) */}
      <div className="block md:hidden">
        <div className="flex items-center justify-between mb-1.5 px-0.5">
          <span className="text-xs font-black text-slate-900 flex items-center gap-1">
            <span>🛵 Your Assigned Pickups:</span>
            <span className="bg-[#E8F8ED] text-[#087C38] text-[10px] font-extrabold px-1.5 py-0.2 rounded-full">
              {assignedSales.length}
            </span>
          </span>
          <span className="text-[10px] text-slate-500">Tap card to inspect</span>
        </div>

        <div className="flex gap-2 overflow-x-auto pb-2 pt-0.5 scrollbar-none snap-x -mx-1 px-1">
          {assignedSales.map((s) => {
            const isSelected = selectedSale?.id === s.id;
            return (
              <div
                key={s.id}
                onClick={() => selectOrderForInspection(s)}
                className={`snap-start shrink-0 w-[240px] p-2.5 rounded-2xl border transition text-left cursor-pointer active:scale-98 ${
                  isSelected
                    ? 'bg-[#E8F8ED]/90 border-2 border-[#0BAA4B] shadow-md ring-2 ring-[#0BAA4B]/20'
                    : 'glass-card'
                }`}
              >
                <div className="flex justify-between items-center mb-1">
                  <span className="font-mono text-[10px] font-black bg-white/80 text-[#17251C] px-1.5 py-0.5 rounded border border-white">
                    {s.sale_code}
                  </span>
                  {getStatusBadge(s.status)}
                </div>
                <h5 className="font-extrabold text-[#17251C] text-xs truncate">
                  {s.brand_name} {s.model_name}
                </h5>
                <div className="flex justify-between items-center text-[11px] mt-1 text-[#7B8980]">
                  <span className="truncate max-w-[120px]">{s.customer_name}</span>
                  <span className="font-black text-[#0BAA4B]">₹{Number(s.final_price || s.estimated_price).toLocaleString('en-IN')}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Main Grid: Left Queue on Desktop, Right Inspection Form */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 sm:gap-6">
        
        {/* DESKTOP PICKUP QUEUE (Hidden on mobile, visible on md+) */}
        <div className="hidden md:block space-y-3">
          <div className="flex justify-between items-center">
            <h4 className="font-black text-[#17251C] text-sm flex items-center gap-1.5">
              <span>🛵 Assigned Pickups</span>
              <span className="bg-[#E8F8ED] text-[#087C38] text-[10px] font-extrabold px-1.5 py-0.5 rounded-full border border-[#0BAA4B]/20">
                {assignedSales.length}
              </span>
            </h4>
          </div>
          
          <div className="space-y-2 max-h-[750px] overflow-y-auto pr-1">
            {assignedSales.map((s) => {
              const isSelected = selectedSale?.id === s.id;
              return (
                <div
                  key={s.id}
                  onClick={() => selectOrderForInspection(s)}
                  className={`cursor-pointer p-3 rounded-2xl border transition ${
                    isSelected
                      ? 'bg-[#E8F8ED]/90 border-2 border-[#0BAA4B] shadow-sm ring-2 ring-[#0BAA4B]/20'
                      : s.is_overdue
                      ? 'bg-rose-50/70 border-rose-300 hover:border-rose-400'
                      : 'glass-card glass-card-hover'
                  }`}
                >
                  <div className="flex justify-between items-start mb-1 gap-1">
                    <span className="font-mono text-[10px] font-bold bg-slate-100 text-slate-800 px-1.5 py-0.5 rounded">
                      {s.sale_code}
                    </span>
                    {s.is_overdue ? (
                      <span className="text-[9px] font-black uppercase tracking-wider bg-rose-100 text-rose-700 px-2 py-0.5 rounded-full border border-rose-300 animate-pulse">
                        ⚠️ Overdue (IST)
                      </span>
                    ) : (
                      getStatusBadge(s.status)
                    )}
                  </div>
                  <h5 className="font-bold text-slate-900 text-xs mt-1">
                    {s.brand_name} {s.model_name}
                  </h5>
                  <p className="text-[11px] text-slate-500 truncate mt-0.5">{s.customer_name} · {s.pickup_city}</p>
                  {s.pickup_slot && (
                    <p className={`text-[10px] font-bold mt-1 ${s.is_overdue ? 'text-rose-600' : 'text-slate-500'}`}>
                      🕒 {s.pickup_date ? `${s.pickup_date} · ` : ''}{s.pickup_slot} (IST)
                    </p>
                  )}
                  <div className="flex justify-between items-center text-[11px] mt-1.5 pt-1.5 border-t border-slate-100">
                    <span className="text-slate-400">Offer:</span>
                    <span className="font-black text-emerald-700">
                      ₹{Number(s.final_price || s.estimated_price).toLocaleString('en-IN')}
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* ACTIVE INSPECTION FORM */}
        {selectedSale ? (
          <form 
            onSubmit={handleSubmitInspection} 
            className="md:col-span-2 bg-white border border-slate-200 rounded-2xl sm:rounded-3xl p-3 sm:p-6 shadow-sm space-y-4 sm:space-y-6 text-xs"
          >
            
            {/* Device Overview Banner */}
            <div className="bg-slate-50 border border-slate-200 rounded-2xl p-3 sm:p-4 space-y-2">
              <div className="flex justify-between items-start gap-2">
                <div className="min-w-0">
                  <div className="flex items-center gap-1.5 flex-wrap">
                    <span className="font-mono text-[10px] font-black bg-slate-900 text-white px-2 py-0.5 rounded">
                      {selectedSale.sale_code}
                    </span>
                    {getStatusBadge(selectedSale.status)}
                  </div>
                  <h3 className="text-base sm:text-xl font-black text-slate-900 mt-1 truncate">
                    {selectedSale.brand_name} {selectedSale.model_name}
                  </h3>
                  <p className="text-slate-500 text-[11px] sm:text-xs">
                    Storage: <strong className="text-slate-800">{selectedSale.storage || selectedSale.variant_details?.storage || 'Standard'}</strong>
                  </p>
                </div>

                <div className="text-right shrink-0">
                  <span className="text-[9px] sm:text-[10px] text-slate-400 uppercase font-bold block">Original Estimate</span>
                  <span className="text-base sm:text-2xl font-black text-emerald-600">
                    ₹{Number(selectedSale.estimated_price).toLocaleString('en-IN')}
                  </span>
                </div>
              </div>

              {/* Customer Contact & Address */}
              <div className="pt-2 border-t border-slate-200/80 grid grid-cols-1 sm:grid-cols-2 gap-1.5 text-[11px] text-slate-600">
                <div className="flex items-center gap-1.5 truncate">
                  <span className="font-bold text-slate-800">Customer:</span>
                  <span className="truncate">{selectedSale.customer_name} ({selectedSale.customer_phone})</span>
                </div>
                <div className="flex items-center gap-1.5 truncate">
                  <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                  <span className="truncate">{selectedSale.pickup_address}, {selectedSale.pickup_city}</span>
                </div>
              </div>
            </div>

            {/* Customer Self-Reported Conditions (Expandable) */}
            {saleDetails?.answers && saleDetails.answers.length > 0 && (
              <div className="border border-blue-200 bg-blue-50/60 rounded-2xl p-3">
                <div 
                  onClick={() => setShowCustomerAnswers(!showCustomerAnswers)}
                  className="flex justify-between items-center cursor-pointer select-none"
                >
                  <span className="font-extrabold text-blue-900 text-[11px] sm:text-xs flex items-center gap-1.5">
                    <FileText className="w-3.5 h-3.5 text-blue-600" />
                    Customer's Self-Reported Valuation Answers ({saleDetails.answers.length})
                  </span>
                  <button type="button" className="text-blue-700">
                    {showCustomerAnswers ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
                  </button>
                </div>

                {showCustomerAnswers && (
                  <div className="mt-2.5 pt-2 border-t border-blue-200/60 grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                    {saleDetails.answers.map((ans, idx) => (
                      <div key={idx} className="bg-white/80 border border-blue-100 rounded-lg p-1.5 px-2 text-[10px] flex justify-between items-center">
                        <span className="text-slate-700 truncate mr-2 font-medium">
                          <strong className="text-blue-950 font-bold">{ans.category_name}:</strong> {ans.option_title}
                        </span>
                        {Number(ans.deduction_applied) > 0 ? (
                          <span className="text-rose-600 font-extrabold shrink-0">-₹{Number(ans.deduction_applied).toLocaleString('en-IN')}</span>
                        ) : (
                          <span className="text-emerald-700 font-bold shrink-0">✓ Clean</span>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            )}

            {/* STEP 1: Hardware & Functional Checklist */}
            <div className="space-y-2.5">
              <div className="flex justify-between items-center">
                <h4 className="font-extrabold text-slate-900 text-xs sm:text-sm flex items-center gap-1.5">
                  <Smartphone className="w-4 h-4 text-emerald-600" /> 1. Functional Verification Checklist
                </h4>
                <span className="text-[10px] text-slate-400">Verify in person</span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                <label className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 cursor-pointer transition select-none">
                  <input
                    type="checkbox"
                    checked={switchesOn}
                    onChange={(e) => setSwitchesOn(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-slate-800 block text-xs">Phone Powers On</span>
                    <span className="text-[10px] text-slate-500">Boots to OS without looping</span>
                  </div>
                </label>

                <label className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 cursor-pointer transition select-none">
                  <input
                    type="checkbox"
                    checked={screenWorking}
                    onChange={(e) => setScreenWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-slate-800 block text-xs">Display Clean & Intact</span>
                    <span className="text-[10px] text-slate-500">No lines, black dots or tint</span>
                  </div>
                </label>

                <label className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 cursor-pointer transition select-none">
                  <input
                    type="checkbox"
                    checked={touchWorking}
                    onChange={(e) => setTouchWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-slate-800 block text-xs">Touchscreen Fully Responsive</span>
                    <span className="text-[10px] text-slate-500">Smooth swipe across edges</span>
                  </div>
                </label>

                <label className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 cursor-pointer transition select-none">
                  <input
                    type="checkbox"
                    checked={cameraWorking}
                    onChange={(e) => setCameraWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-slate-800 block text-xs">Cameras & Sensors OK</span>
                    <span className="text-[10px] text-slate-500">Front, back & flash functional</span>
                  </div>
                </label>

                <label className="flex items-center gap-2.5 p-2.5 rounded-xl border border-slate-200 bg-slate-50 hover:bg-slate-100 cursor-pointer transition select-none">
                  <input
                    type="checkbox"
                    checked={batteryHealthy}
                    onChange={(e) => setBatteryHealthy(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-slate-800 block text-xs">Battery Healthy (&gt;80%)</span>
                    <span className="text-[10px] text-slate-500">Holds charge, no swelling</span>
                  </div>
                </label>

                <label className={`flex items-center gap-2.5 p-2.5 rounded-xl border cursor-pointer transition select-none ${
                  screenGlassBroken ? 'border-rose-300 bg-rose-50' : 'border-slate-200 bg-slate-50 hover:bg-slate-100'
                }`}>
                  <input
                    type="checkbox"
                    checked={screenGlassBroken}
                    onChange={(e) => setScreenGlassBroken(e.target.checked)}
                    className="w-4 h-4 text-rose-600 rounded focus:ring-rose-500"
                  />
                  <div className="leading-tight">
                    <span className="font-bold text-rose-800 block text-xs">Screen Glass Cracked?</span>
                    <span className="text-[10px] text-rose-600">Physical hairline or web crack</span>
                  </div>
                </label>
              </div>

              {/* Body Cosmetic Condition */}
              <div className="pt-1">
                <label className="block font-bold text-slate-700 mb-1 text-xs">Body & Frame Cosmetic Condition</label>
                <select
                  value={bodyCondition}
                  onChange={(e) => setBodyCondition(e.target.value)}
                  className="w-full p-2.5 border border-slate-300 rounded-xl bg-white font-medium text-xs focus:ring-2 focus:ring-emerald-500 focus:outline-none"
                >
                  <option value="FLAWLESS">Flawless (No scratches, Like New)</option>
                  <option value="GOOD">Good (Light micro-scratches)</option>
                  <option value="FAIR">Fair (Visible scuffs / small dents)</option>
                  <option value="HEAVY_WEAR">Heavy Wear (Cracked back or bent frame)</option>
                </select>
              </div>
            </div>

            {/* STEP 2: Security & IMEI Verification */}
            <div className="bg-amber-50/70 border border-amber-300 rounded-2xl p-3 sm:p-4 space-y-3">
              <h4 className="font-extrabold text-amber-950 text-xs sm:text-sm flex items-center gap-1.5">
                <Lock className="w-4 h-4 text-amber-700" /> 2. Security & IMEI Verification (Mandatory)
              </h4>

              <div className="space-y-2">
                <label className="flex items-start gap-2.5 font-bold text-amber-950 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    required
                    checked={cloudLocksRemoved}
                    onChange={(e) => setCloudLocksRemoved(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded mt-0.5"
                  />
                  <span className="text-xs leading-tight">
                    Apple iCloud / Google FRP Account has been completely removed & phone factory reset *
                  </span>
                </label>

                <label className="flex items-start gap-2.5 font-bold text-amber-950 cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={customerIdVerified}
                    onChange={(e) => setCustomerIdVerified(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded mt-0.5"
                  />
                  <span className="text-xs leading-tight">
                    Seller Identity verified with Govt ID (Aadhaar / Driving License / PAN)
                  </span>
                </label>
              </div>

              <div>
                <label className="block font-extrabold text-amber-950 mb-1 text-xs">
                  Verified Device IMEI Number (Dial *#06# on phone) *
                </label>
                <input
                  type="text"
                  required
                  maxLength={20}
                  value={verifiedImei}
                  onChange={(e) => setVerifiedImei(e.target.value.replace(/[^0-9]/g, ''))}
                  placeholder="Enter 15-digit IMEI number"
                  className="w-full p-2.5 border border-amber-300 rounded-xl font-mono tracking-wider bg-white text-xs text-slate-900 focus:ring-2 focus:ring-amber-500 focus:outline-none"
                />
                <span className="text-[10px] text-amber-800 mt-0.5 block">
                  Must match the physical device dialer (*#06#) to ensure authentic ownership.
                </span>
              </div>
            </div>

            {/* STEP 3: Base64 Photos Upload */}
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <span className="font-extrabold text-slate-800 text-xs sm:text-sm flex items-center gap-1.5">
                  <Camera className="w-4 h-4 text-emerald-600" />
                  3. Device Condition Photographs (Base64 Proof)
                </span>
                <span className="text-[10px] text-slate-400 font-bold">{photos.length} Attached</span>
              </div>

              <div className="grid grid-cols-3 gap-2">
                {[
                  { label: 'Front Screen', tip: 'Screen on' },
                  { label: 'Back Body', tip: 'Camera / back' },
                  { label: 'Defect Zoom', tip: 'Any scratches' },
                ].map((item, idx) => (
                  <label 
                    key={idx} 
                    className="border-2 border-dashed border-slate-300 hover:border-emerald-500 rounded-xl p-2 sm:p-3 text-center cursor-pointer bg-slate-50 hover:bg-emerald-50/30 transition block select-none"
                  >
                    <input
                      type="file"
                      accept="image/*"
                      capture="environment"
                      onChange={(e) => handlePhotoUpload(e, item.label)}
                      className="hidden"
                    />
                    <Upload className="w-3.5 h-3.5 sm:w-4 sm:h-4 text-slate-400 mx-auto mb-1" />
                    <span className="text-[10px] sm:text-xs font-bold text-slate-700 block truncate">{item.label}</span>
                    <span className="text-[8px] sm:text-[9px] text-slate-400 hidden xs:block">{item.tip}</span>
                  </label>
                ))}
              </div>

              {/* Photo Preview Thumbnails with Remove */}
              {photos.length > 0 && (
                <div className="flex gap-2 pt-1 overflow-x-auto pb-1">
                  {photos.map((p, i) => (
                    <div key={i} className="relative w-16 h-16 sm:w-20 sm:h-20 rounded-xl border border-slate-200 overflow-hidden shrink-0 group shadow-sm bg-black">
                      <img src={p.image_base64} alt={p.label} className="w-full h-full object-cover" />
                      <span className="absolute bottom-0 inset-x-0 bg-black/60 text-white text-[8px] text-center py-0.5 truncate px-1">
                        {p.label}
                      </span>
                      <button
                        type="button"
                        onClick={() => removePhoto(i)}
                        className="absolute top-1 right-1 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700 transition"
                      >
                        <X className="w-3 h-3" />
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* STEP 4: Final Offer Price Calculation */}
            <div className="bg-slate-50 p-3 sm:p-4 rounded-2xl border border-slate-200 space-y-2.5">
              <div className="flex items-center justify-between">
                <label className="font-extrabold text-slate-900 text-xs sm:text-sm">
                  Recommended Final Buyback Price (₹) *
                </label>
                <button
                  type="button"
                  onClick={() => setSuggestedFinalPrice(selectedSale.estimated_price)}
                  className="text-[10px] text-emerald-700 font-bold bg-emerald-100 hover:bg-emerald-200 px-2 py-0.5 rounded-lg transition"
                >
                  Reset to Original Estimate
                </button>
              </div>

              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400 font-black text-lg">₹</span>
                <input
                  type="number"
                  step="50"
                  min="0"
                  required
                  value={suggestedFinalPrice}
                  onChange={(e) => setSuggestedFinalPrice(e.target.value)}
                  className="w-full pl-8 pr-3 py-2.5 border border-slate-300 rounded-xl text-lg sm:text-xl font-black text-emerald-700 bg-white focus:ring-2 focus:ring-emerald-500 focus:outline-none"
                />
              </div>

              <input
                type="text"
                value={inspectorNotes}
                onChange={(e) => setInspectorNotes(e.target.value)}
                placeholder="Agent notes for customer (e.g. Minor scratches observed on edges, -₹500 applied)"
                className="w-full p-2.5 border border-slate-300 rounded-xl text-xs bg-white focus:ring-2 focus:ring-slate-400 focus:outline-none"
              />
            </div>

            {/* INLINE LIVE FEEDBACK & STATUS REFLECTION BANNER (Positioned right above submit) */}
            <div ref={feedbackRef} className="space-y-2">
              {formError && (
                <div className="p-3.5 rounded-2xl bg-rose-50 border border-rose-300 text-rose-800 text-xs font-bold animate-shake flex items-start gap-2 shadow-sm">
                  <AlertTriangle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
                  <div>
                    <p className="font-black text-rose-900">Validation Notice</p>
                    <p className="mt-0.5 leading-snug">{formError}</p>
                  </div>
                </div>
              )}

              {feedback && (
                <div className={`p-3.5 sm:p-4 rounded-2xl border text-xs font-bold animate-fade-in ${
                  feedback.type === 'success'
                    ? 'bg-emerald-50 border-emerald-300 text-emerald-900 shadow-sm'
                    : 'bg-rose-50 border-rose-300 text-rose-900 shadow-sm'
                }`}>
                  <div className="flex items-start gap-2.5">
                    {feedback.type === 'success' ? (
                      <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                    ) : (
                      <AlertTriangle className="w-5 h-5 text-rose-600 shrink-0 mt-0.5" />
                    )}
                    <div className="space-y-1">
                      <p className="leading-snug">{feedback.message}</p>
                      {feedback.status && (
                        <div className="text-[11px] font-medium text-emerald-800">
                          Current Order Status: <strong className="font-extrabold">{feedback.status.replace(/_/g, ' ')}</strong>
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}

              {/* If already inspected and no fresh feedback, show verified status indicator */}
              {!feedback && !formError && (selectedSale.has_inspection || selectedSale.status === 'OWNERSHIP_TRANSFERRED' || selectedSale.status === 'FINAL_OFFER_SENT') && (
                <div className="p-3 bg-[#E8F8ED] border border-[#0BAA4B]/30 text-[#087C38] rounded-2xl text-xs space-y-1.5">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-[#0BAA4B] shrink-0" />
                      <span className="font-bold">
                        {selectedSale.status === 'OWNERSHIP_TRANSFERRED' 
                          ? 'Handover Completed · Ownership Transferred to 1103 RECELL'
                          : selectedSale.status === 'FINAL_OFFER_SENT'
                          ? 'Revised Final Offer Sent to Customer'
                          : 'Inspection Recorded'}
                      </span>
                    </div>
                    <span className="text-[10px] text-[#087C38] font-black">
                      Agreed: ₹{Number(saleDetails?.final_price || selectedSale.final_price || selectedSale.estimated_price).toLocaleString('en-IN')}
                    </span>
                  </div>
                  {(saleDetails?.admin_notes || selectedSale.admin_notes) && (
                    <p className="text-[10px] text-amber-800 bg-amber-50 border border-amber-200 rounded-lg px-2 py-1 font-semibold whitespace-pre-line">
                      {saleDetails?.admin_notes || selectedSale.admin_notes}
                    </p>
                  )}
                </div>
              )}
            </div>

            {/* SUBMIT BUTTON */}
            <button
              type="submit"
              disabled={submitting}
              className={`w-full text-white font-black py-4 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 text-xs sm:text-sm active:scale-98 ${
                submitting
                  ? 'bg-slate-700 cursor-not-allowed opacity-80'
                  : selectedSale.has_inspection
                  ? 'bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105'
                  : 'bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105'
              }`}
            >
              {submitting ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span>Recording Inspection & Evidence...</span>
                </>
              ) : selectedSale.has_inspection ? (
                <>
                  <Check className="w-4 h-4" />
                  <span>Update Inspection & Final Offer</span>
                </>
              ) : (
                <>
                  <span>Confirm Inspection & Submit Final Offer</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>

          </form>
        ) : (
          <div className="md:col-span-2 bg-white rounded-3xl border border-slate-200 p-8 sm:p-12 text-center text-slate-400">
            <Smartphone className="w-12 h-12 text-slate-300 mx-auto mb-2" />
            <p className="font-bold text-slate-700">No Pickup Selected</p>
            <p className="text-xs text-slate-400 mt-1">Select an assigned order from the queue above to record device inspection.</p>
          </div>
        )}

      </div>

    </div>
  );
}