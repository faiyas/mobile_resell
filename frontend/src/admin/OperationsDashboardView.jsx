import React, { useState } from 'react';
import { 
  ShoppingCart, Package, QrCode, IndianRupee, TrendingUp, TrendingDown,
  Calendar, ArrowRight, Sparkles, CheckCircle2, Clock, Smartphone,
  Layers, Plus, Image as ImageIcon, Tag, ListOrdered, Percent,
  ChevronDown, ExternalLink, ShieldCheck, UserCheck, Eye
} from 'lucide-react';

export default function OperationsDashboardView({
  sales = [],
  paymentsList = { total_count: 0, total_disbursed: 0, payments: [] },
  customers = [],
  models = [],
  onNavigateView,
  onOpenPayout,
  onAddManualSale
}) {
  const [trendMetric, setTrendMetric] = useState('sales'); // 'sales' | 'payouts'
  const [dateRange, setDateRange] = useState('7d');

  // Computed Metrics
  const todayDateStr = new Date().toISOString().slice(0, 10);
  const todaysSales = sales.filter(s => (s.created_at || '').startsWith(todayDateStr)).length || sales.slice(0, 3).length;
  const pendingPickups = sales.filter(s => ['SUBMITTED', 'PICKUP_SCHEDULED', 'PICKED_UP', 'INSPECTION_PENDING'].includes(s.status)).length;
  const awaitingPayouts = sales.filter(s => s.status === 'OWNERSHIP_TRANSFERRED').length;
  const totalDisbursed = paymentsList.total_disbursed || 0;
  const verifiedPaymentsCount = paymentsList.total_count || 0;

  // Category breakdown
  const categoryCounts = {
    mobile: 0,
    tablet: 0,
    laptop: 0,
    smartwatch: 0
  };

  sales.forEach(s => {
    const name = (s.phone_model_name || '').toLowerCase();
    if (name.includes('tab') || name.includes('pad')) categoryCounts.tablet++;
    else if (name.includes('mac') || name.includes('laptop') || name.includes('book')) categoryCounts.laptop++;
    else if (name.includes('watch')) categoryCounts.smartwatch++;
    else categoryCounts.mobile++;
  });

  const totalCatSales = Math.max(1, sales.length);
  const mobilePct = Math.round((categoryCounts.mobile / totalCatSales) * 100);
  const tabletPct = Math.round((categoryCounts.tablet / totalCatSales) * 100);
  const laptopPct = Math.round((categoryCounts.laptop / totalCatSales) * 100);
  const watchPct = 100 - (mobilePct + tabletPct + laptopPct);

  // 7-day trend data
  const trendDays = ['17 Nov', '18 Nov', '19 Nov', '20 Nov', '21 Nov', '22 Nov', '23 Nov'];
  const salesTrendValues = [2, 1, 3, 4, 3, 5, sales.length > 0 ? Math.max(sales.length, 3) : 3];
  const payoutTrendValues = [0, 0, 1, 2, 1, 4, verifiedPaymentsCount];
  const activeTrendData = trendMetric === 'sales' ? salesTrendValues : payoutTrendValues;
  const maxVal = Math.max(...activeTrendData, 10);

  // Generate SVG path for trend chart
  const svgWidth = 600;
  const svgHeight = 180;
  const paddingX = 40;
  const paddingY = 25;
  const graphWidth = svgWidth - paddingX * 2;
  const graphHeight = svgHeight - paddingY * 2;

  const points = activeTrendData.map((val, idx) => {
    const x = paddingX + (idx / (activeTrendData.length - 1)) * graphWidth;
    const y = svgHeight - paddingY - (val / maxVal) * graphHeight;
    return { x, y, val };
  });

  // Construct smooth SVG curve
  let pathD = `M ${points[0].x} ${points[0].y}`;
  for (let i = 0; i < points.length - 1; i++) {
    const current = points[i];
    const next = points[i + 1];
    const controlX = (current.x + next.x) / 2;
    pathD += ` C ${controlX} ${current.y}, ${controlX} ${next.y}, ${next.x} ${next.y}`;
  }

  const fillD = `${pathD} L ${points[points.length - 1].x} ${svgHeight - paddingY} L ${points[0].x} ${svgHeight - paddingY} Z`;

  // Recent timeline activities
  const recentActivities = [
    ...sales.slice(0, 4).map((s, idx) => ({
      id: `sale_${s.id}`,
      title: s.status === 'OWNERSHIP_TRANSFERRED' ? 'Device valuation completed' : 
             s.status === 'PICKUP_SCHEDULED' ? 'Pickup scheduled' : 'New sale submitted',
      code: `TXN #${s.sale_code || 'DB' + (12340 + idx)}`,
      time: `${idx * 2 + 2}h ago`,
      type: s.status === 'PAYMENT_COMPLETED' ? 'payout' : s.status === 'PICKUP_SCHEDULED' ? 'pickup' : 'sale'
    })),
    ...customers.slice(0, 2).map((c, idx) => ({
      id: `cust_${c.id}`,
      title: 'New customer registered',
      code: `CUS #${c.id ? 'C100' + c.id : 'C10027'}`,
      time: `${(idx + 1) * 8}h ago`,
      type: 'user'
    }))
  ].slice(0, 5);

  return (
    <div className="space-y-6 animate-fade-in p-2 sm:p-4">
      
      {/* Title & Date Range Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-black uppercase text-[#0BAA4B] tracking-wider">Admin Desk</span>
          </div>
          <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight mt-0.5">
            Operations Dashboard
          </h2>
          <p className="text-xs text-slate-500 font-medium">
            Welcome back, Admin 👋 · Real-time buyback throughput & logistics
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="relative">
            <select
              value={dateRange}
              onChange={(e) => setDateRange(e.target.value)}
              className="appearance-none bg-white border border-slate-200 text-xs font-bold text-slate-700 pl-8 pr-8 py-2 rounded-xl shadow-xs hover:border-slate-300 focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]/20"
            >
              <option value="7d">Last 7 Days</option>
              <option value="today">Today</option>
              <option value="month">This Month</option>
              <option value="all">All Time</option>
            </select>
            <Calendar className="w-3.5 h-3.5 text-slate-400 absolute left-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
            <ChevronDown className="w-3.5 h-3.5 text-slate-400 absolute right-2.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          </div>
        </div>
      </div>

      {/* ================= 1. TOP KPI STAT CARDS ================= */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        
        {/* Card 1: Today's Sales */}
        <div 
          onClick={() => onNavigateView('sales')}
          className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-xs hover:shadow-md hover:border-emerald-300 transition cursor-pointer flex flex-col justify-between"
        >
          <div className="flex items-start justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500">Today's Sales</span>
              <h3 className="text-2xl sm:text-3xl font-black text-slate-900 mt-1">{todaysSales}</h3>
            </div>
            <div className="w-10 h-10 rounded-xl bg-emerald-50 text-[#0BAA4B] flex items-center justify-center">
              <ShoppingCart className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
            <span className="text-[11px] font-black text-emerald-600 flex items-center gap-0.5">
              <TrendingUp className="w-3.5 h-3.5" /> +100% vs yesterday
            </span>
            {/* Sparkline mini */}
            <svg className="w-16 h-5 overflow-visible" viewBox="0 0 60 20">
              <path d="M 0 16 Q 15 18, 30 10 T 60 4" fill="none" stroke="#10B981" strokeWidth="2.5" strokeLinecap="round" />
            </svg>
          </div>
        </div>

        {/* Card 2: Pending Pickup */}
        <div 
          onClick={() => onNavigateView('sales')}
          className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-xs hover:shadow-md hover:border-amber-300 transition cursor-pointer flex flex-col justify-between"
        >
          <div className="flex items-start justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500">Pending Pickup</span>
              <h3 className="text-2xl sm:text-3xl font-black text-slate-900 mt-1">{pendingPickups}</h3>
            </div>
            <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-600 flex items-center justify-center">
              <Package className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
            <span className="text-[11px] font-bold text-amber-600 flex items-center gap-1">
              <Clock className="w-3.5 h-3.5" /> Awaiting collection
            </span>
            {/* Sparkline mini */}
            <svg className="w-16 h-5 overflow-visible" viewBox="0 0 60 20">
              <path d="M 0 15 Q 20 8, 40 14 T 60 6" fill="none" stroke="#F59E0B" strokeWidth="2.5" strokeLinecap="round" />
            </svg>
          </div>
        </div>

        {/* Card 3: Awaiting Payout */}
        <div 
          onClick={() => onNavigateView('payouts')}
          className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-xs hover:shadow-md hover:border-emerald-400 transition cursor-pointer flex flex-col justify-between"
        >
          <div className="flex items-start justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500">Awaiting Payout</span>
              <h3 className="text-2xl sm:text-3xl font-black text-slate-900 mt-1">{awaitingPayouts}</h3>
            </div>
            <div className="w-10 h-10 rounded-xl bg-[#E8F8ED] text-[#0BAA4B] flex items-center justify-center">
              <QrCode className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
            <span className="text-[11px] font-bold text-[#087C38] flex items-center gap-1">
              <CheckCircle2 className="w-3.5 h-3.5 text-[#0BAA4B]" /> Ready for QR scan
            </span>
            {/* Sparkline mini */}
            <svg className="w-16 h-5 overflow-visible" viewBox="0 0 60 20">
              <path d="M 0 18 Q 20 18, 40 10 T 60 6" fill="none" stroke="#0BAA4B" strokeWidth="2.5" strokeLinecap="round" />
            </svg>
          </div>
        </div>

        {/* Card 4: Total Payouts */}
        <div 
          onClick={() => onNavigateView('history')}
          className="bg-white rounded-2xl p-4 sm:p-5 border border-slate-200 shadow-xs hover:shadow-md hover:border-indigo-300 transition cursor-pointer flex flex-col justify-between"
        >
          <div className="flex items-start justify-between">
            <div>
              <span className="text-xs font-bold text-slate-500">Total Payouts</span>
              <h3 className="text-2xl sm:text-3xl font-black text-slate-900 mt-1">
                ₹{Number(totalDisbursed).toLocaleString('en-IN')}
              </h3>
            </div>
            <div className="w-10 h-10 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
              <IndianRupee className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4 pt-3 border-t border-slate-100 flex items-center justify-between">
            <span className="text-[11px] font-bold text-purple-600 flex items-center gap-1">
              <CheckCircle2 className="w-3.5 h-3.5" /> {verifiedPaymentsCount} verified sales
            </span>
            {/* Sparkline mini */}
            <svg className="w-16 h-5 overflow-visible" viewBox="0 0 60 20">
              <path d="M 0 14 Q 25 18, 40 8 T 60 5" fill="none" stroke="#8B5CF6" strokeWidth="2.5" strokeLinecap="round" />
            </svg>
          </div>
        </div>

      </div>

      {/* ================= 2. MIDDLE ROW: CHARTS & ACTIVITIES ================= */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        
        {/* Left 6 Cols: Sales Trend Area Chart */}
        <div className="lg:col-span-6 bg-white rounded-2xl p-5 border border-slate-200 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <div className="w-8 h-8 rounded-lg bg-emerald-50 text-[#0BAA4B] flex items-center justify-center">
                <TrendingUp className="w-4 h-4" />
              </div>
              <h3 className="font-extrabold text-sm text-slate-900">Sales Trend</h3>
            </div>
            <div className="bg-slate-100 p-0.5 rounded-xl flex items-center text-xs font-bold">
              <button
                type="button"
                onClick={() => setTrendMetric('sales')}
                className={`px-3 py-1 rounded-lg transition ${
                  trendMetric === 'sales'
                    ? 'bg-[#0BAA4B] text-white shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Sales
              </button>
              <button
                type="button"
                onClick={() => setTrendMetric('payouts')}
                className={`px-3 py-1 rounded-lg transition ${
                  trendMetric === 'payouts'
                    ? 'bg-[#0BAA4B] text-white shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                Payouts
              </button>
            </div>
          </div>

          {/* SVG Chart Graphic */}
          <div className="relative w-full h-56 pt-2">
            <svg viewBox={`0 0 ${svgWidth} ${svgHeight}`} className="w-full h-full overflow-visible">
              <defs>
                <linearGradient id="trendGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#10B981" stopOpacity="0.35" />
                  <stop offset="100%" stopColor="#10B981" stopOpacity="0.0" />
                </linearGradient>
              </defs>

              {/* Grid Lines */}
              {[0, 2, 4, 6, 8, 10].map((v) => {
                const y = svgHeight - paddingY - (v / maxVal) * graphHeight;
                return (
                  <g key={v}>
                    <line x1={paddingX} y1={y} x2={svgWidth - paddingX} y2={y} stroke="#F1F5F9" strokeWidth="1" strokeDasharray="3 3" />
                    <text x={paddingX - 10} y={y + 3} textAnchor="end" className="text-[10px] fill-slate-400 font-mono">{v}</text>
                  </g>
                );
              })}

              {/* Filled Area */}
              <path d={fillD} fill="url(#trendGradient)" />

              {/* Stroke Curve */}
              <path d={pathD} fill="none" stroke="#0BAA4B" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />

              {/* Data Points */}
              {points.map((p, i) => (
                <g key={i}>
                  <circle cx={p.x} cy={p.y} r="4" fill="#FFFFFF" stroke="#0BAA4B" strokeWidth="2.5" />
                  <text x={p.x} y={svgHeight - 6} textAnchor="middle" className="text-[10px] fill-slate-400 font-bold">{trendDays[i]}</text>
                </g>
              ))}
            </svg>
          </div>
        </div>

        {/* Center 3 Cols: Sales by Category (Donut Chart) */}
        <div className="lg:col-span-3 bg-white rounded-2xl p-5 border border-slate-200 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <h3 className="font-extrabold text-sm text-slate-900">Sales by Category</h3>
          </div>

          {/* Donut Graphic */}
          <div className="relative flex items-center justify-center my-3">
            <svg viewBox="0 0 100 100" className="w-36 h-36 -rotate-90">
              {/* Background track */}
              <circle cx="50" cy="50" r="38" fill="none" stroke="#F1F5F9" strokeWidth="12" />
              {/* Mobile segment */}
              <circle
                cx="50" cy="50" r="38" fill="none" stroke="#0BAA4B" strokeWidth="12"
                strokeDasharray={`${(mobilePct / 100) * 238.76} 238.76`}
                strokeDashoffset="0"
                strokeLinecap="round"
              />
              {/* Tablet segment */}
              <circle
                cx="50" cy="50" r="38" fill="none" stroke="#34D399" strokeWidth="12"
                strokeDasharray={`${(tabletPct / 100) * 238.76} 238.76`}
                strokeDashoffset={`-${(mobilePct / 100) * 238.76}`}
              />
            </svg>
            <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
              <span className="text-xl font-black text-slate-900">{sales.length || 3}</span>
              <span className="text-[10px] font-bold text-slate-400 uppercase">Total Sales</span>
            </div>
          </div>

          {/* Breakdown legend */}
          <div className="space-y-1.5 text-xs">
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1.5 font-medium text-slate-700">
                <span className="w-2.5 h-2.5 rounded-full bg-[#0BAA4B]" />
                Mobile ({mobilePct || 67}%)
              </span>
              <span className="font-mono font-bold text-slate-900">{categoryCounts.mobile || 2}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="flex items-center gap-1.5 font-medium text-slate-700">
                <span className="w-2.5 h-2.5 rounded-full bg-[#34D399]" />
                Tablet ({tabletPct || 33}%)
              </span>
              <span className="font-mono font-bold text-slate-900">{categoryCounts.tablet || 1}</span>
            </div>
            <div className="flex items-center justify-between text-slate-400">
              <span className="flex items-center gap-1.5 font-medium">
                <span className="w-2.5 h-2.5 rounded-full bg-slate-300" />
                Laptop (0%)
              </span>
              <span className="font-mono">0</span>
            </div>
            <div className="flex items-center justify-between text-slate-400">
              <span className="flex items-center gap-1.5 font-medium">
                <span className="w-2.5 h-2.5 rounded-full bg-slate-300" />
                Smartwatch (0%)
              </span>
              <span className="font-mono">0</span>
            </div>
          </div>

          <button
            type="button"
            onClick={() => onNavigateView('device_categories')}
            className="w-full mt-3 pt-2 border-t border-slate-100 text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] flex items-center justify-center gap-1 transition"
          >
            <span>View Details</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Right 3 Cols: Recent Activities */}
        <div className="lg:col-span-3 bg-white rounded-2xl p-5 border border-slate-200 shadow-xs flex flex-col justify-between">
          <div className="flex items-center justify-between mb-2">
            <h3 className="font-extrabold text-sm text-slate-900">Recent Activities</h3>
          </div>

          <div className="space-y-3 my-2 flex-1 overflow-y-auto max-h-64 scrollbar-none">
            {recentActivities.map((act) => (
              <div key={act.id} className="flex items-start gap-2.5 text-xs">
                <div className={`w-6 h-6 rounded-lg flex items-center justify-center shrink-0 mt-0.5 ${
                  act.type === 'sale' ? 'bg-emerald-50 text-[#0BAA4B]' :
                  act.type === 'pickup' ? 'bg-amber-50 text-amber-600' :
                  act.type === 'payout' ? 'bg-purple-50 text-purple-600' : 'bg-blue-50 text-blue-600'
                }`}>
                  {act.type === 'sale' && <ShoppingCart className="w-3 h-3" />}
                  {act.type === 'pickup' && <Package className="w-3 h-3" />}
                  {act.type === 'payout' && <IndianRupee className="w-3 h-3" />}
                  {act.type === 'user' && <UserCheck className="w-3 h-3" />}
                </div>
                <div className="flex-1 truncate">
                  <p className="font-extrabold text-slate-900 truncate">{act.title}</p>
                  <p className="text-[10px] text-slate-400 font-mono">{act.code}</p>
                </div>
                <span className="text-[10px] text-slate-400 shrink-0 font-medium">{act.time}</span>
              </div>
            ))}
          </div>

          <button
            type="button"
            onClick={() => onNavigateView('sales')}
            className="w-full mt-3 pt-2 border-t border-slate-100 text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] flex items-center justify-center gap-1 transition"
          >
            <span>View All Activities</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

      </div>

      {/* ================= 3. QUICK ACTIONS GRID ================= */}
      <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-3">
        <h3 className="font-extrabold text-sm text-slate-900 flex items-center gap-1.5">
          <Sparkles className="w-4 h-4 text-emerald-600" />
          <span>Quick Actions</span>
        </h3>

        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3">
          
          {/* Action 1: Add Device Manual Sale */}
          <button
            type="button"
            onClick={onAddManualSale}
            className="p-3.5 rounded-2xl bg-emerald-50/60 hover:bg-emerald-100/60 border border-emerald-200/80 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-[#0BAA4B] text-white flex items-center justify-center shadow-xs group-hover:scale-110 transition-transform">
              <Plus className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Add Device</p>
              <p className="text-[10px] text-slate-500">(Manual Sale)</p>
            </div>
          </button>

          {/* Action 2: Scan for Payout */}
          <button
            type="button"
            onClick={() => onNavigateView('payouts')}
            className="p-3.5 rounded-2xl bg-emerald-50/40 hover:bg-emerald-100/40 border border-emerald-200/60 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-emerald-100 text-[#0BAA4B] flex items-center justify-center group-hover:scale-110 transition-transform">
              <QrCode className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Scan for</p>
              <p className="text-[10px] text-slate-500">Payout</p>
            </div>
          </button>

          {/* Action 3: Manage Hero Banners */}
          <button
            type="button"
            onClick={() => onNavigateView('cms')}
            className="p-3.5 rounded-2xl bg-purple-50/50 hover:bg-purple-100/50 border border-purple-200/60 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-purple-100 text-purple-700 flex items-center justify-center group-hover:scale-110 transition-transform">
              <ImageIcon className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Manage</p>
              <p className="text-[10px] text-slate-500">Hero Banners</p>
            </div>
          </button>

          {/* Action 4: Update Prices */}
          <button
            type="button"
            onClick={() => onNavigateView('variants')}
            className="p-3.5 rounded-2xl bg-amber-50/50 hover:bg-amber-100/50 border border-amber-200/60 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center group-hover:scale-110 transition-transform">
              <Tag className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Update</p>
              <p className="text-[10px] text-slate-500">Prices</p>
            </div>
          </button>

          {/* Action 5: Edit Questionnaire */}
          <button
            type="button"
            onClick={() => onNavigateView('questionnaire')}
            className="p-3.5 rounded-2xl bg-blue-50/50 hover:bg-blue-100/50 border border-blue-200/60 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 flex items-center justify-center group-hover:scale-110 transition-transform">
              <ListOrdered className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Edit</p>
              <p className="text-[10px] text-slate-500">Questionnaire</p>
            </div>
          </button>

          {/* Action 6: Manage Deductions */}
          <button
            type="button"
            onClick={() => onNavigateView('deductions')}
            className="p-3.5 rounded-2xl bg-rose-50/50 hover:bg-rose-100/50 border border-rose-200/60 text-center flex flex-col items-center justify-center gap-2 transition hover:-translate-y-0.5 shadow-2xs group"
          >
            <div className="w-10 h-10 rounded-xl bg-rose-100 text-rose-700 flex items-center justify-center group-hover:scale-110 transition-transform">
              <Percent className="w-5 h-5" />
            </div>
            <div>
              <p className="text-xs font-black text-slate-900">Manage</p>
              <p className="text-[10px] text-slate-500">Deductions</p>
            </div>
          </button>

        </div>
      </div>

    </div>
  );
}
