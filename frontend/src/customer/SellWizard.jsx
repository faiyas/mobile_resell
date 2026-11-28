import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import {
  Smartphone, Tablet, Laptop, Watch, AlertOctagon, Layers,
  Search, ArrowRight, ArrowLeft, Check, CheckCircle2, ChevronRight,
  Sparkles, ShieldCheck, MapPin, Calendar, Clock, CreditCard, Banknote,
  HelpCircle, AlertTriangle, Copy, Truck, Gift, FileText, X
} from 'lucide-react';
import { api } from '../services/api';
import { formatImageSrc } from '../utils/imageCompressor';

function ResponsiveModal({ isOpen, onClose, title, children }) {
  if (!isOpen) return null;
  return createPortal(
    <div className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
      <div 
        className="w-full sm:max-w-md bg-white rounded-t-3xl sm:rounded-2xl shadow-2xl border border-slate-200 flex flex-col max-h-[90vh] sm:max-h-[85vh] overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="p-4 sm:p-5 border-b border-slate-100 flex items-center justify-between shrink-0 bg-slate-50/50">
          <h3 className="font-extrabold text-base text-slate-900">{title}</h3>
          <button 
            type="button" 
            onClick={onClose} 
            className="p-1.5 rounded-full hover:bg-slate-200 text-slate-400 hover:text-slate-700 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-4 sm:p-6 overflow-y-auto flex-1">
          {children}
        </div>
      </div>
    </div>,
    document.body
  );
}

