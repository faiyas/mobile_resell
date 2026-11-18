import React, { useState, useEffect } from 'react';
import {
  Smartphone, Tablet, Laptop, Watch, AlertOctagon, Layers,
  Search, ArrowRight, ArrowLeft, Check, CheckCircle2, ChevronRight,
  Sparkles, ShieldCheck, MapPin, Calendar, Clock, CreditCard, Banknote,
  HelpCircle, AlertTriangle, Copy, Truck, Gift, FileText
} from 'lucide-react';
import { api } from '../services/api';

export default function SellWizard({ onOrderCreated, currentUser }) {
  // Navigation: 1=Category, 2=Brand, 3=Model&Variant, 4=Questionnaire(Steps 2-10), 5=Quote, 6=PickupBooking, 7=Success
  const [currentScreen, setCurrentScreen] = useState(1);
  const [questionStepIndex, setQuestionStepIndex] = useState(0);

  // Dynamic DB Lists
  const [categories, setCategories] = useState([]);
  const [brands, setBrands] = useState([]);
  const [seriesList, setSeriesList] = useState([]);
  const [models, setModels] = useState([]);
  const [questionSteps, setQuestionSteps] = useState([]);

  // Selections
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedBrand, setSelectedBrand] = useState(null);
  const [selectedSeriesId, setSelectedSeriesId] = useState('ALL');
  const [selectedModel, setSelectedModel] = useState(null);
  const [selectedVariant, setSelectedVariant] = useState(null);
  const [selectedOptionCodes, setSelectedOptionCodes] = useState([]);
  const [stepCustomNotes, setStepCustomNotes] = useState({});
  const [isCustomDevice, setIsCustomDevice] = useState(false);
  const [customDeviceName, setCustomDeviceName] = useState('');
  const [customDeviceCategory, setCustomDeviceCategory] = useState('Others');
  const [customDeviceSpecs, setCustomDeviceSpecs] = useState('128GB');
  const [customExpectedPrice, setCustomExpectedPrice] = useState('8000');

  // Filters
  const [brandSearch, setBrandSearch] = useState('');
  const [modelSearch, setModelSearch] = useState('');

  // Valuation Quote
  const [valuationResult, setValuationResult] = useState(null);
  const [valuing, setValuing] = useState(false);

  // Customer Contact & Pickup Form
  const [customerName, setCustomerName] = useState(currentUser?.full_name || '');
  const [customerPhone, setCustomerPhone] = useState(currentUser?.phone || '');
  const [customerEmail, setCustomerEmail] = useState(currentUser?.email || '');
  const [pickupAddress, setPickupAddress] = useState(currentUser?.default_address || '');
  const [pickupCity, setPickupCity] = useState(currentUser?.city || '');
  const [pickupPincode, setPickupPincode] = useState(currentUser?.pincode || '');
  const [pickupDate, setPickupDate] = useState(new Date().toISOString().split('T')[0]);
  const [pickupSlot, setPickupSlot] = useState('Afternoon (1:00 PM - 5:00 PM)');

  // Payout Method
  const [beneficiaryType, setBeneficiaryType] = useState('UPI');
  const [beneficiaryName, setBeneficiaryName] = useState(currentUser?.full_name || '');
  const [beneficiaryUpiId, setBeneficiaryUpiId] = useState('');
  const [beneficiaryAccountNo, setBeneficiaryAccountNo] = useState('');
  const [beneficiaryIfsc, setBeneficiaryIfsc] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [createdOrder, setCreatedOrder] = useState(null);
  const [copiedCode, setCopiedCode] = useState(false);

  // Initial Load: Categories & Dynamic Questionnaire from DB
  useEffect(() => {
    loadInitialData();
  }, []);

  useEffect(() => {
    if (currentUser) {
      if (!customerName) setCustomerName(currentUser.full_name || '');
      if (!customerPhone) setCustomerPhone(currentUser.phone || '');
      if (!customerEmail) setCustomerEmail(currentUser.email || '');
      if (!beneficiaryName) setBeneficiaryName(currentUser.full_name || '');
    }
  }, [currentUser]);

  const loadInitialData = async () => {
    try {
      const [cats, qSteps] = await Promise.all([
        api.getCategories(),
        api.getConditionCategories(),
      ]);
      setCategories(cats);
      setQuestionSteps(qSteps);
      if (cats.length > 0) {
        handleSelectCategory(cats[0]);
      }
    } catch (err) {
      console.error("Initial load failed:", err);
    }
  };

  const handleSelectCategory = async (category) => {
    setSelectedCategory(category);
    setSelectedBrand(null);
    setSelectedModel(null);
    setSelectedVariant(null);
    try {
      const brandsData = await api.getBrands(false, false, category.id);
      setBrands(brandsData);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSelectBrand = async (brand) => {
    setSelectedBrand(brand);
    setSelectedModel(null);
    setSelectedVariant(null);
    try {
      const [modelsData, seriesData] = await Promise.all([
        api.getModels(brand.id),
        api.getSeries(brand.id),
      ]);
      setModels(modelsData);
      setSeriesList(seriesData);
      setCurrentScreen(3);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSelectModel = (model) => {
    setSelectedModel(model);
    if (model.variants && model.variants.length > 0) {
      setSelectedVariant(model.variants[0]);
    } else {
      setSelectedVariant(null);
    }
  };

  const toggleOptionCode = (code, exclusiveGroup) => {
    setSelectedOptionCodes((prev) => {
      let next = [...prev];
      if (next.includes(code)) {
        return next.filter((c) => c !== code);
      }
      // If code is from an exclusive group, remove other codes in the same category step
      const currentCat = questionSteps[questionStepIndex];
      if (currentCat) {
        const catCodes = currentCat.options.map((o) => o.code);
        // Mutual exclusion: if selecting a defect, uncheck "no defect" and vice versa
        if (code.toLowerCase().includes('good') || code.toLowerCase().includes('flawless') || code.toLowerCase().includes('no_defect')) {
          next = next.filter((c) => !catCodes.includes(c));
        } else {
          next = next.filter((c) => {
            const isGood = c.toLowerCase().includes('good') || c.toLowerCase().includes('flawless') || c.toLowerCase().includes('no_defect');
            return !isGood;
          });
        }
      }
      next.push(code);
      return next;
    });
  };

  const computeValuation = async () => {
    if (!selectedVariant) return;
    setValuing(true);
    try {
      const res = await api.calculateEstimate(selectedVariant.id, selectedOptionCodes);
      setValuationResult(res);
      setCurrentScreen(5); // Show quote screen
    } catch (e) {
      alert("Valuation calculation failed: " + e.message);
    } finally {
      setValuing(false);
    }
  };

  const handleSubmitBooking = async (e) => {
    e.preventDefault();
    if (!selectedVariant) return;
    setSubmitting(true);
    try {
      const combinedNotes = Object.entries(stepCustomNotes)
        .filter(([_, v]) => v && v.trim())
        .map(([k, v]) => `${k}: "${v.trim()}"`)
        .join('\n');

      const payload = {
        variant_id: selectedVariant ? selectedVariant.id : null,
        is_custom_device: isCustomDevice,
        custom_device_name: customDeviceName || (selectedModel ? selectedModel.name : 'Custom Device'),
        custom_device_category: customDeviceCategory || (selectedCategory ? selectedCategory.name : 'Others'),
        custom_device_specs: customDeviceSpecs || (selectedVariant ? selectedVariant.storage : 'Standard'),
        custom_expected_price: isCustomDevice ? (Number(customExpectedPrice) || 8000) : null,
        other_defects_notes: combinedNotes,
        custom_step_notes: stepCustomNotes,
        selected_option_codes: selectedOptionCodes,
        customer_name: customerName,
        customer_phone: customerPhone,
        customer_email: customerEmail,
        pickup_address: pickupAddress,
        pickup_city: pickupCity,
        pickup_pincode: pickupPincode,
        pickup_date: pickupDate,
        pickup_slot: pickupSlot,
        beneficiary_type: beneficiaryType,
        beneficiary_name: beneficiaryName,
        beneficiary_upi_id: beneficiaryUpiId,
        beneficiary_account_no: beneficiaryAccountNo,
        beneficiary_ifsc: beneficiaryIfsc,
      };
      const res = await api.submitSale(payload);
      setCreatedOrder(res);
      setCurrentScreen(7); // Show tracking screen
      if (onOrderCreated) onOrderCreated(res);
    } catch (err) {
      alert("Failed to submit pickup request: " + err.message);
    } finally {
      setSubmitting(false);
    }
  };

  const filteredBrands = brands.filter(b =>
    b.name.toLowerCase().includes(brandSearch.toLowerCase())
  );

  const filteredModels = models.filter(m => {
    const matchesSearch = m.name.toLowerCase().includes(modelSearch.toLowerCase());
    const matchesSeries = selectedSeriesId === 'ALL' || String(m.series) === String(selectedSeriesId);
    return matchesSearch && matchesSeries;
  });

  return (
    <div className="max-w-6xl mx-auto px-3 sm:px-6 py-4 sm:py-8 space-y-6">

      {/* TOP CATEGORY PILLS BAR */}
      <div className="glass-panel rounded-2xl p-2 flex items-center gap-2 overflow-x-auto scrollbar-none shadow-sm">
        {categories.map((cat) => {
          const isSelected = selectedCategory?.id === cat.id;
          return (
            <button
              key={cat.id}
              onClick={() => {
                handleSelectCategory(cat);
                setCurrentScreen(2);
              }}
              className={`px-4 py-2 rounded-xl text-xs sm:text-sm font-black transition shrink-0 flex items-center gap-2 ${isSelected
                  ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/25'
                  : 'text-[#17251C] hover:bg-white/60 hover:text-[#0BAA4B]'
                }`}
            >
              <span>{cat.name === 'Mobile' ? '📱' : cat.name === 'Tablet' ? '📟' : cat.name === 'Laptop' ? '💻' : cat.name === 'Smartwatch' ? '⌚' : '🔌'}</span>
              <span>Sell {cat.name}</span>
            </button>
          );
        })}
      </div>

      {/* ================= SCREEN 1: CATEGORY SELECTION ================= */}
      {currentScreen === 1 && (
        <div className="space-y-4 animate-fade-in">
          <div className="text-center max-w-xl mx-auto space-y-1">
            <span className="text-[10px] font-black uppercase text-[#0BAA4B] bg-[#E8F8ED] px-3 py-1 rounded-full border border-[#0BAA4B]/20">
              Step 1 of Buyback
            </span>
            <h2 className="text-2xl sm:text-3xl font-black text-[#17251C]">Sell Your Device</h2>
            <p className="text-xs text-[#7B8980]">Choose a device category to get started with instant doorstep valuation</p>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3.5 pt-2">
            {categories.map((cat) => (
              <div
                key={cat.id}
                onClick={() => {
                  handleSelectCategory(cat);
                  setCurrentScreen(2);
                }}
                className="cursor-pointer glass-card glass-card-hover rounded-3xl p-5 text-center transition flex flex-col items-center justify-between min-h-[170px] group"
              >
                <div className="w-14 h-14 rounded-2xl bg-[#E8F8ED] text-[#0BAA4B] flex items-center justify-center text-2xl group-hover:scale-110 transition-transform border border-[#0BAA4B]/20">
                  {cat.name === 'Mobile' ? '📱' : cat.name === 'Tablet' ? '📟' : cat.name === 'Laptop' ? '💻' : cat.name === 'Smartwatch' ? '⌚' : cat.name === 'Dead Phone' ? '⚠️' : '🔌'}
                </div>
                <div>
                  <h4 className="font-black text-[#17251C] text-base group-hover:text-[#0BAA4B] transition">{cat.name}</h4>
                  <p className="text-[11px] text-[#7B8980] mt-0.5">{cat.subtitle || `Sell your ${cat.name.toLowerCase()}`}</p>
                </div>
                <span className="text-[11px] font-bold text-[#0BAA4B] flex items-center gap-1 group-hover:translate-x-1 transition-transform">
                  Select <ChevronRight className="w-3.5 h-3.5" />
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ================= SCREEN 2: CHOOSE BRAND ================= */}
      {currentScreen === 2 && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 border-b border-white/80 pb-4">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-black uppercase text-[#0BAA4B] bg-[#E8F8ED] px-2 py-0.5 rounded-full border border-[#0BAA4B]/20">
                  {selectedCategory?.name || 'Device'}
                </span>
                <h3 className="text-xl sm:text-2xl font-black text-[#17251C]">Choose Your Brand</h3>
              </div>
              <p className="text-xs text-[#7B8980] mt-0.5">Select the manufacturer brand of your device</p>
            </div>

            <div className="relative w-full sm:w-64">
              <Search className="w-4 h-4 text-[#7B8980] absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search brand..."
                value={brandSearch}
                onChange={(e) => setBrandSearch(e.target.value)}
                className="w-full pl-9 pr-3 py-2 glass-input rounded-xl text-xs font-bold text-[#17251C] focus:outline-none"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-3 pt-2">
            {filteredBrands.map((brand) => (
              <div
                key={brand.id}
                onClick={() => handleSelectBrand(brand)}
                className="group cursor-pointer glass-card glass-card-hover rounded-2xl p-4 text-center transition flex flex-col items-center justify-center min-h-[140px]"
              >
                <div className="w-16 h-12 flex items-center justify-center mb-2 group-hover:scale-105 transition-transform">
                  {brand.logo_base64 ? (
                    <img src={brand.logo_base64} alt={brand.name} className="max-h-10 max-w-full object-contain" />
                  ) : (
                    <Smartphone className="w-8 h-8 text-[#0BAA4B]" />
                  )}
                </div>
                <h4 className="font-black text-[#17251C] text-xs sm:text-sm group-hover:text-[#0BAA4B] transition">{brand.name}</h4>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ================= SCREEN 3: CHOOSE MODEL & STORAGE VARIANT ================= */}
      {currentScreen === 3 && (
        <div className="space-y-5 animate-fade-in">
          {/* Header */}
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 border-b border-white/80 pb-4">
            <div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentScreen(2)}
                  className="p-1 rounded-lg hover:bg-white/60 text-[#7B8980]"
                >
                  <ArrowLeft className="w-4 h-4" />
                </button>
                <h3 className="text-xl sm:text-2xl font-black text-[#17251C]">
                  {selectedBrand?.name} — Choose Model
                </h3>
              </div>
              <p className="text-xs text-[#7B8980] mt-0.5">Select your specific model and storage capacity</p>
            </div>

            <div className="relative w-full sm:w-64">
              <Search className="w-4 h-4 text-[#7B8980] absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Search device model..."
                value={modelSearch}
                onChange={(e) => setModelSearch(e.target.value)}
                className="w-full pl-9 pr-3 py-2 glass-input rounded-xl text-xs font-bold text-[#17251C] focus:outline-none"
              />
            </div>
          </div>

          {/* Series Filter Pills */}
          {seriesList.length > 0 && (
            <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
              <button
                onClick={() => setSelectedSeriesId('ALL')}
                className={`px-3 py-1.5 rounded-xl text-xs font-black transition whitespace-nowrap ${selectedSeriesId === 'ALL'
                    ? 'bg-[#0BAA4B] text-white shadow-sm'
                    : 'glass-card text-[#7B8980] hover:bg-white'
                  }`}
              >
                All Series
              </button>
              {seriesList.map((s) => (
                <button
                  key={s.id}
                  onClick={() => setSelectedSeriesId(s.id)}
                  className={`px-3 py-1.5 rounded-xl text-xs font-black transition whitespace-nowrap ${selectedSeriesId === s.id
                      ? 'bg-[#0BAA4B] text-white shadow-sm'
                      : 'glass-card text-[#7B8980] hover:bg-white'
                    }`}
                >
                  {s.name}
                </button>
              ))}
            </div>
          )}

          {/* Models Grid & Storage Variants */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {/* Models Column */}
            <div className="md:col-span-2 space-y-3">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 max-h-[500px] overflow-y-auto pr-1">
                {filteredModels.map((m) => {
                  const isSelected = selectedModel?.id === m.id;
                  return (
                    <div
                      key={m.id}
                      onClick={() => handleSelectModel(m)}
                      className={`cursor-pointer rounded-2xl p-3 text-center transition flex flex-col items-center justify-between min-h-[160px] ${isSelected
                          ? 'border-2 border-[#0BAA4B] bg-[#E8F8ED]/70 shadow-md ring-2 ring-[#0BAA4B]/20'
                          : 'glass-card glass-card-hover'
                        }`}
                    >
                      <div className="w-16 h-20 bg-white/70 rounded-xl flex items-center justify-center p-1.5 overflow-hidden border border-white/80">
                        {m.image_base64 ? (
                          <img src={m.image_base64} alt={m.name} className="max-h-full object-contain" />
                        ) : (
                          <Smartphone className="w-8 h-8 text-[#0BAA4B]" />
                        )}
                      </div>
                      <div>
                        <h4 className="font-black text-xs text-[#17251C] mt-2 line-clamp-2">{m.name}</h4>
                        <span className="text-[10px] text-[#0BAA4B] font-bold block mt-0.5">
                          {m.variants?.length || 0} Variants
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Storage Variants Column */}
            <div className="glass-panel rounded-3xl p-5 shadow-sm space-y-4">
              <h4 className="font-black text-sm text-[#17251C] flex items-center gap-1.5">
                <Layers className="w-4 h-4 text-[#0BAA4B]" />
                Select Storage Variant:
              </h4>

              {selectedModel ? (
                <div className="space-y-3">
                  <div className="space-y-2">
                    {selectedModel.variants?.map((v) => {
                      const isVarSelected = selectedVariant?.id === v.id;
                      return (
                        <div
                          key={v.id}
                          onClick={() => setSelectedVariant(v)}
                          className={`cursor-pointer p-3 rounded-2xl border-2 transition flex items-center justify-between ${isVarSelected
                              ? 'border-[#0BAA4B] bg-[#0BAA4B] text-white shadow-md'
                              : 'glass-card text-[#17251C] hover:border-[#0BAA4B]/40'
                            }`}
                        >
                          <div>
                            <p className="font-black text-sm">
                              {v.ram ? `${v.ram} / ` : ''}{v.storage}
                            </p>
                            <span className={`text-[11px] font-bold ${isVarSelected ? 'text-[#E8F8ED]' : 'text-[#7B8980]'}`}>
                              Base Buyback: ₹{Number(v.base_price).toLocaleString('en-IN')}
                            </span>
                          </div>
                          {isVarSelected && <CheckCircle2 className="w-5 h-5 text-white shrink-0" />}
                        </div>
                      );
                    })}
                  </div>

                  <button
                    onClick={() => {
                      setQuestionStepIndex(0);
                      setCurrentScreen(4); // Start questionnaire
                    }}
                    disabled={!selectedVariant}
                    className="w-full bg-[#0BAA4B] hover:bg-[#087C38] disabled:bg-slate-200 disabled:text-slate-400 text-white font-black py-3.5 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 text-sm mt-4"
                  >
                    Start Device Evaluation <ArrowRight className="w-4 h-4" />
                  </button>
                </div>
              ) : (
                <div className="text-center py-16 text-[#7B8980] text-xs">
                  ← Tap a phone model on the left to view available storage and base prices.
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ================= SCREEN 4: DYNAMIC QUESTIONNAIRE (STEPS 2-10) ================= */}
      {currentScreen === 4 && questionSteps.length > 0 && (
        <div className="space-y-5 animate-fade-in max-w-3xl mx-auto">
          {(() => {
            const currentCat = questionSteps[questionStepIndex];
            if (!currentCat) return null;

            return (
              <div className="glass-panel rounded-3xl p-5 sm:p-7 shadow-sm space-y-5">

                {/* Step indicator header */}
                <div className="flex items-center justify-between border-b border-white/80 pb-3">
                  <div>
                    <span className="text-[10px] font-black uppercase text-[#0BAA4B] bg-[#E8F8ED] px-2.5 py-0.5 rounded-full border border-[#0BAA4B]/20">
                      Step {questionStepIndex + 2} of 11
                    </span>
                    <h3 className="text-lg sm:text-xl font-black text-[#17251C] mt-1">
                      {selectedModel?.name} — {currentCat.name}
                    </h3>
                    <p className="text-xs text-[#7B8980]">{currentCat.subtitle || 'Choose device condition'}</p>
                  </div>
                  <span className="text-xs font-black text-[#7B8980]">
                    {questionStepIndex + 2}/11
                  </span>
                </div>

                {/* Pro tip card if configured */}
                {currentCat.pro_tip && (
                  <div className="bg-[#FFFBEB] border border-[#F59E0B]/30 rounded-2xl p-3 flex items-start gap-2.5 text-xs text-[#92400E]">
                    <HelpCircle className="w-4 h-4 text-[#F59E0B] shrink-0 mt-0.5" />
                    <div>
                      <strong className="block font-black">Pro Tip:</strong>
                      <span>{currentCat.pro_tip}</span>
                    </div>
                  </div>
                )}

                {/* Question Options Cards */}
                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3.5 pt-1">
                  {currentCat.options?.map((opt) => {
                    const isSelected = selectedOptionCodes.includes(opt.code);
                    return (
                      <div
                        key={opt.id}
                        onClick={() => toggleOptionCode(opt.code, opt.exclusive_group)}
                        className={`cursor-pointer rounded-2xl p-3.5 transition flex flex-col justify-between active:scale-[0.98] select-none ${isSelected
                            ? opt.is_rejection
                              ? 'border-2 border-rose-600 bg-rose-50/90 shadow-md ring-2 ring-rose-500/20'
                              : 'border-2 border-[#0BAA4B] bg-[#E8F8ED]/90 shadow-md ring-2 ring-[#0BAA4B]/20'
                            : 'glass-card glass-card-hover'
                          }`}
                      >
                        {/* Top Indicator */}
                        <div className="flex justify-between items-center mb-2">
                          <span className={`text-[10px] font-black uppercase px-2 py-0.5 rounded-full ${isSelected
                              ? opt.is_rejection ? 'bg-rose-600 text-white' : 'bg-[#0BAA4B] text-white'
                              : 'bg-white/80 text-slate-700 border border-white'
                            }`}>
                            {isSelected ? '✓ Selected' : 'Tap to select'}
                          </span>
                          <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${isSelected ? 'border-[#0BAA4B] bg-[#0BAA4B] text-white' : 'border-slate-300 bg-white'
                            }`}>
                            {isSelected && <Check className="w-3 h-3 stroke-[3]" />}
                          </div>
                        </div>

                        {/* Visual Image */}
                        <div className="w-full h-32 sm:h-36 rounded-xl bg-white/80 border border-white overflow-hidden flex items-center justify-center p-2 mb-2 shadow-inner">
                          {opt.image_base64 ? (
                            <img src={opt.image_base64} alt={opt.title} className="max-h-full max-w-full object-contain" />
                          ) : (
                            <Smartphone className="w-10 h-10 text-slate-300" />
                          )}
                        </div>

                        <div>
                          <h5 className="font-black text-xs sm:text-sm text-[#17251C] leading-snug">{opt.title}</h5>
                          {opt.description && (
                            <p className="text-[10px] text-[#7B8980] mt-0.5 line-clamp-1">{opt.description}</p>
                          )}
                          <div className="flex items-center justify-between mt-2 pt-2 border-t border-white/80 text-[10px]">
                            <span className="text-[#7B8980] font-bold">Price Impact</span>
                            {opt.is_rejection ? (
                              <span className="font-black text-rose-600">Rejects Offer (₹0)</span>
                            ) : opt.is_accessory_bonus ? (
                              <span className="font-black text-[#0BAA4B]">+ Accessory Added</span>
                            ) : Number(opt.default_deduction_value) > 0 ? (
                              <span className="font-black text-amber-700 bg-amber-100 px-1.5 py-0.5 rounded">
                                -₹{Number(opt.default_deduction_value).toLocaleString('en-IN')}
                              </span>
                            ) : (
                              <span className="font-black text-[#0BAA4B]">✓ No Impact (₹0)</span>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>

                {/* Custom Defect / Special Note for this Step */}
                <div className="glass-card p-4 rounded-2xl border border-white mt-4">
                  <div className="flex items-center gap-2 mb-2">
                    <FileText className="w-4 h-4 text-[#0BAA4B]" />
                    <span className="text-xs font-black text-[#17251C]">Other {currentCat.name} Issue or Detail (Optional):</span>
                  </div>
                  <textarea
                    rows={2}
                    value={stepCustomNotes[currentCat.name] || ''}
                    onChange={(e) => {
                      const val = e.target.value;
                      setStepCustomNotes(prev => ({ ...prev, [currentCat.name]: val }));
                    }}
                    placeholder={`Describe any other minor defect or remark for ${currentCat.name.toLowerCase()}...`}
                    className="w-full text-xs p-3 rounded-xl border border-slate-200 bg-white/90 focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]/40 placeholder:text-slate-400"
                  />
                </div>

                {/* Navigation Buttons: Previous & Continue */}
                <div className="flex items-center justify-between pt-4 border-t border-white/80">
                  <button
                    onClick={() => {
                      if (questionStepIndex > 0) {
                        setQuestionStepIndex(questionStepIndex - 1);
                      } else {
                        setCurrentScreen(3);
                      }
                    }}
                    className="flex items-center gap-1.5 text-xs font-black text-[#17251C] glass-card hover:bg-white px-4 py-2.5 rounded-xl transition"
                  >
                    <ArrowLeft className="w-3.5 h-3.5" /> Previous
                  </button>

                  <button
                    onClick={() => {
                      if (questionStepIndex < questionSteps.length - 1) {
                        setQuestionStepIndex(questionStepIndex + 1);
                      } else {
                        computeValuation(); // Finished questions, compute quote
                      }
                    }}
                    className="flex items-center gap-1.5 text-xs font-black text-white bg-[#0BAA4B] hover:bg-[#087C38] px-6 py-2.5 rounded-xl shadow-md shadow-[#0BAA4B]/20 transition"
                  >
                    {questionStepIndex === questionSteps.length - 1 ? 'Get Estimated Quote' : 'Continue'} <ArrowRight className="w-3.5 h-3.5" />
                  </button>
                </div>

              </div>
            );
          })()}
        </div>
      )}

      {/* ================= SCREEN 5: GET ESTIMATED QUOTE ================= */}
      {currentScreen === 5 && valuationResult && (
        <div className="max-w-xl mx-auto space-y-5 animate-fade-in">

          {/* Emerald Gradient Hero Quote Banner */}
          <div className="bg-gradient-to-br from-[#0BAA4B] via-[#087C38] to-[#0D4722] text-white rounded-3xl p-6 sm:p-8 shadow-2xl relative overflow-hidden text-center space-y-3 border border-white/30">
            <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 backdrop-blur px-3 py-1 rounded-full inline-block border border-white/20">
              Indicative Buyback Valuation
            </span>
            <h3 className="text-xl sm:text-2xl font-black">
              {valuationResult.brand} {valuationResult.model} ({valuationResult.variant})
            </h3>

            <div className="py-2">
              <span className="text-xs text-[#E8F8ED] block font-bold">Estimated Buyback Value</span>
              <span className="text-4xl sm:text-5xl font-black tracking-tight text-white drop-shadow">
                ₹{Number(valuationResult.estimated_price).toLocaleString('en-IN')}
              </span>
            </div>

            <p className="text-[11px] text-[#E8F8ED] max-w-sm mx-auto">
              Subject to physical doorstep verification by our 1103 RECELL collection specialist before payout.
            </p>
          </div>

          {/* Transparent Price Summary Frosted Card */}
          <div className="glass-panel rounded-3xl p-5 sm:p-6 space-y-3 text-xs shadow-sm">
            <h4 className="font-black text-sm text-[#17251C] border-b border-white/80 pb-2">
              Price Summary Breakdown:
            </h4>

            <div className="flex justify-between items-center py-1">
              <span className="text-[#7B8980]">Base Catalog Value (Mint):</span>
              <strong className="text-[#17251C] font-black">₹{Number(valuationResult.base_price).toLocaleString('en-IN')}</strong>
            </div>

            {valuationResult.breakdown?.map((item, idx) => (
              <div key={idx} className="flex justify-between items-center py-1 text-amber-800">
                <span>{item.title}:</span>
                <span className="font-black">-₹{Number(item.deduction).toLocaleString('en-IN')}</span>
              </div>
            ))}

            <div className="flex justify-between items-center pt-3 border-t border-white/80 text-sm">
              <span className="font-black text-[#17251C]">Net Doorstep Payout:</span>
              <span className="text-xl font-black text-[#0BAA4B]">
                ₹{Number(valuationResult.estimated_price).toLocaleString('en-IN')}
              </span>
            </div>
          </div>

          {/* Action buttons */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => setCurrentScreen(4)}
              className="w-1/3 glass-card hover:bg-white text-[#17251C] font-black py-3.5 rounded-2xl transition text-xs"
            >
              ← Edit Answers
            </button>
            <button
              onClick={() => setCurrentScreen(6)}
              className="w-2/3 bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black py-3.5 rounded-2xl shadow-xl shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 text-sm"
            >
              Proceed to Doorstep Pickup <ArrowRight className="w-4 h-4" />
            </button>
          </div>

        </div>
      )}

      {/* ================= SCREEN 6: DOORSTEP BOOKING & PAYOUT DETAILS ================= */}
      {currentScreen === 6 && (
        <form onSubmit={handleSubmitBooking} className="max-w-xl mx-auto glass-panel rounded-3xl p-5 sm:p-7 shadow-sm space-y-5 animate-fade-in text-xs">

          <div className="border-b border-white/80 pb-3">
            <span className="text-[10px] font-black uppercase text-[#0BAA4B] bg-[#E8F8ED] px-2.5 py-0.5 rounded-full border border-[#0BAA4B]/20">
              Final Step
            </span>
            <h3 className="text-lg sm:text-xl font-black text-[#17251C] mt-1">Book Free Doorstep Pickup</h3>
            <p className="text-xs text-[#7B8980]">Our certified agent will visit your home and disburse instant cash</p>
          </div>

          {/* Personal Info */}
          <div className="space-y-3">
            <h4 className="font-black text-[#17251C] text-sm">1. Customer Information</h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div>
                <label className="block font-bold text-[#17251C] mb-1">Full Name *</label>
                <input
                  type="text"
                  required
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                  placeholder="e.g. Mohamed K."
                  className="w-full p-2.5 glass-input rounded-xl font-bold"
                />
              </div>
              <div>
                <label className="block font-bold text-[#17251C] mb-1">Mobile Number *</label>
                <input
                  type="tel"
                  required
                  value={customerPhone}
                  onChange={(e) => setCustomerPhone(e.target.value)}
                  placeholder="e.g. 9876543210"
                  className="w-full p-2.5 glass-input rounded-xl font-bold"
                />
              </div>
            </div>
          </div>

          {/* Address */}
          <div className="space-y-3">
            <h4 className="font-black text-[#17251C] text-sm flex items-center gap-1.5">
              <MapPin className="w-4 h-4 text-[#0BAA4B]" /> 2. Pickup Address
            </h4>
            <textarea
              required
              rows={2}
              value={pickupAddress}
              onChange={(e) => setPickupAddress(e.target.value)}
              placeholder="Door No, Street Name, Area / Landmark"
              className="w-full p-2.5 glass-input rounded-xl font-medium"
            />
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-bold text-[#17251C] mb-1">City</label>
                <input
                  type="text"
                  required
                  value={pickupCity}
                  onChange={(e) => setPickupCity(e.target.value)}
                  className="w-full p-2.5 glass-input rounded-xl font-bold"
                />
              </div>
              <div>
                <label className="block font-bold text-[#17251C] mb-1">Pincode</label>
                <input
                  type="text"
                  required
                  value={pickupPincode}
                  onChange={(e) => setPickupPincode(e.target.value)}
                  className="w-full p-2.5 glass-input rounded-xl font-bold"
                />
              </div>
            </div>
          </div>

          {/* Date & Slot */}
          <div className="space-y-3">
            <h4 className="font-black text-[#17251C] text-sm flex items-center gap-1.5">
              <Calendar className="w-4 h-4 text-[#0BAA4B]" /> 3. Preferred Date & Time
            </h4>
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <input
                type="date"
                required
                value={pickupDate}
                onChange={(e) => setPickupDate(e.target.value)}
                className="w-full p-2.5 glass-input rounded-xl font-bold"
              />
              <select
                value={pickupSlot}
                onChange={(e) => setPickupSlot(e.target.value)}
                className="w-full p-2.5 glass-input rounded-xl font-bold"
              >
                <option value="Morning (10:00 AM - 1:00 PM)">Morning (10:00 AM - 1:00 PM)</option>
                <option value="Afternoon (1:00 PM - 5:00 PM)">Afternoon (1:00 PM - 5:00 PM)</option>
                <option value="Evening (5:00 PM - 8:00 PM)">Evening (5:00 PM - 8:00 PM)</option>
              </select>
            </div>
          </div>

          {/* Payment Method */}
          <div className="space-y-3">
            <h4 className="font-black text-[#17251C] text-sm flex items-center gap-1.5">
              <Banknote className="w-4 h-4 text-[#0BAA4B]" /> 4. Instant Payment Details
            </h4>

            <div className="grid grid-cols-2 gap-3">
              <button
                type="button"
                onClick={() => setBeneficiaryType('UPI')}
                className={`p-3 rounded-2xl border-2 font-black transition ${beneficiaryType === 'UPI'
                    ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38]'
                    : 'glass-card text-[#7B8980]'
                  }`}
              >
                Instant UPI (GPay / PhonePe)
              </button>
              <button
                type="button"
                onClick={() => setBeneficiaryType('BANK')}
                className={`p-3 rounded-2xl border-2 font-black transition ${beneficiaryType === 'BANK'
                    ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38]'
                    : 'glass-card text-[#7B8980]'
                  }`}
              >
                Direct Bank Transfer
              </button>
            </div>

            {beneficiaryType === 'UPI' ? (
              <div>
                <label className="block font-bold text-[#17251C] mb-1">UPI ID (e.g. mobile@okaxis) *</label>
                <input
                  type="text"
                  required
                  value={beneficiaryUpiId}
                  onChange={(e) => setBeneficiaryUpiId(e.target.value)}
                  placeholder="e.g. 9876543210@paytm"
                  className="w-full p-2.5 glass-input rounded-xl font-bold"
                />
              </div>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <input
                  type="text"
                  required
                  placeholder="Bank Account Number"
                  value={beneficiaryAccountNo}
                  onChange={(e) => setBeneficiaryAccountNo(e.target.value)}
                  className="p-2.5 glass-input rounded-xl font-bold"
                />
                <input
                  type="text"
                  required
                  placeholder="IFSC Code"
                  value={beneficiaryIfsc}
                  onChange={(e) => setBeneficiaryIfsc(e.target.value.toUpperCase())}
                  className="p-2.5 glass-input rounded-xl font-bold font-mono"
                />
              </div>
            )}
          </div>

          <button
            type="submit"
            disabled={submitting}
            className="w-full bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black py-4 rounded-2xl shadow-xl shadow-[#0BAA4B]/25 transition flex items-center justify-center gap-2 text-sm"
          >
            {submitting ? 'Confirming Doorstep Pickup...' : 'Confirm Free Doorstep Pickup Booking →'}
          </button>

        </form>
      )}

      {/* ================= SCREEN 7: ORDER CONFIRMATION & TRACKING TIMELINE ================= */}
      {currentScreen === 7 && createdOrder && (
        <div className="max-w-xl mx-auto glass-panel rounded-3xl p-6 sm:p-8 shadow-sm space-y-6 animate-fade-in text-center">

          <div className="w-16 h-16 rounded-full bg-[#E8F8ED] text-[#0BAA4B] flex items-center justify-center mx-auto shadow-md shadow-[#0BAA4B]/20 border border-[#0BAA4B]/30">
            <CheckCircle2 className="w-9 h-9" />
          </div>

          <div>
            <h3 className="text-2xl font-black text-[#17251C]">Pickup Booked Successfully!</h3>
            <p className="text-xs text-[#7B8980] mt-1">Our certified technician will visit your location to inspect the device.</p>
          </div>

          {/* Request ID Badge */}
          <div className="glass-card rounded-2xl p-4 flex items-center justify-between">
            <div className="text-left">
              <span className="text-[10px] text-[#7B8980] font-black uppercase">Request ID</span>
              <h4 className="text-lg font-black text-[#17251C] font-mono">{createdOrder.sale_code}</h4>
            </div>
            <button
              onClick={() => {
                navigator.clipboard.writeText(createdOrder.sale_code);
                setCopiedCode(true);
                setTimeout(() => setCopiedCode(false), 2000);
              }}
              className="px-3 py-1.5 bg-white border border-[#0BAA4B]/30 rounded-xl text-xs font-black text-[#0BAA4B] hover:bg-[#E8F8ED] transition flex items-center gap-1 shadow-sm"
            >
              <Copy className="w-3.5 h-3.5" />
              <span>{copiedCode ? 'Copied!' : 'Copy'}</span>
            </button>
          </div>

          {/* 5-Stage Visual Timeline */}
          <div className="text-left space-y-4 pt-2">
            <h4 className="font-black text-sm text-[#17251C]">Live Order Status:</h4>

            <div className="space-y-4 pl-3 border-l-2 border-[#0BAA4B]">
              <div className="relative pl-5">
                <div className="absolute -left-[19px] top-0.5 w-4 h-4 rounded-full bg-[#0BAA4B] ring-4 ring-[#E8F8ED]" />
                <strong className="text-xs text-[#17251C] block font-black">1. Request Submitted</strong>
                <span className="text-[10px] text-[#7B8980]">Valuation generated & details received</span>
              </div>

              <div className="relative pl-5">
                <div className="absolute -left-[19px] top-0.5 w-4 h-4 rounded-full bg-[#0BAA4B] ring-4 ring-[#E8F8ED]" />
                <strong className="text-xs text-[#17251C] block font-black">2. Quote Generated</strong>
                <span className="text-[10px] text-[#0BAA4B] font-bold">Estimated ₹{Number(createdOrder.estimated_price).toLocaleString('en-IN')}</span>
              </div>

              <div className="relative pl-5">
                <div className="absolute -left-[19px] top-0.5 w-4 h-4 rounded-full bg-slate-300" />
                <strong className="text-xs text-[#7B8980] block font-black">3. Pickup Scheduled</strong>
                <span className="text-[10px] text-[#7B8980]">Assigned to field pickup specialist</span>
              </div>

              <div className="relative pl-5">
                <div className="absolute -left-[19px] top-0.5 w-4 h-4 rounded-full bg-slate-300" />
                <strong className="text-xs text-[#7B8980] block font-black">4. Device Inspection</strong>
                <span className="text-[10px] text-[#7B8980]">In-person hardware and IMEI verification</span>
              </div>

              <div className="relative pl-5">
                <div className="absolute -left-[19px] top-0.5 w-4 h-4 rounded-full bg-slate-300" />
                <strong className="text-xs text-[#7B8980] block font-black">5. Final Price & Instant Payout</strong>
                <span className="text-[10px] text-[#7B8980]">Direct transfer to {createdOrder.beneficiary_upi_id || 'Bank account'}</span>
              </div>
            </div>
          </div>

          <button
            onClick={() => {
              setCurrentScreen(1);
              setSelectedModel(null);
              setSelectedVariant(null);
              setSelectedOptionCodes([]);
            }}
            className="w-full bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black py-3.5 rounded-2xl shadow-lg transition text-xs"
          >
            Sell Another Device →
          </button>

        </div>
      )}

    </div>
  );
}
