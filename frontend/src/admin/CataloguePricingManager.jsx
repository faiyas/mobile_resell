import React, { useState, useEffect } from 'react';
import { 
  Smartphone, Plus, Edit2, Trash2, CheckCircle2, AlertCircle, 
  Search, Filter, RefreshCw, Layers, Shield, IndianRupee, 
  HelpCircle, Sparkles, ChevronRight, Check, X, ArrowRight,
  TrendingDown, TrendingUp, History, AlertTriangle, Eye, ShieldAlert, Upload
} from 'lucide-react';
import { api } from '../services/api';
import { fileToBase64 } from '../utils/imageCompressor';

export default function CataloguePricingManager() {
  // Sub-tabs: 'brands' | 'models' | 'variants' | 'categories' | 'deductions' | 'simulator' | 'history'
  const [subTab, setSubTab] = useState('brands');

  // Data states
  const [brands, setBrands] = useState([]);
  const [models, setModels] = useState([]);
  const [variants, setVariants] = useState([]);
  const [categories, setConditionCategories] = useState([]);
  const [options, setConditionOptions] = useState([]);
  const [priceHistory, setPriceHistory] = useState([]);

  const [loading, setLoading] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterBrandId, setFilterBrandId] = useState('');
  const [filterCategoryId, setFilterCategoryId] = useState('');

  // Modals state
  const [brandModalOpen, setBrandModalOpen] = useState(false);
  const [editingBrand, setEditingBrand] = useState(null);
  const [brandForm, setBrandForm] = useState({ name: '', logo_base64: '', display_order: 0, is_active: true });

  const [modelModalOpen, setModelModalOpen] = useState(false);
  const [editingModel, setEditingModel] = useState(null);
  const [modelForm, setModelForm] = useState({ brand: '', name: '', release_year: 2024, image_base64: '', is_active: true });

  const [variantModalOpen, setVariantModalOpen] = useState(false);
  const [editingVariant, setEditingVariant] = useState(null);
  const [variantForm, setVariantForm] = useState({ model: '', ram: '', storage: '128GB', base_price: '', min_price: '500', is_active: true, change_reason: '' });

  const [categoryModalOpen, setCategoryModalOpen] = useState(false);
  const [editingCategory, setEditingCategory] = useState(null);
  const [categoryForm, setCategoryForm] = useState({ 
    name: '', 
    subtitle: '', 
    step_number: 1, 
    selection_type: 'SINGLE', 
    pro_tip: '', 
    icon_name: 'Smartphone', 
    image_base64: '',
    brand: null,
    is_mandatory: true,
    display_order: 0, 
    is_active: true 
  });

  // Copy Questions from Brand Modal
  const [copyModalOpen, setCopyModalOpen] = useState(false);
  const [copySourceBrand, setCopySourceBrand] = useState('');
  const [copyTargetBrand, setCopyTargetBrand] = useState('');
  const [copyMandatory, setCopyMandatory] = useState(true);
  const [copyLoading, setCopyLoading] = useState(false);

  const [deviceCategories, setDeviceCategories] = useState([]);
  const [seriesList, setSeriesList] = useState([]);
  const [cmsSections, setCmsSections] = useState([]);
  const [editingCmsSection, setEditingCmsSection] = useState(null);
  const [cmsForm, setCmsForm] = useState({ title: '', subtitle: '', badge: '', is_active: true });
  const [selectedQuestionStep, setSelectedQuestionStep] = useState(null);

  const [optionModalOpen, setOptionModalOpen] = useState(false);
  const [editingOption, setEditingOption] = useState(null);
  const [optionForm, setOptionForm] = useState({
    category: '', code: '', title: '', description: '', image_base64: '',
    deduction_type: 'FLAT', default_deduction_value: '500',
    exclusive_group: '', is_rejection: false, display_order: 0, is_active: true
  });

  // Simulator state
  const [simBrandId, setSimBrandId] = useState('');
  const [simModelId, setSimModelId] = useState('');
  const [simVariantId, setSimVariantId] = useState('');
  const [simSelectedCodes, setSimSelectedCodes] = useState([]);
  const [simResult, setSimResult] = useState(null);
  const [simLoading, setSimLoading] = useState(false);

  // Status message
  const [feedback, setFeedback] = useState({ type: '', message: '' });

  useEffect(() => {
    loadAllData();
  }, []);

  const showFeedback = (type, message) => {
    setFeedback({ type, message });
    setTimeout(() => setFeedback({ type: '', message: '' }), 4000);
  };

  const loadAllData = async () => {
    setLoading(true);
    try {
      const [bData, mData, vData, cData, oData, hData, dCats, sData, cmsData] = await Promise.all([
        api.getBrands(false, true).catch(() => []),
        api.getModels('', true).catch(() => []),
        api.getVariants('', true).catch(() => []),
        api.getConditionCategories(true).catch(() => []),
        api.getConditionOptions('', true).catch(() => []),
        api.getPriceHistory().catch(() => []),
        api.getCategories(true).catch(() => []),
        api.getSeries().catch(() => []),
        api.getCMSSections().catch(() => []),
      ]);

      setBrands(bData);
      setModels(mData);
      setVariants(vData);
      setConditionCategories(cData);
      setConditionOptions(oData);
      setPriceHistory(hData);
      setDeviceCategories(dCats);
      setSeriesList(sData);
      setCmsSections(cmsData);

      if (cmsData.length > 0) {
        setEditingCmsSection(cmsData[0]);
        setCmsForm({
          title: cmsData[0].title,
          subtitle: cmsData[0].subtitle || '',
          badge: cmsData[0].data_json?.badge || '',
          is_active: cmsData[0].is_active
        });
      }

      if (cData.length > 0) {
        setSelectedQuestionStep(cData[0]);
        setCategoryForm({
          name: cData[0].name,
          subtitle: cData[0].subtitle || '',
          step_number: cData[0].step_number || 1,
          selection_type: cData[0].selection_type || 'SINGLE',
          pro_tip: cData[0].pro_tip || '',
          icon_name: cData[0].icon_name || 'Smartphone',
          display_order: cData[0].display_order || 0,
          is_active: cData[0].is_active
        });
      }

      // Default simulator selections
      if (bData.length > 0 && !simBrandId) setSimBrandId(bData[0].id.toString());
    } catch (err) {
      console.error(err);
      showFeedback('error', 'Failed to load catalogue data');
    } finally {
      setLoading(false);
    }
  };

  // Sync simulator model when brand changes
  useEffect(() => {
    if (simBrandId) {
      const filtered = models.filter(m => m.brand === parseInt(simBrandId) || m.brand?.id === parseInt(simBrandId));
      if (filtered.length > 0) {
        setSimModelId(filtered[0].id.toString());
      } else {
        setSimModelId('');
        setSimVariantId('');
      }
    }
  }, [simBrandId, models]);

  // Sync simulator variant when model changes
  useEffect(() => {
    if (simModelId) {
      const filtered = variants.filter(v => v.model === parseInt(simModelId) || v.model_id === parseInt(simModelId));
      if (filtered.length > 0) {
        setSimVariantId(filtered[0].id.toString());
      } else {
        setSimVariantId('');
      }
    }
  }, [simModelId, variants]);

  // Trigger simulator calculation
  useEffect(() => {
    if (simVariantId && subTab === 'simulator') {
      runSimulatorCalculation();
    }
  }, [simVariantId, simSelectedCodes, subTab]);

  const runSimulatorCalculation = async () => {
    if (!simVariantId) return;
    setSimLoading(true);
    try {
      const res = await api.previewValuation(parseInt(simVariantId), simSelectedCodes);
      setSimResult(res);
    } catch (err) {
      console.error('Simulator error:', err);
    } finally {
      setSimLoading(false);
    }
  };

  const toggleSimCode = (code) => {
    if (simSelectedCodes.includes(code)) {
      setSimSelectedCodes(simSelectedCodes.filter(c => c !== code));
    } else {
      setSimSelectedCodes([...simSelectedCodes, code]);
    }
  };

  // ================= 1. BRAND ACTIONS =================
  const handleOpenBrandModal = (brand = null) => {
    if (brand) {
      setEditingBrand(brand);
      setBrandForm({
        name: brand.name,
        logo_base64: brand.logo_base64 || '',
        display_order: brand.display_order || 0,
        is_active: brand.is_active
      });
    } else {
      setEditingBrand(null);
      setBrandForm({ name: '', logo_base64: '', display_order: brands.length + 1, is_active: true });
    }
    setBrandModalOpen(true);
  };

  const handleSaveBrand = async (e) => {
    e.preventDefault();
    try {
      if (editingBrand) {
        await api.updateBrand(editingBrand.id, brandForm);
        showFeedback('success', `Brand '${brandForm.name}' updated successfully`);
      } else {
        await api.createBrand(brandForm);
        showFeedback('success', `Brand '${brandForm.name}' created successfully`);
      }
      setBrandModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving brand');
    }
  };

  const handleToggleBrandActive = async (brand) => {
    try {
      await api.updateBrand(brand.id, { is_active: !brand.is_active });
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleDeleteBrand = async (brand) => {
    if (!window.confirm(`Are you sure you want to delete brand '${brand.name}'? This will delete associated models and variants.`)) return;
    try {
      await api.deleteBrand(brand.id);
      showFeedback('success', `Brand '${brand.name}' deleted`);
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  // ================= 2. MODEL ACTIONS =================
  const handleOpenModelModal = (model = null) => {
    if (model) {
      setEditingModel(model);
      setModelForm({
        brand: model.brand?.id || model.brand,
        name: model.name,
        release_year: model.release_year || 2024,
        image_base64: model.image_base64 || '',
        is_active: model.is_active
      });
    } else {
      setEditingModel(null);
      setModelForm({
        brand: filterBrandId || (brands[0]?.id || ''),
        name: '',
        release_year: 2024,
        image_base64: '',
        is_active: true
      });
    }
    setModelModalOpen(true);
  };

  const handleSaveModel = async (e) => {
    e.preventDefault();
    try {
      if (editingModel) {
        await api.updateModel(editingModel.id, modelForm);
        showFeedback('success', `Model '${modelForm.name}' updated`);
      } else {
        await api.createModel(modelForm);
        showFeedback('success', `Model '${modelForm.name}' created`);
      }
      setModelModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving model');
    }
  };

  const handleToggleModelActive = async (model) => {
    try {
      await api.updateModel(model.id, { is_active: !model.is_active });
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleDeleteModel = async (model) => {
    if (!window.confirm(`Delete phone model '${model.name}'?`)) return;
    try {
      await api.deleteModel(model.id);
      showFeedback('success', `Model '${model.name}' deleted`);
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  // ================= 3. VARIANT & BASE PRICE ACTIONS =================
  const handleOpenVariantModal = (variant = null) => {
    if (variant) {
      setEditingVariant(variant);
      setVariantForm({
        model: variant.model_id || variant.model,
        ram: variant.ram || '',
        storage: variant.storage,
        base_price: variant.base_price,
        min_price: variant.min_price || '500',
        is_active: variant.is_active,
        change_reason: ''
      });
    } else {
      setEditingVariant(null);
      setVariantForm({
        model: models[0]?.id || '',
        ram: '',
        storage: '128GB',
        base_price: '25000',
        min_price: '1000',
        is_active: true,
        change_reason: 'Initial variant creation'
      });
    }
    setVariantModalOpen(true);
  };

  const handleSaveVariant = async (e) => {
    e.preventDefault();
    try {
      if (editingVariant) {
        await api.updateVariant(editingVariant.id, variantForm);
        showFeedback('success', `Variant base price updated to ₹${Number(variantForm.base_price).toLocaleString('en-IN')}`);
      } else {
        await api.createVariant(variantForm);
        showFeedback('success', 'Storage variant created successfully');
      }
      setVariantModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving variant');
    }
  };

  const handleToggleVariantActive = async (variant) => {
    try {
      await api.updateVariant(variant.id, { is_active: !variant.is_active });
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleDeleteVariant = async (variant) => {
    if (!window.confirm(`Delete ${variant.storage} variant for ${variant.model_name}?`)) return;
    try {
      await api.deleteVariant(variant.id);
      showFeedback('success', 'Variant deleted');
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  // ================= 4. CATEGORY ACTIONS =================
  const handleOpenCategoryModal = (cat = null) => {
    if (cat) {
      setEditingCategory(cat);
      setCategoryForm({
        name: cat.name,
        subtitle: cat.subtitle || '',
        step_number: cat.step_number || 1,
        selection_type: cat.selection_type || 'SINGLE',
        pro_tip: cat.pro_tip || '',
        description: cat.description || '',
        icon_name: cat.icon_name || 'Smartphone',
        image_base64: cat.image_base64 || '',
        brand: cat.brand || null,
        is_mandatory: cat.is_mandatory ?? true,
        display_order: cat.display_order || 0,
        is_active: cat.is_active
      });
    } else {
      setEditingCategory(null);
      setCategoryForm({
        name: '',
        subtitle: '',
        step_number: categories.length + 1,
        selection_type: 'SINGLE',
        pro_tip: '',
        description: '',
        icon_name: 'Smartphone',
        image_base64: '',
        brand: null,
        is_mandatory: true,
        display_order: categories.length + 1,
        is_active: true
      });
    }
    setCategoryModalOpen(true);
  };

  const handleCopyQuestions = async (e) => {
    e.preventDefault();
    if (!copyTargetBrand) {
      alert('Please select a target brand');
      return;
    }
    setCopyLoading(true);
    try {
      const res = await api.copyQuestionsFromBrand(copySourceBrand, copyTargetBrand, copyMandatory);
      showFeedback('success', res.detail || 'Condition questions copied successfully!');
      setCopyModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Failed to clone questions');
    } finally {
      setCopyLoading(false);
    }
  };

  const handleSaveCategory = async (e) => {
    e.preventDefault();
    try {
      if (editingCategory) {
        await api.updateConditionCategory(editingCategory.id, categoryForm);
        showFeedback('success', `Questionnaire Step '${categoryForm.name}' updated`);
      } else {
        await api.createConditionCategory(categoryForm);
        showFeedback('success', `Questionnaire Step '${categoryForm.name}' created`);
      }
      setCategoryModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving question step');
    }
  };

  const handleSaveCmsSection = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    if (!editingCmsSection) return;
    try {
      const payload = {
        section_type: editingCmsSection.section_type,
        title: cmsForm.title,
        subtitle: cmsForm.subtitle,
        display_order: editingCmsSection.display_order,
        is_active: cmsForm.is_active,
        data_json: {
          ...(editingCmsSection.data_json || {}),
          badge: cmsForm.badge,
        }
      };
      await api.updateCMSSection(payload);
      showFeedback('success', `CMS Section '${editingCmsSection.section_type}' saved to Database!`);
      const fresh = await api.getCMSSections();
      setCmsSections(fresh);
    } catch (err) {
      alert(err.message || 'Failed to update CMS section');
    }
  };

  // ================= 5. DEDUCTION RULE ACTIONS =================
  const handleOpenOptionModal = (opt = null) => {
    if (opt) {
      setEditingOption(opt);
      setOptionForm({
        category: opt.category,
        code: opt.code,
        title: opt.title,
        description: opt.description || '',
        image_base64: opt.image_base64 || '',
        deduction_type: opt.deduction_type,
        default_deduction_value: opt.default_deduction_value,
        exclusive_group: opt.exclusive_group || '',
        is_rejection: opt.is_rejection || false,
        display_order: opt.display_order || 0,
        is_active: opt.is_active
      });
    } else {
      setEditingOption(null);
      setOptionForm({
        category: categories[0]?.id || '',
        code: `DEFECT_${Date.now().toString().slice(-6)}`,
        title: '',
        description: '',
        image_base64: '',
        deduction_type: 'FLAT',
        default_deduction_value: '1000',
        exclusive_group: '',
        is_rejection: false,
        display_order: options.length + 1,
        is_active: true
      });
    }
    setOptionModalOpen(true);
  };

  const handleSaveOption = async (e) => {
    e.preventDefault();
    try {
      if (editingOption) {
        await api.updateConditionOption(editingOption.id, optionForm);
        showFeedback('success', `Deduction rule '${optionForm.title}' updated`);
      } else {
        await api.createConditionOption(optionForm);
        showFeedback('success', `Deduction rule '${optionForm.title}' created`);
      }
      setOptionModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  const handleDeleteOption = async (opt) => {
    if (!window.confirm(`Delete rule '${opt.title}'?`)) return;
    try {
      await api.deleteConditionOption(opt.id);
      showFeedback('success', 'Deduction rule deleted');
      loadAllData();
    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <div className="space-y-6">
      
      {/* Top Banner */}
      <div className="bg-slate-900 text-white rounded-3xl p-5 sm:p-6 shadow-xl flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <div className="inline-flex items-center gap-1.5 bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider">
            <Sparkles className="w-3 h-3" /> Core Catalogue & Pricing Engine
          </div>
          <h2 className="text-xl sm:text-2xl font-black mt-1">
            Phone Catalogue & Valuation Matrix
          </h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Admin controls which brands, models, storage variants, and defect deductions customers can submit.
          </p>
        </div>

        <button
          onClick={loadAllData}
          disabled={loading}
          className="flex items-center gap-2 bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-bold px-4 py-2 rounded-xl border border-slate-700 transition shrink-0"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin text-emerald-400' : ''}`} />
          {loading ? 'Refreshing...' : 'Reload Catalogue'}
        </button>
      </div>

      {/* Global Feedback Banner */}
      {feedback.message && (
        <div className={`p-4 rounded-2xl text-xs font-bold flex items-center gap-2.5 animate-fade-in ${
          feedback.type === 'success' 
            ? 'bg-emerald-50 border border-emerald-200 text-emerald-800' 
            : 'bg-rose-50 border border-rose-200 text-rose-800'
        }`}>
          {feedback.type === 'success' ? <CheckCircle2 className="w-4 h-4 text-emerald-600" /> : <AlertCircle className="w-4 h-4 text-rose-600" />}
          <span>{feedback.message}</span>
        </div>
      )}

      {/* Sub Navigation Tabs */}
      <div className="flex border-b border-slate-200 gap-1.5 overflow-x-auto pb-1 scrollbar-none">
        {[
          { id: 'cms', label: '🎨 Homepage Builder (CMS)', count: cmsSections.length },
          { id: 'questionnaire', label: '📋 Questionnaire Builder (11 Steps)', count: categories.length },
          { id: 'brands', label: '📱 Brands', count: brands.length },
          { id: 'models', label: '🏷️ Models', count: models.length },
          { id: 'variants', label: '💾 Storage & Base Prices', count: variants.length },
          { id: 'deductions', label: '📉 Deduction Rules', count: options.length },
          { id: 'device_categories', label: '🗂️ Categories & Series', count: deviceCategories.length },
          { id: 'simulator', label: '⚡ Valuation Simulator', badge: 'Interactive' },
          { id: 'history', label: '📜 Price Audit Log', count: priceHistory.length },
        ].map((tab) => (
          <button
            key={tab.id}
            onClick={() => setSubTab(tab.id)}
            className={`pb-2.5 px-3 text-xs font-extrabold transition border-b-2 shrink-0 flex items-center gap-1.5 ${
              subTab === tab.id
                ? 'border-indigo-600 text-indigo-700'
                : 'border-transparent text-slate-500 hover:text-slate-800'
            }`}
          >
            <span>{tab.label}</span>
            {tab.count !== undefined && (
              <span className={`text-[10px] px-1.5 py-0.2 rounded-full font-mono ${
                subTab === tab.id ? 'bg-indigo-100 text-indigo-800' : 'bg-slate-100 text-slate-600'
              }`}>
                {tab.count}
              </span>
            )}
            {tab.badge && (
              <span className="text-[9px] bg-emerald-100 text-emerald-800 px-1.5 py-0.2 rounded font-bold">
                {tab.badge}
              </span>
            )}
          </button>
        ))}
      </div>

      {/* ================= CMS HOMEPAGE BUILDER (Matching Infographic) ================= */}
      {subTab === 'cms' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                <span>🎨 Homepage Builder (Dynamic CMS)</span>
                <span className="text-[10px] bg-[#E8F8ED] text-[#087C38] px-2 py-0.5 rounded-full font-bold">100% Dynamic DB</span>
              </h3>
              <p className="text-xs text-slate-500">Configure promotional hero banners, quick service links, top brands, and security policies without touching code.</p>
            </div>
            <button
              onClick={() => handleSaveCmsSection()}
              className="bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black text-xs px-5 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
            >
              <Check className="w-4 h-4" /> Save Changes
            </button>
          </div>

          {/* Green Live Hero Banner Card (Exact match to Infographic preview) */}
          <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-6 sm:p-8 rounded-3xl shadow-xl flex flex-col md:flex-row items-center justify-between gap-6 border border-emerald-400/30">
            <div className="space-y-2 max-w-xl">
              <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 text-white px-3 py-1 rounded-full">
                {cmsForm.badge || '1103 RECELL · Buyback Company'}
              </span>
              <h2 className="text-2xl sm:text-4xl font-black mt-2 leading-tight">
                {cmsForm.title || 'Sell Your Old Device'}
              </h2>
              <p className="text-xs sm:text-sm text-[#E8F8ED] leading-relaxed">
                {cmsForm.subtitle || 'Get the best value for your phone, tablet, laptop & more with instant doorstep payout.'}
              </p>
              <div className="pt-2 flex items-center gap-3">
                <button type="button" className="bg-white text-[#087C38] font-black text-xs px-5 py-2.5 rounded-xl shadow-lg hover:bg-[#E8F8ED] transition flex items-center gap-1.5">
                  <span>Start Selling Now</span>
                  <ArrowRight className="w-3.5 h-3.5" />
                </button>
                <span className="text-[11px] text-emerald-200 font-bold">⚡ Doorstep in 60 Mins</span>
              </div>
            </div>

            <div className="w-36 h-36 rounded-2xl bg-white/10 backdrop-blur border border-white/20 flex flex-col items-center justify-center p-3 text-center text-xs shrink-0">
              <Smartphone className="w-12 h-12 text-white mb-2" />
              <span className="font-extrabold text-[11px]">Customer View</span>
              <span className="text-[9px] text-emerald-200">Live Preview</span>
            </div>
          </div>

          {/* CMS Section Blocks Grid */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {/* Left: Section Selector */}
            <div className="space-y-2">
              <h4 className="text-xs font-black uppercase text-slate-500 tracking-wider">Homepage Sections ({cmsSections.length})</h4>
              <div className="space-y-2">
                {cmsSections.map((sec) => (
                  <div
                    key={sec.id}
                    onClick={() => {
                      setEditingCmsSection(sec);
                      setCmsForm({
                        title: sec.title,
                        subtitle: sec.subtitle || '',
                        badge: sec.data_json?.badge || '',
                        is_active: sec.is_active
                      });
                    }}
                    className={`p-3.5 rounded-2xl border cursor-pointer transition flex items-center justify-between ${
                      editingCmsSection?.id === sec.id
                        ? 'bg-[#E8F8ED] border-[#0BAA4B] ring-2 ring-[#0BAA4B]/20 shadow-sm'
                        : 'bg-white border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div>
                      <span className="font-extrabold text-xs text-slate-900 capitalize">{sec.section_type.replace(/_/g, ' ')}</span>
                      <p className="text-[11px] text-slate-500 truncate max-w-[160px]">{sec.title}</p>
                    </div>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${sec.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'}`}>
                      {sec.is_active ? 'Active' : 'Hidden'}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Right: Section Editor */}
            {editingCmsSection && (
              <div className="md:col-span-2 bg-white rounded-3xl border border-slate-200 p-5 sm:p-6 shadow-sm space-y-4">
                <div className="flex justify-between items-center pb-3 border-b border-slate-100">
                  <h4 className="font-black text-slate-900 text-sm">
                    Edit Section: <span className="text-[#0BAA4B] capitalize">{editingCmsSection.section_type.replace(/_/g, ' ')}</span>
                  </h4>
                  <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                    <input
                      type="checkbox"
                      checked={cmsForm.is_active}
                      onChange={(e) => setCmsForm({ ...cmsForm, is_active: e.target.checked })}
                      className="rounded text-[#0BAA4B] focus:ring-[#0BAA4B]"
                    />
                    <span>Visible on Customer App</span>
                  </label>
                </div>

                <div className="space-y-3 text-xs">
                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Section Title *</label>
                    <input
                      type="text"
                      value={cmsForm.title}
                      onChange={(e) => setCmsForm({ ...cmsForm, title: e.target.value })}
                      className="w-full p-2.5 border border-slate-300 rounded-xl text-xs font-bold focus:ring-2 focus:ring-[#0BAA4B]"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Section Subtitle</label>
                    <input
                      type="text"
                      value={cmsForm.subtitle}
                      onChange={(e) => setCmsForm({ ...cmsForm, subtitle: e.target.value })}
                      className="w-full p-2.5 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-[#0BAA4B]"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Badge Text (Optional)</label>
                    <input
                      type="text"
                      value={cmsForm.badge}
                      onChange={(e) => setCmsForm({ ...cmsForm, badge: e.target.value })}
                      className="w-full p-2.5 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-[#0BAA4B]"
                    />
                  </div>

                  <div className="pt-2 flex justify-end">
                    <button
                      type="button"
                      onClick={handleSaveCmsSection}
                      className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black px-6 py-2.5 rounded-xl shadow transition text-xs"
                    >
                      Save Section
                    </button>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ================= QUESTIONNAIRE BUILDER (11 Evaluation Steps) ================= */}
      {subTab === 'questionnaire' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                <span>📋 Questionnaire Evaluation Builder (11 Steps)</span>
                <span className="text-[10px] bg-[#E8F8ED] text-[#087C38] px-2 py-0.5 rounded-full font-bold">11 Steps Complete</span>
              </h3>
              <p className="text-xs text-slate-500">Every step in the customer evaluation wizard is dynamically fetched from this database table.</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setCopyModalOpen(true)}
                className="bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Sparkles className="w-4 h-4" /> Copy Questions from Brand
              </button>
              <button
                onClick={() => handleOpenCategoryModal()}
                className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Plus className="w-4 h-4" /> Add Questionnaire Step
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {/* Left Column: 11 Steps List */}
            <div className="space-y-2">
              <h4 className="text-xs font-black uppercase text-slate-500 tracking-wider">Evaluation Steps</h4>
              <div className="space-y-2 max-h-[700px] overflow-y-auto pr-1">
                {categories.map((cat, idx) => {
                  const isSelected = selectedQuestionStep?.id === cat.id;
                  const catOpts = options.filter(o => o.category === cat.id);
                  return (
                    <div
                      key={cat.id}
                      onClick={() => {
                        setSelectedQuestionStep(cat);
                        setCategoryForm({
                          name: cat.name,
                          subtitle: cat.subtitle || '',
                          step_number: cat.step_number || (idx + 1),
                          selection_type: cat.selection_type || 'SINGLE',
                          pro_tip: cat.pro_tip || '',
                          icon_name: cat.icon_name || 'Smartphone',
                          display_order: cat.display_order || idx,
                          is_active: cat.is_active
                        });
                      }}
                      className={`p-3 rounded-2xl border cursor-pointer transition flex items-center justify-between ${
                        isSelected
                          ? 'bg-[#E8F8ED] border-[#0BAA4B] ring-2 ring-[#0BAA4B]/20 shadow-sm'
                          : 'bg-white border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="min-w-0 pr-2">
                        <span className="text-[9px] font-mono font-black text-[#087C38] uppercase">
                          Step {cat.step_number || (idx + 1)} of {categories.length}
                        </span>
                        <h5 className="font-extrabold text-slate-900 text-xs truncate mt-0.5">{cat.name}</h5>
                        <span className="text-[10px] text-slate-400">{catOpts.length} Options Attached</span>
                      </div>
                      <span className={`text-[10px] font-black shrink-0 px-2 py-0.5 rounded-full ${
                        cat.selection_type === 'MULTIPLE' ? 'bg-amber-100 text-amber-800' : 'bg-blue-100 text-blue-800'
                      }`}>
                        {cat.selection_type}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Right Column: Edit Question Panel & Attached Option Cards */}
            {selectedQuestionStep && (
              <div className="md:col-span-2 bg-white rounded-3xl border border-slate-200 p-5 sm:p-6 shadow-sm space-y-4">
                <div className="flex justify-between items-center pb-3 border-b border-slate-100">
                  <div>
                    <span className="text-[10px] font-black uppercase text-[#0BAA4B]">Step {categoryForm.step_number} Configuration</span>
                    <h4 className="font-black text-slate-900 text-base">{categoryForm.name}</h4>
                  </div>
                  <button
                    onClick={() => handleOpenOptionModal()}
                    className="text-xs bg-[#E8F8ED] text-[#087C38] hover:bg-[#0BAA4B] hover:text-white font-extrabold px-3 py-1.5 rounded-xl transition flex items-center gap-1"
                  >
                    <Plus className="w-3.5 h-3.5" /> Add Option Card
                  </button>
                </div>

                {/* Question Properties Form */}
                <form onSubmit={handleSaveCategory} className="space-y-3 text-xs">
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Question Title *</label>
                      <input
                        type="text"
                        required
                        value={categoryForm.name}
                        onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                        className="w-full p-2.5 border border-slate-300 rounded-xl font-bold focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Question Type *</label>
                      <select
                        value={categoryForm.selection_type}
                        onChange={(e) => setCategoryForm({ ...categoryForm, selection_type: e.target.value })}
                        className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white focus:ring-2 focus:ring-[#0BAA4B]"
                      >
                        <option value="SINGLE">Single Selection (A/B Visual Cards)</option>
                        <option value="MULTIPLE">Multiple Selection (Check all faults)</option>
                        <option value="ACCESSORY">Accessories & Box (Bonus/Deduction)</option>
                        <option value="WARRANTY">Warranty & Bill Verification</option>
                      </select>
                    </div>
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Subtitle / Customer Instruction</label>
                    <input
                      type="text"
                      value={categoryForm.subtitle}
                      onChange={(e) => setCategoryForm({ ...categoryForm, subtitle: e.target.value })}
                      placeholder="e.g. Choose the display glass condition of your device"
                      className="w-full p-2.5 border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#0BAA4B]"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Pro Tip for Customer</label>
                    <input
                      type="text"
                      value={categoryForm.pro_tip}
                      onChange={(e) => setCategoryForm({ ...categoryForm, pro_tip: e.target.value })}
                      placeholder="e.g. Check your screen under bright light and from different angles."
                      className="w-full p-2.5 border border-slate-300 rounded-xl focus:ring-2 focus:ring-[#0BAA4B]"
                    />
                  </div>

                  {/* Attached Options (A/B Visual Cards) */}
                  <div className="pt-2">
                    <label className="block font-black text-slate-800 uppercase tracking-wider text-[10px] mb-2">
                      Visual Option Cards ({options.filter(o => o.category === selectedQuestionStep.id).length})
                    </label>
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                      {options.filter(o => o.category === selectedQuestionStep.id).map((opt) => (
                        <div key={opt.id} className="p-2.5 rounded-xl border border-slate-200 bg-slate-50 flex flex-col justify-between text-center relative group">
                          <div className="text-left">
                            {opt.image_base64 && (
                              <img src={opt.image_base64} alt="" className="w-10 h-10 object-contain mx-auto mb-1 rounded" />
                            )}
                            <h6 className="font-extrabold text-slate-900 text-xs truncate">{opt.title}</h6>
                            <span className="text-[10px] font-black text-rose-600 block mt-0.5">
                              {opt.deduction_type === 'PERCENTAGE' ? `-${opt.default_deduction_value}%` : `-₹${Number(opt.default_deduction_value).toLocaleString('en-IN')}`}
                            </span>
                          </div>
                          <div className="mt-1 pt-1 border-t border-slate-200 flex justify-between text-[10px]">
                            <button
                              type="button"
                              onClick={() => handleOpenOptionModal(opt)}
                              className="text-indigo-600 font-bold hover:underline"
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              onClick={() => handleDeleteOption(opt)}
                              className="text-rose-600 font-bold hover:underline"
                            >
                              Delete
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>

                  <div className="pt-2 flex justify-end gap-2">
                    <button
                      type="submit"
                      className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black px-6 py-2.5 rounded-xl shadow transition text-xs"
                    >
                      Save Question
                    </button>
                  </div>
                </form>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ================= DEVICE CATEGORIES & SERIES ================= */}
      {subTab === 'device_categories' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex justify-between items-center">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Device Categories & Brand Series</h3>
              <p className="text-xs text-slate-500">Categories (Mobile, Tablet, Laptop, etc.) and series (iPhone 11, S21 Series) managed in DB.</p>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {/* Device Categories */}
            <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
              <h4 className="font-extrabold text-slate-900 text-sm">1. Device Categories ({deviceCategories.length})</h4>
              <div className="grid grid-cols-2 gap-2">
                {deviceCategories.map((dc) => (
                  <div key={dc.id} className="p-3 rounded-xl border border-slate-200 bg-slate-50 flex items-center justify-between">
                    <div>
                      <span className="font-bold text-xs text-slate-900">{dc.name}</span>
                      <span className="text-[10px] text-slate-400 block font-mono">{dc.slug}</span>
                    </div>
                    <span className="text-[9px] bg-emerald-100 text-emerald-800 font-bold px-1.5 py-0.5 rounded">Active</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Brand Series */}
            <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
              <h4 className="font-extrabold text-slate-900 text-sm">2. Configured Series ({seriesList.length})</h4>
              <div className="grid grid-cols-2 gap-2 max-h-[360px] overflow-y-auto pr-1">
                {seriesList.map((s) => (
                  <div key={s.id} className="p-3 rounded-xl border border-slate-200 bg-slate-50">
                    <span className="font-bold text-xs text-slate-900">{s.name}</span>
                    <span className="text-[10px] text-indigo-600 block">{s.brand_name || 'Brand Series'}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ================= 1. BRAND MANAGEMENT ================= */}
      {subTab === 'brands' && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Registered Phone Brands</h3>
              <p className="text-xs text-slate-500">Brands configured here appear instantly in the customer selling wizard.</p>
            </div>
            <button
              onClick={() => handleOpenBrandModal()}
              className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
            >
              <Plus className="w-4 h-4" /> Add Phone Brand
            </button>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {brands.map((b) => (
              <div 
                key={b.id} 
                className={`bg-white rounded-2xl border p-5 shadow-sm transition flex flex-col justify-between ${
                  b.is_active ? 'border-slate-200' : 'border-rose-200 bg-rose-50/20 opacity-75'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-[10px] font-mono text-slate-400">Order #{b.display_order}</span>
                    <button
                      onClick={() => handleToggleBrandActive(b)}
                      className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                        b.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                      }`}
                    >
                      {b.is_active ? '● Active' : '○ Inactive'}
                    </button>
                  </div>

                  <div className="h-14 flex items-center justify-center p-2 mb-3 bg-slate-50 rounded-xl border border-slate-100">
                    {b.logo_base64 ? (
                      <img src={b.logo_base64} alt={b.name} className="max-h-10 max-w-full object-contain" />
                    ) : (
                      <Smartphone className="w-8 h-8 text-slate-400" />
                    )}
                  </div>

                  <h4 className="font-extrabold text-slate-900 text-base">{b.name}</h4>
                  <p className="text-xs text-slate-500 mt-0.5">
                    {models.filter(m => m.brand === b.id || m.brand?.id === b.id).length} eligible models
                  </p>
                </div>

                <div className="flex gap-2 pt-4 border-t border-slate-100 mt-4">
                  <button
                    onClick={() => handleOpenBrandModal(b)}
                    className="flex-1 border border-slate-200 hover:bg-slate-50 text-slate-700 font-bold py-1.5 rounded-lg text-xs flex items-center justify-center gap-1"
                  >
                    <Edit2 className="w-3.5 h-3.5" /> Edit
                  </button>
                  <button
                    onClick={() => handleDeleteBrand(b)}
                    className="p-1.5 border border-rose-200 text-rose-600 hover:bg-rose-50 rounded-lg text-xs"
                    title="Delete Brand"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* ================= 2. MODEL MANAGEMENT ================= */}
      {subTab === 'models' && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Phone Model Catalogue</h3>
              <p className="text-xs text-slate-500">Configure models per manufacturer with release year and specifications.</p>
            </div>
            
            <div className="flex items-center gap-2 w-full sm:w-auto">
              <select
                value={filterBrandId}
                onChange={(e) => setFilterBrandId(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white"
              >
                <option value="">All Brands ({brands.length})</option>
                {brands.map(b => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>

              <button
                onClick={() => handleOpenModelModal()}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5 shrink-0"
              >
                <Plus className="w-4 h-4" /> Add Model
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {models
              .filter(m => filterBrandId ? (m.brand === parseInt(filterBrandId) || m.brand?.id === parseInt(filterBrandId)) : true)
              .map((m) => {
                const modelVariants = variants.filter(v => v.model === m.id || v.model_id === m.id);
                return (
                  <div key={m.id} className="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm flex flex-col justify-between">
                    <div>
                      <div className="flex justify-between items-start">
                        <span className="text-[10px] font-bold uppercase tracking-wider text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded">
                          {m.brand_name || 'Brand'}
                        </span>
                        <button
                          onClick={() => handleToggleModelActive(m)}
                          className={`text-[9px] font-bold px-2 py-0.5 rounded-full ${
                            m.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-600'
                          }`}
                        >
                          {m.is_active ? 'Active' : 'Disabled'}
                        </button>
                      </div>

                      <div className="h-24 flex items-center justify-center p-2 my-2 bg-slate-50 rounded-xl">
                        {m.image_base64 ? (
                          <img src={m.image_base64} alt={m.name} className="max-h-20 max-w-full object-contain" />
                        ) : (
                          <Smartphone className="w-10 h-10 text-slate-400" />
                        )}
                      </div>

                      <h4 className="font-extrabold text-slate-900 text-sm">{m.name}</h4>
                      <p className="text-xs text-slate-500 mt-0.5">Year: {m.release_year || 'N/A'}</p>
                      
                      <div className="mt-2 text-[11px] text-slate-600 bg-slate-50 p-2 rounded-lg space-y-1">
                        <span className="font-bold block text-slate-700">Storage Variants ({modelVariants.length}):</span>
                        {modelVariants.length > 0 ? (
                          <div className="flex flex-wrap gap-1">
                            {modelVariants.map(v => (
                              <span key={v.id} className="bg-white border border-slate-200 px-1.5 py-0.5 rounded text-[10px] font-mono">
                                {v.storage}: ₹{Number(v.base_price).toLocaleString('en-IN')}
                              </span>
                            ))}
                          </div>
                        ) : (
                          <span className="text-slate-400 italic">No variants configured</span>
                        )}
                      </div>
                    </div>

                    <div className="flex gap-2 pt-3 border-t border-slate-100 mt-3">
                      <button
                        onClick={() => handleOpenModelModal(m)}
                        className="flex-1 border border-slate-200 hover:bg-slate-50 font-bold py-1.5 rounded-lg text-xs flex items-center justify-center gap-1"
                      >
                        <Edit2 className="w-3 h-3" /> Edit
                      </button>
                      <button
                        onClick={() => handleDeleteModel(m)}
                        className="p-1.5 border border-rose-200 text-rose-600 hover:bg-rose-50 rounded-lg text-xs"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                );
              })}
          </div>
        </div>
      )}

      {/* ================= 3. STORAGE VARIANTS & BASE PRICES ================= */}
      {subTab === 'variants' && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Storage Variants & Base Prices</h3>
              <p className="text-xs text-slate-500">
                Base price represents the maximum buyback offer for a mint device. Modifying price logs an entry into the audit trail.
              </p>
            </div>

            <button
              onClick={() => handleOpenVariantModal()}
              className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5 shrink-0"
            >
              <Plus className="w-4 h-4" /> Add Storage Variant
            </button>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-white uppercase text-[10px] tracking-wider font-bold">
                  <tr>
                    <th className="py-3 px-4">Brand & Model</th>
                    <th className="py-3 px-4">Spec / Storage</th>
                    <th className="py-3 px-4">Configured Base Price</th>
                    <th className="py-3 px-4">Min Floor Price</th>
                    <th className="py-3 px-4">Status</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {variants.map((v) => (
                    <tr key={v.id} className="hover:bg-slate-50 transition">
                      <td className="py-3 px-4 font-bold text-slate-900">
                        {v.brand_name} {v.model_name}
                      </td>
                      <td className="py-3 px-4 font-mono font-semibold text-slate-700">
                        {v.ram ? `${v.ram} / ` : ''}{v.storage}
                      </td>
                      <td className="py-3 px-4">
                        <span className="font-extrabold text-emerald-700 text-sm">
                          ₹{Number(v.base_price).toLocaleString('en-IN')}
                        </span>
                      </td>
                      <td className="py-3 px-4 font-mono text-slate-500">
                        ₹{Number(v.min_price).toLocaleString('en-IN')}
                      </td>
                      <td className="py-3 px-4">
                        <button
                          onClick={() => handleToggleVariantActive(v)}
                          className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${
                            v.is_active ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-200 text-slate-600'
                          }`}
                        >
                          {v.is_active ? 'Active' : 'Disabled'}
                        </button>
                      </td>
                      <td className="py-3 px-4 text-right space-x-2">
                        <button
                          onClick={() => handleOpenVariantModal(v)}
                          className="px-2.5 py-1 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 font-bold rounded-lg text-[11px]"
                        >
                          Update Price
                        </button>
                        <button
                          onClick={() => handleDeleteVariant(v)}
                          className="p-1 text-slate-400 hover:text-rose-600 rounded"
                        >
                          <Trash2 className="w-3.5 h-3.5 inline" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ================= 4. CONDITION CATEGORIES ================= */}
      {subTab === 'categories' && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Condition Categories</h3>
              <p className="text-xs text-slate-500">Categories organize defects shown to customers and inspection agents.</p>
            </div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setCopyModalOpen(true)}
                className="bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Sparkles className="w-4 h-4" /> Copy from Brand
              </button>
              <button
                onClick={() => handleOpenCategoryModal()}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Plus className="w-4 h-4" /> Add Category
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            {categories.map((cat) => {
              const catOptions = options.filter(o => o.category === cat.id);
              return (
                <div key={cat.id} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="text-[10px] font-mono text-slate-400">Order #{cat.display_order}</span>
                    <span className="text-[10px] font-bold bg-indigo-50 text-indigo-700 px-2 py-0.5 rounded">
                      {catOptions.length} Deduction Rules
                    </span>
                  </div>

                  <div>
                    <h4 className="font-extrabold text-slate-900 text-base">{cat.name}</h4>
                    <p className="text-xs text-slate-500 mt-0.5">{cat.description || 'No description'}</p>
                  </div>

                  <div className="pt-2 border-t border-slate-100 flex justify-between items-center text-xs">
                    <span className="text-slate-400">Icon: <code className="text-slate-700 font-mono">{cat.icon_name}</code></span>
                    <button
                      onClick={() => handleOpenCategoryModal(cat)}
                      className="text-indigo-600 hover:text-indigo-800 font-bold flex items-center gap-1"
                    >
                      <Edit2 className="w-3 h-3" /> Edit
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* ================= 5. DEDUCTION RULES ================= */}
      {subTab === 'deductions' && (
        <div className="space-y-4 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Condition & Deduction Rules Matrix</h3>
              <p className="text-xs text-slate-500">
                Configure exact deductions in flat INR (₹) or percentage (%). Exclusive groups prevent stacking incompatible defects.
              </p>
            </div>

            <button
              onClick={() => handleOpenOptionModal()}
              className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5 shrink-0"
            >
              <Plus className="w-4 h-4" /> Add Deduction Rule
            </button>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-white uppercase text-[10px] tracking-wider font-bold">
                  <tr>
                    <th className="py-3 px-4">Condition Title & Description</th>
                    <th className="py-3 px-4">Category</th>
                    <th className="py-3 px-4">Deduction Method & Amount</th>
                    <th className="py-3 px-4">Exclusive Group</th>
                    <th className="py-3 px-4">Flags</th>
                    <th className="py-3 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {options.map((opt) => (
                    <tr key={opt.id} className="hover:bg-slate-50 transition">
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2.5">
                          {opt.image_base64 ? (
                            <img src={opt.image_base64} alt="" className="w-10 h-10 rounded-xl object-contain bg-slate-50 border border-slate-200 shrink-0 p-0.5" />
                          ) : (
                            <div className="w-10 h-10 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-400 text-[9px] font-bold shrink-0">
                              No Pic
                            </div>
                          )}
                          <div className="min-w-0">
                            <strong className="text-slate-900 block truncate max-w-xs">{opt.title}</strong>
                            <span className="text-[10px] text-slate-500 font-mono">{opt.code}</span>
                          </div>
                        </div>
                      </td>
                      <td className="py-3 px-4 font-semibold text-slate-700">
                        {opt.category_name || categories.find(c => c.id === opt.category)?.name}
                      </td>
                      <td className="py-3 px-4">
                        {opt.deduction_type === 'PERCENTAGE' ? (
                          <span className="font-extrabold text-indigo-700 bg-indigo-50 border border-indigo-200 px-2 py-0.5 rounded">
                            {opt.default_deduction_value}% of Base Price
                          </span>
                        ) : (
                          <span className="font-extrabold text-rose-700 bg-rose-50 border border-rose-200 px-2 py-0.5 rounded">
                            -₹{Number(opt.default_deduction_value).toLocaleString('en-IN')} Flat
                          </span>
                        )}
                      </td>
                      <td className="py-3 px-4">
                        {opt.exclusive_group ? (
                          <span className="font-mono text-[10px] bg-slate-100 text-slate-700 px-2 py-0.5 rounded font-bold">
                            {opt.exclusive_group}
                          </span>
                        ) : (
                          <span className="text-slate-400 italic">Standalone</span>
                        )}
                      </td>
                      <td className="py-3 px-4">
                        {opt.is_rejection ? (
                          <span className="bg-rose-600 text-white font-extrabold text-[9px] px-2 py-0.5 rounded flex items-center gap-1 w-fit">
                            <ShieldAlert className="w-3 h-3" /> Safety Rejection
                          </span>
                        ) : (
                          <span className="text-emerald-700 text-[10px] font-bold">Standard Defect</span>
                        )}
                      </td>
                      <td className="py-3 px-4 text-right space-x-2">
                        <button
                          onClick={() => handleOpenOptionModal(opt)}
                          className="px-2.5 py-1 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-lg text-[11px]"
                        >
                          Edit Rule
                        </button>
                        <button
                          onClick={() => handleDeleteOption(opt)}
                          className="p-1 text-slate-400 hover:text-rose-600 rounded"
                        >
                          <Trash2 className="w-3.5 h-3.5 inline" />
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ================= 6. LIVE VALUATION SIMULATOR ================= */}
      {subTab === 'simulator' && (
        <div className="space-y-6 animate-fade-in">
          <div>
            <h3 className="text-base font-extrabold text-slate-900">Interactive Valuation Simulator</h3>
            <p className="text-xs text-slate-500">
              Test how your live pricing matrix behaves for any device with any combination of defects before customer rollout.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            
            {/* Left 2 Cols: Device Selection & Defect Toggles */}
            <div className="md:col-span-2 space-y-4">
              
              <div className="bg-white rounded-2xl border border-slate-200 p-4 sm:p-5 shadow-sm space-y-3">
                <span className="text-xs font-bold text-indigo-700 uppercase">Step 1: Select Device Specification</span>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div>
                    <label className="block text-[11px] font-bold text-slate-700 mb-1">Brand</label>
                    <select
                      value={simBrandId}
                      onChange={(e) => setSimBrandId(e.target.value)}
                      className="w-full p-2 border border-slate-300 rounded-xl text-xs font-bold"
                    >
                      {brands.map(b => (
                        <option key={b.id} value={b.id}>{b.name}</option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[11px] font-bold text-slate-700 mb-1">Model</label>
                    <select
                      value={simModelId}
                      onChange={(e) => setSimModelId(e.target.value)}
                      className="w-full p-2 border border-slate-300 rounded-xl text-xs font-bold"
                    >
                      {models
                        .filter(m => m.brand === parseInt(simBrandId) || m.brand?.id === parseInt(simBrandId))
                        .map(m => (
                          <option key={m.id} value={m.id}>{m.name}</option>
                        ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[11px] font-bold text-slate-700 mb-1">Storage Variant</label>
                    <select
                      value={simVariantId}
                      onChange={(e) => setSimVariantId(e.target.value)}
                      className="w-full p-2 border border-slate-300 rounded-xl text-xs font-bold"
                    >
                      {variants
                        .filter(v => v.model === parseInt(simModelId) || v.model_id === parseInt(simModelId))
                        .map(v => (
                          <option key={v.id} value={v.id}>
                            {v.storage} (Base: ₹{Number(v.base_price).toLocaleString('en-IN')})
                          </option>
                        ))}
                    </select>
                  </div>
                </div>
              </div>

              {/* Step 2: Defects Checklist */}
              <div className="space-y-4">
                <span className="text-xs font-bold text-slate-700 uppercase block">
                  Step 2: Tick Condition Questions to Simulate Deductions
                </span>

                {categories.map((cat) => {
                  const catOpts = options.filter(o => o.category === cat.id);
                  if (catOpts.length === 0) return null;

                  return (
                    <div key={cat.id} className="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm space-y-2">
                      <h4 className="font-extrabold text-slate-900 text-xs flex items-center gap-2">
                        <Smartphone className="w-3.5 h-3.5 text-indigo-600" />
                        {cat.name}
                      </h4>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-1">
                        {catOpts.map((opt) => {
                          const isChecked = simSelectedCodes.includes(opt.code);
                          return (
                            <div
                              key={opt.id}
                              onClick={() => toggleSimCode(opt.code)}
                              className={`cursor-pointer p-2.5 rounded-xl border text-xs transition flex items-start justify-between ${
                                isChecked 
                                  ? 'bg-rose-50 border-rose-300 shadow-sm' 
                                  : 'bg-slate-50 border-slate-200 hover:border-slate-300'
                              }`}
                            >
                              <div className="pr-2">
                                <span className={`font-bold block text-[11px] ${isChecked ? 'text-rose-900' : 'text-slate-800'}`}>
                                  {opt.title}
                                </span>
                                <span className="text-[10px] font-mono text-slate-400">
                                  {opt.deduction_type === 'PERCENTAGE' ? `${opt.default_deduction_value}%` : `₹${opt.default_deduction_value}`}
                                  {opt.exclusive_group && ` · Group: ${opt.exclusive_group}`}
                                  {opt.is_rejection && ` · REJECT`}
                                </span>
                              </div>

                              <input
                                type="checkbox"
                                checked={isChecked}
                                onChange={() => {}}
                                className="mt-0.5 rounded text-rose-600 focus:ring-rose-500"
                              />
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  );
                })}
              </div>

            </div>

            {/* Right Column: Live Calculated Simulation Card */}
            <div className="space-y-4">
              <div className="bg-slate-900 text-white rounded-3xl p-6 shadow-xl space-y-4 sticky top-20 border border-slate-800">
                <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-400 bg-emerald-500/20 px-2.5 py-0.5 rounded-full">
                  Live Engine Calculation
                </span>

                {simResult ? (
                  <div className="space-y-4">
                    <div>
                      <h4 className="text-lg font-black">{simResult.brand} {simResult.model}</h4>
                      <p className="text-xs text-slate-400">{simResult.variant}</p>
                    </div>

                    <div className="p-4 bg-slate-800/90 rounded-2xl border border-slate-700 space-y-2">
                      <div className="flex justify-between text-xs text-slate-300">
                        <span>Configured Base:</span>
                        <span className="font-mono">₹{Number(simResult.base_price).toLocaleString('en-IN')}</span>
                      </div>
                      
                      <div className="flex justify-between text-xs text-rose-400 border-b border-slate-700 pb-2">
                        <span>Total Deductions:</span>
                        <span className="font-mono">-₹{Number(simResult.total_deduction).toLocaleString('en-IN')}</span>
                      </div>

                      <div className="flex justify-between items-baseline pt-1">
                        <span className="text-xs font-bold text-slate-200">Net Estimated Offer:</span>
                        <span className="text-2xl font-black text-emerald-400 font-mono">
                          ₹{Number(simResult.estimated_price).toLocaleString('en-IN')}
                        </span>
                      </div>
                    </div>

                    {simResult.is_rejected && (
                      <div className="p-3 bg-rose-500/20 border border-rose-500 text-rose-200 rounded-xl text-xs space-y-1">
                        <div className="font-bold flex items-center gap-1.5 text-rose-400">
                          <AlertTriangle className="w-4 h-4 shrink-0" /> Safety/Ownership Block Triggered
                        </div>
                        <p className="text-[11px]">{simResult.message}</p>
                      </div>
                    )}

                    {/* Deductions applied list */}
                    <div className="space-y-1.5 text-[11px]">
                      <span className="font-bold text-slate-400 uppercase text-[10px] block">Itemized Rules Applied:</span>
                      {simResult.deductions?.length > 0 ? (
                        simResult.deductions.map((d, idx) => (
                          <div key={idx} className="flex justify-between text-slate-300 bg-slate-800/40 p-1.5 rounded">
                            <span className="truncate pr-2">{d.title}</span>
                            <span className="text-rose-400 font-mono shrink-0">-₹{Number(d.deduction_amount).toLocaleString('en-IN')}</span>
                          </div>
                        ))
                      ) : (
                        <span className="text-emerald-400 text-xs">✓ Mint Condition (Zero deductions)</span>
                      )}
                    </div>

                    <button
                      onClick={() => setSimSelectedCodes([])}
                      className="w-full border border-slate-700 hover:bg-slate-800 text-slate-300 font-bold py-2 rounded-xl text-xs transition"
                    >
                      Reset All Checked Defects
                    </button>
                  </div>
                ) : (
                  <div className="py-8 text-center text-slate-400 text-xs">
                    Select a variant to preview live valuation
                  </div>
                )}
              </div>
            </div>

          </div>
        </div>
      )}

      {/* ================= 7. PRICE HISTORY AUDIT TRAIL ================= */}
      {subTab === 'history' && (
        <div className="space-y-4 animate-fade-in">
          <div>
            <h3 className="text-base font-extrabold text-slate-900">Price Change History & Audit Log</h3>
            <p className="text-xs text-slate-500">
              Immutable ledger of base price changes made by administrators. Existing submitted quotes maintain their original price snapshots.
            </p>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-white uppercase text-[10px] tracking-wider font-bold">
                  <tr>
                    <th className="py-3 px-4">Phone Specification</th>
                    <th className="py-3 px-4">Previous Price</th>
                    <th className="py-3 px-4">New Price</th>
                    <th className="py-3 px-4">Adjustment</th>
                    <th className="py-3 px-4">Reason / Notes</th>
                    <th className="py-3 px-4">Changed By</th>
                    <th className="py-3 px-4">Effective Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {priceHistory.map((h) => {
                    const diff = Number(h.new_base_price) - Number(h.old_base_price);
                    return (
                      <tr key={h.id} className="hover:bg-slate-50 transition">
                        <td className="py-3 px-4 font-bold text-slate-900">
                          {h.variant_spec}
                        </td>
                        <td className="py-3 px-4 font-mono text-slate-500">
                          ₹{Number(h.old_base_price).toLocaleString('en-IN')}
                        </td>
                        <td className="py-3 px-4 font-mono font-extrabold text-slate-900">
                          ₹{Number(h.new_base_price).toLocaleString('en-IN')}
                        </td>
                        <td className="py-3 px-4 font-mono font-bold">
                          {diff >= 0 ? (
                            <span className="text-emerald-600 flex items-center gap-0.5">
                              <TrendingUp className="w-3 h-3" /> +₹{diff.toLocaleString('en-IN')}
                            </span>
                          ) : (
                            <span className="text-rose-600 flex items-center gap-0.5">
                              <TrendingDown className="w-3 h-3" /> -₹{Math.abs(diff).toLocaleString('en-IN')}
                            </span>
                          )}
                        </td>
                        <td className="py-3 px-4 text-slate-700">
                          {h.reason}
                        </td>
                        <td className="py-3 px-4 font-semibold text-slate-800">
                          {h.changed_by_name || 'Admin'}
                        </td>
                        <td className="py-3 px-4 text-slate-500">
                          {new Date(h.created_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })}
                        </td>
                      </tr>
                    );
                  })}
                  {priceHistory.length === 0 && (
                    <tr>
                      <td colSpan={7} className="py-8 text-center text-slate-400">
                        No base price changes logged yet. Any future price updates will be logged here.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ================= MODAL: ADD / EDIT BRAND ================= */}
      {brandModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-extrabold text-base text-slate-900">
              {editingBrand ? `Edit Brand: ${editingBrand.name}` : 'Add New Phone Brand'}
            </h3>

            <form onSubmit={handleSaveBrand} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Brand Name *</label>
                <input
                  type="text"
                  required
                  value={brandForm.name}
                  onChange={(e) => setBrandForm({ ...brandForm, name: e.target.value })}
                  placeholder="e.g. Apple, Samsung, Vivo, Nothing"
                  className="w-full p-2.5 border border-slate-300 rounded-xl text-xs font-bold"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Upload Brand Logo (Base64) *</label>
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const f = e.target.files[0];
                    if (f) {
                      const b64 = await fileToBase64(f, 400, 0.8);
                      setBrandForm({ ...brandForm, logo_base64: b64 });
                    }
                  }}
                  className="w-full p-2 border border-slate-300 rounded-xl text-xs"
                />
                {brandForm.logo_base64 && (
                  <div className="mt-2 p-2 bg-slate-50 border rounded-lg flex items-center justify-center h-12">
                    <img src={brandForm.logo_base64} alt="Preview" className="max-h-8 object-contain" />
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Display Order</label>
                  <input
                    type="number"
                    value={brandForm.display_order}
                    onChange={(e) => setBrandForm({ ...brandForm, display_order: parseInt(e.target.value) || 0 })}
                    className="w-full p-2 border border-slate-300 rounded-xl"
                  />
                </div>
                <div className="flex items-center pt-5">
                  <label className="inline-flex items-center gap-2 cursor-pointer font-bold text-slate-700">
                    <input
                      type="checkbox"
                      checked={brandForm.is_active}
                      onChange={(e) => setBrandForm({ ...brandForm, is_active: e.target.checked })}
                      className="rounded text-indigo-600"
                    />
                    <span>Active in Wizard</span>
                  </label>
                </div>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setBrandModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold text-slate-700"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl font-bold shadow-md"
                >
                  Save Brand
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ================= MODAL: ADD / EDIT MODEL ================= */}
      {modelModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-extrabold text-base text-slate-900">
              {editingModel ? `Edit Model: ${editingModel.name}` : 'Add Phone Model'}
            </h3>

            <form onSubmit={handleSaveModel} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Select Brand *</label>
                <select
                  required
                  value={modelForm.brand}
                  onChange={(e) => setModelForm({ ...modelForm, brand: parseInt(e.target.value) })}
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                >
                  <option value="">Select Brand</option>
                  {brands.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Model Name *</label>
                <input
                  type="text"
                  required
                  value={modelForm.name}
                  onChange={(e) => setModelForm({ ...modelForm, name: e.target.value })}
                  placeholder="e.g. iPhone 15 Pro Max, Galaxy S24 Ultra"
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Release Year</label>
                <input
                  type="number"
                  value={modelForm.release_year}
                  onChange={(e) => setModelForm({ ...modelForm, release_year: parseInt(e.target.value) || 2024 })}
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-mono"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Upload Device Illustration / Photo (Base64)</label>
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const f = e.target.files[0];
                    if (f) {
                      const b64 = await fileToBase64(f, 600, 0.8);
                      setModelForm({ ...modelForm, image_base64: b64 });
                    }
                  }}
                  className="w-full p-2 border border-slate-300 rounded-xl"
                />
              </div>

              <div className="flex items-center pt-2">
                <label className="inline-flex items-center gap-2 cursor-pointer font-bold text-slate-700">
                  <input
                    type="checkbox"
                    checked={modelForm.is_active}
                    onChange={(e) => setModelForm({ ...modelForm, is_active: e.target.checked })}
                    className="rounded text-indigo-600"
                  />
                  <span>Active & Accept Submissions</span>
                </label>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setModelModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl font-bold shadow-md"
                >
                  Save Model
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ================= MODAL: ADD / EDIT VARIANT & PRICE ================= */}
      {variantModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-extrabold text-base text-slate-900">
              {editingVariant ? `Update Base Price: ${editingVariant.model_name}` : 'Add Storage Variant & Price'}
            </h3>

            <form onSubmit={handleSaveVariant} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Phone Model *</label>
                <select
                  required
                  disabled={!!editingVariant}
                  value={variantForm.model}
                  onChange={(e) => setVariantForm({ ...variantForm, model: parseInt(e.target.value) })}
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white disabled:bg-slate-100"
                >
                  <option value="">Select Phone Model</option>
                  {models.map(m => (
                    <option key={m.id} value={m.id}>{m.brand_name} {m.name}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Storage *</label>
                  <input
                    type="text"
                    required
                    value={variantForm.storage}
                    onChange={(e) => setVariantForm({ ...variantForm, storage: e.target.value })}
                    placeholder="e.g. 128GB, 256GB, 1TB"
                    className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">RAM (Optional)</label>
                  <input
                    type="text"
                    value={variantForm.ram}
                    onChange={(e) => setVariantForm({ ...variantForm, ram: e.target.value })}
                    placeholder="e.g. 6GB, 8GB, 12GB"
                    className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Mint Condition Base Price (INR ₹) *</label>
                <input
                  type="number"
                  step="100"
                  required
                  value={variantForm.base_price}
                  onChange={(e) => setVariantForm({ ...variantForm, base_price: e.target.value })}
                  placeholder="e.g. 26000"
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-black text-emerald-700 text-sm"
                />
                <span className="text-[10px] text-slate-400 mt-0.5 block">Max amount paid to customer for 100% flaw-free unit.</span>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Floor / Minimum Offer (INR ₹)</label>
                <input
                  type="number"
                  step="50"
                  required
                  value={variantForm.min_price}
                  onChange={(e) => setVariantForm({ ...variantForm, min_price: e.target.value })}
                  className="w-full p-2 border border-slate-300 rounded-xl font-mono"
                />
              </div>

              {editingVariant && (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Reason for Price Revision (Audit Log) *</label>
                  <input
                    type="text"
                    required
                    value={variantForm.change_reason}
                    onChange={(e) => setVariantForm({ ...variantForm, change_reason: e.target.value })}
                    placeholder="e.g. Market price dropped post new model launch"
                    className="w-full p-2.5 border border-indigo-300 bg-indigo-50/30 rounded-xl font-semibold"
                  />
                </div>
              )}

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setVariantModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-emerald-600 hover:bg-emerald-700 text-white py-2.5 rounded-xl font-bold shadow-md"
                >
                  Save Price
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ================= MODAL: ADD / EDIT CATEGORY ================= */}
      {categoryModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-extrabold text-base text-slate-900">
              {editingCategory ? `Edit Category: ${editingCategory.name}` : 'Add Condition Category'}
            </h3>

            <form onSubmit={handleSaveCategory} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Category Name *</label>
                <input
                  type="text"
                  required
                  value={categoryForm.name}
                  onChange={(e) => setCategoryForm({ ...categoryForm, name: e.target.value })}
                  placeholder="e.g. Screen & Display, Battery Health"
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Description</label>
                <textarea
                  rows={2}
                  value={categoryForm.description}
                  onChange={(e) => setCategoryForm({ ...categoryForm, description: e.target.value })}
                  placeholder="e.g. Display glass, scratches, dead spots and lines"
                  className="w-full p-2 border border-slate-300 rounded-xl"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Display Order</label>
                  <input
                    type="number"
                    value={categoryForm.display_order}
                    onChange={(e) => setCategoryForm({ ...categoryForm, display_order: parseInt(e.target.value) || 0 })}
                    className="w-full p-2 border border-slate-300 rounded-xl"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Icon Name</label>
                  <input
                    type="text"
                    value={categoryForm.icon_name}
                    onChange={(e) => setCategoryForm({ ...categoryForm, icon_name: e.target.value })}
                    placeholder="Smartphone, Battery, Camera..."
                    className="w-full p-2 border border-slate-300 rounded-xl font-mono"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Brand-Specific Assignment</label>
                <select
                  value={categoryForm.brand || ''}
                  onChange={(e) => setCategoryForm({ ...categoryForm, brand: e.target.value ? parseInt(e.target.value) : null })}
                  className="w-full p-2 border border-slate-300 rounded-xl bg-white"
                >
                  <option value="">🌐 Universal (All Brands)</option>
                  {brands.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
                <span className="text-[10px] text-slate-400 mt-0.5 block">Select specific brand or leave Universal to show for all devices.</span>
              </div>

              <div className="flex items-center gap-2 p-2.5 bg-slate-50 rounded-xl border border-slate-200">
                <input
                  type="checkbox"
                  id="is_mandatory_check"
                  checked={categoryForm.is_mandatory ?? true}
                  onChange={(e) => setCategoryForm({ ...categoryForm, is_mandatory: e.target.checked })}
                  className="w-4 h-4 text-emerald-600 rounded"
                />
                <label htmlFor="is_mandatory_check" className="font-bold text-slate-700 text-xs cursor-pointer">
                  Mandatory Step (Customer must answer to proceed)
                </label>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setCategoryModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl font-bold shadow-md"
                >
                  Save Category
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ================= MODAL: COPY QUESTIONS FROM BRAND ================= */}
      {copyModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4">
            <div className="flex items-center gap-2">
              <div className="p-2 bg-emerald-100 text-emerald-700 rounded-xl">
                <Sparkles className="w-5 h-5" />
              </div>
              <div>
                <h3 className="font-extrabold text-base text-slate-900">Copy Questions from Brand</h3>
                <p className="text-[11px] text-slate-500">Clone all diagnostic questions, options, Base64 images and rules to another brand.</p>
              </div>
            </div>

            <form onSubmit={handleCopyQuestions} className="space-y-3 pt-2">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Source Brand (Copy From)</label>
                <select
                  value={copySourceBrand}
                  onChange={(e) => setCopySourceBrand(e.target.value)}
                  className="w-full p-2.5 border border-slate-300 rounded-xl bg-white font-medium"
                >
                  <option value="">🌐 Universal / Default Questions</option>
                  {brands.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Target Brand (Clone To) *</label>
                <select
                  required
                  value={copyTargetBrand}
                  onChange={(e) => setCopyTargetBrand(e.target.value)}
                  className="w-full p-2.5 border border-slate-300 rounded-xl bg-white font-bold text-emerald-900"
                >
                  <option value="">Select Target Brand...</option>
                  {brands.map(b => (
                    <option key={b.id} value={b.id}>{b.name}</option>
                  ))}
                </select>
              </div>

              <div className="flex items-center gap-2 p-2 bg-slate-50 rounded-xl border border-slate-200">
                <input
                  type="checkbox"
                  id="copy_mand_check"
                  checked={copyMandatory}
                  onChange={(e) => setCopyMandatory(e.target.checked)}
                  className="w-4 h-4 text-emerald-600 rounded"
                />
                <label htmlFor="copy_mand_check" className="font-bold text-slate-700 text-xs cursor-pointer">
                  Mark Copied Questions as Mandatory
                </label>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setCopyModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={copyLoading}
                  className="w-1/2 bg-[#0BAA4B] hover:bg-[#087C38] text-white py-2.5 rounded-xl font-bold shadow-md transition"
                >
                  {copyLoading ? 'Cloning...' : 'Clone Questions'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ================= MODAL: ADD / EDIT DEDUCTION RULE ================= */}
      {optionModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
          <div className="bg-white rounded-2xl max-w-md w-full p-5 sm:p-6 shadow-2xl border border-slate-200 text-xs space-y-4 max-h-[92vh] overflow-y-auto">
            <h3 className="font-extrabold text-base text-slate-900">
              {editingOption ? `Edit Rule: ${editingOption.title}` : 'Add Condition Deduction Rule'}
            </h3>

            <form onSubmit={handleSaveOption} className="space-y-3">
              <div>
                <label className="block font-bold text-slate-700 mb-1">Category *</label>
                <select
                  required
                  value={optionForm.category}
                  onChange={(e) => setOptionForm({ ...optionForm, category: parseInt(e.target.value) })}
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white"
                >
                  <option value="">Select Category</option>
                  {categories.map(c => (
                    <option key={c.id} value={c.id}>{c.name}</option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Defect Code *</label>
                  <input
                    type="text"
                    required
                    value={optionForm.code}
                    onChange={(e) => setOptionForm({ ...optionForm, code: e.target.value.toUpperCase().replace(/\s+/g, '_') })}
                    placeholder="e.g. SCREEN_CRACKED"
                    className="w-full p-2 border border-slate-300 rounded-xl font-mono uppercase"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Exclusive Group</label>
                  <input
                    type="text"
                    value={optionForm.exclusive_group}
                    onChange={(e) => setOptionForm({ ...optionForm, exclusive_group: e.target.value.toLowerCase().replace(/\s+/g, '_') })}
                    placeholder="e.g. screen_glass"
                    className="w-full p-2 border border-slate-300 rounded-xl font-mono"
                  />
                  <span className="text-[9px] text-slate-400">Rules in same group take max deduction</span>
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 mb-1">Question / Defect Title *</label>
                <input
                  type="text"
                  required
                  value={optionForm.title}
                  onChange={(e) => setOptionForm({ ...optionForm, title: e.target.value })}
                  placeholder="e.g. Display glass cracked or shattered"
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                />
              </div>

              {/* Visual Photo Upload for Customer Card */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">Visual Defect Photo / Illustration</label>
                <div className="flex items-center gap-3">
                  {optionForm.image_base64 && (
                    <div className="w-14 h-14 rounded-xl border border-slate-200 overflow-hidden bg-slate-50 shrink-0 relative p-1">
                      <img src={optionForm.image_base64} alt="" className="w-full h-full object-contain" />
                      <button
                        type="button"
                        onClick={() => setOptionForm({ ...optionForm, image_base64: '' })}
                        className="absolute top-0.5 right-0.5 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700"
                      >
                        <X className="w-2.5 h-2.5" />
                      </button>
                    </div>
                  )}
                  <label className="border-2 border-dashed border-slate-300 hover:border-emerald-500 rounded-xl p-2.5 text-center cursor-pointer bg-slate-50 flex-1 transition block select-none">
                    <input
                      type="file"
                      accept="image/*"
                      onChange={async (e) => {
                        const file = e.target.files[0];
                        if (file) {
                          const b64 = await fileToBase64(file, 400, 0.75);
                          setOptionForm(prev => ({ ...prev, image_base64: b64 }));
                        }
                      }}
                      className="hidden"
                    />
                    <Upload className="w-4 h-4 text-slate-400 mx-auto mb-0.5" />
                    <span className="text-xs font-bold text-slate-700 block">
                      {optionForm.image_base64 ? 'Change Visual Photo' : 'Upload Visual Photo (Photo / Icon)'}
                    </span>
                    <span className="text-[9px] text-slate-400">Displayed to customer on condition quiz card</span>
                  </label>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Calculation Method</label>
                  <select
                    value={optionForm.deduction_type}
                    onChange={(e) => setOptionForm({ ...optionForm, deduction_type: e.target.value })}
                    className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
                  >
                    <option value="FLAT">Flat Rupee Amount (₹)</option>
                    <option value="PERCENTAGE">Percentage of Base (%)</option>
                  </select>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {optionForm.deduction_type === 'PERCENTAGE' ? 'Percentage Value (%) *' : 'Deduction Amount (₹) *'}
                  </label>
                  <input
                    type="number"
                    step="10"
                    required
                    value={optionForm.default_deduction_value}
                    onChange={(e) => setOptionForm({ ...optionForm, default_deduction_value: e.target.value })}
                    className="w-full p-2.5 border border-slate-300 rounded-xl font-black text-rose-600 text-sm"
                  />
                </div>
              </div>

              <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl">
                <label className="inline-flex items-center gap-2 cursor-pointer font-bold text-amber-900">
                  <input
                    type="checkbox"
                    checked={optionForm.is_rejection}
                    onChange={(e) => setOptionForm({ ...optionForm, is_rejection: e.target.checked })}
                    className="rounded text-rose-600"
                  />
                  <span>⚠️ Flag as Safety Hazard / Ownership Block (Rejection)</span>
                </label>
                <p className="text-[10px] text-amber-800 mt-1">
                  If selected, sets final price to ₹0 and rejects order (e.g. Swollen battery, iCloud/Google lock).
                </p>
              </div>

              <div className="flex gap-2 pt-3">
                <button
                  type="button"
                  onClick={() => setOptionModalOpen(false)}
                  className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="w-1/2 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl font-bold shadow-md"
                >
                  Save Deduction Rule
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