export default function SellWizard({ onOrderCreated, currentUser, onOpenAuth }) {
  // Navigation: 1=Category, 2=Brand, 3=Model&Variant, 3.5=TriageHealthCheck, 4=Questionnaire(Steps 2-10), 5=Quote, 6=PickupBooking, 7=Success
  const [currentScreen, setCurrentScreen] = useState(1);
  const [questionStepIndex, setQuestionStepIndex] = useState(0);

  // Triage Health Check Questions (Dynamic DB-driven)
  const [triageQuestions, setTriageQuestions] = useState([]);
  const [triageAnswers, setTriageAnswers] = useState({}); // code -> 'YES' | 'NO'
  const [triageLoading, setTriageLoading] = useState(false);

  // Dynamic DB Lists
  const [categories, setCategories] = useState([]);
  const [brands, setBrands] = useState([]);
  const [brandsLoading, setBrandsLoading] = useState(true);
  const [seriesList, setSeriesList] = useState([]);
  const [models, setModels] = useState([]);
  const [questionSteps, setQuestionSteps] = useState([]);

  // Selections
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedBrand, setSelectedBrand] = useState(null);
  const [selectedSeriesId, setSelectedSeriesId] = useState('ALL');
  const [selectedModel, setSelectedModel] = useState(null);
  const [selectedVariant, setSelectedVariant] = useState(null);
  const defaultHeroSlides = [
    {
      type: 'IMAGE',
      image_base64: '/banners/hero_buyback.png',
      title: 'Check Value • Book Pickup • Get Paid',
      is_active: true
    },
    {
      type: 'IMAGE',
      image_base64: '/banners/hero_upgrade.png',
      title: 'Upgrade Smarter with Dolly Buyback',
      is_active: true
    },
    {
      type: 'IMAGE',
      image_base64: '/banners/hero_value.png',
      title: 'Turn Phones Into Value',
      is_active: true
    }
  ];
  const [heroSlides, setHeroSlides] = useState(defaultHeroSlides);
  const [currentSlideIdx, setCurrentSlideIdx] = useState(0);

  // Auto-cycle hero slides every 5 seconds
  useEffect(() => {
    if (heroSlides.length <= 1) return;
    const timer = setInterval(() => {
      setCurrentSlideIdx((prev) => (prev + 1) % heroSlides.length);
    }, 5000);
    return () => clearInterval(timer);
  }, [heroSlides.length]);
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
  const [visibleModelCount, setVisibleModelCount] = useState(12);
  const [brandModelsLoading, setBrandModelsLoading] = useState(false);

  useEffect(() => {
    setVisibleModelCount(12);
  }, [modelSearch, selectedSeriesId]);

  // Valuation Quote
  const [valuationResult, setValuationResult] = useState(null);
  const [valuing, setValuing] = useState(false);

  // Customer Contact & Pickup Form
  // Pickup Cutoff Rule:
  // Same-day is strictly prohibited.
  // After 8:00 PM IST (20:00), earliest pickup is Day After Tomorrow (+2 days).
  // Before 8:00 PM IST, earliest pickup is Tomorrow (+1 day).
  const getEarliestPickupDateStr = () => {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
    const isLate = istDate.getHours() >= 20;
    istDate.setDate(istDate.getDate() + (isLate ? 2 : 1));
    return istDate.toISOString().split('T')[0];
  };

  const isAfter8PMCutoff = () => {
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
    return istDate.getHours() >= 20;
  };

  const [customerName, setCustomerName] = useState(currentUser?.full_name || '');
  const [customerPhone, setCustomerPhone] = useState(currentUser?.phone || '');
  const [customerEmail, setCustomerEmail] = useState(currentUser?.email || '');
  const [pickupAddress, setPickupAddress] = useState(currentUser?.default_address || '');
  const [pickupCity, setPickupCity] = useState(currentUser?.city || '');
  const [pickupPincode, setPickupPincode] = useState(currentUser?.pincode || '');
  const [pickupDate, setPickupDate] = useState(getEarliestPickupDateStr());
  const [pickupSlot, setPickupSlot] = useState('Afternoon (1:00 PM - 5:00 PM)');

  // Live Location & Pincode Lookup States
  const [detectingLocation, setDetectingLocation] = useState(false);
  const [pincodeLoading, setPincodeLoading] = useState(false);
  const [pincodeInfo, setPincodeInfo] = useState(null);

  const handleDetectLocation = () => {
    if (!navigator.geolocation) {
      alert('Geolocation is not supported by your browser.');
      return;
    }
    setDetectingLocation(true);
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const { latitude, longitude } = pos.coords;
          const res = await fetch(`https://nominatim.openstreetmap.org/reverse?format=json&lat=${latitude}&lon=${longitude}`);
          if (res.ok) {
            const data = await res.json();
            const addr = data.address || {};
            const city = addr.city || addr.town || addr.municipality || addr.state_district || addr.suburb || 'City';
            const postcode = addr.postcode ? addr.postcode.replace(/\D/g, '').slice(0, 6) : '';
            const roadParts = [addr.house_number, addr.road, addr.neighbourhood, addr.suburb].filter(Boolean);
            const fullStreet = roadParts.length > 0 ? roadParts.join(', ') : (data.display_name?.split(',').slice(0, 3).join(',') || '');
            
            if (fullStreet) setPickupAddress(fullStreet);
            if (city) setPickupCity(city);
            if (postcode && postcode.length === 6) {
              setPickupPincode(postcode);
              verifyPincode(postcode);
            }
          }
        } catch (err) {
          console.warn('Reverse geocode failed:', err);
        } finally {
          setDetectingLocation(false);
        }
      },
      () => {
        setDetectingLocation(false);
        alert('Could not detect location. Please enter address manually.');
      },
      { timeout: 10000, enableHighAccuracy: true }
    );
  };

  const verifyPincode = async (pin) => {
    const clean = String(pin || '').trim().replace(/\D/g, '');
    if (clean.length !== 6) {
      setPincodeInfo(null);
      return;
    }
    setPincodeLoading(true);
    try {
      const res = await api.lookupPincode(clean);
      if (res && res.valid) {
        setPincodeInfo(res);
        if (res.city) {
          setPickupCity(res.city);
        }
      } else {
        setPincodeInfo({ valid: false, message: 'Invalid PIN code' });
      }
    } catch {
      setPincodeInfo(null);
    } finally {
      setPincodeLoading(false);
    }
  };

  // Payout Method
  const [beneficiaryType, setBeneficiaryType] = useState('UPI');
  const [beneficiaryName, setBeneficiaryName] = useState(currentUser?.full_name || '');
  const [beneficiaryUpiId, setBeneficiaryUpiId] = useState(currentUser?.default_upi_id || '');
  const [beneficiaryAccountNo, setBeneficiaryAccountNo] = useState('');
  const [beneficiaryIfsc, setBeneficiaryIfsc] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [createdOrder, setCreatedOrder] = useState(null);
  const [copiedCode, setCopiedCode] = useState(false);

  // Modal & Address Toggle States
  const [isEditingAddress, setIsEditingAddress] = useState(false);
  const [summaryModalOpen, setSummaryModalOpen] = useState(false);

  // Helper: Deduplicate condition categories/steps by trimmed name
  const deduplicateSteps = (steps) => {
    if (!Array.isArray(steps)) return [];
    const seen = new Set();
    const result = [];
    for (const s of steps) {
      const key = (s.name || '').trim().toLowerCase();
      if (!key) continue;
      if (!seen.has(key)) {
        seen.add(key);
        result.push(s);
      }
    }
    return result;
  };

  // Helper: Get upcoming 7 pickup date slots
  const getUpcomingDates = () => {
    const list = [];
    const now = new Date();
    const istOffset = 5.5 * 60 * 60 * 1000;
    const istDate = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
    const isLate = istDate.getHours() >= 20;
    const startOffset = isLate ? 2 : 1;
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

    for (let i = 0; i < 7; i++) {
      const d = new Date(now.getTime() + (now.getTimezoneOffset() * 60000) + istOffset);
      d.setDate(d.getDate() + startOffset + i);
      const isoStr = d.toISOString().split('T')[0];
      const monthStr = months[d.getMonth()];
      const dayNum = String(d.getDate()).padStart(2, '0');
      const dayOfWeek = days[d.getDay()];
      list.push({
        iso: isoStr,
        month: monthStr,
        dayNum: dayNum,
        dayOfWeek: dayOfWeek,
        formatted: `${monthStr} ${dayNum} ${dayOfWeek}`
      });
    }
    return list;
  };

  // Initial Load: Categories, Brands & CMS in ONE Parallel Batch (0ms on repeat via SWR)
  useEffect(() => {
    loadInitialData();
  }, []);

  useEffect(() => {
    if (currentUser) {
      if (!customerName) setCustomerName(currentUser.full_name || '');
      if (!customerPhone) setCustomerPhone(currentUser.phone || '');
      if (!customerEmail) setCustomerEmail(currentUser.email || '');
      if (!pickupAddress) setPickupAddress(currentUser.default_address || '');
      if (!pickupCity) setPickupCity(currentUser.city || '');
      if (!pickupPincode && currentUser.pincode) {
        setPickupPincode(currentUser.pincode);
        verifyPincode(currentUser.pincode);
      }
      if (!beneficiaryName) setBeneficiaryName(currentUser.full_name || '');
      if (!beneficiaryUpiId && currentUser.default_upi_id) setBeneficiaryUpiId(currentUser.default_upi_id);
    }
  }, [currentUser]);

  const loadInitialData = async () => {
    try {
      setBrandsLoading(true);
      // 1. Fetch Categories, Initial Brands, and Hero CMS simultaneously (0ms when cached)
      const [cats, initialBrands, cmsData] = await Promise.all([
        api.getCategories().catch(() => []),
        api.getBrands(false, false).catch(() => []),
        api.getCMSSections().catch(() => []),
      ]);
      setCategories(cats);
      if (Array.isArray(initialBrands) && initialBrands.length > 0) {
        setBrands(initialBrands);
      }
      setBrandsLoading(false);

      const sections = Array.isArray(cmsData) ? cmsData : (Array.isArray(cmsData?.results) ? cmsData.results : []);
      const heroSec = sections.find((s) => s.section_type === 'HERO_CAROUSEL');
      if (heroSec && Array.isArray(heroSec.data_json?.slides)) {
        const activeSlides = heroSec.data_json.slides.filter((s) => s.is_active && (s.image_base64 || s.type !== 'IMAGE'));
        if (activeSlides.length > 0) {
          setHeroSlides(activeSlides);
        }
      }

      if (cats.length > 0) {
        setSelectedCategory(cats[0]);
      }

      // 2. Pre-fetch condition categories questionnaire in background so it never blocks front page paint
      api.getConditionCategories().then((qSteps) => {
        setQuestionSteps(deduplicateSteps(qSteps));
      }).catch(() => {});
    } catch (err) {
      console.error("Initial load failed:", err);
      setBrandsLoading(false);
    }
  };

  const handleSelectCategory = async (category) => {
    setSelectedCategory(category);
    setSelectedBrand(null);
    setSelectedModel(null);
    setSelectedVariant(null);
    setBrandsLoading(true);
    try {
      const brandsData = await api.getBrands(false, false, category.id);
      setBrands(brandsData);
    } catch (e) {
      console.error(e);
    } finally {
      setBrandsLoading(false);
    }
  };

  const handleSelectBrand = async (brand) => {
    setSelectedBrand(brand);
    setSelectedModel(null);
    setSelectedVariant(null);
    setSelectedSeriesId('ALL');
    setModelSearch('');
    setVisibleModelCount(12);
    setBrandModelsLoading(true);
    try {
      const [modelsData, seriesData, brandSteps] = await Promise.all([
        api.getModels(brand.id),
        api.getSeries(brand.id),
        api.getConditionCategories(false, brand.id).catch(() => []),
      ]);
      const safeModels = Array.isArray(modelsData) ? modelsData : (modelsData?.results || []);
      setModels(safeModels);
      setSeriesList(Array.isArray(seriesData) ? seriesData : []);
      if (brandSteps && brandSteps.length > 0) {
        setQuestionSteps(deduplicateSteps(brandSteps));
      }
      setCurrentScreen(3);
    } catch (e) {
      console.error(e);
    } finally {
      setBrandModelsLoading(false);
    }
  };

  const handleSelectModel = (model) => {
    setSelectedModel(model);
    if (model.variants && model.variants.length > 0) {
      setSelectedVariant(model.variants[0]);
    } else {
      setSelectedVariant(null);
    }
    setTimeout(() => {
      document.getElementById('sell-variant-panel')?.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }, 60);
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

  const computeValuation = async (overrideTriageAnswers = null) => {
    if (!selectedVariant) return;
    setValuing(true);
    try {
      const answersToUse = overrideTriageAnswers || triageAnswers;
      const res = await api.calculateEstimate(selectedVariant.id, selectedOptionCodes, answersToUse);
      setValuationResult(res);
      setCurrentScreen(5); // Show quote screen
    } catch (e) {
      alert("Valuation calculation failed: " + e.message);
    } finally {
      setValuing(false);
    }
  };

  const handleTriageAnswer = (code, val) => {
    setTriageAnswers(prev => {
      const updated = { ...prev, [code]: val };
      // If answered NO, find disabled questions and clear them
      const qObj = triageQuestions.find(q => q.code === code);
      if (val === 'NO' && qObj && Array.isArray(qObj.disables_question_codes)) {
        for (const dc of qObj.disables_question_codes) {
          delete updated[dc];
        }
      }
      return updated;
    });
  };

  // Compute disabled triage question codes based on current answers
  const getDisabledTriageCodes = () => {
    const disabled = new Set();
    for (const q of triageQuestions) {
      if (triageAnswers[q.code] === 'NO' && Array.isArray(q.disables_question_codes)) {
        for (const dc of q.disables_question_codes) {
          disabled.add(dc);
        }
      }
    }
    return disabled;
  };

  const getVisibleTriageQuestions = () => {
    const disabled = getDisabledTriageCodes();
    return triageQuestions.filter(q => !disabled.has(q.code));
  };

  const handleSubmitBooking = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!selectedVariant) return;

    if (!currentUser) {
      if (onOpenAuth) onOpenAuth();
      return;
    }

    const addr = pickupAddress || currentUser.default_address;
    if (!addr || !addr.trim()) {
      setIsEditingAddress(true);
      alert("Please provide your doorstep pickup address.");
      return;
    }

    const cleanPin = String(pickupPincode || currentUser.pincode || '').replace(/\D/g, '');
    if (cleanPin.length !== 6) {
      setIsEditingAddress(true);
      alert("Please enter a valid 6-digit doorstep pincode.");
      return;
    }

    let currentPinInfo = pincodeInfo;
    if (!currentPinInfo || currentPinInfo.pincode !== cleanPin) {
      try {
        currentPinInfo = await api.lookupPincode(cleanPin);
        setPincodeInfo(currentPinInfo);
      } catch {}
    }

    if (currentPinInfo && (currentPinInfo.valid === false || currentPinInfo.serviceable === false)) {
      setIsEditingAddress(true);
      alert(currentPinInfo.message || `Not deliverable: Doorstep pickup is not available for pincode ${cleanPin}.`);
      return;
    }

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
        triage_answers: triageAnswers,
        customer_name: customerName || currentUser.full_name || 'Customer',
        customer_phone: customerPhone || currentUser.phone || '',
        customer_email: customerEmail || currentUser.email || '',
        pickup_address: addr.trim(),
        pickup_city: (pickupCity || currentUser.city || 'Doorstep Pickup').trim(),
        pickup_pincode: (pickupPincode || currentUser.pincode || '').trim(),
        pickup_date: pickupDate,
        pickup_slot: pickupSlot,
        beneficiary_type: beneficiaryType,
        beneficiary_name: beneficiaryName || customerName || currentUser.full_name || '',
        beneficiary_upi_id: beneficiaryUpiId || currentUser.default_upi_id || '',
        beneficiary_account_no: beneficiaryAccountNo,
        beneficiary_ifsc: beneficiaryIfsc,
      };
      const res = await api.submitSale(payload);
      if (payload.customer_phone) {
        try { localStorage.setItem('recell_customer_phone', payload.customer_phone); } catch (_) {}
      }
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
    <div className="max-w-6xl mx-auto px-3 sm:px-6 py-2 sm:py-5 space-y-5">

      {/* ================= 1. PROMINENT HERO SECTION BANNER ================= */}
      {currentScreen <= 2 && heroSlides.length > 0 && (() => {
        const slide = heroSlides[currentSlideIdx] || heroSlides[0];
        return (
          <div className="relative overflow-hidden rounded-3xl shadow-xl transition-all duration-500 group border border-emerald-500/20 bg-slate-900">
            {slide.type === 'IMAGE' && slide.image_base64 ? (
              <div className="relative w-full aspect-[2.7/1] max-h-[380px] min-h-[160px] overflow-hidden rounded-3xl">
                <img
                  src={formatImageSrc(slide.image_base64)}
                  alt={slide.title || 'Promotional Banner'}
                  className="w-full h-full object-cover transition-opacity duration-500"
                />
                {slide.title && (
                  <div className="hidden sm:block absolute bottom-4 left-4 sm:bottom-6 sm:left-6 bg-black/60 backdrop-blur-md text-white text-xs sm:text-sm font-black px-4 py-2 rounded-2xl border border-white/20">
                    {slide.title}
                  </div>
                )}
              </div>
            ) : (
              <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-6 sm:p-8 rounded-3xl shadow-xl flex flex-col md:flex-row items-center justify-between gap-6 border border-emerald-400/30">
                <div className="space-y-2 max-w-xl">
                  <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 text-white px-3 py-1 rounded-full">
                    {slide.badge || '1103 RECELL · Buyback Company'}
                  </span>
                  <h2 className="text-2xl sm:text-4xl font-black mt-2 leading-tight">
                    {slide.title || 'Sell Your Old Device'}
                  </h2>
                  <p className="text-xs sm:text-sm text-[#E8F8ED] leading-relaxed">
                    {slide.subtitle || 'Get the best value for your phone, tablet, laptop & more with instant doorstep payout.'}
                  </p>
                  <div className="pt-2 flex items-center gap-3">
                    <button
                      type="button"
                      onClick={() => {
                        if (categories.length > 0) {
                          handleSelectCategory(categories[0]);
                          setCurrentScreen(2);
                        }
                      }}
                      className="bg-white text-[#087C38] font-black text-xs px-5 py-2.5 rounded-xl shadow-lg hover:bg-[#E8F8ED] transition flex items-center gap-1.5"
                    >
                      <span>{slide.cta_text || 'Start Selling Now'}</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>

                <div className="w-32 h-32 rounded-2xl bg-white/10 backdrop-blur border border-white/20 flex flex-col items-center justify-center p-3 text-center text-xs shrink-0">
                  <Smartphone className="w-10 h-10 text-white mb-2" />
                  <span className="font-extrabold text-[11px]">Instant Payout</span>
                  <span className="text-[9px] text-emerald-200">Doorstep Verification</span>
                </div>
              </div>
            )}

            {/* Dot Indicators */}
            {heroSlides.length > 1 && (
              <div className="absolute bottom-3 right-4 flex items-center gap-1.5 bg-black/40 backdrop-blur-md px-2.5 py-1 rounded-full z-10">
                {heroSlides.map((_, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setCurrentSlideIdx(i)}
                    className={`h-2 rounded-full transition-all ${
                      i === currentSlideIdx ? 'w-5 bg-white' : 'w-2 bg-white/50'
                    }`}
                  />
                ))}
              </div>
            )}
          </div>
        );
      })()}

      {/* ================= 2. CATEGORY PILLS BAR ================= */}
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
        <div className="space-y-6 animate-fade-in">

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
                <div className="w-14 h-14 rounded-2xl bg-[#E8F8ED] text-[#0BAA4B] flex items-center justify-center text-2xl group-hover:scale-110 transition-transform border border-[#0BAA4B]/20 overflow-hidden p-1.5">
                  {cat.image_base64 ? (
                    <img src={formatImageSrc(cat.image_base64)} alt={cat.name} className="w-full h-full object-contain" />
                  ) : (
                    <span>{cat.name === 'Mobile' ? '📱' : cat.name === 'Tablet' ? '📟' : cat.name === 'Laptop' ? '💻' : cat.name === 'Smartwatch' ? '⌚' : cat.name === 'Dead Phone' ? '⚠️' : '🔌'}</span>
                  )}
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
            {brandsLoading && brands.length === 0 ? (
              // Fast Shimmer Skeleton Cards during initial cold fetch
              Array.from({ length: 12 }).map((_, i) => (
                <div key={i} className="animate-pulse glass-card rounded-2xl p-4 flex flex-col items-center justify-center min-h-[140px] bg-white/50">
                  <div className="w-14 h-10 bg-slate-200/80 rounded-xl mb-3"></div>
                  <div className="w-20 h-3.5 bg-slate-200/80 rounded-full"></div>
                </div>
              ))
            ) : (
              filteredBrands.map((brand) => (
                <div
                  key={brand.id}
                  onClick={() => handleSelectBrand(brand)}
                  className="group cursor-pointer glass-card glass-card-hover rounded-2xl p-4 text-center transition flex flex-col items-center justify-center min-h-[140px]"
                >
                  <div className="w-16 h-12 flex items-center justify-center mb-2 group-hover:scale-105 transition-transform">
                    {brandModelsLoading && selectedBrand?.id === brand.id ? (
                      <div className="w-7 h-7 border-2 border-[#0BAA4B] border-t-transparent rounded-full animate-spin" />
                    ) : brand.logo_base64 ? (
                      <img src={formatImageSrc(brand.logo_base64)} alt={brand.name} className="max-h-10 max-w-full object-contain" />
                    ) : (
                      <Smartphone className="w-8 h-8 text-[#0BAA4B]" />
                    )}
                  </div>
                  <h4 className="font-black text-[#17251C] text-xs sm:text-sm group-hover:text-[#0BAA4B] transition">{brand.name}</h4>
                </div>
              ))
            )}
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
                {filteredModels.slice(0, visibleModelCount).map((m) => {
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
                          <img src={formatImageSrc(m.image_base64)} alt={m.name} className="max-h-full object-contain" />
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

              {filteredModels.length > visibleModelCount && (
                <div className="pt-1 text-center">
                  <button
                    type="button"
                    onClick={() => setVisibleModelCount(prev => prev + 12)}
                    className="w-full py-2.5 px-4 bg-white/90 hover:bg-white text-[#0BAA4B] font-extrabold text-xs rounded-2xl border border-emerald-200 shadow-sm hover:shadow transition flex items-center justify-center gap-2 group"
                  >
                    <span>Load More Models ({Math.min(visibleModelCount, filteredModels.length)} of {filteredModels.length})</span>
                    <span className="text-[10px] bg-emerald-100 text-[#0BAA4B] px-2 py-0.5 rounded-full font-bold group-hover:scale-105 transition-transform">
                      +{Math.min(12, filteredModels.length - visibleModelCount)}
                    </span>
                  </button>
                </div>
              )}
            </div>

            {/* Storage Variants Column */}
            <div id="sell-variant-panel" className="glass-panel rounded-3xl p-5 shadow-sm space-y-4">
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
                    onClick={async () => {
                      if (selectedModel?.has_warranty === false) {
                        setQuestionSteps(prev => prev
                          .filter(cat => !cat.name.toLowerCase().includes('warranty'))
                          .map(cat => ({
                            ...cat,
                            options: (cat.options || []).filter(opt => !opt.is_warranty)
                          }))
                          .filter(cat => cat.options.length > 0)
                        );
                      }
                      setTriageLoading(true);
                      try {
                        const tqs = await api.getTriageQuestions(false);
                        const safeTqs = Array.isArray(tqs) ? tqs : (tqs?.results || []);
                        if (safeTqs.length > 0) {
                          setTriageQuestions(safeTqs);
                          // Initialize default answers to 'YES'
                          const initAnswers = {};
                          safeTqs.forEach(q => { initAnswers[q.code] = 'YES'; });
                          setTriageAnswers(initAnswers);
                          setCurrentScreen(3.5); // Open Triage Health Check Screen
                          return;
                        }
                      } catch (err) {
                        console.warn("Could not load triage questions, proceeding to detailed questionnaire", err);
                      } finally {
                        setTriageLoading(false);
                      }
                      setQuestionStepIndex(0);
                      setCurrentScreen(4); // Fallback to cosmetic questionnaire
                    }}
                    disabled={!selectedVariant || triageLoading}
                    className="w-full bg-[#0BAA4B] hover:bg-[#087C38] disabled:bg-slate-200 disabled:text-slate-400 text-white font-black py-3.5 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 text-sm mt-4"
                  >
                    {triageLoading ? 'Loading Checks...' : 'Start Device Evaluation'} <ArrowRight className="w-4 h-4" />
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

      {/* ================= SCREEN 3.5: INITIAL HEALTH CHECK TRIAGE QUESTIONS ================= */}
      {currentScreen === 3.5 && (
        <div className="space-y-6 animate-fade-in max-w-2xl mx-auto">
          <div className="glass-panel rounded-3xl p-6 sm:p-8 shadow-sm space-y-6">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <div>
                <span className="text-[10px] font-black uppercase text-[#0BAA4B] bg-[#E8F8ED] px-2.5 py-0.5 rounded-full border border-[#0BAA4B]/20">
                  Step 2 of 11 · Initial Health Check
                </span>
                <h3 className="text-xl font-black text-[#17251C] mt-1.5">
                  {selectedModel?.name} ({selectedVariant?.ram ? `${selectedVariant.ram} / ` : ''}{selectedVariant?.storage})
                </h3>
                <p className="text-xs text-[#7B8980]">
                  Please answer these preliminary functional questions accurately to determine your initial evaluation offer.
                </p>
              </div>
            </div>

            {/* Questions List */}
            <div className="space-y-5">
              {getVisibleTriageQuestions().map((q, idx) => {
                const currentVal = triageAnswers[q.code] || 'YES';
                const isNo = currentVal === 'NO';
                const isYes = currentVal === 'YES';

                return (
                  <div key={q.id || q.code} className="p-4 rounded-2xl bg-white border border-slate-200/80 shadow-sm space-y-3">
                    <div className="flex items-start justify-between gap-3">
                      <div>
                        <h4 className="font-extrabold text-sm text-[#17251C]">
                          {idx + 1}. {q.question_text}
                        </h4>
                        {q.subtitle && (
                          <p className="text-xs text-[#7B8980] mt-1 leading-relaxed">
                            {q.subtitle}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Yes / No Choice Buttons */}
                    <div className="grid grid-cols-2 gap-3 pt-1">
                      <button
                        type="button"
                        onClick={() => handleTriageAnswer(q.code, 'YES')}
                        className={`py-3 px-4 rounded-xl border-2 font-black text-xs flex items-center justify-center gap-2 transition ${
                          isYes
                            ? 'bg-[#E8F8ED] border-[#0BAA4B] text-[#0BAA4B] shadow-sm'
                            : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <Check className="w-4 h-4" />
                        Yes
                      </button>

                      <button
                        type="button"
                        onClick={() => handleTriageAnswer(q.code, 'NO')}
                        className={`py-3 px-4 rounded-xl border-2 font-black text-xs flex items-center justify-center gap-2 transition ${
                          isNo
                            ? 'bg-rose-50 border-rose-500 text-rose-600 shadow-sm'
                            : 'bg-white border-slate-200 text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <X className="w-4 h-4" />
                        No
                      </button>
                    </div>

                    {/* Info note if answered NO */}
                    {isNo && (
                      <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200/60 text-[11px] text-amber-800 flex items-center gap-2">
                        <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0" />
                        <span>
                          {q.is_power_on_gate
                            ? "Device cannot power on. Dead phone minimum floor valuation rule will be applied."
                            : `Condition deduction will be applied (${q.deduction_type === 'PERCENTAGE' ? `${q.deduction_value_on_no}%` : `₹${q.deduction_value_on_no}`} deduction).`}
                        </span>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>

            {/* Navigation Buttons */}
            <div className="flex items-center justify-between pt-4 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setCurrentScreen(3)}
                className="flex items-center gap-1.5 text-xs font-black text-[#17251C] glass-card hover:bg-white px-4 py-2.5 rounded-xl transition"
              >
                <ArrowLeft className="w-3.5 h-3.5" /> Back to Variants
              </button>

              <button
                type="button"
                onClick={() => {
                  // If Power On is NO or dead phone, can jump straight to evaluation quote or continue
                  const isPowerOnNo = Object.entries(triageAnswers).some(([code, ans]) => {
                    const q = triageQuestions.find(item => item.code === code);
                    return q?.is_power_on_gate && ans === 'NO';
                  });

                  if (isPowerOnNo) {
                    // Direct to estimated quote for dead phone
                    computeValuation();
                  } else {
                    // Proceed to cosmetic defect questionnaire
                    setQuestionStepIndex(0);
                    setCurrentScreen(4);
                  }
                }}
                className="flex items-center gap-1.5 text-xs font-black text-white bg-[#0BAA4B] hover:bg-[#087C38] px-6 py-2.5 rounded-xl shadow-md shadow-[#0BAA4B]/20 transition"
              >
                Continue Evaluation <ArrowRight className="w-3.5 h-3.5" />
              </button>
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
                            <img src={formatImageSrc(opt.image_base64)} alt={opt.title} className="max-h-full max-w-full object-contain" />
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
                            <span className="text-[#7B8980] font-semibold">Verification:</span>
                            {opt.is_rejection ? (
                              <span className="font-black text-rose-600">Critical Check</span>
                            ) : opt.is_accessory_bonus ? (
                              <span className="font-black text-[#0BAA4B]">✓ Accessory Included</span>
                            ) : isSelected ? (
                              <span className="font-black text-[#0BAA4B]">✓ Selected</span>
                            ) : (
                              <span className="font-semibold text-[#7B8980]">Verified at Doorstep</span>
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

                {/* Smart Warning Banner if Invoice Bill not selected in accessories step */}
                {currentCat.options?.some(o => o.code.toLowerCase().includes('bill')) &&
                  !selectedOptionCodes.some(c => c.toLowerCase().includes('bill')) && (
                    <div className="bg-[#FFFBEB] border border-[#F59E0B]/40 rounded-2xl p-3 flex items-center gap-2 text-xs text-[#92400E]">
                      <AlertTriangle className="w-4 h-4 text-[#F59E0B] shrink-0" />
                      <span>Invoice Bill not selected. Warranty is set to &quot;No Warranty / Expired&quot;.</span>
                    </div>
                  )}

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
                      if (currentCat.is_mandatory && currentCat.options?.length > 0) {
                        const hasSelection = currentCat.options.some(o => selectedOptionCodes.includes(o.code));
                        if (!hasSelection) {
                          alert(`Please complete step: "${currentCat.name}" before proceeding.`);
                          return;
                        }
                      }
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

      {/* ================= SCREEN 5: FINAL VALUATION & DOORSTEP BOOKING ================= */}
      {currentScreen === 5 && valuationResult && (
        <div className="max-w-xl mx-auto space-y-6 animate-fade-in text-xs">

          {/* ================= TOP SECTION: DOORSTEP ADDRESS & PICKUP BOOKING ================= */}
          {currentUser ? (
            <div className="bg-white rounded-3xl p-5 sm:p-6 shadow-sm border border-slate-200/80 space-y-4">
              {/* Address Header */}
              <div className="flex items-start justify-between gap-3 border-b border-slate-100 pb-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="font-extrabold text-sm sm:text-base text-slate-900">
                      {customerName || currentUser.full_name || 'Customer'}
                    </span>
                    <span className="text-slate-300">|</span>
                    <span className="font-bold text-xs text-slate-600">
                      {customerPhone || currentUser.phone}
                    </span>
                  </div>
                  {!isEditingAddress ? (
                    <p className="text-xs text-slate-600 leading-relaxed">
                      {pickupAddress
                        ? `${pickupAddress}, ${pickupCity} ${pickupPincode}`
                        : `${currentUser.default_address || ''}, ${currentUser.city || ''} ${currentUser.pincode || ''}` || 'Doorstep Pickup Address'}
                    </p>
                  ) : null}
                </div>
                <button
                  type="button"
                  onClick={() => setIsEditingAddress(!isEditingAddress)}
                  className="text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] px-2.5 py-1 rounded-lg bg-emerald-50 border border-emerald-200 transition shrink-0"
                >
                  {isEditingAddress ? 'Done' : 'Change Address'}
                </button>
              </div>

              {/* Address Edit Form (if toggled) */}
              {isEditingAddress && (
                <div className="space-y-2.5 pt-1 animate-fade-in">
                  <div className="flex items-center justify-between">
                    <label className="text-[11px] font-bold text-slate-600">Doorstep Street Address</label>
                    <button
                      type="button"
                      onClick={handleDetectLocation}
                      disabled={detectingLocation}
                      className="text-[10px] font-bold text-emerald-800 bg-emerald-50 hover:bg-emerald-100 px-2 py-0.5 rounded border border-emerald-200 transition"
                    >
                      {detectingLocation ? 'Detecting GPS...' : '📍 Use GPS Location'}
                    </button>
                  </div>
                  <textarea
                    rows={2}
                    value={pickupAddress}
                    onChange={(e) => setPickupAddress(e.target.value)}
                    placeholder="Door No, Flat/House Name, Street Name, Landmark"
                    className="w-full p-2.5 text-xs rounded-xl border border-slate-200 focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]/30 font-medium"
                  />
                  <div className="grid grid-cols-2 gap-2">
                    <input
                      type="text"
                      value={pickupCity}
                      onChange={(e) => setPickupCity(e.target.value)}
                      placeholder="City"
                      className="p-2 text-xs rounded-xl border border-slate-200 font-bold"
                    />
                    <input
                      type="text"
                      maxLength={6}
                      value={pickupPincode}
                      onChange={(e) => {
                        const val = e.target.value.replace(/\D/g, '').slice(0, 6);
                        setPickupPincode(val);
                        if (val.length === 6) verifyPincode(val);
                        else setPincodeInfo(null);
                      }}
                      placeholder="PIN Code (e.g. 605008)"
                      className="p-2 text-xs rounded-xl border border-slate-200 font-mono font-bold"
                    />
                  </div>
                  {pincodeLoading && (
                    <p className="text-[11px] text-slate-500 font-semibold">Checking pincode serviceability...</p>
                  )}
                  {!pincodeLoading && pincodeInfo && (
                    <div
                      className={`p-2 rounded-xl text-[11px] font-bold border ${
                        pincodeInfo.valid && pincodeInfo.serviceable !== false
                          ? 'bg-emerald-50 border-emerald-200 text-emerald-800'
                          : 'bg-rose-50 border-rose-200 text-rose-700'
                      }`}
                    >
                      {pincodeInfo.valid && pincodeInfo.serviceable !== false ? '✓ ' : '✗ '}
                      {pincodeInfo.message || (pincodeInfo.serviceable !== false ? 'Doorstep pickup available' : 'Not deliverable in this pincode')}
                    </div>
                  )}
                  {/* Payment / Payout Preference Selector */}
                  <div className="pt-1 space-y-1.5">
                    <label className="block text-[11px] font-black text-slate-700">Payout Preference:</label>
                    <div className="grid grid-cols-3 gap-2">
                      <button
                        type="button"
                        onClick={() => setBeneficiaryType('UPI')}
                        className={`p-2 rounded-xl border text-center transition ${
                          beneficiaryType === 'UPI'
                            ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38] font-bold shadow-xs'
                            : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <span className="block text-[11px] font-extrabold">Instant UPI</span>
                        <span className="text-[9px] text-slate-400">GPay/PhonePe</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setBeneficiaryType('BANK')}
                        className={`p-2 rounded-xl border text-center transition ${
                          beneficiaryType === 'BANK'
                            ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38] font-bold shadow-xs'
                            : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <span className="block text-[11px] font-extrabold">Bank Transfer</span>
                        <span className="text-[9px] text-slate-400">NEFT / IMPS</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setBeneficiaryType('CASH')}
                        className={`p-2 rounded-xl border text-center transition ${
                          beneficiaryType === 'CASH'
                            ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38] font-bold shadow-xs'
                            : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'
                        }`}
                      >
                        <span className="block text-[11px] font-extrabold">Cash on Pickup</span>
                        <span className="text-[9px] text-[#0BAA4B] font-bold">In-app OTP</span>
                      </button>
                    </div>
                  </div>

                  {beneficiaryType === 'UPI' && (
                    <div>
                      <label className="block text-[11px] font-bold text-slate-600 mb-0.5">Instant UPI ID for Doorstep Transfer</label>
                      <input
                        type="text"
                        value={beneficiaryUpiId}
                        onChange={(e) => setBeneficiaryUpiId(e.target.value)}
                        placeholder="e.g. name@okaxis or 9876543210@paytm"
                        className="w-full p-2 text-xs rounded-xl border border-slate-200 font-mono"
                      />
                    </div>
                  )}

                  {beneficiaryType === 'BANK' && (
                    <div className="space-y-2">
                      <div>
                        <label className="block text-[11px] font-bold text-slate-600 mb-0.5">Account Number</label>
                        <input
                          type="text"
                          value={beneficiaryAccountNo}
                          onChange={(e) => setBeneficiaryAccountNo(e.target.value)}
                          placeholder="e.g. 50100234567890"
                          className="w-full p-2 text-xs rounded-xl border border-slate-200 font-mono"
                        />
                      </div>
                      <div className="grid grid-cols-2 gap-2">
                        <input
                          type="text"
                          value={beneficiaryIfsc}
                          onChange={(e) => setBeneficiaryIfsc(e.target.value.toUpperCase())}
                          placeholder="IFSC Code (e.g. HDFC0001234)"
                          className="p-2 text-xs rounded-xl border border-slate-200 font-mono font-bold"
                        />
                        <input
                          type="text"
                          value={beneficiaryName}
                          onChange={(e) => setBeneficiaryName(e.target.value)}
                          placeholder="Account Holder Name"
                          className="p-2 text-xs rounded-xl border border-slate-200 font-bold"
                        />
                      </div>
                    </div>
                  )}

                  {beneficiaryType === 'CASH' && (
                    <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200/70 text-[11px] text-amber-900 flex items-start gap-2">
                      <Banknote className="w-4 h-4 text-amber-600 shrink-0 mt-0.5" />
                      <div>
                        <span className="font-extrabold block">Cash on Pickup Chosen:</span>
                        <span>Our agent will hand over physical cash during doorstep pickup. You will verify via a 4-digit code shown in your tracking screen.</span>
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* Pickup Booking */}
              <div className="space-y-3 pt-1">
                <div>
                  <h4 className="font-black text-sm text-[#17251C]">Pickup Booking</h4>
                  <p className="text-[11px] font-bold text-slate-500 mt-0.5">Choose a pickup date</p>
                </div>

                {/* Horizontal Date Pills */}
                <div className="flex gap-2.5 overflow-x-auto pb-1.5 scrollbar-none">
                  {getUpcomingDates().map((dt) => {
                    const isSelected = pickupDate === dt.iso;
                    return (
                      <button
                        key={dt.iso}
                        type="button"
                        onClick={() => setPickupDate(dt.iso)}
                        className={`flex-shrink-0 w-20 py-2.5 px-1.5 rounded-2xl border-2 flex flex-col items-center justify-center transition active:scale-95 ${
                          isSelected
                            ? 'border-slate-900 bg-slate-900 text-white shadow-md'
                            : 'border-slate-200 bg-white text-slate-700 hover:border-slate-300'
                        }`}
                      >
                        <span className={`text-[10px] font-bold uppercase tracking-wider ${isSelected ? 'text-emerald-400' : 'text-slate-400'}`}>
                          {dt.month}
                        </span>
                        <span className="text-xl font-black my-0.5 leading-none">
                          {dt.dayNum}
                        </span>
                        <span className={`text-[10px] font-extrabold uppercase ${isSelected ? 'text-slate-200' : 'text-slate-500'}`}>
                          {dt.dayOfWeek}
                        </span>
                      </button>
                    );
                  })}
                </div>

                {/* Pickup Slot Selector */}
                <div className="space-y-1.5 pt-1">
                  <p className="text-[11px] font-bold text-slate-500">Choose a pickup slot</p>
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
                    {[
                      { id: 'Morning (10:00 AM - 1:00 PM)', label: 'Morning', time: '10 AM - 1 PM' },
                      { id: 'Afternoon (1:00 PM - 5:00 PM)', label: 'Afternoon', time: '1 PM - 5 PM' },
                      { id: 'Evening (5:00 PM - 8:00 PM)', label: 'Evening', time: '5 PM - 8 PM' },
                    ].map((slot) => {
                      const isSelected = pickupSlot === slot.id;
                      return (
                        <button
                          key={slot.id}
                          type="button"
                          onClick={() => setPickupSlot(slot.id)}
                          className={`p-2.5 rounded-xl border-2 font-bold text-left transition flex flex-col justify-center ${
                            isSelected
                              ? 'border-[#0BAA4B] bg-[#E8F8ED] text-[#087C38]'
                              : 'border-slate-200 bg-white text-slate-600 hover:border-slate-300'
                          }`}
                        >
                          <span className="text-xs font-black">{slot.label}</span>
                          <span className="text-[10px] opacity-75">{slot.time}</span>
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Book Pickup Button */}
                <div className="pt-2">
                  <button
                    type="button"
                    onClick={handleSubmitBooking}
                    disabled={submitting}
                    className="w-full bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black py-3.5 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 text-sm"
                  >
                    {submitting ? 'Booking Pickup...' : 'Book Pickup'}
                  </button>
                </div>
              </div>
            </div>
          ) : (
            /* Guest / Not Logged In View */
            <div className="bg-white rounded-3xl p-6 shadow-sm border border-slate-200/80 text-center space-y-4">
              <div className="w-12 h-12 bg-[#E8F8ED] text-[#0BAA4B] rounded-2xl flex items-center justify-center mx-auto shadow-sm">
                <Truck className="w-6 h-6" />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-[#17251C]">Doorstep Pickup & Instant Payout</h3>
                <p className="text-xs text-[#7B8980] mt-1 max-w-sm mx-auto">
                  Login to book your doorstep pickup slot, save delivery address, and receive cash or UPI directly.
                </p>
              </div>
              <button
                type="button"
                onClick={() => {
                  if (onOpenAuth) onOpenAuth();
                }}
                className="w-full py-3.5 px-6 rounded-2xl bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black text-sm shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2"
              >
                Login to Proceed / Book Pickup <ArrowRight className="w-4 h-4" />
              </button>
            </div>
          )}

          {/* ================= LOWER SECTION: SELL NOW FOR AMAZING PRICE ================= */}
          <div className="space-y-3">
            <h3 className="text-center font-extrabold text-base sm:text-lg text-[#17251C]">
              Sell Now For Amazing price
            </h3>

            <div className="bg-white rounded-3xl p-6 sm:p-7 shadow-sm border border-slate-200/80 text-center space-y-4">
              {/* Centered Device Graphic */}
              <div className="w-24 h-24 mx-auto flex items-center justify-center">
                {selectedModel?.image_base64 ? (
                  <img
                    src={formatImageSrc(selectedModel.image_base64)}
                    alt={selectedModel.name}
                    className="max-h-full max-w-full object-contain drop-shadow"
                  />
                ) : (
                  <Smartphone className="w-16 h-16 text-slate-400 stroke-1" />
                )}
              </div>

              <div>
                <h4 className="font-extrabold text-base text-[#17251C]">
                  {selectedBrand?.name || valuationResult.brand} {selectedModel?.name || valuationResult.model} ({selectedVariant?.storage || valuationResult.variant})
                </h4>
                <p className="text-xs text-slate-500 font-semibold mt-1">
                  Instantly Sell And Get
                </p>
                <div className="text-3xl sm:text-4xl font-black text-slate-900 tracking-tight mt-1">
                  ₹ {Number(valuationResult.estimated_price).toLocaleString('en-IN')}
                </div>
                {/* Thin readable disclaimer text */}
                <p className="text-[11px] font-normal text-slate-400 mt-1.5 max-w-sm mx-auto leading-normal">
                  * Note: Final buyback price may vary during doorstep physical evaluation based on actual device inspection.
                </p>
              </div>

              {/* BEST PRICE Section */}
              <div className="border-t border-slate-100 pt-3 text-left space-y-2">
                <span className="text-[10px] font-black uppercase tracking-wider text-rose-500 block">
                  BEST PRICE
                </span>
                <div className="flex items-center justify-between text-xs py-0.5">
                  <span className="text-slate-500">Get Value</span>
                  <span className="font-black text-slate-800">₹ {Number(valuationResult.estimated_price).toLocaleString('en-IN')}</span>
                </div>
                <div className="flex items-center justify-between text-xs py-0.5">
                  <span className="text-slate-500 font-medium">Get value</span>
                  <span className="font-black text-slate-800">₹ {Number(valuationResult.estimated_price).toLocaleString('en-IN')}</span>
                </div>
              </div>

              {/* View Evaluation Summary Link / Button */}
              <button
                type="button"
                onClick={() => setSummaryModalOpen(true)}
                className="w-full py-2.5 px-4 rounded-xl border border-slate-200 hover:bg-slate-50 text-xs font-bold text-slate-700 transition flex items-center justify-center gap-1.5"
              >
                <span>View Evaluation Summary</span>
                <ChevronRight className="w-4 h-4 text-slate-400" />
              </button>

              {/* Our assurance win your trust */}
              <div className="pt-4 border-t border-slate-100 text-left space-y-3">
                <h5 className="font-extrabold text-xs sm:text-sm text-center text-slate-900">
                  Our assurance win your trust
                </h5>

                <div className="grid grid-cols-2 gap-3 pt-1">
                  <div className="flex items-center gap-2.5 p-2 rounded-xl bg-slate-50/80 border border-slate-100">
                    <Truck className="w-6 h-6 text-slate-700 shrink-0 stroke-[1.5]" />
                    <span className="text-[10px] sm:text-[11px] font-bold text-slate-700 leading-tight">
                      Hassle-Less Doorstep Free Pickup
                    </span>
                  </div>
                  <div className="flex items-center gap-2.5 p-2 rounded-xl bg-slate-50/80 border border-slate-100">
                    <ShieldCheck className="w-6 h-6 text-slate-700 shrink-0 stroke-[1.5]" />
                    <span className="text-[10px] sm:text-[11px] font-bold text-slate-700 leading-tight">
                      Services offered across India
                    </span>
                  </div>
                  <div className="flex items-center gap-2.5 p-2 rounded-xl bg-slate-50/80 border border-slate-100">
                    <Sparkles className="w-6 h-6 text-slate-700 shrink-0 stroke-[1.5]" />
                    <span className="text-[10px] sm:text-[11px] font-bold text-slate-700 leading-tight">
                      Unbeatable Market Value
                    </span>
                  </div>
                  <div className="flex items-center gap-2.5 p-2 rounded-xl bg-slate-50/80 border border-slate-100">
                    <Banknote className="w-6 h-6 text-slate-700 shrink-0 stroke-[1.5]" />
                    <span className="text-[10px] sm:text-[11px] font-bold text-slate-700 leading-tight">
                      Instant Cash in Hand
                    </span>
                  </div>
                </div>
              </div>

              {/* Edit Answers link */}
              <div className="pt-2">
                <button
                  type="button"
                  onClick={() => setCurrentScreen(4)}
                  className="text-xs font-bold text-slate-500 hover:text-slate-800 transition"
                >
                  ← Edit Questionnaire Answers
                </button>
              </div>
            </div>
          </div>

          {/* Evaluation Summary Modal */}
          {summaryModalOpen && (
            <ResponsiveModal
              isOpen={summaryModalOpen}
              onClose={() => setSummaryModalOpen(false)}
              title="Evaluation Summary"
            >
              <div className="space-y-4 text-xs">
                {/* Variant & Model Name Confirmation */}
                <div className="p-2.5 rounded-xl bg-slate-100 flex items-center justify-between">
                  <span className="font-extrabold text-slate-800">
                    {valuationResult.brand} {valuationResult.model}
                  </span>
                  <span className="font-bold text-[#0BAA4B] bg-white px-2 py-0.5 rounded-md border border-slate-200">
                    {valuationResult.variant}
                  </span>
                </div>

                <div className="p-3 bg-slate-50 rounded-xl space-y-2 border border-slate-100">
                  <div className="flex justify-between items-center">
                    <span className="text-slate-600">Base Catalog Price (Flawless):</span>
                    <strong className="text-slate-900 font-bold">₹{Number(valuationResult.base_price).toLocaleString('en-IN')}</strong>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-600">Condition Deductions:</span>
                    <strong className="text-rose-600 font-bold">
                      {Number(valuationResult.total_deduction || (Number(valuationResult.base_price) - Number(valuationResult.estimated_price))) > 0
                        ? `-₹${Number(valuationResult.total_deduction || (Number(valuationResult.base_price) - Number(valuationResult.estimated_price))).toLocaleString('en-IN')}`
                        : '₹0 (Mint condition)'}
                    </strong>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="text-slate-600">Doorstep Pickup Fee:</span>
                    {Number(valuationResult.doorstep_fee || 0) > 0 ? (
                      <strong className="text-rose-600 font-bold">-₹{Number(valuationResult.doorstep_fee).toLocaleString('en-IN')}</strong>
                    ) : (
                      <strong className="text-[#0BAA4B] font-bold">FREE</strong>
                    )}
                  </div>
                  <div className="flex justify-between items-center pt-2 border-t border-slate-200 text-sm">
                    <span className="font-black text-slate-900">Calculated Offer:</span>
                    <span className="font-black text-[#0BAA4B]">₹{Number(valuationResult.estimated_price).toLocaleString('en-IN')}</span>
                  </div>
                </div>

                {/* Deductions Breakdown from Backend if available */}
                {Array.isArray(valuationResult.deductions) && valuationResult.deductions.length > 0 ? (
                  <div>
                    <h6 className="font-bold text-slate-700 mb-1.5">Applied Condition Deductions:</h6>
                    <div className="space-y-1.5 max-h-48 overflow-y-auto">
                      {valuationResult.deductions.map((d, dIdx) => (
                        <div key={dIdx} className="flex items-center justify-between p-2 rounded-lg bg-rose-50/60 border border-rose-100 text-[11px]">
                          <div>
                            <span className="font-bold text-slate-800 block">{d.title}</span>
                            <span className="text-[10px] text-slate-500">{d.category} · {d.rule_type}</span>
                          </div>
                          <span className="font-mono font-bold text-rose-600 shrink-0">
                            -₹{Number(d.deduction_amount).toLocaleString('en-IN')}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                ) : (
                  <div>
                    <h6 className="font-bold text-slate-700 mb-1.5">Selected Condition Details:</h6>
                    <div className="space-y-1 max-h-48 overflow-y-auto">
                      {selectedOptionCodes.length === 0 ? (
                        <p className="text-slate-400 italic">No defects selected (Device in excellent / mint condition).</p>
                      ) : (
                        selectedOptionCodes.map((code) => (
                          <div key={code} className="flex items-center gap-2 p-1.5 rounded-lg bg-slate-50 text-[11px]">
                            <span className="w-1.5 h-1.5 rounded-full bg-slate-400"></span>
                            <span className="font-mono text-slate-700 font-semibold">{code.replace(/_/g, ' ')}</span>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                )}

                <p className="text-[10px] text-slate-400 leading-relaxed italic">
                  * All evaluations are verified at doorstep by an authorized 1103 RECELL technician prior to instant payment disbursement.
                </p>

                <button
                  type="button"
                  onClick={() => setSummaryModalOpen(false)}
                  className="w-full py-2.5 bg-[#0BAA4B] text-white font-bold rounded-xl text-xs"
                >
                  Close Summary
                </button>
              </div>
            </ResponsiveModal>
          )}

        </div>
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
