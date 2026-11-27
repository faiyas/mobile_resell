import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { 
  Smartphone, Plus, Edit2, Trash2, CheckCircle2, AlertCircle, 
  Search, Filter, RefreshCw, Layers, Shield, IndianRupee, 
  HelpCircle, Sparkles, ChevronRight, Check, X, ArrowRight,
  TrendingDown, TrendingUp, History, AlertTriangle, Eye, ShieldAlert, Upload,
  Image as ImageIcon, Type, Sliders, Crop, MoveVertical, ZoomIn
} from 'lucide-react';
import { api } from '../services/api';
import { fileToBase64, cropAndResizeToBanner, formatImageSrc } from '../utils/imageCompressor';

function ResponsiveModal({ isOpen, onClose, title, children, maxWidth = 'max-w-md' }) {
  if (!isOpen) return null;
  return createPortal(
    <div 
      className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in overflow-y-auto"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div 
        className={`bg-white rounded-t-3xl sm:rounded-2xl ${maxWidth} w-full shadow-2xl border border-slate-200/90 flex flex-col max-h-[90vh] sm:max-h-[85vh] overflow-hidden animate-slide-up sm:animate-zoom-in`}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Mobile drag handle */}
        <div className="sm:hidden pt-3 pb-1 flex justify-center">
          <div className="w-12 h-1.5 bg-slate-300 rounded-full" />
        </div>

        {/* Fixed Header */}
        <div className="px-5 py-3.5 border-b border-slate-150 flex items-center justify-between shrink-0 bg-white">
          <h3 className="font-extrabold text-base text-slate-900 truncate pr-2">{title}</h3>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-slate-100 hover:bg-slate-200 text-slate-500 hover:text-slate-800 flex items-center justify-center transition shrink-0"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Scrollable Form Body */}
        <div className="flex-1 overflow-y-auto p-5 text-xs space-y-4">
          {children}
        </div>
      </div>
    </div>,
    document.body
  );
}

function BulkActionBar({ totalCount, selectedIds, onToggleSelectAll, onDeleteSelected, onDeleteAll, itemName = 'items', loading = false }) {
  const allSelected = totalCount > 0 && selectedIds.length === totalCount;
  return (
    <div className="bg-slate-50 border border-slate-200 rounded-2xl px-4 py-2.5 flex flex-wrap items-center justify-between gap-3">
      <label className="flex items-center gap-2 text-xs font-bold text-slate-700 cursor-pointer select-none">
        <input
          type="checkbox"
          checked={allSelected}
          onChange={onToggleSelectAll}
          disabled={totalCount === 0 || loading}
          className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
        />
        <span>Select All ({totalCount} {itemName})</span>
      </label>

      <div className="flex items-center gap-2">
        {selectedIds.length > 0 && (
          <button
            type="button"
            disabled={loading}
            onClick={onDeleteSelected}
            className="px-3 py-1.5 bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs rounded-xl shadow-sm transition flex items-center gap-1.5 disabled:opacity-50"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Delete Selected ({selectedIds.length})</span>
          </button>
        )}
        <button
          type="button"
          disabled={totalCount === 0 || loading}
          onClick={onDeleteAll}
          className="px-3 py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 font-bold text-xs rounded-xl transition flex items-center gap-1.5 disabled:opacity-50"
        >
          <Trash2 className="w-3.5 h-3.5" />
          <span>Delete All {itemName}</span>
        </button>
      </div>
    </div>
  );
}

