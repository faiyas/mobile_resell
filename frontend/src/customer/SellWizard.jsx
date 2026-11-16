import React, { useState, useEffect } from 'react';
import { 
  Smartphone, ShieldCheck, Check, ArrowRight, ArrowLeft, 
  HelpCircle, AlertCircle, Calendar, MapPin, CreditCard, 
  Sparkles, CheckCircle2, ChevronRight, IndianRupee, Layers
} from 'lucide-react';
import { api } from '../services/api';

export default function SellWizard({ onOrderCreated, currentUser }) {
  // Steps: 1. Brand, 2. Model & Storage, 3. Condition, 4. Price & Valuation, 5. Pickup & Payment, 6. Success
  const [step, setStep] = useState(1);
  
  // Data lists
  const [brands, setBrands] = useState([]);
  const [models, setModels] = useState([]);
  const [conditionCategories, setConditionCategories] = useState([]);

  // Selections
  const [selectedBrand, setSelectedBrand] = useState(null);
  const [selectedModel, setSelectedModel] = useState(null);
  const [selectedVariant, setSelectedVariant] = useState(null);
  const [selectedDefectCodes, setSelectedDefectCodes] = useState([]);

  // Live calculated valuation
  const [valuationResult, setValuationResult] = useState(null);
  const [valuing, setValuing] = useState(false);

  // Customer Contact & Pickup
  const [customerName, setCustomerName] = useState(currentUser?.full_name || '');
  const [customerPhone, setCustomerPhone] = useState(currentUser?.phone || '');
  const [customerEmail, setCustomerEmail] = useState(currentUser?.email || '');
  const [pickupAddress, setPickupAddress] = useState('');
  const [pickupCity, setPickupCity] = useState('Bengaluru');
  const [pickupPincode, setPickupPincode] = useState('560001');
  const [pickupSlot, setPickupSlot] = useState('Morning (10:00 AM - 1:00 PM)');

  // Customer Payout Method
  const [beneficiaryType, setBeneficiaryType] = useState('UPI');
  const [beneficiaryName, setBeneficiaryName] = useState(currentUser?.full_name || '');
  const [beneficiaryUpiId, setBeneficiaryUpiId] = useState('');
  const [beneficiaryAccountNo, setBeneficiaryAccountNo] = useState('');
  const [beneficiaryIfsc, setBeneficiaryIfsc] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [createdOrder, setCreatedOrder] = useState(null);
  const [errorMsg, setErrorMsg] = useState('');

  // Initial load: brands & condition categories
  useEffect(() => {
    api.getBrands().then(setBrands).catch(console.error);
    api.getConditionCategories().then(setConditionCategories).catch(console.error);
  }, []);

  // Update customer details when user logs in
  useEffect(() => {
    if (currentUser) {
      if (!customerName) setCustomerName(currentUser.full_name || '');
      if (!customerPhone) setCustomerPhone(currentUser.phone || '');
      if (!customerEmail) setCustomerEmail(currentUser.email || '');
      if (!beneficiaryName) setBeneficiaryName(currentUser.full_name || '');
    }
  }, [currentUser]);

  // Load models when brand changes
  const handleSelectBrand = async (brand) => {
    setSelectedBrand(brand);
    setSelectedModel(null);
    setSelectedVariant(null);
    try {
      const modelsData = await api.getModels(brand.id);
      setModels(modelsData);
      setStep(2);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSelectModel = (model) => {
    setSelectedModel(model);
    if (model.variants && model.variants.length > 0) {
      setSelectedVariant(model.variants[0]);
    }
  };

  const toggleDefectCode = (code) => {
    if (selectedDefectCodes.includes(code)) {
      setSelectedDefectCodes(selectedDefectCodes.filter(c => c !== code));
    } else {
      setSelectedDefectCodes([...selectedDefectCodes, code]);
    }
  };

  // Recalculate dynamic price whenever variant or defect questions change
  const computeValuation = async () => {
    if (!selectedVariant) return;
    setValuing(true);
    try {
      const res = await api.calculateEstimate(selectedVariant.id, selectedDefectCodes);
      setValuationResult(res);
      setStep(4);
    } catch (err) {
      console.error(err);
      setErrorMsg(err.message || 'Failed to calculate price');
    } finally {
      setValuing(false);
    }
  };

  const handleSubmitOrder = async (e) => {
    e.preventDefault();
    setSubmitting(true);
    setErrorMsg('');

    if (beneficiaryType === 'UPI' && !beneficiaryUpiId.includes('@')) {
      setErrorMsg('Please enter a valid UPI ID (e.g. yourname@okaxis, 9876543210@paytm)');
      setSubmitting(false);
      return;
    }

    try {
      const payload = {
        variant_id: selectedVariant.id,
        selected_option_codes: selectedDefectCodes,
        customer_name: customerName,
        customer_phone: customerPhone,
        customer_email: customerEmail,
        pickup_address: pickupAddress,
        pickup_city: pickupCity,
        pickup_pincode: pickupPincode,
        pickup_slot: pickupSlot,
        beneficiary_type: beneficiaryType,
        beneficiary_name: beneficiaryName || customerName,
        beneficiary_upi_id: beneficiaryUpiId,
        beneficiary_account_no: beneficiaryAccountNo,
        beneficiary_ifsc: beneficiaryIfsc,
      };

      const res = await api.submitSale(payload);
      setCreatedOrder(res);
      setStep(6);
      if (onOrderCreated) onOrderCreated(res);
    } catch (err) {
      setErrorMsg(err.message || 'Failed to submit request');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      
      {/* Wizard Progress Stepper (Mobile Optimized) */}
      <div className="mb-6 bg-white p-3 sm:p-4 rounded-2xl border border-slate-200 shadow-sm">
        <div className="flex items-center justify-between max-w-3xl mx-auto">
          {[
            { num: 1, label: 'Brand' },
            { num: 2, label: 'Model' },
            { num: 3, label: 'Checks' },
            { num: 4, label: 'Offer' },
            { num: 5, label: 'Payout' },
          ].map((s, idx) => (
            <div key={s.num} className="flex items-center flex-1 justify-center">
              <div className="flex flex-col items-center">
                <div 
                  className={`w-7 h-7 sm:w-9 sm:h-9 rounded-full flex items-center justify-center font-bold text-xs transition-colors ${
                    step === s.num
                      ? 'bg-emerald-600 text-white shadow-md shadow-emerald-500/20 ring-2 sm:ring-4 ring-emerald-100'
                      : step > s.num
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-slate-100 text-slate-400'
                  }`}
                >
                  {step > s.num ? <Check className="w-3.5 h-3.5 sm:w-4 sm:h-4 stroke-[3]" /> : s.num}
                </div>
                <span className={`text-[10px] sm:text-[11px] font-semibold mt-1 truncate ${step >= s.num ? 'text-slate-800' : 'text-slate-400'}`}>
                  {s.label}
                </span>
              </div>
              {idx < 4 && (
                <div className={`flex-1 h-0.5 mx-1 sm:mx-2 rounded ${step > s.num ? 'bg-emerald-500' : 'bg-slate-200'}`} />
              )}
            </div>
          ))}
        </div>
      </div>

      {errorMsg && (
        <div className="mb-6 p-4 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 text-sm font-semibold flex items-center gap-2">
          <AlertCircle className="w-5 h-5 text-rose-600 shrink-0" />
          <span>{errorMsg}</span>
        </div>
      )}

      {/* ================= STEP 1: SELECT BRAND ================= */}
      {step === 1 && (
        <div className="space-y-6 animate-fade-in">
          <div className="text-center max-w-xl mx-auto">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full">
              Step 1 of 5
            </span>
            <h2 className="text-2xl sm:text-3xl font-extrabold text-slate-900 mt-2">
              Select Your Phone Brand
            </h2>
            <p className="text-sm text-slate-500 mt-1">
              Choose your manufacturer to view eligible models for instant sell & buyback.
            </p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-4">
            {brands.map((brand) => (
              <div
                key={brand.id}
                onClick={() => handleSelectBrand(brand)}
                className="group cursor-pointer bg-white border border-slate-200 hover:border-emerald-500 hover:shadow-lg hover:shadow-emerald-500/10 rounded-2xl p-6 text-center transition flex flex-col items-center justify-center min-h-[160px]"
              >
                <div className="w-20 h-14 flex items-center justify-center mb-3 group-hover:scale-110 transition-transform">
                  {brand.logo_base64 ? (
                    <img src={brand.logo_base64} alt={brand.name} className="max-h-12 max-w-full object-contain" />
                  ) : (
                    <Smartphone className="w-10 h-10 text-slate-400" />
                  )}
                </div>
                <h3 className="font-bold text-slate-900 group-hover:text-emerald-700 transition">
                  {brand.name}
                </h3>
                <span className="text-xs text-slate-400 mt-1 flex items-center gap-1 group-hover:text-emerald-600">
                  Select <ChevronRight className="w-3.5 h-3.5" />
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ================= STEP 2: SELECT MODEL & VARIANT ================= */}
      {step === 2 && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex items-center justify-between border-b border-slate-200 pb-4">
            <div>
              <span className="text-xs font-bold text-emerald-600 uppercase">Selected Brand</span>
              <h3 className="text-xl font-extrabold text-slate-900">{selectedBrand?.name}</h3>
            </div>
            <button
              onClick={() => setStep(1)}
              className="text-xs font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-3 py-1.5 rounded-lg hover:bg-slate-50 transition"
            >
              <ArrowLeft className="w-3.5 h-3.5" /> Change Brand
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            {/* Models Column */}
            <div className="md:col-span-2 space-y-3">
              <h4 className="font-bold text-slate-900 text-sm">Select Phone Model:</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-h-[460px] overflow-y-auto pr-1">
                {models.map((model) => (
                  <div
                    key={model.id}
                    onClick={() => handleSelectModel(model)}
                    className={`cursor-pointer p-4 rounded-xl border transition flex items-center gap-3 ${
                      selectedModel?.id === model.id
                        ? 'bg-emerald-50/70 border-emerald-500 shadow-sm ring-2 ring-emerald-500/20'
                        : 'bg-white border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="w-12 h-14 bg-slate-100 rounded-lg flex items-center justify-center shrink-0 overflow-hidden p-1">
                      {model.image_base64 ? (
                        <img src={model.image_base64} alt={model.name} className="max-h-full object-contain" />
                      ) : (
                        <Smartphone className="w-6 h-6 text-slate-400" />
                      )}
                    </div>
                    <div className="min-w-0">
                      <h4 className="font-bold text-slate-900 text-sm truncate">{model.name}</h4>
                      <p className="text-xs text-slate-500 mt-0.5">{model.variants?.length || 0} Storage Variants</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Storage Variants Column */}
            <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-sm space-y-4">
              <h4 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                <Layers className="w-4 h-4 text-emerald-600" />
                Select Storage Variant:
              </h4>

              {selectedModel ? (
                <div className="space-y-3">
                  <div className="space-y-2">
                    {selectedModel.variants?.map((v) => (
                      <div
                        key={v.id}
                        onClick={() => setSelectedVariant(v)}
                        className={`cursor-pointer p-3.5 rounded-xl border transition flex items-center justify-between ${
                          selectedVariant?.id === v.id
                            ? 'bg-emerald-600 text-white border-emerald-600 shadow-md'
                            : 'bg-slate-50 border-slate-200 hover:border-emerald-300 text-slate-800'
                        }`}
                      >
                        <div>
                          <p className="font-bold text-sm">
                            {v.ram ? `${v.ram} / ` : ''}{v.storage}
                          </p>
                          <span className={`text-[11px] ${selectedVariant?.id === v.id ? 'text-emerald-100' : 'text-slate-500'}`}>
                            Mint Base: ₹{Number(v.base_price).toLocaleString('en-IN')}
                          </span>
                        </div>
                        {selectedVariant?.id === v.id && (
                          <CheckCircle2 className="w-5 h-5 text-white shrink-0" />
                        )}
                      </div>
                    ))}
                  </div>

                  <div className="pt-4 border-t border-slate-100">
                    <button
                      onClick={() => setStep(3)}
                      disabled={!selectedVariant}
                      className="w-full bg-emerald-600 hover:bg-emerald-700 disabled:bg-slate-200 disabled:text-slate-400 text-white font-bold py-3 rounded-xl shadow transition flex items-center justify-center gap-2"
                    >
                      Answer Condition Questions <ArrowRight className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              ) : (
                <div className="text-center py-12 text-slate-400 text-xs">
                  ← Select a model to view storage and base price
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ================= STEP 3: CONDITION QUESTIONS ================= */}
      {step === 3 && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex items-center justify-between border-b border-slate-200 pb-4">
            <div>
              <span className="text-xs font-bold text-emerald-600 uppercase">Configured Device</span>
              <h3 className="text-xl font-extrabold text-slate-900">
                {selectedModel?.name} ({selectedVariant?.ram ? `${selectedVariant.ram} / ` : ''}{selectedVariant?.storage})
              </h3>
              <p className="text-xs text-slate-500">Max Base Price (Mint condition): ₹{Number(selectedVariant?.base_price).toLocaleString('en-IN')}</p>
            </div>
            <button
              onClick={() => setStep(2)}
              className="text-xs font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-3 py-1.5 rounded-lg hover:bg-slate-50 transition"
            >
              <ArrowLeft className="w-3.5 h-3.5" /> Back
            </button>
          </div>

          {/* Mint Condition Shortcut */}
          <div className="bg-gradient-to-r from-emerald-50 to-teal-50 border border-emerald-200 rounded-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 shadow-sm">
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-emerald-600 text-white flex items-center justify-center shrink-0 shadow-sm">
                <Sparkles className="w-5 h-5" />
              </div>
              <div>
                <h4 className="font-extrabold text-slate-900 text-sm">Is your phone like new with zero defects?</h4>
                <p className="text-xs text-slate-600">If your device has no scratches, cracks or hardware issues, get the maximum valuation.</p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => {
                setSelectedDefectCodes([]);
                computeValuation();
              }}
              className="w-full sm:w-auto bg-emerald-600 hover:bg-emerald-700 text-white font-black text-xs px-4 py-2.5 rounded-xl shadow transition shrink-0 whitespace-nowrap"
            >
              ✓ Mint Condition (Top Price)
            </button>
          </div>

          <div className="text-center sm:text-left">
            <h3 className="text-lg font-black text-slate-900">Check Your Phone's Condition:</h3>
            <p className="text-xs text-slate-500">Tap any picture that matches visible defects on your phone. If none apply, leave unselected.</p>
          </div>

          {/* Condition Categories with Visual Cards */}
          <div className="space-y-6">
            {conditionCategories.map((cat) => (
              <div key={cat.id} className="bg-white border border-slate-200 rounded-2xl sm:rounded-3xl p-4 sm:p-5 shadow-sm space-y-4">
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2.5">
                    <div className="w-8 h-8 rounded-xl bg-emerald-50 text-emerald-700 flex items-center justify-center font-bold">
                      <Smartphone className="w-4 h-4" />
                    </div>
                    <div>
                      <h4 className="font-black text-slate-900 text-sm">{cat.name}</h4>
                      <p className="text-[11px] text-slate-500">{cat.description}</p>
                    </div>
                  </div>
                  <span className="text-[10px] font-bold text-slate-400 bg-slate-50 px-2 py-1 rounded-md">
                    {cat.options?.filter(o => selectedDefectCodes.includes(o.code)).length || 0} Reported
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                  {cat.options?.map((opt) => {
                    const isChecked = selectedDefectCodes.includes(opt.code);
                    return (
                      <div
                        key={opt.id}
                        onClick={() => toggleDefectCode(opt.code)}
                        className={`cursor-pointer rounded-2xl border-2 p-3 transition flex flex-col justify-between active:scale-[0.98] select-none ${
                          isChecked
                            ? opt.is_rejection
                              ? 'bg-rose-50 border-rose-500 shadow-md ring-2 ring-rose-500/20'
                              : 'bg-amber-50/80 border-amber-500 shadow-md ring-2 ring-amber-500/20'
                            : 'bg-slate-50/60 border-slate-200 hover:border-slate-300 hover:bg-white shadow-sm'
                        }`}
                      >
                        {/* Top selection indicator */}
                        <div className="flex justify-between items-center mb-2">
                          <span className={`text-[10px] font-black uppercase px-2 py-0.5 rounded-full flex items-center gap-1 ${
                            isChecked
                              ? opt.is_rejection ? 'bg-rose-600 text-white' : 'bg-amber-600 text-white'
                              : 'bg-slate-200 text-slate-700'
                          }`}>
                            {isChecked ? (opt.is_rejection ? '🛑 Rejection' : '⚠️ Selected') : 'Tap if applies'}
                          </span>
                          <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition ${
                            isChecked
                              ? opt.is_rejection ? 'border-rose-600 bg-rose-600 text-white' : 'border-amber-600 bg-amber-600 text-white'
                              : 'border-slate-300 bg-white'
                          }`}>
                            {isChecked && <Check className="w-3 h-3 stroke-[3]" />}
                          </div>
                        </div>

                        {/* Visual Defect Photograph / Illustration */}
                        <div className="w-full h-32 sm:h-36 rounded-xl bg-white border border-slate-200/80 overflow-hidden flex items-center justify-center mb-2.5 p-2 shadow-inner">
                          {opt.image_base64 ? (
                            <img src={opt.image_base64} alt={opt.title} className="max-h-full max-w-full object-contain" />
                          ) : (
                            <Smartphone className="w-12 h-12 text-slate-300" />
                          )}
                        </div>

                        {/* Text & Deduction */}
                        <div>
                          <h5 className={`font-black text-xs sm:text-sm leading-tight ${isChecked ? 'text-slate-900' : 'text-slate-800'}`}>
                            {opt.title}
                          </h5>
                          {opt.description && (
                            <p className="text-[10px] text-slate-500 mt-0.5 line-clamp-1">{opt.description}</p>
                          )}
                          <div className="flex items-center justify-between mt-2 pt-2 border-t border-slate-200/60 text-[10px]">
                            <span className="text-slate-400 font-bold uppercase">Impact</span>
                            {opt.is_rejection ? (
                              <span className="font-black text-rose-600">Rejects Offer (₹0)</span>
                            ) : opt.deduction_type === 'PERCENTAGE' ? (
                              <span className="font-black text-amber-700 bg-amber-100 px-1.5 py-0.5 rounded">-{opt.default_deduction_value}%</span>
                            ) : (
                              <span className="font-black text-amber-700 bg-amber-100 px-1.5 py-0.5 rounded">-₹{Number(opt.default_deduction_value).toLocaleString('en-IN')}</span>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-between gap-3 pt-4 border-t border-slate-200">
            <span className="text-xs text-slate-500 font-bold">
              {selectedDefectCodes.length} {selectedDefectCodes.length === 1 ? 'Defect' : 'Defects'} Selected
            </span>
            <button
              onClick={computeValuation}
              disabled={valuing}
              className="w-full sm:w-auto bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold px-8 py-3.5 rounded-xl shadow-lg shadow-emerald-600/20 transition flex items-center justify-center gap-2 text-base active:scale-98"
            >
              {valuing ? 'Calculating Best Offer...' : 'See My Estimated Cash Offer'}
              <ArrowRight className="w-5 h-5" />
            </button>
          </div>
        </div>
      )}

      {/* ================= STEP 4: VALUATION RESULT ================= */}
      {step === 4 && valuationResult && (
        <div className="space-y-6 animate-fade-in max-w-2xl mx-auto">
          <div className="bg-gradient-to-br from-slate-900 to-slate-950 text-white rounded-3xl p-8 shadow-2xl relative overflow-hidden border border-slate-800">
            <div className="absolute top-0 right-0 p-8 opacity-10">
              <Sparkles className="w-48 h-48" />
            </div>

            <div className="relative z-10 text-center space-y-3">
              <span className="text-xs font-bold uppercase tracking-wider bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-3 py-1 rounded-full">
                Indicative Buyback Valuation
              </span>
              <h3 className="text-xl font-bold text-slate-300">
                {valuationResult.brand} {valuationResult.model} ({valuationResult.variant})
              </h3>

              <div className="py-4">
                <span className="text-sm text-slate-400 block font-medium">Estimated Selling Price:</span>
                <span className="text-4xl sm:text-5xl font-black text-emerald-400 tracking-tight">
                  ₹{Number(valuationResult.estimated_price).toLocaleString('en-IN')}
                </span>
                <p className="text-xs text-slate-400 mt-2">
                  *Final offer confirmed upon physical inspection by our collection agent.
                </p>
              </div>
            </div>

            {/* Itemized deduction breakdown */}
            <div className="bg-slate-800/80 rounded-2xl p-4 mt-6 border border-slate-700 space-y-2 text-xs">
              <div className="flex justify-between text-slate-300 font-semibold pb-2 border-b border-slate-700">
                <span>Base Model Value (Mint):</span>
                <span>₹{Number(valuationResult.base_price).toLocaleString('en-IN')}</span>
              </div>

              {valuationResult.deductions?.length > 0 ? (
                valuationResult.deductions.map((d, i) => (
                  <div key={i} className="flex justify-between text-rose-300">
                    <span>- {d.title}:</span>
                    <span>-₹{Number(d.deduction_amount).toLocaleString('en-IN')}</span>
                  </div>
                ))
              ) : (
                <div className="text-emerald-400 font-medium py-1">
                  ✓ Full Mint Condition! No condition deductions applied.
                </div>
              )}

              <div className="flex justify-between font-bold text-emerald-400 pt-2 border-t border-slate-700 text-sm">
                <span>Total Net Offer:</span>
                <span>₹{Number(valuationResult.estimated_price).toLocaleString('en-IN')}</span>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-4 pt-2">
            <button
              onClick={() => setStep(3)}
              className="w-1/3 border border-slate-300 hover:bg-slate-100 font-bold py-3.5 rounded-xl text-slate-700 text-sm transition"
            >
              Modify Conditions
            </button>
            <button
              onClick={() => setStep(5)}
              className="w-2/3 bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold py-3.5 rounded-xl shadow-lg shadow-emerald-600/20 text-sm transition flex items-center justify-center gap-2"
            >
              Schedule Pickup & Payout <ArrowRight className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}

      {/* ================= STEP 5: PICKUP & PAYOUT DETAILS ================= */}
      {step === 5 && (
        <form onSubmit={handleSubmitOrder} className="space-y-6 animate-fade-in max-w-2xl mx-auto">
          <div className="flex items-center justify-between border-b border-slate-200 pb-3">
            <div>
              <span className="text-xs font-bold text-emerald-600 uppercase">Step 5 of 5</span>
              <h3 className="text-xl font-extrabold text-slate-900">Doorstep Pickup & Payment Info</h3>
            </div>
            <button
              type="button"
              onClick={() => setStep(4)}
              className="text-xs font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-3 py-1.5 rounded-lg hover:bg-slate-50 transition"
            >
              <ArrowLeft className="w-3.5 h-3.5" /> Back
            </button>
          </div>

          {/* Contact Details */}
          <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-sm space-y-4">
            <h4 className="font-bold text-slate-900 text-sm flex items-center gap-2">
              <MapPin className="w-4 h-4 text-emerald-600" /> Customer Contact & Pickup Address
            </h4>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Your Full Name *</label>
                <input
                  type="text"
                  required
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                  placeholder="Rahul Sharma"
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Mobile Number (For Agent Call) *</label>
                <input
                  type="tel"
                  required
                  value={customerPhone}
                  onChange={(e) => setCustomerPhone(e.target.value)}
                  placeholder="9876543210"
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Street Address / House No / Landmark *</label>
              <textarea
                required
                rows={2}
                value={pickupAddress}
                onChange={(e) => setPickupAddress(e.target.value)}
                placeholder="Flat 302, Palm Heights, Outer Ring Road..."
                className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">City / Region *</label>
                <input
                  type="text"
                  required
                  value={pickupCity}
                  onChange={(e) => setPickupCity(e.target.value)}
                  placeholder="Bengaluru, Delhi, Mumbai..."
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">PIN Code *</label>
                <input
                  type="text"
                  required
                  value={pickupPincode}
                  onChange={(e) => setPickupPincode(e.target.value)}
                  placeholder="560103"
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Preferred Collection Slot</label>
              <select
                value={pickupSlot}
                onChange={(e) => setPickupSlot(e.target.value)}
                className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
              >
                <option value="Morning (10:00 AM - 1:00 PM)">Morning (10:00 AM - 1:00 PM)</option>
                <option value="Afternoon (1:00 PM - 4:00 PM)">Afternoon (1:00 PM - 4:00 PM)</option>
                <option value="Evening (4:00 PM - 7:30 PM)">Evening (4:00 PM - 7:30 PM)</option>
              </select>
            </div>
          </div>

          {/* Customer Payout Method */}
          <div className="bg-white border border-slate-200 rounded-2xl p-5 shadow-sm space-y-4">
            <div className="flex items-center justify-between">
              <h4 className="font-bold text-slate-900 text-sm flex items-center gap-2">
                <CreditCard className="w-4 h-4 text-emerald-600" />
                Where should we send your payout? (₹{Number(valuationResult?.estimated_price).toLocaleString('en-IN')})
              </h4>
            </div>

            {/* UPI or Bank Selector */}
            <div className="grid grid-cols-2 gap-3">
              <div
                onClick={() => setBeneficiaryType('UPI')}
                className={`cursor-pointer p-3 rounded-xl border text-center font-bold text-xs transition ${
                  beneficiaryType === 'UPI'
                    ? 'bg-emerald-50 border-emerald-600 text-emerald-800 ring-2 ring-emerald-500/20'
                    : 'bg-slate-50 border-slate-200 text-slate-600'
                }`}
              >
                UPI ID (Google Pay, PhonePe, Paytm)
              </div>
              <div
                onClick={() => setBeneficiaryType('BANK')}
                className={`cursor-pointer p-3 rounded-xl border text-center font-bold text-xs transition ${
                  beneficiaryType === 'BANK'
                    ? 'bg-emerald-50 border-emerald-600 text-emerald-800 ring-2 ring-emerald-500/20'
                    : 'bg-slate-50 border-slate-200 text-slate-600'
                }`}
              >
                Direct Bank Transfer (IMPS/NEFT)
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Account Holder / Payee Name *</label>
              <input
                type="text"
                required
                value={beneficiaryName}
                onChange={(e) => setBeneficiaryName(e.target.value)}
                placeholder="Exact name matching bank/UPI"
                className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
              />
            </div>

            {beneficiaryType === 'UPI' ? (
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">UPI ID (VPA) *</label>
                <input
                  type="text"
                  required
                  value={beneficiaryUpiId}
                  onChange={(e) => setBeneficiaryUpiId(e.target.value)}
                  placeholder="e.g. 9876543210@paytm or yourname@okaxis"
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                />
                <p className="text-[11px] text-slate-400 mt-1">Our admin will transfer funds to this UPI ID upon pickup & inspection.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Bank Account Number *</label>
                  <input
                    type="text"
                    required
                    value={beneficiaryAccountNo}
                    onChange={(e) => setBeneficiaryAccountNo(e.target.value)}
                    placeholder="e.g. 0123456789012"
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">IFSC Code *</label>
                  <input
                    type="text"
                    required
                    value={beneficiaryIfsc}
                    onChange={(e) => setBeneficiaryIfsc(e.target.value.toUpperCase())}
                    placeholder="e.g. SBIN0001234"
                    className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm uppercase focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
              </div>
            )}
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold py-4 rounded-2xl shadow-xl shadow-emerald-600/20 text-base transition flex items-center justify-center gap-2"
          >
            {submitting ? 'Submitting Sale Request...' : 'Confirm & Request Free Pickup'}
            <CheckCircle2 className="w-5 h-5" />
          </button>
        </form>
      )}

      {/* ================= STEP 6: CONFIRMATION SUCCESS ================= */}
      {step === 6 && createdOrder && (
        <div className="max-w-xl mx-auto bg-white rounded-3xl border border-slate-200 p-8 text-center shadow-xl space-y-6 animate-fade-in">
          <div className="w-16 h-16 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto ring-8 ring-emerald-50">
            <Check className="w-8 h-8 stroke-[3]" />
          </div>

          <div>
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full">
              Sale Request Received
            </span>
            <h2 className="text-2xl font-black text-slate-900 mt-2">
              Pickup Scheduled Successfully!
            </h2>
            <p className="text-sm text-slate-500 mt-1">
              Your tracking reference is:
            </p>
            <div className="inline-block bg-slate-900 text-white font-mono text-xl font-bold px-4 py-2 rounded-xl mt-2 tracking-wider">
              {createdOrder.sale_code}
            </div>
          </div>

          <div className="bg-slate-50 rounded-2xl p-4 text-left space-y-2 text-xs border border-slate-200">
            <div className="flex justify-between py-1 border-b border-slate-200">
              <span className="text-slate-500">Device:</span>
              <span className="font-bold text-slate-800">{createdOrder.brand_name} {createdOrder.model_name}</span>
            </div>
            <div className="flex justify-between py-1 border-b border-slate-200">
              <span className="text-slate-500">Indicative Price:</span>
              <span className="font-bold text-emerald-700">₹{Number(createdOrder.estimated_price).toLocaleString('en-IN')}</span>
            </div>
            <div className="flex justify-between py-1 border-b border-slate-200">
              <span className="text-slate-500">Pickup Slot:</span>
              <span className="font-bold text-slate-800">{createdOrder.pickup_slot}</span>
            </div>
            <div className="flex justify-between py-1">
              <span className="text-slate-500">Payout Target:</span>
              <span className="font-bold text-slate-800">{createdOrder.beneficiary_upi_id || createdOrder.beneficiary_account_no}</span>
            </div>
          </div>

          <div className="flex flex-col sm:flex-row gap-3">
            <button
              onClick={() => {
                if (onOrderCreated) onOrderCreated(createdOrder);
              }}
              className="w-full bg-slate-900 hover:bg-black text-white font-bold py-3 rounded-xl transition text-sm"
            >
              Track Live Order Status
            </button>
            <button
              onClick={() => {
                setStep(1);
                setSelectedBrand(null);
                setSelectedModel(null);
                setSelectedVariant(null);
                setSelectedDefectCodes([]);
                setValuationResult(null);
                setCreatedOrder(null);
              }}
              className="w-full border border-slate-300 hover:bg-slate-50 font-bold py-3 rounded-xl text-slate-700 transition text-sm"
            >
              Sell Another Phone
            </button>
          </div>
        </div>
      )}

    </div>
  );
}