export default function CataloguePricingManager({ initialSubTab = 'brands', onSubTabChange }) {
  // Sub-tabs: 'brands' | 'models' | 'variants' | 'categories' | 'deductions' | 'simulator' | 'history'
  const [subTab, setSubTab] = useState(initialSubTab);

  useEffect(() => {
    if (initialSubTab) {
      setSubTab(initialSubTab);
    }
  }, [initialSubTab]);

  const handleSubTabChange = (newTab) => {
    setSubTab(newTab);
    if (onSubTabChange) onSubTabChange(newTab);
  };

  // Data states
  const [brands, setBrands] = useState([]);
  const [models, setModels] = useState([]);
  const [variants, setVariants] = useState([]);
  const [categories, setConditionCategories] = useState([]);
  const [options, setConditionOptions] = useState([]);
  const [priceHistory, setPriceHistory] = useState([]);

  // Initial Health Check (4 Yes/No Triage Questions)
  const [triageQuestions, setTriageQuestions] = useState([]);
  const [triageModalOpen, setTriageModalOpen] = useState(false);
  const [editingTriage, setEditingTriage] = useState(null);
  const [triageForm, setTriageForm] = useState({
    code: '',
    question_text: '',
    subtitle: '',
    is_power_on_gate: false,
    deduction_type: 'PERCENTAGE',
    deduction_value_on_no: 10,
    display_order: 1,
    is_active: true
  });

  const [loading, setLoading] = useState(false);
  const [modelsLoading, setModelsLoading] = useState(true);
  const [modelsPage, setModelsPage] = useState(1);
  const [modelsPageSize, setModelsPageSize] = useState(24);
  const [modelsTotalCount, setModelsTotalCount] = useState(0);
  const [modelsTotalPages, setModelsTotalPages] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const [filterBrandId, setFilterBrandId] = useState('');
  const [filterSeriesId, setFilterSeriesId] = useState('');
  const [filterModelId, setFilterModelId] = useState('');
  const [variantSearch, setVariantSearch] = useState('');
  const [filterCategoryId, setFilterCategoryId] = useState('');

  const handleBrandFilterChange = (bId) => {
    setFilterBrandId(bId);
    setFilterSeriesId('');
    setFilterModelId('');
    setModelsPage(1);
  };

  const handleSeriesFilterChange = (sId) => {
    setFilterSeriesId(sId);
    setFilterModelId('');
    setModelsPage(1);
  };

  // Modals state
  const [brandModalOpen, setBrandModalOpen] = useState(false);
  const [editingBrand, setEditingBrand] = useState(null);
  const [brandForm, setBrandForm] = useState({ name: '', logo_base64: '', display_order: 0, is_active: true });

  const [modelModalOpen, setModelModalOpen] = useState(false);
  const [editingModel, setEditingModel] = useState(null);
  const [modelForm, setModelForm] = useState({ brand: '', name: '', release_year: 2024, image_base64: '', has_warranty: true, is_active: true });

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

  // Device Category & Series Modal States
  const [deviceCategoryModalOpen, setDeviceCategoryModalOpen] = useState(false);
  const [editingDeviceCategory, setEditingDeviceCategory] = useState(null);
  const [deviceCategoryForm, setDeviceCategoryForm] = useState({ name: '', subtitle: '', icon_name: 'Smartphone', image_base64: '', is_active: true });

  const [seriesModalOpen, setSeriesModalOpen] = useState(false);
  const [editingSeries, setEditingSeries] = useState(null);
  const [seriesForm, setSeriesForm] = useState({ name: '', brand: '', display_order: 0, is_active: true });

  // Selected Brand for Question Mapping
  const [selectedBrandQuestionMapping, setSelectedBrandQuestionMapping] = useState('');

  const [deviceCategories, setDeviceCategories] = useState([]);
  const [seriesList, setSeriesList] = useState([]);
  const [cmsSections, setCmsSections] = useState([]);
  const [editingCmsSection, setEditingCmsSection] = useState(null);
  const [cmsForm, setCmsForm] = useState({ title: '', subtitle: '', badge: '', is_active: true });
  const [heroSlides, setHeroSlides] = useState([
    {
      id: 'slide_1',
      type: 'TEXT',
      title: 'Sell Your Old Device',
      subtitle: 'Get the best value for your phone, tablet, laptop & more with instant doorstep payout.',
      badge: 'Dolly · Buyback Platform',
      cta_text: 'Start Selling Now',
      image_base64: '',
      is_active: true
    }
  ]);
  const [selectedSlideIndex, setSelectedSlideIndex] = useState(0);

  // Interactive 1200x480 Banner Crop Modal States
  const [cropModalOpen, setCropModalOpen] = useState(false);
  const [rawCropImage, setRawCropImage] = useState(null);
  const [cropOffsetY, setCropOffsetY] = useState(0.5);
  const [cropZoom, setCropZoom] = useState(1.0);
  const [cropPreviewBase64, setCropPreviewBase64] = useState('');
  const [isProcessingCrop, setIsProcessingCrop] = useState(false);

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

  const [selectedIds, setSelectedIds] = useState([]);
  const [selectedSeriesIds, setSelectedSeriesIds] = useState([]);
  const [bulkDeleting, setBulkDeleting] = useState(false);

  useEffect(() => {
    setSelectedIds([]);
    setSelectedSeriesIds([]);
  }, [subTab]);

  const toggleSelectId = (id) => {
    setSelectedIds((prev) => prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]);
  };

  const handleBulkDelete = async (scope, target, allFlag = false, customIds = null, warningText = '') => {
    const idsToDelete = customIds ?? selectedIds;
    if (!allFlag && idsToDelete.length === 0) return;

    const label = allFlag ? `ALL ${target}` : `${idsToDelete.length} selected ${target}`;
    const extra = warningText ? `\n\n${warningText}` : '';
    if (!window.confirm(`Are you sure you want to permanently delete ${label}?${extra}`)) return;

    setBulkDeleting(true);
    try {
      const res = scope === 'valuation'
        ? await api.bulkDeleteValuation(target, idsToDelete, allFlag)
        : await api.bulkDeleteCatalog(target, idsToDelete, allFlag);
      showFeedback('success', res.message || `Deleted ${res.deleted || ''} ${target}`);
      setSelectedIds([]);
      setSelectedSeriesIds([]);
      await loadAllData();
    } catch (err) {
      const msg = err.message || `Failed to delete ${target}`;
      showFeedback('error', msg);
      alert(msg);
    } finally {
      setBulkDeleting(false);
    }
  };

  const handleOpenTriageModal = (q = null) => {
    if (q) {
      setEditingTriage(q);
      setTriageForm({
        code: q.code || '',
        question_text: q.question_text || '',
        subtitle: q.subtitle || '',
        is_power_on_gate: !!q.is_power_on_gate,
        deduction_type: q.deduction_type || 'PERCENTAGE',
        deduction_value_on_no: q.deduction_value_on_no !== undefined ? q.deduction_value_on_no : 10,
        display_order: q.display_order || 1,
        is_active: q.is_active !== undefined ? q.is_active : true
      });
    } else {
      setEditingTriage(null);
      setTriageForm({
        code: `TRIAGE_${Date.now()}`,
        question_text: '',
        subtitle: '',
        is_power_on_gate: false,
        deduction_type: 'PERCENTAGE',
        deduction_value_on_no: 10,
        display_order: triageQuestions.length + 1,
        is_active: true
      });
    }
    setTriageModalOpen(true);
  };

  const handleSaveTriageQuestion = async (e) => {
    e?.preventDefault();
    try {
      if (editingTriage) {
        await api.updateTriageQuestion(editingTriage.id, triageForm);
        showFeedback('success', 'Health check question updated successfully');
      } else {
        await api.createTriageQuestion(triageForm);
        showFeedback('success', 'Health check question created successfully');
      }
      setTriageModalOpen(false);
      const updated = await api.getTriageQuestions(true);
      setTriageQuestions(updated);
    } catch (err) {
      showFeedback('error', err.message || 'Failed to save health check question');
    }
  };

  const handleDeleteTriageQuestion = async (q) => {
    if (!window.confirm(`Delete question: "${q.question_text}"?`)) return;
    try {
      await api.deleteTriageQuestion(q.id, true);
      showFeedback('success', 'Question deleted successfully');
      const updated = await api.getTriageQuestions(true);
      setTriageQuestions(updated);
    } catch (err) {
      showFeedback('error', err.message || 'Failed to delete question');
    }
  };

  const loadAllData = async () => {
    setLoading(true);
    setModelsLoading(true);
    try {
      // PHASE 1: Lightning-fast core endpoints (< 250ms total)
      const [bData, cData, oData, dCats, sData, cmsData, tqData] = await Promise.all([
        api.getBrands(false, true).catch(() => []),
        api.getConditionCategories(true).catch(() => []),
        api.getConditionOptions('', true).catch(() => []),
        api.getCategories(true).catch(() => []),
        api.getSeries().catch(() => []),
        api.getCMSSections().catch(() => []),
        api.getTriageQuestions(true).catch(() => []),
      ]);

      setBrands(bData);
      setConditionCategories(cData);
      setConditionOptions(oData);
      setDeviceCategories(dCats);
      setSeriesList(sData);
      setCmsSections(cmsData);
      setTriageQuestions(tqData);

      const cmsList = Array.isArray(cmsData) ? cmsData : (Array.isArray(cmsData?.results) ? cmsData.results : []);
      if (cmsList.length > 0) {
        const heroSec = cmsList.find(s => s.section_type === 'HERO_CAROUSEL') || cmsList[0];
        setEditingCmsSection(heroSec);
        setCmsForm({
          title: heroSec.title,
          subtitle: heroSec.subtitle || '',
          badge: heroSec.data_json?.badge || '',
          is_active: heroSec.is_active
        });

        let slides = heroSec.data_json?.slides;
        if (!Array.isArray(slides) || slides.length === 0) {
          slides = [
            {
              id: 'slide_1',
              type: heroSec.data_json?.image_base64 ? 'IMAGE' : 'TEXT',
              title: heroSec.title || 'Sell Your Old Device',
              subtitle: heroSec.subtitle || 'Get the best value for your device with instant doorstep payout.',
              badge: heroSec.data_json?.badge || '1103 RECELL · Buyback Company',
              cta_text: 'Start Selling Now',
              image_base64: heroSec.data_json?.image_base64 || '',
              is_active: heroSec.is_active
            }
          ];
        }
        setHeroSlides(slides);
        setSelectedSlideIndex(0);
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
      } else {
        setSelectedQuestionStep(null);
      }

      // Default simulator selections
      if (bData.length > 0 && !simBrandId) setSimBrandId(bData[0].id.toString());

      // Release loading immediately so Questionnaire & Banners are interactive without waiting!
      setLoading(false);

      // PHASE 2: Background fetch initial paginated models & variant tables
      Promise.all([
        api.getModels('', false, '', 1, modelsPageSize).catch(() => ({ results: [], count: 0, total_pages: 1 })),
        api.getVariants('', true).catch(() => []),
        api.getPriceHistory().catch(() => [])
      ]).then(([mRes, vData, hData]) => {
        if (mRes && mRes.results) {
          setModels(mRes.results);
          setModelsTotalCount(mRes.count || 0);
          setModelsTotalPages(mRes.total_pages || 1);
        } else if (Array.isArray(mRes)) {
          setModels(mRes);
          setModelsTotalCount(mRes.length);
          setModelsTotalPages(1);
        }
        if (vData && vData.length > 0) setVariants(vData);
        if (hData && hData.length > 0) setPriceHistory(hData);
      }).catch(() => {}).finally(() => {
        setModelsLoading(false);
      });

    } catch (err) {
      console.error(err);
      showFeedback('error', 'Failed to load catalogue data');
      setLoading(false);
      setModelsLoading(false);
    }
  };

  const fetchPaginatedModels = async (page = modelsPage, size = modelsPageSize, bId = filterBrandId, sId = filterSeriesId, q = searchQuery) => {
    setModelsLoading(true);
    try {
      const res = await api.getModels(bId, false, sId, page, size, q);
      if (res && res.results) {
        setModels(res.results);
        setModelsTotalCount(res.count || 0);
        setModelsTotalPages(res.total_pages || 1);
        setModelsPage(res.current_page || page);
      } else if (Array.isArray(res)) {
        setModels(res);
        setModelsTotalCount(res.length);
        setModelsTotalPages(1);
      }
    } catch (err) {
      console.error(err);
    } finally {
      setModelsLoading(false);
    }
  };

  useEffect(() => {
    if (subTab === 'models') {
      const timer = setTimeout(() => {
        fetchPaginatedModels(modelsPage, modelsPageSize, filterBrandId, filterSeriesId, searchQuery);
      }, 250);
      return () => clearTimeout(timer);
    }
  }, [subTab, modelsPage, modelsPageSize, filterBrandId, filterSeriesId, searchQuery]);

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
        series: model.series?.id || model.series || '',
        name: model.name,
        release_year: model.release_year || 2024,
        image_base64: model.image_base64 || '',
        has_warranty: model.has_warranty !== false,
        is_active: model.is_active
      });
    } else {
      setEditingModel(null);
      setModelForm({
        brand: filterBrandId || (brands[0]?.id || ''),
        series: '',
        name: '',
        release_year: 2024,
        image_base64: '',
        has_warranty: true,
        is_active: true
      });
    }
    setModelModalOpen(true);
  };

  const handleSaveModel = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        ...modelForm,
        brand: parseInt(modelForm.brand),
        series: modelForm.series ? parseInt(modelForm.series) : null,
        release_year: parseInt(modelForm.release_year) || 2024,
        has_warranty: modelForm.has_warranty !== false,
      };
      if (editingModel) {
        await api.updateModel(editingModel.id, payload);
        showFeedback('success', `Model '${modelForm.name}' updated`);
      } else {
        await api.createModel(payload);
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

  const handleDeleteCategory = async (cat) => {
    if (!window.confirm(`Are you sure you want to delete question step '${cat.name}' and all its options?`)) return;
    try {
      await api.deleteConditionCategory(cat.id);
      showFeedback('success', `Question '${cat.name}' deleted`);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error deleting question');
    }
  };

  // Device Category Handlers
  const handleToggleDeviceCategoryActive = async (dc) => {
    try {
      await api.updateCategory(dc.id, { is_active: !dc.is_active });
      showFeedback('success', `Category '${dc.name}' ${dc.is_active ? 'deactivated' : 'activated'}`);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error updating category');
    }
  };

  const handleDeleteDeviceCategory = async (dc) => {
    if (!window.confirm(`Are you sure you want to delete device category '${dc.name}'?`)) return;
    try {
      await api.deleteCategory(dc.id);
      showFeedback('success', `Category '${dc.name}' deleted`);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error deleting category');
    }
  };

  const handleOpenDeviceCategoryModal = (dc = null) => {
    if (dc) {
      setEditingDeviceCategory(dc);
      setDeviceCategoryForm({
        name: dc.name,
        subtitle: dc.subtitle || '',
        icon_name: dc.icon_name || 'Smartphone',
        image_base64: dc.image_base64 || '',
        is_active: dc.is_active ?? true
      });
    } else {
      setEditingDeviceCategory(null);
      setDeviceCategoryForm({ name: '', subtitle: '', icon_name: 'Smartphone', image_base64: '', is_active: true });
    }
    setDeviceCategoryModalOpen(true);
  };

  const handleSaveDeviceCategory = async (e) => {
    e.preventDefault();
    try {
      if (editingDeviceCategory) {
        await api.updateCategory(editingDeviceCategory.id, deviceCategoryForm);
        showFeedback('success', `Category '${deviceCategoryForm.name}' updated`);
      } else {
        await api.createCategory(deviceCategoryForm);
        showFeedback('success', `Category '${deviceCategoryForm.name}' created`);
      }
      setDeviceCategoryModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving category');
    }
  };

  // Series Handlers
  const handleDeleteSeries = async (s) => {
    if (!window.confirm(`Are you sure you want to delete series '${s.name}'?`)) return;
    try {
      await api.deleteSeries(s.id);
      showFeedback('success', `Series '${s.name}' deleted`);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error deleting series');
    }
  };

  const handleOpenSeriesModal = (s = null) => {
    if (s) {
      setEditingSeries(s);
      setSeriesForm({
        name: s.name,
        brand: s.brand || (s.brand_id ? s.brand_id : (brands[0]?.id || '')),
        display_order: s.display_order || 0,
        is_active: s.is_active ?? true
      });
    } else {
      setEditingSeries(null);
      setSeriesForm({
        name: '',
        brand: brands[0]?.id || '',
        display_order: seriesList.length + 1,
        is_active: true
      });
    }
    setSeriesModalOpen(true);
  };

  const handleSaveSeries = async (e) => {
    e.preventDefault();
    try {
      if (editingSeries) {
        await api.updateSeries(editingSeries.id, seriesForm);
        showFeedback('success', `Series '${seriesForm.name}' updated`);
      } else {
        await api.createSeries(seriesForm);
        showFeedback('success', `Series '${seriesForm.name}' created`);
      }
      setSeriesModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving series');
    }
  };

  const handleSaveCategory = async (e) => {
    e.preventDefault();
    try {
      const payload = {
        name: categoryForm.name,
        subtitle: categoryForm.subtitle || '',
        step_number: Number(categoryForm.step_number) || 1,
        selection_type: categoryForm.selection_type || 'SINGLE',
        pro_tip: categoryForm.pro_tip || '',
        icon_name: categoryForm.icon_name || 'Smartphone',
        image_base64: categoryForm.image_base64 || '',
        brand: categoryForm.brand ? Number(categoryForm.brand) : null,
        device_category: categoryForm.device_category ? Number(categoryForm.device_category) : null,
        is_mandatory: Boolean(categoryForm.is_mandatory),
        display_order: Number(categoryForm.display_order) || 0,
        is_active: Boolean(categoryForm.is_active)
      };
      const targetId = editingCategory ? editingCategory.id : (selectedQuestionStep ? selectedQuestionStep.id : null);
      if (targetId) {
        await api.updateConditionCategory(targetId, payload);
        showFeedback('success', `Questionnaire Step '${payload.name}' updated`);
      } else {
        await api.createConditionCategory(payload);
        showFeedback('success', `Questionnaire Step '${payload.name}' created`);
      }
      setCategoryModalOpen(false);
      loadAllData();
    } catch (err) {
      alert(err.message || 'Error saving question step');
    }
  };

  const handleSaveHeroCarousel = async (slidesToSave = heroSlides) => {
    try {
      const activeSlide = slidesToSave[selectedSlideIndex] || slidesToSave[0];
      const payload = {
        section_type: 'HERO_CAROUSEL',
        title: activeSlide?.title || 'Promotional Hero Banners',
        subtitle: activeSlide?.subtitle || 'Doorstep Device Buyback',
        display_order: 0,
        is_active: slidesToSave.some(s => s.is_active),
        data_json: {
          badge: activeSlide?.badge || '1103 RECELL · Buyback Company',
          slides: slidesToSave,
          image_base64: activeSlide?.type === 'IMAGE' ? (activeSlide.image_base64 || '') : ''
        }
      };
      await api.updateCMSSection(payload);
      showFeedback('success', `✓ Hero Carousel with ${slidesToSave.length} slides saved to Database!`);
      const fresh = await api.getCMSSections();
      setCmsSections(fresh);
    } catch (err) {
      alert(err.message || 'Failed to update Hero Carousel');
    }
  };

  const handleAddHeroSlide = () => {
    const newSlide = {
      id: `slide_${Date.now()}`,
      type: 'TEXT',
      title: 'Sell Your Old Device',
      subtitle: 'Get top value with instant doorstep evaluation and payout.',
      badge: 'Dolly · Special',
      cta_text: 'Start Selling Now',
      image_base64: '',
      is_active: true
    };
    const updated = [...heroSlides, newSlide];
    setHeroSlides(updated);
    setSelectedSlideIndex(updated.length - 1);
    handleSaveHeroCarousel(updated);
  };

  const handleDeleteHeroSlide = (idx) => {
    if (heroSlides.length <= 1) {
      alert('You must have at least one hero slide.');
      return;
    }
    if (!window.confirm('Delete this banner slide?')) return;
    const updated = heroSlides.filter((_, i) => i !== idx);
    setHeroSlides(updated);
    setSelectedSlideIndex(Math.max(0, idx - 1));
    handleSaveHeroCarousel(updated);
  };

  const handleUpdateCurrentSlide = (fields) => {
    const updated = [...heroSlides];
    updated[selectedSlideIndex] = { ...updated[selectedSlideIndex], ...fields };
    setHeroSlides(updated);
  };

  const handleFileSelectForCrop = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = async (ev) => {
      const raw = ev.target.result;
      setRawCropImage(raw);
      setCropOffsetY(0.5);
      setCropZoom(1.0);
      try {
        const preview = await cropAndResizeToBanner(raw, 1200, 480, 0.85, 0.5, 1.0);
        setCropPreviewBase64(preview);
        setCropModalOpen(true);
      } catch (err) {
        alert('Image processing error: ' + err.message);
      }
    };
    reader.readAsDataURL(file);
    e.target.value = '';
  };

  const handleRecalculateCropPreview = async (newOffsetY, newZoom) => {
    if (!rawCropImage) return;
    try {
      const preview = await cropAndResizeToBanner(rawCropImage, 1200, 480, 0.85, newOffsetY, newZoom);
      setCropPreviewBase64(preview);
    } catch (_) {}
  };

  const handleApplyCrop = async () => {
    if (!rawCropImage) return;
    try {
      setIsProcessingCrop(true);
      const finalCropped = await cropAndResizeToBanner(rawCropImage, 1200, 480, 0.85, cropOffsetY, cropZoom);
      handleUpdateCurrentSlide({
        image_base64: finalCropped,
        type: 'IMAGE'
      });
      setCropModalOpen(false);
      setIsProcessingCrop(false);
      showFeedback('success', '✓ Banner image cropped to 1200x480 px and converted to Base64! Click Save to apply.');
    } catch (err) {
      setIsProcessingCrop(false);
      alert('Error saving crop: ' + err.message);
    }
  };

  const handleSaveCmsSection = async (e) => {
    if (e && e.preventDefault) e.preventDefault();
    handleSaveHeroCarousel();
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



      {/* ================= HERO CAROUSEL & PROMOTIONAL BANNERS MANAGER ================= */}
      {subTab === 'cms' && (() => {
        const currentSlide = heroSlides[selectedSlideIndex] || heroSlides[0] || {};
        return (
          <div className="space-y-6 animate-fade-in">
            {/* Header */}
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
              <div>
                <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                  <span>🎨 Hero Carousel & Promotional Banners</span>
                  <span className="text-[10px] bg-[#E8F8ED] text-[#087C38] px-2.5 py-0.5 rounded-full font-bold">1200 × 480 px Canvas</span>
                </h3>
                <p className="text-xs text-slate-500">Configure promotional hero slides (Graphic Image or Custom Text) with built-in 1200×480 cropping for Web and Mobile.</p>
              </div>
              <button
                type="button"
                onClick={() => handleSaveHeroCarousel()}
                className="bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black text-xs px-5 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Check className="w-4 h-4" /> Save Carousel Changes
              </button>
            </div>

            {/* LIVE PREVIEW OF SELECTED SLIDE */}
            <div className="space-y-1.5">
              <div className="flex items-center justify-between px-1">
                <span className="text-[11px] font-black uppercase text-slate-500 tracking-wider flex items-center gap-1.5">
                  <Eye className="w-3.5 h-3.5 text-[#0BAA4B]" />
                  Live Customer Preview · Slide #{selectedSlideIndex + 1} ({currentSlide.type === 'IMAGE' ? '🖼️ Graphic Banner' : '✍️ Text Banner'})
                </span>
                <span className="text-[10px] text-slate-400 font-mono">Aspect Ratio 2.5 : 1 (1200 × 480 px)</span>
              </div>

              {currentSlide.type === 'IMAGE' ? (
                currentSlide.image_base64 ? (
                  <div className="relative w-full aspect-[2.5/1] max-h-[380px] rounded-3xl overflow-hidden border border-emerald-500/30 shadow-xl bg-slate-900 group">
                    <img
                      src={currentSlide.image_base64}
                      alt={currentSlide.title || 'Hero Banner'}
                      className="w-full h-full object-cover"
                    />
                    <div className="absolute top-4 left-4 bg-black/60 backdrop-blur-md text-white text-[10px] font-black px-3 py-1 rounded-full border border-white/20">
                      ✓ Graphic Banner (1200 × 480 px)
                    </div>
                    {currentSlide.title && (
                      <div className="absolute bottom-4 left-4 bg-black/70 backdrop-blur-md text-white text-xs font-bold px-3 py-1.5 rounded-xl border border-white/20">
                        {currentSlide.title}
                      </div>
                    )}
                  </div>
                ) : (
                  <div
                    onClick={() => document.getElementById('hero-img-upload')?.click()}
                    className="w-full aspect-[2.5/1] max-h-[320px] rounded-3xl border-2 border-dashed border-[#0BAA4B]/40 bg-[#E8F8ED]/30 hover:bg-[#E8F8ED]/60 flex flex-col items-center justify-center p-6 text-center cursor-pointer transition"
                  >
                    <Upload className="w-10 h-10 text-[#0BAA4B] mb-2 animate-bounce" />
                    <span className="font-extrabold text-sm text-slate-800">No Image Uploaded Yet for Slide #{selectedSlideIndex + 1}</span>
                    <span className="text-xs text-slate-500 mt-1">Click to upload banner creative (Recommended 1200 × 480 px)</span>
                  </div>
                )
              ) : (
                <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] text-white p-6 sm:p-8 rounded-3xl shadow-xl flex flex-col md:flex-row items-center justify-between gap-6 border border-emerald-400/30">
                  <div className="space-y-2 max-w-xl">
                    <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 text-white px-3 py-1 rounded-full">
                      {currentSlide.badge || '1103 RECELL · Buyback Company'}
                    </span>
                    <h2 className="text-2xl sm:text-4xl font-black mt-2 leading-tight">
                      {currentSlide.title || 'Sell Your Old Device'}
                    </h2>
                    <p className="text-xs sm:text-sm text-[#E8F8ED] leading-relaxed">
                      {currentSlide.subtitle || 'Get the best value for your phone, tablet, laptop & more with instant doorstep payout.'}
                    </p>
                    <div className="pt-2 flex items-center gap-3">
                      <button type="button" className="bg-white text-[#087C38] font-black text-xs px-5 py-2.5 rounded-xl shadow-lg hover:bg-[#E8F8ED] transition flex items-center gap-1.5">
                        <span>{currentSlide.cta_text || 'Start Selling Now'}</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  <div className="w-32 h-32 rounded-2xl bg-white/10 backdrop-blur border border-white/20 flex flex-col items-center justify-center p-3 text-center text-xs shrink-0">
                    <Smartphone className="w-10 h-10 text-white mb-2" />
                    <span className="font-extrabold text-[11px]">Customer View</span>
                    <span className="text-[9px] text-emerald-200">Text Banner</span>
                  </div>
                </div>
              )}
            </div>

            {/* SLIDE MANAGER & EDITOR GRID */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
              {/* Left Column: Carousel Slides List */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h4 className="text-xs font-black uppercase text-slate-500 tracking-wider">
                    Carousel Slides ({heroSlides.length})
                  </h4>
                  <button
                    type="button"
                    onClick={handleAddHeroSlide}
                    className="text-xs font-black text-[#087C38] hover:text-[#0BAA4B] bg-[#E8F8ED] px-3 py-1 rounded-lg border border-[#0BAA4B]/20 flex items-center gap-1 transition"
                  >
                    <Plus className="w-3.5 h-3.5" /> Add Slide
                  </button>
                </div>

                <div className="space-y-2">
                  {heroSlides.map((slide, idx) => {
                    const isSelected = selectedSlideIndex === idx;
                    return (
                      <div
                        key={slide.id || idx}
                        onClick={() => setSelectedSlideIndex(idx)}
                        className={`p-3 rounded-2xl border cursor-pointer transition flex items-center justify-between gap-3 ${
                          isSelected
                            ? 'bg-[#E8F8ED] border-[#0BAA4B] ring-2 ring-[#0BAA4B]/20 shadow-sm'
                            : 'bg-white border-slate-200 hover:border-slate-300'
                        }`}
                      >
                        <div className="flex items-center gap-2.5 min-w-0">
                          {slide.type === 'IMAGE' && slide.image_base64 ? (
                            <img
                              src={slide.image_base64}
                              alt="Thumbnail"
                              className="w-12 h-8 rounded-lg object-cover border border-slate-200 shrink-0"
                            />
                          ) : (
                            <div className="w-12 h-8 rounded-lg bg-[#087C38] text-white text-[10px] font-black flex items-center justify-center shrink-0">
                              {slide.type === 'IMAGE' ? '🖼️' : '✍️'}
                            </div>
                          )}

                          <div className="min-w-0">
                            <div className="flex items-center gap-1.5">
                              <span className="font-extrabold text-xs text-slate-900 truncate">
                                Slide #{idx + 1}
                              </span>
                              <span className="text-[9px] font-bold px-1.5 py-0.2 rounded bg-slate-100 text-slate-600">
                                {slide.type === 'IMAGE' ? 'Image' : 'Text'}
                              </span>
                            </div>
                            <p className="text-[11px] text-slate-500 truncate max-w-[140px]">
                              {slide.title || 'Untitled Banner'}
                            </p>
                          </div>
                        </div>

                        <div className="flex items-center gap-1 shrink-0">
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleDeleteHeroSlide(idx);
                            }}
                            className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg transition hover:bg-rose-50"
                            title="Delete Slide"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Right Column: Slide Editor */}
              <div className="md:col-span-2 bg-white rounded-3xl border border-slate-200 p-5 sm:p-6 shadow-sm space-y-4">
                <div className="flex justify-between items-center pb-3 border-b border-slate-100">
                  <h4 className="font-black text-slate-900 text-sm flex items-center gap-2">
                    <span>Edit Slide #{selectedSlideIndex + 1}</span>
                    <span className="text-xs text-[#0BAA4B] font-bold">
                      ({currentSlide.type === 'IMAGE' ? 'Graphic Banner' : 'Text Banner'})
                    </span>
                  </h4>
                  <label className="flex items-center gap-2 cursor-pointer text-xs font-bold text-slate-700">
                    <input
                      type="checkbox"
                      checked={Boolean(currentSlide.is_active)}
                      onChange={(e) => handleUpdateCurrentSlide({ is_active: e.target.checked })}
                      className="rounded text-[#0BAA4B] focus:ring-[#0BAA4B]"
                    />
                    <span>Visible to Customers</span>
                  </label>
                </div>

                {/* Banner Mode Toggle: Image vs Text */}
                <div className="flex items-center gap-2 p-1 bg-slate-100 rounded-2xl">
                  <button
                    type="button"
                    onClick={() => handleUpdateCurrentSlide({ type: 'IMAGE' })}
                    className={`flex-1 py-2 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition ${
                      currentSlide.type === 'IMAGE'
                        ? 'bg-[#0BAA4B] text-white shadow-md'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <ImageIcon className="w-4 h-4" /> 🖼️ Graphic Image Banner
                  </button>
                  <button
                    type="button"
                    onClick={() => handleUpdateCurrentSlide({ type: 'TEXT' })}
                    className={`flex-1 py-2 rounded-xl text-xs font-extrabold flex items-center justify-center gap-2 transition ${
                      currentSlide.type === 'TEXT'
                        ? 'bg-[#0BAA4B] text-white shadow-md'
                        : 'text-slate-600 hover:text-slate-900'
                    }`}
                  >
                    <Type className="w-4 h-4" /> ✍️ Text & Gradient Banner
                  </button>
                </div>

                {/* MODE A: IMAGE BANNER CONFIG */}
                {currentSlide.type === 'IMAGE' && (
                  <div className="space-y-4 pt-1 animate-fade-in">
                    {/* Dimension Helper Badge */}
                    <div className="p-3 bg-emerald-50/80 border border-emerald-200/80 rounded-2xl text-xs text-emerald-900 flex items-start gap-2.5">
                      <Sparkles className="w-4 h-4 text-[#0BAA4B] shrink-0 mt-0.5" />
                      <div>
                        <span className="font-extrabold">Recommended Dimension: 1200 × 480 px (2.5 : 1 Ratio)</span>
                        <p className="text-[11px] text-emerald-800/80 mt-0.5">
                          Upload your promotional poster. The built-in cropper automatically resizes, crops, and optimizes it to Base64 for instant loading across Web and Mobile.
                        </p>
                      </div>
                    </div>

                    {/* Upload & Crop Buttons */}
                    <div className="space-y-2">
                      <label className="block font-bold text-slate-700 text-xs">Banner Graphic (Base64) *</label>
                      <div className="flex flex-col sm:flex-row items-center gap-3">
                        <input
                          id="hero-img-upload"
                          type="file"
                          accept="image/*"
                          onChange={handleFileSelectForCrop}
                          className="hidden"
                        />
                        <button
                          type="button"
                          onClick={() => document.getElementById('hero-img-upload')?.click()}
                          className="w-full sm:w-auto px-4 py-2.5 bg-slate-900 hover:bg-slate-800 text-white font-extrabold text-xs rounded-xl flex items-center justify-center gap-2 transition shadow-sm"
                        >
                          <Upload className="w-4 h-4" /> Upload & Crop New Image
                        </button>

                        {currentSlide.image_base64 && (
                          <button
                            type="button"
                            onClick={() => {
                              setRawCropImage(currentSlide.image_base64);
                              setCropPreviewBase64(currentSlide.image_base64);
                              setCropOffsetY(0.5);
                              setCropZoom(1.0);
                              setCropModalOpen(true);
                            }}
                            className="w-full sm:w-auto px-4 py-2.5 bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 font-extrabold text-xs rounded-xl flex items-center justify-center gap-2 transition shadow-sm"
                          >
                            <Crop className="w-4 h-4 text-[#0BAA4B]" /> Adjust Crop / Alignment
                          </button>
                        )}
                      </div>
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 text-xs mb-1">Banner Title / Alt Tag</label>
                      <input
                        type="text"
                        value={currentSlide.title || ''}
                        onChange={(e) => handleUpdateCurrentSlide({ title: e.target.value })}
                        placeholder="e.g. Festival Exchange Bonus 2026"
                        className="w-full p-2.5 border border-slate-300 rounded-xl text-xs font-bold focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                  </div>
                )}

                {/* MODE B: TEXT BANNER CONFIG */}
                {currentSlide.type === 'TEXT' && (
                  <div className="space-y-3 pt-1 animate-fade-in text-xs">
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Badge Tag</label>
                      <input
                        type="text"
                        value={currentSlide.badge || ''}
                        onChange={(e) => handleUpdateCurrentSlide({ badge: e.target.value })}
                        placeholder="e.g. 1103 RECELL · Buyback Company"
                        className="w-full p-2.5 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Banner Headline / Title *</label>
                      <input
                        type="text"
                        value={currentSlide.title || ''}
                        onChange={(e) => handleUpdateCurrentSlide({ title: e.target.value })}
                        placeholder="e.g. Sell Your Old Device"
                        className="w-full p-2.5 border border-slate-300 rounded-xl text-xs font-black focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Subtitle / Customer Instruction</label>
                      <input
                        type="text"
                        value={currentSlide.subtitle || ''}
                        onChange={(e) => handleUpdateCurrentSlide({ subtitle: e.target.value })}
                        placeholder="e.g. Get the best value for your phone with instant doorstep payout."
                        className="w-full p-2.5 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Action Button Text</label>
                      <input
                        type="text"
                        value={currentSlide.cta_text || ''}
                        onChange={(e) => handleUpdateCurrentSlide({ cta_text: e.target.value })}
                        placeholder="e.g. Start Selling Now"
                        className="w-full p-2.5 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                  </div>
                )}

                {/* Action Save Button */}
                <div className="pt-3 border-t border-slate-100 flex justify-end">
                  <button
                    type="button"
                    onClick={() => handleSaveHeroCarousel()}
                    className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black px-6 py-2.5 rounded-xl shadow transition text-xs flex items-center gap-2"
                  >
                    <Check className="w-4 h-4" /> Save Hero Carousel
                  </button>
                </div>
              </div>
            </div>

            {/* INTERACTIVE 1200 x 480 BANNER CROP MODAL */}
            <ResponsiveModal
              isOpen={cropModalOpen}
              onClose={() => setCropModalOpen(false)}
              title="Crop Banner Image (1200 × 480 px)"
              maxWidth="max-w-3xl"
            >
              <div className="space-y-4 text-xs">
                <div className="bg-slate-50 p-3 rounded-2xl border border-slate-200 flex items-center justify-between">
                  <span className="font-extrabold text-slate-800">Target Resolution: 1200 × 480 px (Aspect Ratio 2.5:1)</span>
                  <span className="text-[10px] font-bold bg-[#E8F8ED] text-[#087C38] px-2 py-0.5 rounded-full">
                    Auto-Optimized Base64
                  </span>
                </div>

                {/* Interactive Canvas Live Preview */}
                <div className="relative w-full aspect-[2.5/1] rounded-2xl overflow-hidden bg-slate-900 border-2 border-[#0BAA4B] shadow-inner flex items-center justify-center">
                  {cropPreviewBase64 ? (
                    <img
                      src={cropPreviewBase64}
                      alt="Crop Result"
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <span className="text-white">Generating preview...</span>
                  )}
                  <div className="absolute bottom-2 right-2 bg-black/70 text-white text-[9px] font-mono px-2 py-0.5 rounded">
                    1200 × 480 px
                  </div>
                </div>

                {/* Crop & Alignment Sliders */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 bg-slate-50 p-3.5 rounded-2xl border border-slate-200">
                  <div>
                    <label className="font-bold text-slate-700 flex items-center justify-between mb-1">
                      <span className="flex items-center gap-1.5"><MoveVertical className="w-3.5 h-3.5 text-[#0BAA4B]" /> Vertical Alignment</span>
                      <span className="text-[10px] text-slate-500 font-mono">{Math.round(cropOffsetY * 100)}%</span>
                    </label>
                    <input
                      type="range"
                      min="0"
                      max="1"
                      step="0.05"
                      value={cropOffsetY}
                      onChange={(e) => {
                        const val = parseFloat(e.target.value);
                        setCropOffsetY(val);
                        handleRecalculateCropPreview(val, cropZoom);
                      }}
                      className="w-full accent-[#0BAA4B]"
                    />
                    <div className="flex justify-between text-[9px] text-slate-400 font-bold mt-0.5">
                      <span>Top</span>
                      <span>Center</span>
                      <span>Bottom</span>
                    </div>
                  </div>

                  <div>
                    <label className="font-bold text-slate-700 flex items-center justify-between mb-1">
                      <span className="flex items-center gap-1.5"><ZoomIn className="w-3.5 h-3.5 text-[#0BAA4B]" /> Image Zoom</span>
                      <span className="text-[10px] text-slate-500 font-mono">{cropZoom.toFixed(1)}x</span>
                    </label>
                    <input
                      type="range"
                      min="1.0"
                      max="2.2"
                      step="0.1"
                      value={cropZoom}
                      onChange={(e) => {
                        const val = parseFloat(e.target.value);
                        setCropZoom(val);
                        handleRecalculateCropPreview(cropOffsetY, val);
                      }}
                      className="w-full accent-[#0BAA4B]"
                    />
                    <div className="flex justify-between text-[9px] text-slate-400 font-bold mt-0.5">
                      <span>1.0x (Fit)</span>
                      <span>1.5x</span>
                      <span>2.2x (Zoom)</span>
                    </div>
                  </div>
                </div>

                <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
                  <button
                    type="button"
                    onClick={() => setCropModalOpen(false)}
                    className="px-4 py-2 border border-slate-300 text-slate-700 font-bold rounded-xl text-xs hover:bg-slate-100"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    onClick={handleApplyCrop}
                    disabled={isProcessingCrop}
                    className="px-5 py-2 bg-[#0BAA4B] hover:bg-[#087C38] text-white font-black rounded-xl text-xs shadow flex items-center gap-1.5"
                  >
                    {isProcessingCrop ? 'Processing...' : '✓ Crop & Apply Banner (1200 × 480 px)'}
                  </button>
                </div>
              </div>
            </ResponsiveModal>
          </div>
        );
      })()}

      {/* ================= QUESTIONNAIRE BUILDER (11 Evaluation Steps) ================= */}
      {subTab === 'questionnaire' && (
        <div className="space-y-6 animate-fade-in">
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                <span>📋 Questionnaire Evaluation Builder ({categories.length} Steps)</span>
                <span className="text-[10px] bg-[#E8F8ED] text-[#087C38] px-2 py-0.5 rounded-full font-bold">Configured in DB</span>
              </h3>
              <p className="text-xs text-slate-500">Every step and defect question is dynamically fetched from the database, customizable per brand (e.g. Apple iCloud & Battery Health vs Android FRP).</p>
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

          {/* ================= 0. INITIAL HEALTH CHECK YES/NO TRIAGE GATE ================= */}
          <div className="bg-gradient-to-r from-rose-50 via-white to-red-50/40 rounded-2xl p-5 border border-rose-200/80 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xl">🩺</span>
                  <h4 className="text-sm font-black text-slate-900 tracking-tight">
                    Initial Health Check Gate ({triageQuestions.length} Questions)
                  </h4>
                  <span className="text-[10px] bg-rose-100 text-rose-700 px-2.5 py-0.5 rounded-full font-bold">
                    Step 0 · Screen Before Defect Questions
                  </span>
                </div>
                <p className="text-xs text-slate-500 mt-1">
                  Customers answer these Yes/No screening questions first on the mobile app. If Question 1 is answered "No", the app immediately locks to Dead Phone valuation.
                </p>
              </div>
              <button
                type="button"
                onClick={() => handleOpenTriageModal()}
                className="bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs px-3.5 py-2 rounded-xl shadow transition flex items-center gap-1.5 shrink-0"
              >
                <Plus className="w-3.5 h-3.5" /> Add Triage Question
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-1">
              {triageQuestions.map((tq, idx) => (
                <div
                  key={tq.id || idx}
                  className="bg-white p-4 rounded-xl border border-slate-200 shadow-xs hover:border-rose-300 transition flex flex-col justify-between"
                >
                  <div>
                    <div className="flex items-start justify-between gap-2">
                      <span className="text-xs font-black text-slate-900 leading-snug">
                        {idx + 1}. {tq.question_text}
                      </span>
                      <div className="flex items-center gap-1 shrink-0">
                        <button
                          type="button"
                          onClick={() => handleOpenTriageModal(tq)}
                          className="p-1 text-slate-500 hover:text-rose-600 rounded-lg hover:bg-rose-50 transition"
                          title="Edit Question"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          type="button"
                          onClick={() => handleDeleteTriageQuestion(tq)}
                          className="p-1 text-slate-400 hover:text-red-600 rounded-lg hover:bg-red-50 transition"
                          title="Delete Question"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                    {tq.subtitle && (
                      <p className="text-[11px] text-slate-500 mt-1 line-clamp-2">
                        {tq.subtitle}
                      </p>
                    )}
                  </div>

                  <div className="mt-3 pt-2.5 border-t border-slate-100 flex items-center justify-between text-[11px]">
                    <div className="flex items-center gap-1.5">
                      {tq.is_power_on_gate ? (
                        <span className="bg-rose-100 text-rose-700 font-bold px-2 py-0.5 rounded-full flex items-center gap-1">
                          ⚡ Power-On Gate
                        </span>
                      ) : (
                        <span className="bg-slate-100 text-slate-600 font-semibold px-2 py-0.5 rounded-full">
                          Progressive Reveal
                        </span>
                      )}
                    </div>
                    <span className="font-extrabold text-rose-600">
                      Deduct on "No": {tq.deduction_type === 'PERCENTAGE' ? `${tq.deduction_value_on_no}%` : `₹${tq.deduction_value_on_no}`}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Brand-Specific Question Filter Bar */}
          <div className="bg-white rounded-2xl p-3 border border-slate-200 shadow-sm flex items-center gap-2 overflow-x-auto">
            <span className="text-xs font-black text-slate-500 uppercase tracking-wider shrink-0 mr-1 flex items-center gap-1">
              <Filter className="w-3.5 h-3.5 text-[#0BAA4B]" /> Brand Questions:
            </span>
            <button
              type="button"
              onClick={() => setSelectedBrandQuestionMapping('')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition shrink-0 flex items-center gap-1.5 ${
                selectedBrandQuestionMapping === ''
                  ? 'bg-[#0BAA4B] text-white shadow-sm'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
              }`}
            >
              <span>🌐 All Questions</span>
              <span className="text-[10px] bg-black/10 px-1.5 py-0.5 rounded-full">{categories.length}</span>
            </button>
            <button
              type="button"
              onClick={() => setSelectedBrandQuestionMapping('universal')}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold transition shrink-0 flex items-center gap-1.5 ${
                selectedBrandQuestionMapping === 'universal'
                  ? 'bg-[#0BAA4B] text-white shadow-sm'
                  : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
              }`}
            >
              <span>🌐 Universal Only</span>
              <span className="text-[10px] bg-black/10 px-1.5 py-0.5 rounded-full">
                {categories.filter(c => !c.brand).length}
              </span>
            </button>
            {brands.map(b => {
              const brandCatCount = categories.filter(c => !c.brand || c.brand === b.id).length;
              const exclusiveCount = categories.filter(c => c.brand === b.id).length;
              const isSelected = selectedBrandQuestionMapping === String(b.id);
              return (
                <button
                  key={b.id}
                  type="button"
                  onClick={() => setSelectedBrandQuestionMapping(String(b.id))}
                  className={`px-3 py-1.5 rounded-xl text-xs font-bold transition shrink-0 flex items-center gap-1.5 ${
                    isSelected
                      ? 'bg-[#0BAA4B] text-white shadow-sm'
                      : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                  }`}
                >
                  <span>{b.name}</span>
                  <span className="text-[10px] bg-black/10 px-1.5 py-0.5 rounded-full">
                    {brandCatCount} {exclusiveCount > 0 && `(${exclusiveCount} exclusive)`}
                  </span>
                </button>
              );
            })}
          </div>

          <BulkActionBar
            totalCount={categories.filter(cat => {
              if (!selectedBrandQuestionMapping) return true;
              if (selectedBrandQuestionMapping === 'universal') return !cat.brand;
              return !cat.brand || String(cat.brand) === selectedBrandQuestionMapping;
            }).length}
            selectedIds={selectedIds}
            itemName="Steps"
            loading={bulkDeleting}
            onToggleSelectAll={() => {
              const filteredIds = categories.filter(cat => {
                if (!selectedBrandQuestionMapping) return true;
                if (selectedBrandQuestionMapping === 'universal') return !cat.brand;
                return !cat.brand || String(cat.brand) === selectedBrandQuestionMapping;
              }).map(c => c.id);
              setSelectedIds(selectedIds.length === filteredIds.length ? [] : filteredIds);
            }}
            onDeleteSelected={() => handleBulkDelete('valuation', 'categories', false, selectedIds, 'Deleting steps will also delete all attached deduction options.')}
            onDeleteAll={() => handleBulkDelete('valuation', 'categories', true, [], 'This will delete ALL questionnaire steps and their options!')}
          />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
            {/* Left Column: Filtered Steps List */}
            <div className="space-y-2">
              <div className="flex justify-between items-center">
                <h4 className="text-xs font-black uppercase text-slate-500 tracking-wider">Evaluation Steps</h4>
                <span className="text-[10px] text-slate-400 font-bold">
                  {categories.filter(cat => {
                    if (!selectedBrandQuestionMapping) return true;
                    if (selectedBrandQuestionMapping === 'universal') return !cat.brand;
                    return !cat.brand || String(cat.brand) === selectedBrandQuestionMapping;
                  }).length} steps
                </span>
              </div>
              <div className="space-y-2 max-h-[700px] overflow-y-auto pr-1">
                {categories
                  .filter(cat => {
                    if (!selectedBrandQuestionMapping) return true;
                    if (selectedBrandQuestionMapping === 'universal') return !cat.brand;
                    return !cat.brand || String(cat.brand) === selectedBrandQuestionMapping;
                  })
                  .map((cat, idx) => {
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
                            description: cat.description || '',
                            icon_name: cat.icon_name || 'Smartphone',
                            image_base64: cat.image_base64 || '',
                            brand: cat.brand || null,
                            is_mandatory: cat.is_mandatory ?? true,
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
                        <div className="flex items-center gap-2.5 min-w-0 pr-2">
                          <input
                            type="checkbox"
                            checked={selectedIds.includes(cat.id)}
                            onChange={(e) => {
                              e.stopPropagation();
                              toggleSelectId(cat.id);
                            }}
                            onClick={(e) => e.stopPropagation()}
                            className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] shrink-0 cursor-pointer"
                          />
                          <div className="min-w-0">
                          <div className="flex items-center gap-1.5">
                            <span className="text-[9px] font-mono font-black text-[#087C38] uppercase">
                              Step {cat.step_number || (idx + 1)}
                            </span>
                            {cat.brand_name ? (
                              <span className="text-[8px] bg-indigo-100 text-indigo-800 font-bold px-1.5 py-0.2 rounded">
                                {cat.brand_name} Exclusive
                              </span>
                            ) : (
                              <span className="text-[8px] bg-slate-100 text-slate-600 font-bold px-1.5 py-0.2 rounded">
                                🌐 Universal
                              </span>
                            )}
                            <span className={`text-[8px] font-bold px-1.5 py-0.2 rounded ${
                              cat.is_mandatory ? 'bg-emerald-100 text-emerald-800' : 'bg-slate-100 text-slate-500'
                            }`}>
                              {cat.is_mandatory ? 'Mandatory' : 'Optional'}
                            </span>
                          </div>
                          <h5 className="font-extrabold text-slate-900 text-xs truncate mt-0.5">{cat.name}</h5>
                          <span className="text-[10px] text-slate-400">{catOpts.length} Options Attached</span>
                          </div>
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
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => handleDeleteCategory(selectedQuestionStep)}
                      className="text-xs bg-rose-50 text-rose-600 hover:bg-rose-600 hover:text-white font-extrabold px-3 py-1.5 rounded-xl transition flex items-center gap-1 border border-rose-200"
                    >
                      <Trash2 className="w-3.5 h-3.5" /> Delete Step
                    </button>
                    <button
                      onClick={() => handleOpenOptionModal()}
                      className="text-xs bg-[#E8F8ED] text-[#087C38] hover:bg-[#0BAA4B] hover:text-white font-extrabold px-3 py-1.5 rounded-xl transition flex items-center gap-1"
                    >
                      <Plus className="w-3.5 h-3.5" /> Add Option Card
                    </button>
                  </div>
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

                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Brand-Specific Questionnaire *</label>
                      <select
                        value={categoryForm.brand || ''}
                        onChange={(e) => setCategoryForm({ ...categoryForm, brand: e.target.value ? parseInt(e.target.value) : null })}
                        className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white focus:ring-2 focus:ring-[#0BAA4B]"
                      >
                        <option value="">🌐 Universal (All Brands)</option>
                        {brands.map(b => (
                          <option key={b.id} value={b.id}>{b.name} Exclusive</option>
                        ))}
                      </select>
                      <span className="text-[10px] text-slate-400 mt-0.5 block">Applies only to selected brand, or to all devices if Universal.</span>
                    </div>

                    <div>
                      <label className="block font-bold text-slate-700 mb-1">Step Mandatory / Optional</label>
                      <div className="flex items-center gap-2 p-2 bg-slate-50 border border-slate-200 rounded-xl mt-0.5">
                        <input
                          type="checkbox"
                          id="panel_mandatory_check"
                          checked={categoryForm.is_mandatory ?? true}
                          onChange={(e) => setCategoryForm({ ...categoryForm, is_mandatory: e.target.checked })}
                          className="w-4 h-4 text-[#0BAA4B] rounded"
                        />
                        <label htmlFor="panel_mandatory_check" className="font-bold text-slate-800 text-xs cursor-pointer">
                          Mandatory (Customer must complete)
                        </label>
                      </div>
                    </div>
                  </div>

                  <div>
                    <label className="block font-bold text-slate-700 mb-1">Question Banner / Visual Illustration</label>
                    <div className="flex items-center gap-3">
                      {categoryForm.image_base64 && (
                        <div className="w-14 h-14 rounded-xl border border-slate-200 overflow-hidden bg-slate-50 shrink-0 relative p-1">
                          <img src={formatImageSrc(categoryForm.image_base64)} alt="" className="w-full h-full object-contain" />
                          <button
                            type="button"
                            onClick={() => setCategoryForm({ ...categoryForm, image_base64: '' })}
                            className="absolute top-0.5 right-0.5 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700"
                          >
                            <X className="w-2.5 h-2.5" />
                          </button>
                        </div>
                      )}
                      <label className="border-2 border-dashed border-slate-300 hover:border-[#0BAA4B] rounded-xl p-2.5 text-center cursor-pointer bg-slate-50 flex-1 transition block select-none">
                        <input
                          type="file"
                          accept="image/*"
                          onChange={async (e) => {
                            const file = e.target.files[0];
                            if (file) {
                              const b64 = await fileToBase64(file, 400, 0.75);
                              setCategoryForm(prev => ({ ...prev, image_base64: b64 }));
                            }
                          }}
                          className="hidden"
                        />
                        <Upload className="w-4 h-4 text-slate-400 mx-auto mb-0.5" />
                        <span className="text-xs font-bold text-slate-700 block">
                          {categoryForm.image_base64 ? 'Change Question Image' : 'Upload Question Image / Diagram (Base64)'}
                        </span>
                        <span className="text-[9px] text-slate-400">Stored as Base64 in database & shown in questionnaire</span>
                      </label>
                    </div>
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
                              <img src={formatImageSrc(opt.image_base64)} alt="" className="w-10 h-10 object-contain mx-auto mb-1 rounded" />
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
          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3">
            <div>
              <h3 className="text-base font-extrabold text-slate-900">Device Categories & Brand Series</h3>
              <p className="text-xs text-slate-500">Categories (Mobile, Tablet, Gaming Console, etc.) and series (Galaxy S, iPhone 13 Series) with full Add, Edit, Delete and Active controls.</p>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => handleOpenDeviceCategoryModal()}
                className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-bold text-xs px-3.5 py-2 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Plus className="w-4 h-4" /> Add Device Category
              </button>
              <button
                type="button"
                onClick={() => handleOpenSeriesModal()}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-3.5 py-2 rounded-xl shadow-md transition flex items-center gap-1.5"
              >
                <Plus className="w-4 h-4" /> Add Brand Series
              </button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            {/* Device Categories */}
            <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
              <div className="flex justify-between items-center pb-2 border-b border-slate-100">
                <h4 className="font-extrabold text-slate-900 text-sm">1. Device Categories ({deviceCategories.length})</h4>
                <span className="text-[10px] text-slate-400">Only Active categories appear on App/Web</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-[500px] overflow-y-auto pr-1">
                {deviceCategories.map((dc) => (
                  <div key={dc.id} className={`p-3 rounded-xl border transition flex flex-col justify-between ${
                    dc.is_active ? 'border-slate-200 bg-slate-50/70' : 'border-rose-200 bg-rose-50/30 opacity-70'
                  }`}>
                    <div className="flex items-start justify-between gap-1">
                      <div>
                        <span className="font-bold text-xs text-slate-900 block">{dc.name}</span>
                        <span className="text-[10px] text-slate-400 block font-mono">{dc.slug}</span>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleToggleDeviceCategoryActive(dc)}
                        className={`text-[9px] font-bold px-2 py-0.5 rounded cursor-pointer transition ${
                          dc.is_active 
                            ? 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200' 
                            : 'bg-rose-100 text-rose-800 hover:bg-rose-200'
                        }`}
                        title="Click to toggle active status"
                      >
                        {dc.is_active ? 'Active' : 'Disabled'}
                      </button>
                    </div>

                    <div className="mt-3 pt-2 border-t border-slate-200 flex items-center justify-between text-[11px]">
                      <button
                        type="button"
                        onClick={() => handleOpenDeviceCategoryModal(dc)}
                        className="text-indigo-600 hover:text-indigo-800 font-bold flex items-center gap-1"
                      >
                        <Edit2 className="w-3 h-3" /> Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteDeviceCategory(dc)}
                        className="text-rose-600 hover:text-rose-800 font-bold flex items-center gap-1"
                      >
                        <Trash2 className="w-3 h-3" /> Delete
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Brand Series */}
            <div className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
              <div className="flex justify-between items-center pb-2 border-b border-slate-100">
                <h4 className="font-extrabold text-slate-900 text-sm">2. Configured Series ({seriesList.length})</h4>
                <span className="text-[10px] text-slate-400">Model series grouping</span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 max-h-[500px] overflow-y-auto pr-1">
                {seriesList.map((s) => (
                  <div key={s.id} className="p-3 rounded-xl border border-slate-200 bg-slate-50/70 flex flex-col justify-between">
                    <div>
                      <span className="font-bold text-xs text-slate-900 block">{s.name}</span>
                      <span className="text-[10px] text-indigo-600 font-semibold block">{s.brand_name || 'Brand Series'}</span>
                    </div>
                    <div className="mt-3 pt-2 border-t border-slate-200 flex items-center justify-between text-[11px]">
                      <button
                        type="button"
                        onClick={() => handleOpenSeriesModal(s)}
                        className="text-indigo-600 hover:text-indigo-800 font-bold flex items-center gap-1"
                      >
                        <Edit2 className="w-3 h-3" /> Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDeleteSeries(s)}
                        className="text-rose-600 hover:text-rose-800 font-bold flex items-center gap-1"
                      >
                        <Trash2 className="w-3 h-3" /> Delete
                      </button>
                    </div>
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

          <BulkActionBar
            totalCount={brands.length}
            selectedIds={selectedIds}
            itemName="Brands"
            loading={bulkDeleting}
            onToggleSelectAll={() => setSelectedIds(selectedIds.length === brands.length ? [] : brands.map(b => b.id))}
            onDeleteSelected={() => handleBulkDelete('catalog', 'brands', false, selectedIds, 'Deleting a brand will permanently delete ALL of its Series, Models, and Storage Variants.')}
            onDeleteAll={() => handleBulkDelete('catalog', 'brands', true, [], 'WARNING: This will permanently delete ALL Brands, Series, Models, and Storage Variants!')}
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {brands.map((b) => (
              <div 
                key={b.id} 
                className={`bg-white rounded-2xl border p-5 shadow-sm transition flex flex-col justify-between ${
                  selectedIds.includes(b.id)
                    ? 'border-[#0BAA4B] ring-2 ring-[#0BAA4B]/20'
                    : b.is_active ? 'border-slate-200' : 'border-rose-200 bg-rose-50/20 opacity-75'
                }`}
              >
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        checked={selectedIds.includes(b.id)}
                        onChange={() => toggleSelectId(b.id)}
                        className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                      />
                      <span className="text-[10px] font-mono text-slate-400">Order #{b.display_order}</span>
                    </div>
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
                      <img src={formatImageSrc(b.logo_base64)} alt={b.name} className="max-h-10 max-w-full object-contain" />
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
            
            <div className="flex flex-wrap items-center gap-2 w-full sm:w-auto">
              <select
                value={filterBrandId}
                onChange={(e) => handleBrandFilterChange(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white"
              >
                <option value="">All Brands ({brands.length})</option>
                {brands.map(b => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>

              <select
                value={filterSeriesId}
                onChange={(e) => handleSeriesFilterChange(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white"
              >
                <option value="">All Series ({seriesList.filter(s => !filterBrandId || String(s.brand || s.brand_id) === String(filterBrandId)).length})</option>
                {seriesList
                  .filter(s => !filterBrandId || String(s.brand || s.brand_id) === String(filterBrandId))
                  .map(s => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
              </select>

              {(filterBrandId || filterSeriesId) && (
                <button
                  type="button"
                  onClick={() => { setFilterBrandId(''); setFilterSeriesId(''); setFilterModelId(''); }}
                  className="px-2 py-2 text-rose-600 hover:bg-rose-50 border border-rose-200 rounded-xl text-xs font-bold transition flex items-center gap-1"
                  title="Clear Filters"
                >
                  <X className="w-3.5 h-3.5" /> Clear
                </button>
              )}

              <button
                onClick={() => handleOpenModelModal()}
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs px-4 py-2.5 rounded-xl shadow-md transition flex items-center gap-1.5 shrink-0"
              >
                <Plus className="w-4 h-4" /> Add Model
              </button>
            </div>
          </div>

          {/* Series Quick-Manage & Bulk Delete Panel */}
          {(() => {
            const filteredSeries = seriesList.filter(s => filterBrandId ? String(s.brand) === String(filterBrandId) : true);
            return (
              <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm space-y-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <h4 className="text-xs font-black uppercase tracking-wider text-slate-700">
                      Device Series ({filteredSeries.length})
                    </h4>
                    <p className="text-[11px] text-slate-500">Deleting a series also deletes all Models & Variants inside it.</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      disabled={filteredSeries.length === 0 || bulkDeleting}
                      onClick={() => setSelectedSeriesIds(selectedSeriesIds.length === filteredSeries.length ? [] : filteredSeries.map(s => s.id))}
                      className="px-2.5 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-[11px] rounded-xl transition"
                    >
                      {selectedSeriesIds.length === filteredSeries.length && filteredSeries.length > 0 ? 'Unselect All Series' : 'Select All Series'}
                    </button>
                    {selectedSeriesIds.length > 0 && (
                      <button
                        type="button"
                        disabled={bulkDeleting}
                        onClick={() => handleBulkDelete('catalog', 'series', false, selectedSeriesIds, 'Deleting these series will also permanently delete ALL Models & Variants in them.')}
                        className="px-2.5 py-1.5 bg-rose-600 hover:bg-rose-700 text-white font-bold text-[11px] rounded-xl transition flex items-center gap-1"
                      >
                        <Trash2 className="w-3 h-3" /> Delete Selected Series ({selectedSeriesIds.length})
                      </button>
                    )}
                    <button
                      type="button"
                      disabled={filteredSeries.length === 0 || bulkDeleting}
                      onClick={() => handleBulkDelete('catalog', 'series', !filterBrandId, filterBrandId ? filteredSeries.map(s => s.id) : [], 'This will delete ALL displayed Series and ALL Models & Variants inside them!')}
                      className="px-2.5 py-1.5 bg-rose-50 hover:bg-rose-100 text-rose-700 border border-rose-200 font-bold text-[11px] rounded-xl transition flex items-center gap-1"
                    >
                      <Trash2 className="w-3 h-3" /> Delete All Series
                    </button>
                  </div>
                </div>
                {filteredSeries.length > 0 && (
                  <div className="flex flex-wrap gap-1.5 max-h-28 overflow-y-auto pt-1">
                    {filteredSeries.map(s => {
                      const isSel = selectedSeriesIds.includes(s.id);
                      const bName = brands.find(b => b.id === s.brand)?.name;
                      return (
                        <label
                          key={s.id}
                          className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg border text-[11px] font-bold cursor-pointer transition ${
                            isSel ? 'bg-rose-50 border-rose-300 text-rose-800' : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                          }`}
                        >
                          <input
                            type="checkbox"
                            checked={isSel}
                            onChange={() => setSelectedSeriesIds(prev => prev.includes(s.id) ? prev.filter(x => x !== s.id) : [...prev, s.id])}
                            className="w-3.5 h-3.5 rounded text-rose-600 focus:ring-rose-500"
                          />
                          <span>{!filterBrandId && bName ? `${bName} · ` : ''}{s.name}</span>
                        </label>
                      );
                    })}
                  </div>
                )}
              </div>
            );
          })()}

          {(() => {
            return (
              <BulkActionBar
                totalCount={modelsTotalCount || models.length}
                selectedIds={selectedIds}
                itemName="Models"
                loading={bulkDeleting}
                onToggleSelectAll={() => setSelectedIds(selectedIds.length === models.length ? [] : models.map(m => m.id))}
                onDeleteSelected={() => handleBulkDelete('catalog', 'models', false, selectedIds, 'Deleting models will also delete all their Storage Variants.')}
                onDeleteAll={() => handleBulkDelete('catalog', 'models', !filterBrandId && !filterSeriesId, (filterBrandId || filterSeriesId) ? models.map(m => m.id) : [], 'This will delete ALL displayed Models and their Storage Variants!')}
              />
            );
          })()}

          {(() => {
            if (modelsLoading) {
              return (
                <div className="bg-white rounded-3xl border border-slate-200/90 p-14 text-center shadow-sm flex flex-col items-center justify-center my-4 animate-fade-in">
                  <div className="relative w-16 h-16 flex items-center justify-center mb-4">
                    <div className="absolute inset-0 rounded-2xl bg-[#0BAA4B]/20 animate-ping" />
                    <img
                      src="/dolly_icon.png"
                      alt="Dolly"
                      onError={(e) => { e.currentTarget.src = '/dolly_logo.png'; }}
                      className="w-12 h-12 object-contain rounded-2xl relative animate-pulse shadow-md"
                    />
                  </div>
                  <h4 className="text-base font-extrabold text-slate-900">Loading Catalogue Models</h4>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                    Retrieving devices, series & valuation matrix...
                  </p>
                </div>
              );
            }

            if (models.length === 0) {
              const activeBrand = brands.find(b => String(b.id) === String(filterBrandId));
              const activeSeries = seriesList.find(s => String(s.id) === String(filterSeriesId));
              return (
                <div className="bg-white rounded-2xl border border-slate-200 p-8 text-center shadow-sm">
                  <Smartphone className="w-10 h-10 text-slate-300 mx-auto mb-2" />
                  <h4 className="text-sm font-extrabold text-slate-800">
                    No models found {activeSeries ? `under "${activeSeries.name}"` : (activeBrand ? `for ${activeBrand.name}` : '')}
                  </h4>
                  <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
                    {filterSeriesId 
                      ? 'This series has no models configured yet. You can view all series models or add a new model to this series.'
                      : 'No models configured yet. Click below to add a model.'}
                  </p>
                  <div className="flex items-center justify-center gap-2 mt-4">
                    {filterSeriesId && (
                      <button
                        type="button"
                        onClick={() => setFilterSeriesId('')}
                        className="px-3 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition"
                      >
                        View All {activeBrand ? activeBrand.name : ''} Series
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => handleOpenModelModal()}
                      className="px-3.5 py-1.5 bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs rounded-xl shadow transition flex items-center gap-1.5"
                    >
                      <Plus className="w-3.5 h-3.5" /> Add Model
                    </button>
                  </div>
                </div>
              );
            }

            return (
              <div>
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                  {models.map((m) => {
                    const modelVariants = variants.filter(v => v.model === m.id || v.model_id === m.id);
                    return (
                      <div key={m.id} className={`bg-white rounded-2xl border p-4 shadow-sm flex flex-col justify-between ${
                        selectedIds.includes(m.id) ? 'border-[#0BAA4B] ring-2 ring-[#0BAA4B]/20' : 'border-slate-200'
                      }`}>
                        <div>
                          <div className="flex justify-between items-start">
                            <div className="flex items-center gap-1.5">
                              <input
                                type="checkbox"
                                checked={selectedIds.includes(m.id)}
                                onChange={() => toggleSelectId(m.id)}
                                className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                              />
                              <span className="text-[10px] font-bold uppercase tracking-wider text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded">
                                {m.brand_name || 'Brand'}
                              </span>
                            </div>
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
                              <img src={formatImageSrc(m.image_base64)} alt={m.name} className="max-h-20 max-w-full object-contain" />
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

                {/* ================= PAGINATION CONTROLS ================= */}
                {modelsTotalCount > 0 && (
                  <div className="bg-white rounded-2xl border border-slate-200 p-4 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4 mt-6">
                    <div className="flex flex-wrap items-center gap-3 text-xs text-slate-500">
                      <span>
                        Showing <strong className="text-slate-800">{(modelsPage - 1) * modelsPageSize + 1}</strong> to <strong className="text-slate-800">{Math.min(modelsPage * modelsPageSize, modelsTotalCount)}</strong> of <strong className="text-slate-800">{modelsTotalCount.toLocaleString()}</strong> Models
                      </span>
                      <div className="flex items-center gap-1.5 ml-2 border-l border-slate-200 pl-3">
                        <span className="text-[11px] font-bold text-slate-400">Per page:</span>
                        <select
                          value={modelsPageSize}
                          onChange={(e) => {
                            setModelsPageSize(Number(e.target.value));
                            setModelsPage(1);
                          }}
                          className="bg-slate-50 border border-slate-200 rounded-lg px-2 py-1 text-xs font-bold text-slate-700 outline-none cursor-pointer"
                        >
                          <option value={12}>12</option>
                          <option value={24}>24</option>
                          <option value={48}>48</option>
                          <option value={96}>96</option>
                        </select>
                      </div>
                    </div>

                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        disabled={modelsPage <= 1 || modelsLoading}
                        onClick={() => setModelsPage(prev => Math.max(1, prev - 1))}
                        className="px-3.5 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-bold transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1"
                      >
                        &larr; Previous
                      </button>

                      <div className="flex items-center gap-1 px-1">
                        {Array.from({ length: Math.min(5, modelsTotalPages) }, (_, i) => {
                          let pageNum;
                          if (modelsTotalPages <= 5) {
                            pageNum = i + 1;
                          } else if (modelsPage <= 3) {
                            pageNum = i + 1;
                          } else if (modelsPage >= modelsTotalPages - 2) {
                            pageNum = modelsTotalPages - 4 + i;
                          } else {
                            pageNum = modelsPage - 2 + i;
                          }
                          return (
                            <button
                              key={pageNum}
                              type="button"
                              disabled={modelsLoading}
                              onClick={() => setModelsPage(pageNum)}
                              className={`w-8 h-8 rounded-xl text-xs font-bold transition ${
                                modelsPage === pageNum
                                  ? 'bg-[#0BAA4B] text-white shadow-sm'
                                  : 'text-slate-600 hover:bg-slate-100 border border-transparent'
                              }`}
                            >
                              {pageNum}
                            </button>
                          );
                        })}
                      </div>

                      <button
                        type="button"
                        disabled={modelsPage >= modelsTotalPages || modelsLoading}
                        onClick={() => setModelsPage(prev => Math.min(modelsTotalPages, prev + 1))}
                        className="px-3.5 py-1.5 rounded-xl border border-slate-200 bg-white hover:bg-slate-50 text-slate-700 text-xs font-bold transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1"
                      >
                        Next &rarr;
                      </button>
                    </div>
                  </div>
                )}
              </div>
            );
          })()}
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

          {/* ================= BRAND, SERIES & MODEL FILTERS BAR ================= */}
          <div className="bg-white rounded-2xl border border-slate-200 p-3 shadow-sm flex flex-wrap items-center justify-between gap-3">
            <div className="flex flex-wrap items-center gap-2 flex-1 min-w-[280px]">
              <div className="flex items-center gap-1.5 text-xs font-bold text-slate-700 mr-1">
                <Filter className="w-3.5 h-3.5 text-indigo-600" />
                <span>Filters:</span>
              </div>

              {/* Brand Filter */}
              <select
                value={filterBrandId}
                onChange={(e) => handleBrandFilterChange(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white text-slate-800 focus:ring-2 focus:ring-indigo-500/20"
              >
                <option value="">All Brands ({brands.length})</option>
                {brands.map(b => (
                  <option key={b.id} value={b.id}>{b.name}</option>
                ))}
              </select>

              {/* Series Filter */}
              <select
                value={filterSeriesId}
                onChange={(e) => handleSeriesFilterChange(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white text-slate-800 focus:ring-2 focus:ring-indigo-500/20"
              >
                <option value="">All Series ({seriesList.filter(s => !filterBrandId || String(s.brand || s.brand_id) === String(filterBrandId)).length})</option>
                {seriesList
                  .filter(s => !filterBrandId || String(s.brand || s.brand_id) === String(filterBrandId))
                  .map(s => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
              </select>

              {/* Model Filter */}
              <select
                value={filterModelId}
                onChange={(e) => setFilterModelId(e.target.value)}
                className="px-3 py-2 border border-slate-300 rounded-xl text-xs font-bold bg-white text-slate-800 focus:ring-2 focus:ring-indigo-500/20 max-w-[220px]"
              >
                <option value="">All Models</option>
                {models
                  .filter(m => (!filterBrandId || String(m.brand || m.brand?.id) === String(filterBrandId)) && (!filterSeriesId || String(m.series || m.series?.id) === String(filterSeriesId)))
                  .map(m => (
                    <option key={m.id} value={m.id}>{m.name}</option>
                  ))}
              </select>

              {/* Text Search */}
              <div className="relative min-w-[180px] flex-1 max-w-xs">
                <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                <input
                  type="text"
                  placeholder="Search model, storage, RAM..."
                  value={variantSearch}
                  onChange={(e) => setVariantSearch(e.target.value)}
                  className="w-full pl-8 pr-7 py-2 border border-slate-300 rounded-xl text-xs font-medium focus:ring-2 focus:ring-indigo-500/20 bg-slate-50 focus:bg-white"
                />
                {variantSearch && (
                  <button
                    type="button"
                    onClick={() => setVariantSearch('')}
                    className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-600"
                  >
                    <X className="w-3 h-3" />
                  </button>
                )}
              </div>

              {/* Reset Filters */}
              {(filterBrandId || filterSeriesId || filterModelId || variantSearch) && (
                <button
                  type="button"
                  onClick={() => {
                    setFilterBrandId('');
                    setFilterSeriesId('');
                    setFilterModelId('');
                    setVariantSearch('');
                  }}
                  className="px-2.5 py-1.5 text-rose-600 hover:bg-rose-50 border border-rose-200 rounded-xl text-xs font-bold transition flex items-center gap-1"
                >
                  <X className="w-3.5 h-3.5" /> Reset
                </button>
              )}
            </div>

            {/* Total / Filtered Counts */}
            {(() => {
              const count = variants.filter(v => {
                const m = models.find(mod => mod.id === (v.model || v.model_id));
                const vBrandId = v.brand_id || (m ? (m.brand?.id || m.brand) : null);
                const vSeriesId = v.series_id || (m ? (m.series?.id || m.series) : null);
                if (filterBrandId && String(vBrandId) !== String(filterBrandId)) return false;
                if (filterSeriesId && String(vSeriesId) !== String(filterSeriesId)) return false;
                if (filterModelId && String(v.model || v.model_id) !== String(filterModelId)) return false;
                if (variantSearch.trim()) {
                  const q = variantSearch.toLowerCase().trim();
                  const bName = (v.brand_name || (m?.brand_name) || '').toLowerCase();
                  const mName = (v.model_name || (m?.name) || '').toLowerCase();
                  const sName = (v.series_name || (m?.series_name) || '').toLowerCase();
                  const storageStr = (v.storage || '').toLowerCase();
                  const ramStr = (v.ram || '').toLowerCase();
                  if (!bName.includes(q) && !mName.includes(q) && !sName.includes(q) && !storageStr.includes(q) && !ramStr.includes(q)) return false;
                }
                return true;
              }).length;

              return (
                <div className="text-[11px] font-bold text-slate-500 whitespace-nowrap">
                  Showing <span className="text-slate-900 font-extrabold">{count}</span> of {variants.length}
                </div>
              );
            })()}
          </div>

          {(() => {
            const filteredVariants = variants.filter(v => {
              const m = models.find(mod => mod.id === (v.model || v.model_id));
              const vBrandId = v.brand_id || (m ? (m.brand?.id || m.brand) : null);
              const vSeriesId = v.series_id || (m ? (m.series?.id || m.series) : null);

              if (filterBrandId && String(vBrandId) !== String(filterBrandId)) return false;
              if (filterSeriesId && String(vSeriesId) !== String(filterSeriesId)) return false;
              if (filterModelId && String(v.model || v.model_id) !== String(filterModelId)) return false;
              if (variantSearch.trim()) {
                const q = variantSearch.toLowerCase().trim();
                const bName = (v.brand_name || (m?.brand_name) || '').toLowerCase();
                const mName = (v.model_name || (m?.name) || '').toLowerCase();
                const sName = (v.series_name || (m?.series_name) || '').toLowerCase();
                const storageStr = (v.storage || '').toLowerCase();
                const ramStr = (v.ram || '').toLowerCase();
                if (!bName.includes(q) && !mName.includes(q) && !sName.includes(q) && !storageStr.includes(q) && !ramStr.includes(q)) return false;
              }
              return true;
            });

            const hasActiveFilters = Boolean(filterBrandId || filterSeriesId || filterModelId || variantSearch);

            return (
              <>
                <BulkActionBar
                  totalCount={filteredVariants.length}
                  selectedIds={selectedIds}
                  itemName="Storage Variants"
                  loading={bulkDeleting}
                  onToggleSelectAll={() => setSelectedIds(selectedIds.length === filteredVariants.length ? [] : filteredVariants.map(v => v.id))}
                  onDeleteSelected={() => handleBulkDelete('catalog', 'variants', false, selectedIds)}
                  onDeleteAll={() => handleBulkDelete(
                    'catalog',
                    'variants',
                    !hasActiveFilters,
                    hasActiveFilters ? filteredVariants.map(v => v.id) : [],
                    hasActiveFilters
                      ? `This will delete ALL ${filteredVariants.length} filtered Storage Variants!`
                      : 'This will delete ALL Storage Variants & Base Prices!'
                  )}
                />

                <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
                  <div className="overflow-x-auto">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-900 text-white uppercase text-[10px] tracking-wider font-bold">
                        <tr>
                          <th className="py-3 px-4 w-10">
                            <input
                              type="checkbox"
                              checked={filteredVariants.length > 0 && selectedIds.length === filteredVariants.length}
                              onChange={() => setSelectedIds(selectedIds.length === filteredVariants.length ? [] : filteredVariants.map(v => v.id))}
                              className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                            />
                          </th>
                          <th className="py-3 px-4">Brand & Model</th>
                          <th className="py-3 px-4">Spec / Storage</th>
                          <th className="py-3 px-4">Configured Base Price</th>
                          <th className="py-3 px-4">Min Floor Price</th>
                          <th className="py-3 px-4">Status</th>
                          <th className="py-3 px-4 text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {modelsLoading ? (
                          <tr>
                            <td colSpan={7} className="text-center py-12">
                              <div className="relative w-12 h-12 mx-auto mb-3 flex items-center justify-center">
                                <div className="absolute inset-0 rounded-2xl bg-[#0BAA4B]/20 animate-ping" />
                                <img
                                  src="/dolly_icon.png"
                                  alt="Dolly"
                                  onError={(e) => { e.currentTarget.src = '/dolly_logo.png'; }}
                                  className="w-9 h-9 object-contain rounded-xl relative animate-pulse shadow-sm"
                                />
                              </div>
                              <p className="font-bold text-sm text-slate-700">Loading Storage Variants...</p>
                              <p className="text-xs text-slate-400 mt-0.5">Fetching pricing matrix and models...</p>
                            </td>
                          </tr>
                        ) : filteredVariants.length === 0 ? (
                          <tr>
                            <td colSpan={7} className="text-center py-12 text-slate-400">
                              <AlertCircle className="w-8 h-8 mx-auto mb-2 opacity-40 text-slate-400" />
                              <p className="font-bold text-sm text-slate-600">No Storage Variants Found</p>
                              <p className="text-xs text-slate-400 mt-0.5">
                                {hasActiveFilters ? 'Try adjusting or clearing your filters.' : 'No storage variants configured yet.'}
                              </p>
                              {hasActiveFilters && (
                                <button
                                  type="button"
                                  onClick={() => {
                                    setFilterBrandId('');
                                    setFilterSeriesId('');
                                    setFilterModelId('');
                                    setVariantSearch('');
                                  }}
                                  className="mt-3 px-3 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-xs rounded-xl transition inline-flex items-center gap-1.5"
                                >
                                  <X className="w-3.5 h-3.5" /> Clear All Filters
                                </button>
                              )}
                            </td>
                          </tr>
                        ) : (
                          filteredVariants.map((v) => (
                            <tr key={v.id} className={`hover:bg-slate-50 transition ${selectedIds.includes(v.id) ? 'bg-emerald-50/40' : ''}`}>
                              <td className="py-3 px-4">
                                <input
                                  type="checkbox"
                                  checked={selectedIds.includes(v.id)}
                                  onChange={() => toggleSelectId(v.id)}
                                  className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                                />
                              </td>
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
                          ))
                        )}
                      </tbody>
                    </table>
                  </div>
                </div>
              </>
            );
          })()}
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
          {/* Top Section: Initial Triage Gate Deductions */}
          <div className="bg-rose-50/60 border border-rose-200/80 rounded-2xl p-4 sm:p-5 shadow-xs">
            <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-3">
              <div className="flex items-center gap-2.5">
                <div className="w-9 h-9 rounded-xl bg-rose-600 text-white flex items-center justify-center shrink-0 shadow-sm">
                  <ShieldAlert className="w-5 h-5" />
                </div>
                <div>
                  <h4 className="text-sm font-extrabold text-slate-900 flex items-center gap-2">
                    Initial Triage Gate Deductions
                    <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-rose-100 text-rose-700">
                      {triageQuestions.length} Gates
                    </span>
                  </h4>
                  <p className="text-xs text-slate-500">
                    Upfront health check questions evaluated first. Answering "No" deducts percentage or flat amount, or rejects dead devices.
                  </p>
                </div>
              </div>

              <button
                type="button"
                onClick={() => handleOpenTriageModal()}
                className="bg-rose-600 hover:bg-rose-700 text-white font-bold text-xs px-3.5 py-2 rounded-xl shadow transition flex items-center gap-1.5 shrink-0"
              >
                <Plus className="w-3.5 h-3.5" /> Add Triage Question
              </button>
            </div>

            {triageQuestions.length === 0 ? (
              <div className="bg-white rounded-xl border border-rose-100 p-4 text-center text-xs text-slate-500">
                No initial triage questions configured yet. Click "+ Add Triage Question" to add power-on or screen gates.
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3 pt-1">
                {triageQuestions.map((tq, idx) => (
                  <div
                    key={tq.id || idx}
                    className="bg-white p-3.5 rounded-xl border border-rose-100 shadow-xs hover:border-rose-300 transition flex flex-col justify-between"
                  >
                    <div>
                      <div className="flex items-start justify-between gap-2">
                        <span className="text-xs font-black text-slate-900 leading-snug">
                          {idx + 1}. {tq.question_text}
                        </span>
                        <div className="flex items-center gap-1 shrink-0">
                          <button
                            type="button"
                            onClick={() => handleOpenTriageModal(tq)}
                            className="p-1.5 text-slate-500 hover:text-rose-600 rounded-lg hover:bg-rose-50 transition"
                            title="Edit Question & Deduction"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteTriageQuestion(tq)}
                            className="p-1.5 text-slate-400 hover:text-red-600 rounded-lg hover:bg-red-50 transition"
                            title="Delete Question"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      </div>
                      {tq.subtitle && (
                        <p className="text-[11px] text-slate-500 mt-1 line-clamp-2">
                          {tq.subtitle}
                        </p>
                      )}
                    </div>

                    <div className="mt-3 pt-2.5 border-t border-slate-100 flex items-center justify-between text-[11px]">
                      <div className="flex items-center gap-1.5">
                        {tq.is_power_on_gate ? (
                          <span className="bg-rose-100 text-rose-700 font-bold px-2 py-0.5 rounded-full flex items-center gap-1 text-[10px]">
                            ⚡ Reject / Power-On Gate
                          </span>
                        ) : (
                          <span className="bg-slate-100 text-slate-600 font-semibold px-2 py-0.5 rounded-full text-[10px]">
                            Progressive Gate
                          </span>
                        )}
                        <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded ${tq.is_active !== false ? 'bg-emerald-50 text-emerald-700' : 'bg-slate-100 text-slate-500'}`}>
                          {tq.is_active !== false ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                      <span className="font-extrabold text-rose-600">
                        Deduct on "No": {tq.deduction_type === 'PERCENTAGE' ? `-${tq.deduction_value_on_no}%` : `-₹${tq.deduction_value_on_no}`}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 pt-2">
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

          <BulkActionBar
            totalCount={options.length}
            selectedIds={selectedIds}
            itemName="Deduction Rules"
            loading={bulkDeleting}
            onToggleSelectAll={() => setSelectedIds(selectedIds.length === options.length ? [] : options.map(o => o.id))}
            onDeleteSelected={() => handleBulkDelete('valuation', 'options', false, selectedIds)}
            onDeleteAll={() => handleBulkDelete('valuation', 'options', true, [], 'This will delete ALL Deduction Rules & Options!')}
          />

          <div className="bg-white rounded-2xl border border-slate-200 overflow-hidden shadow-sm">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-900 text-white uppercase text-[10px] tracking-wider font-bold">
                  <tr>
                    <th className="py-3 px-4 w-10">
                      <input
                        type="checkbox"
                        checked={options.length > 0 && selectedIds.length === options.length}
                        onChange={() => setSelectedIds(selectedIds.length === options.length ? [] : options.map(o => o.id))}
                        className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                      />
                    </th>
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
                    <tr key={opt.id} className={`hover:bg-slate-50 transition ${selectedIds.includes(opt.id) ? 'bg-emerald-50/40' : ''}`}>
                      <td className="py-3 px-4">
                        <input
                          type="checkbox"
                          checked={selectedIds.includes(opt.id)}
                          onChange={() => toggleSelectId(opt.id)}
                          className="w-4 h-4 rounded text-[#0BAA4B] focus:ring-[#0BAA4B] cursor-pointer"
                        />
                      </td>
                      <td className="py-3 px-4">
                        <div className="flex items-center gap-2.5">
                          {opt.image_base64 ? (
                            <img src={formatImageSrc(opt.image_base64)} alt="" className="w-10 h-10 rounded-xl object-contain bg-slate-50 border border-slate-200 shrink-0 p-0.5" />
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
      <ResponsiveModal
        isOpen={brandModalOpen}
        onClose={() => setBrandModalOpen(false)}
        title={editingBrand ? `Edit Brand: ${editingBrand.name}` : 'Add New Phone Brand'}
      >
        <form onSubmit={handleSaveBrand} className="space-y-4">
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
                <img src={formatImageSrc(brandForm.logo_base64)} alt="Preview" className="max-h-8 object-contain" />
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

          <div className="flex gap-2 pt-3 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setBrandModalOpen(false)}
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold text-slate-700 hover:bg-slate-50 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="w-1/2 bg-[#0BAA4B] hover:bg-[#087C38] text-white py-2.5 rounded-xl font-bold shadow-md transition"
            >
              Save Brand
            </button>
          </div>
        </form>
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT MODEL ================= */}
      <ResponsiveModal
        isOpen={modelModalOpen}
        onClose={() => setModelModalOpen(false)}
        title={editingModel ? `Edit Model: ${editingModel.name}` : 'Add Phone Model'}
      >
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
            <label className="block font-bold text-slate-700 mb-1">Brand Series (Optional)</label>
            <select
              value={modelForm.series || ''}
              onChange={(e) => setModelForm({ ...modelForm, series: e.target.value ? parseInt(e.target.value) : '' })}
              className="w-full p-2.5 border border-slate-300 rounded-xl font-medium bg-white"
            >
              <option value="">No Series Grouping</option>
              {seriesList
                .filter(s => !modelForm.brand || s.brand === parseInt(modelForm.brand) || s.brand_id === parseInt(modelForm.brand))
                .map(s => (
                  <option key={s.id} value={s.id}>{s.name}</option>
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
            <label className="block font-bold text-slate-700 mb-1">Device Illustration / Photo</label>
            <div className="flex items-center gap-3">
              {modelForm.image_base64 && (
                <div className="w-16 h-16 rounded-xl border border-slate-200 overflow-hidden bg-slate-50 shrink-0 relative p-1 flex items-center justify-center">
                  <img src={formatImageSrc(modelForm.image_base64)} alt="" className="w-full h-full object-contain" />
                  <button
                    type="button"
                    onClick={() => setModelForm(prev => ({ ...prev, image_base64: '' }))}
                    className="absolute top-0.5 right-0.5 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700"
                    title="Remove photo"
                  >
                    <X className="w-2.5 h-2.5" />
                  </button>
                </div>
              )}
              <label className="border-2 border-dashed border-slate-300 hover:border-indigo-500 rounded-xl p-3 text-center cursor-pointer bg-slate-50 flex-1 transition block select-none">
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const f = e.target.files[0];
                    if (f) {
                      const b64 = await fileToBase64(f, 600, 0.8);
                      setModelForm(prev => ({ ...prev, image_base64: b64 }));
                    }
                  }}
                  className="hidden"
                />
                <Upload className="w-4 h-4 text-slate-400 mx-auto mb-1" />
                <span className="text-xs font-bold text-slate-700 block">
                  {modelForm.image_base64 ? 'Change Device Photo' : 'Upload Device Photo (JPG/PNG)'}
                </span>
                <span className="text-[10px] text-slate-400">Stores directly as Base64 in DB and renders on mobile</span>
              </label>
            </div>
          </div>

          <div className="space-y-2 pt-2 border-t border-slate-100">
            <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-700 text-xs select-none">
              <input
                type="checkbox"
                checked={modelForm.has_warranty !== false}
                onChange={(e) => setModelForm({ ...modelForm, has_warranty: e.target.checked })}
                className="rounded text-emerald-600 focus:ring-emerald-500 w-4 h-4"
              />
              <span>Include Warranty Questions (Uncheck for older/discontinued models to skip warranty questions)</span>
            </label>

            <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-700 text-xs select-none">
              <input
                type="checkbox"
                checked={modelForm.is_active}
                onChange={(e) => setModelForm({ ...modelForm, is_active: e.target.checked })}
                className="rounded text-emerald-600 focus:ring-emerald-500 w-4 h-4"
              />
              <span>Active & Accept Submissions</span>
            </label>
          </div>

          <div className="flex gap-2 pt-3">
            <button
              type="button"
              onClick={() => setModelModalOpen(false)}
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
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
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT VARIANT & PRICE ================= */}
      <ResponsiveModal
        isOpen={variantModalOpen}
        onClose={() => setVariantModalOpen(false)}
        title={editingVariant ? `Update Base Price: ${editingVariant.model_name}` : 'Add Storage Variant & Price'}
      >
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
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
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
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT CATEGORY ================= */}
      <ResponsiveModal
        isOpen={categoryModalOpen}
        onClose={() => setCategoryModalOpen(false)}
        title={editingCategory ? `Edit Category: ${editingCategory.name}` : 'Add Condition Category'}
      >
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

          <div>
            <label className="block font-bold text-slate-700 mb-1">Category Photo / Icon (Base64)</label>
            <div className="flex items-center gap-3">
              {categoryForm.image_base64 && (
                <div className="w-14 h-14 rounded-xl border border-slate-200 overflow-hidden bg-slate-50 shrink-0 relative p-1 flex items-center justify-center">
                  <img src={formatImageSrc(categoryForm.image_base64)} alt="" className="w-full h-full object-contain" />
                  <button
                    type="button"
                    onClick={() => setCategoryForm(prev => ({ ...prev, image_base64: '' }))}
                    className="absolute top-0.5 right-0.5 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700"
                    title="Remove photo"
                  >
                    <X className="w-2.5 h-2.5" />
                  </button>
                </div>
              )}
              <label className="border-2 border-dashed border-slate-300 hover:border-[#0BAA4B] rounded-xl p-2.5 text-center cursor-pointer bg-slate-50 flex-1 transition block select-none">
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const f = e.target.files[0];
                    if (f) {
                      const b64 = await fileToBase64(f, 400, 0.8);
                      setCategoryForm(prev => ({ ...prev, image_base64: b64 }));
                    }
                  }}
                  className="hidden"
                />
                <Upload className="w-4 h-4 text-slate-400 mx-auto mb-0.5" />
                <span className="text-xs font-bold text-slate-700 block">
                  {categoryForm.image_base64 ? 'Change Category Image' : 'Upload Category Image (Base64)'}
                </span>
                <span className="text-[9px] text-slate-400">Rendered in Mobile App and Web Buyback Home</span>
              </label>
            </div>
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
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
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
      </ResponsiveModal>

      {/* ================= MODAL: COPY QUESTIONS FROM BRAND ================= */}
      <ResponsiveModal
        isOpen={copyModalOpen}
        onClose={() => setCopyModalOpen(false)}
        title="Copy Questions from Brand"
      >
        <div className="space-y-4">
          <div className="flex items-center gap-2">
            <div className="p-2 bg-emerald-100 text-emerald-700 rounded-xl">
              <Sparkles className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-sm text-slate-900">Clone Diagnostic Flow</h3>
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
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT DEDUCTION RULE ================= */}
      <ResponsiveModal
        isOpen={optionModalOpen}
        onClose={() => setOptionModalOpen(false)}
        title={editingOption ? `Edit Rule: ${editingOption.title}` : 'Add Condition Deduction Rule'}
      >
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
                  <img src={formatImageSrc(optionForm.image_base64)} alt="" className="w-full h-full object-contain" />
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
                {optionForm.deduction_type === 'PERCENTAGE' ? 'Percentage Value (% of Base Price) *' : 'Deduction Amount (₹) *'}
              </label>
              <div className="relative">
                <input
                  type="number"
                  step={optionForm.deduction_type === 'PERCENTAGE' ? '1' : '50'}
                  min="0"
                  max={optionForm.deduction_type === 'PERCENTAGE' ? '100' : '100000'}
                  required
                  value={optionForm.default_deduction_value}
                  onChange={(e) => setOptionForm({ ...optionForm, default_deduction_value: e.target.value })}
                  className="w-full p-2.5 border border-slate-300 rounded-xl font-black text-rose-600 text-sm pr-8"
                />
                <span className="absolute right-3 top-2.5 text-slate-400 font-bold text-sm">
                  {optionForm.deduction_type === 'PERCENTAGE' ? '%' : '₹'}
                </span>
              </div>
              {optionForm.deduction_type === 'PERCENTAGE' && (
                <p className="text-[11px] text-indigo-600 font-semibold mt-1">
                  ℹ️ Example: On a ₹40,000 phone, {optionForm.default_deduction_value || 0}% will deduct ₹{Math.round(40000 * ((Number(optionForm.default_deduction_value) || 0) / 100)).toLocaleString('en-IN')}.
                </p>
              )}
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
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
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
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT DEVICE CATEGORY ================= */}
      <ResponsiveModal
        isOpen={deviceCategoryModalOpen}
        onClose={() => setDeviceCategoryModalOpen(false)}
        title={editingDeviceCategory ? `Edit Category: ${editingDeviceCategory.name}` : 'Add Device Category'}
      >
        <form onSubmit={handleSaveDeviceCategory} className="space-y-3">
          <div>
            <label className="block font-bold text-slate-700 mb-1">Category Name *</label>
            <input
              type="text"
              required
              value={deviceCategoryForm.name}
              onChange={(e) => setDeviceCategoryForm({ ...deviceCategoryForm, name: e.target.value })}
              placeholder="e.g. Mobile, Tablet, Gaming Console"
              className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Subtitle</label>
            <input
              type="text"
              value={deviceCategoryForm.subtitle}
              onChange={(e) => setDeviceCategoryForm({ ...deviceCategoryForm, subtitle: e.target.value })}
              placeholder="e.g. Sell used smartphones with instant valuation"
              className="w-full p-2.5 border border-slate-300 rounded-xl"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Icon Name</label>
            <input
              type="text"
              value={deviceCategoryForm.icon_name}
              onChange={(e) => setDeviceCategoryForm({ ...deviceCategoryForm, icon_name: e.target.value })}
              placeholder="Smartphone, Tablet, Gamepad..."
              className="w-full p-2 border border-slate-300 rounded-xl font-mono"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Category Photo / Icon (Base64)</label>
            <div className="flex items-center gap-3">
              {deviceCategoryForm.image_base64 && (
                <div className="w-14 h-14 rounded-xl border border-slate-200 overflow-hidden bg-slate-50 shrink-0 relative p-1 flex items-center justify-center">
                  <img src={formatImageSrc(deviceCategoryForm.image_base64)} alt="" className="w-full h-full object-contain" />
                  <button
                    type="button"
                    onClick={() => setDeviceCategoryForm(prev => ({ ...prev, image_base64: '' }))}
                    className="absolute top-0.5 right-0.5 bg-rose-600 text-white rounded-full p-0.5 shadow hover:bg-rose-700"
                    title="Remove photo"
                  >
                    <X className="w-2.5 h-2.5" />
                  </button>
                </div>
              )}
              <label className="border-2 border-dashed border-slate-300 hover:border-[#0BAA4B] rounded-xl p-2.5 text-center cursor-pointer bg-slate-50 flex-1 transition block select-none">
                <input
                  type="file"
                  accept="image/*"
                  onChange={async (e) => {
                    const f = e.target.files[0];
                    if (f) {
                      const b64 = await fileToBase64(f, 400, 0.8);
                      setDeviceCategoryForm(prev => ({ ...prev, image_base64: b64 }));
                    }
                  }}
                  className="hidden"
                />
                <Upload className="w-4 h-4 text-slate-400 mx-auto mb-0.5" />
                <span className="text-xs font-bold text-slate-700 block">
                  {deviceCategoryForm.image_base64 ? 'Change Category Image' : 'Upload Category Image (Base64)'}
                </span>
                <span className="text-[9px] text-slate-400">Rendered in Mobile App and Web Buyback Home</span>
              </label>
            </div>
          </div>

          <div className="flex items-center gap-2 p-2.5 bg-slate-50 rounded-xl border border-slate-200">
            <input
              type="checkbox"
              id="dc_is_active_check"
              checked={deviceCategoryForm.is_active}
              onChange={(e) => setDeviceCategoryForm({ ...deviceCategoryForm, is_active: e.target.checked })}
              className="w-4 h-4 text-emerald-600 rounded"
            />
            <label htmlFor="dc_is_active_check" className="font-bold text-slate-700 text-xs cursor-pointer">
              Category is Active (Visible on Customer App & Web)
            </label>
          </div>

          <div className="flex gap-2 pt-3">
            <button
              type="button"
              onClick={() => setDeviceCategoryModalOpen(false)}
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="w-1/2 bg-[#0BAA4B] hover:bg-[#087C38] text-white py-2.5 rounded-xl font-bold shadow-md"
            >
              Save Category
            </button>
          </div>
        </form>
      </ResponsiveModal>

      {/* ================= MODAL: ADD / EDIT SERIES ================= */}
      <ResponsiveModal
        isOpen={seriesModalOpen}
        onClose={() => setSeriesModalOpen(false)}
        title={editingSeries ? `Edit Series: ${editingSeries.name}` : 'Add Brand Series'}
      >
        <form onSubmit={handleSaveSeries} className="space-y-3">
          <div>
            <label className="block font-bold text-slate-700 mb-1">Brand *</label>
            <select
              required
              value={seriesForm.brand}
              onChange={(e) => setSeriesForm({ ...seriesForm, brand: parseInt(e.target.value) })}
              className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white"
            >
              <option value="">Select Brand</option>
              {brands.map(b => (
                <option key={b.id} value={b.id}>{b.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Series Name *</label>
            <input
              type="text"
              required
              value={seriesForm.name}
              onChange={(e) => setSeriesForm({ ...seriesForm, name: e.target.value })}
              placeholder="e.g. Galaxy S Series, iPhone 15 Series"
              className="w-full p-2.5 border border-slate-300 rounded-xl font-bold"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Display Order</label>
            <input
              type="number"
              value={seriesForm.display_order}
              onChange={(e) => setSeriesForm({ ...seriesForm, display_order: parseInt(e.target.value) || 0 })}
              className="w-full p-2 border border-slate-300 rounded-xl"
            />
          </div>

          <div className="flex gap-2 pt-3">
            <button
              type="button"
              onClick={() => setSeriesModalOpen(false)}
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold hover:bg-slate-50"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="w-1/2 bg-indigo-600 hover:bg-indigo-700 text-white py-2.5 rounded-xl font-bold shadow-md"
            >
              Save Series
            </button>
          </div>
        </form>
      </ResponsiveModal>

      {/* ================= TRIAGE QUESTION (YES/NO HEALTH CHECK) MODAL ================= */}
      <ResponsiveModal
        isOpen={triageModalOpen}
        onClose={() => setTriageModalOpen(false)}
        title={editingTriage ? `Edit Health Check Question` : 'Add Health Check Question'}
      >
        <form onSubmit={handleSaveTriageQuestion} className="space-y-4 text-xs">
          <div>
            <label className="block font-black text-slate-800 mb-1">Question Text *</label>
            <input
              type="text"
              required
              value={triageForm.question_text}
              onChange={(e) => setTriageForm({ ...triageForm, question_text: e.target.value })}
              placeholder="e.g. Is the phone in proper working condition?"
              className="w-full p-2.5 border border-slate-300 rounded-xl font-bold text-slate-900 focus:ring-2 focus:ring-rose-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 mb-1">Subtitle / Customer Instruction</label>
            <textarea
              rows={2}
              value={triageForm.subtitle}
              onChange={(e) => setTriageForm({ ...triageForm, subtitle: e.target.value })}
              placeholder="e.g. Check if the phone powers on and confirm that it is in working condition"
              className="w-full p-2.5 border border-slate-300 rounded-xl text-slate-700 focus:ring-2 focus:ring-rose-500 focus:outline-none"
            />
          </div>

          {/* Power-On Gate Feature Toggle */}
          <div className="p-3 bg-rose-50/70 border border-rose-200 rounded-xl space-y-1.5">
            <label className="flex items-center gap-2 cursor-pointer font-black text-rose-900">
              <input
                type="checkbox"
                checked={triageForm.is_power_on_gate}
                onChange={(e) => setTriageForm({ ...triageForm, is_power_on_gate: e.target.checked })}
                className="w-4 h-4 rounded text-rose-600 focus:ring-rose-500"
              />
              <span>⚡ Power-On Gate (Dead Phone Logic)</span>
            </label>
            <p className="text-[11px] text-rose-700/90 pl-6 leading-relaxed">
              If customer clicks <strong>"No"</strong>, all following questions are hidden and the bottom button switches to <strong>"Finish"</strong>, taking the user straight to Dead Phone valuation.
            </p>
          </div>

          {/* Deduction Type & Value */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-700 mb-1">Deduction Type</label>
              <select
                value={triageForm.deduction_type}
                onChange={(e) => setTriageForm({ ...triageForm, deduction_type: e.target.value })}
                className="w-full p-2.5 border border-slate-300 rounded-xl font-bold bg-white focus:outline-none"
              >
                <option value="PERCENTAGE">Percentage (%)</option>
                <option value="FIXED">Flat Rupee (₹)</option>
              </select>
            </div>
            <div>
              <label className="block font-bold text-slate-700 mb-1">
                Deduct on "No" {triageForm.deduction_type === 'PERCENTAGE' ? '(%)' : '(₹)'} *
              </label>
              <input
                type="number"
                step="any"
                min="0"
                required
                value={triageForm.deduction_value_on_no}
                onChange={(e) => setTriageForm({ ...triageForm, deduction_value_on_no: parseFloat(e.target.value) || 0 })}
                className="w-full p-2.5 border border-slate-300 rounded-xl font-bold text-slate-900 focus:outline-none"
              />
            </div>
          </div>

          {/* Display Order & Active status */}
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-bold text-slate-700 mb-1">Display Order</label>
              <input
                type="number"
                min="1"
                value={triageForm.display_order}
                onChange={(e) => setTriageForm({ ...triageForm, display_order: parseInt(e.target.value) || 1 })}
                className="w-full p-2.5 border border-slate-300 rounded-xl font-bold focus:outline-none"
              />
            </div>
            <div className="flex items-center pt-5">
              <label className="flex items-center gap-2 cursor-pointer font-bold text-slate-800">
                <input
                  type="checkbox"
                  checked={triageForm.is_active}
                  onChange={(e) => setTriageForm({ ...triageForm, is_active: e.target.checked })}
                  className="w-4 h-4 rounded text-rose-600 focus:ring-rose-500"
                />
                <span>Active in App</span>
              </label>
            </div>
          </div>

          <div className="flex gap-2 pt-3 border-t border-slate-100">
            <button
              type="button"
              onClick={() => setTriageModalOpen(false)}
              className="w-1/2 border border-slate-300 py-2.5 rounded-xl font-bold text-slate-700 hover:bg-slate-50 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="w-1/2 bg-rose-600 hover:bg-rose-700 text-white py-2.5 rounded-xl font-bold shadow-md transition"
            >
              {editingTriage ? 'Update Question' : 'Create Question'}
            </button>
          </div>
        </form>
      </ResponsiveModal>

    </div>
  );
}
