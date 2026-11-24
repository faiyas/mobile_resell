import React, { useState, useEffect, useRef } from 'react';
import { 
  Menu, Smartphone, Search, Bell, Crown, LogOut, ChevronDown, 
  X, CheckCircle2, AlertTriangle, Truck, UserCheck, ArrowRight
} from 'lucide-react';

export default function AdminHeader({
  currentUser,
  onToggleSidebar,
  onNavigateTab,
  onLogout,
  onQuickSearchSelect,
  sales = [],
  customers = [],
  models = []
}) {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchOpen, setSearchOpen] = useState(false);
  const [notificationsOpen, setNotificationsOpen] = useState(false);
  const [profileOpen, setProfileOpen] = useState(false);

  const searchRef = useRef(null);
  const notifRef = useRef(null);
  const profileRef = useRef(null);

  // Keyboard shortcut Ctrl+K / Cmd+K
  useEffect(() => {
    const handleKeyDown = (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        searchRef.current?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Click outside listener for dropdowns
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (notifRef.current && !notifRef.current.contains(e.target)) {
        setNotificationsOpen(false);
      }
      if (profileRef.current && !profileRef.current.contains(e.target)) {
        setProfileOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Filtered search results across Sales, Customers & Models
  const cleanQ = searchQuery.trim().toLowerCase();
  const matchedSales = cleanQ ? sales.filter(s => 
    s.sale_code?.toLowerCase().includes(cleanQ) || 
    s.phone_model_name?.toLowerCase().includes(cleanQ) ||
    s.customer_name?.toLowerCase().includes(cleanQ) ||
    s.customer_phone?.toLowerCase().includes(cleanQ)
  ).slice(0, 4) : [];

  const matchedCustomers = cleanQ ? customers.filter(c =>
    c.full_name?.toLowerCase().includes(cleanQ) ||
    c.phone?.toLowerCase().includes(cleanQ) ||
    c.email?.toLowerCase().includes(cleanQ)
  ).slice(0, 4) : [];

  const matchedModels = cleanQ ? models.filter(m =>
    m.name?.toLowerCase().includes(cleanQ) ||
    m.brand_name?.toLowerCase().includes(cleanQ)
  ).slice(0, 4) : [];

  const hasResults = matchedSales.length > 0 || matchedCustomers.length > 0 || matchedModels.length > 0;

  // Recent system notifications
  const recentOrders = sales.slice(0, 4);

  return (
    <header className="h-16 bg-white/90 backdrop-blur-md border-b border-slate-200 px-4 sm:px-6 flex items-center justify-between gap-3 sticky top-0 z-20 shadow-xs">
      
      {/* Left: Mobile Sidebar Toggle & Quick Links */}
      <div className="flex items-center gap-2 sm:gap-4 shrink-0">
        <button
          type="button"
          onClick={onToggleSidebar}
          className="p-2 rounded-xl text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition"
          title="Toggle Sidebar"
        >
          <Menu className="w-5 h-5" />
        </button>

        {/* Sell Device & Track Status Links */}
        <div className="hidden md:flex items-center gap-2">
          <button
            type="button"
            onClick={() => onNavigateTab && onNavigateTab('sell')}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-slate-700 hover:text-[#0BAA4B] hover:bg-emerald-50/70 border border-transparent hover:border-emerald-200 transition"
          >
            <Smartphone className="w-4 h-4 text-[#0BAA4B]" />
            <span>Sell Device</span>
          </button>
          <button
            type="button"
            onClick={() => onNavigateTab && onNavigateTab('track')}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-bold text-slate-700 hover:text-[#0BAA4B] hover:bg-emerald-50/70 border border-transparent hover:border-emerald-200 transition"
          >
            <Search className="w-4 h-4 text-[#0BAA4B]" />
            <span>Track Status</span>
          </button>
        </div>
      </div>

      {/* Center: Omnisearch Ctrl+K */}
      <div className="flex-1 max-w-md relative">
        <div className="relative">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
          <input
            ref={searchRef}
            type="text"
            value={searchQuery}
            onChange={(e) => {
              setSearchQuery(e.target.value);
              setSearchOpen(true);
            }}
            onFocus={() => setSearchOpen(true)}
            placeholder="Search customers, devices, models..."
            className="w-full pl-9 pr-14 py-2 bg-slate-100/90 hover:bg-slate-100 focus:bg-white text-xs font-medium text-slate-900 rounded-xl border border-transparent focus:border-[#0BAA4B] focus:ring-2 focus:ring-[#0BAA4B]/15 outline-none transition"
          />
          <div className="absolute right-2.5 top-1/2 -translate-y-1/2 flex items-center gap-1">
            {searchQuery ? (
              <button
                type="button"
                onClick={() => {
                  setSearchQuery('');
                  setSearchOpen(false);
                }}
                className="text-slate-400 hover:text-slate-600 p-0.5"
              >
                <X className="w-3.5 h-3.5" />
              </button>
            ) : (
              <kbd className="hidden sm:inline-block px-1.5 py-0.5 text-[10px] font-mono font-semibold text-slate-500 bg-white border border-slate-200 rounded shadow-2xs">
                Ctrl + K
              </kbd>
            )}
          </div>
        </div>

        {/* Omnisearch Results Dropdown */}
        {searchOpen && cleanQ && (
          <div className="absolute top-full left-0 right-0 mt-2 bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden z-50 animate-zoom-in max-h-96 overflow-y-auto">
            {hasResults ? (
              <div className="p-2 space-y-3">
                {matchedSales.length > 0 && (
                  <div>
                    <p className="px-3 py-1 text-[10px] font-black uppercase text-slate-400">Orders & Sales</p>
                    {matchedSales.map(s => (
                      <button
                        key={s.id}
                        type="button"
                        onClick={() => {
                          onQuickSearchSelect && onQuickSearchSelect('sales', s);
                          setSearchOpen(false);
                        }}
                        className="w-full text-left px-3 py-2 rounded-xl hover:bg-slate-50 flex items-center justify-between text-xs transition"
                      >
                        <div>
                          <p className="font-extrabold text-slate-900">{s.phone_model_name} <span className="font-mono text-emerald-700">({s.sale_code})</span></p>
                          <p className="text-[11px] text-slate-500">{s.customer_name} · ₹{Number(s.final_price || s.estimated_price).toLocaleString('en-IN')}</p>
                        </div>
                        <span className="text-[10px] px-2 py-0.5 rounded-full font-bold uppercase bg-slate-100 text-slate-700">
                          {s.status}
                        </span>
                      </button>
                    ))}
                  </div>
                )}

                {matchedCustomers.length > 0 && (
                  <div>
                    <p className="px-3 py-1 text-[10px] font-black uppercase text-slate-400">Customers</p>
                    {matchedCustomers.map(c => (
                      <button
                        key={c.id}
                        type="button"
                        onClick={() => {
                          onQuickSearchSelect && onQuickSearchSelect('customers', c);
                          setSearchOpen(false);
                        }}
                        className="w-full text-left px-3 py-2 rounded-xl hover:bg-slate-50 flex items-center justify-between text-xs transition"
                      >
                        <div>
                          <p className="font-extrabold text-slate-900">{c.full_name || 'Customer'}</p>
                          <p className="text-[11px] text-slate-500">{c.phone || c.email}</p>
                        </div>
                        <ArrowRight className="w-3.5 h-3.5 text-slate-400" />
                      </button>
                    ))}
                  </div>
                )}

                {matchedModels.length > 0 && (
                  <div>
                    <p className="px-3 py-1 text-[10px] font-black uppercase text-slate-400">Catalogue Models</p>
                    {matchedModels.map(m => (
                      <button
                        key={m.id}
                        type="button"
                        onClick={() => {
                          onQuickSearchSelect && onQuickSearchSelect('models', m);
                          setSearchOpen(false);
                        }}
                        className="w-full text-left px-3 py-2 rounded-xl hover:bg-slate-50 flex items-center justify-between text-xs transition"
                      >
                        <p className="font-extrabold text-slate-900">{m.brand_name} {m.name}</p>
                        <span className="text-[10px] font-bold text-slate-400">{m.release_year}</span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="p-6 text-center text-xs text-slate-400">
                No matching orders, customers, or devices found.
              </div>
            )}
          </div>
        )}
      </div>

      {/* Right: Notifications & Profile Pill */}
      <div className="flex items-center gap-3 shrink-0">
        
        {/* Notification Bell */}
        <div ref={notifRef} className="relative">
          <button
            type="button"
            onClick={() => setNotificationsOpen(!notificationsOpen)}
            className="w-9 h-9 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 flex items-center justify-center transition relative"
            title="System Notifications"
          >
            <Bell className="w-4 h-4" />
            <span className="w-2 h-2 rounded-full bg-[#0BAA4B] absolute top-2 right-2 ring-2 ring-white" />
          </button>

          {notificationsOpen && (
            <div className="absolute right-0 mt-2 w-80 bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden z-50 animate-zoom-in">
              <div className="p-3 border-b border-slate-150 flex items-center justify-between bg-slate-50">
                <span className="font-extrabold text-xs text-slate-900">System Activity</span>
                <span className="text-[10px] font-bold bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full">
                  Live
                </span>
              </div>
              <div className="p-2 space-y-1 max-h-72 overflow-y-auto">
                {recentOrders.length > 0 ? (
                  recentOrders.map((ord) => (
                    <div key={ord.id} className="p-2 rounded-xl hover:bg-slate-50 text-xs flex items-start gap-2.5 transition">
                      <div className="w-7 h-7 rounded-lg bg-emerald-50 text-[#0BAA4B] flex items-center justify-center shrink-0 mt-0.5">
                        <Truck className="w-3.5 h-3.5" />
                      </div>
                      <div className="flex-1 truncate">
                        <p className="font-bold text-slate-900 truncate">{ord.phone_model_name}</p>
                        <p className="text-[10px] text-slate-500">Order #{ord.sale_code} · {ord.status}</p>
                      </div>
                      <span className="text-[9px] font-mono text-slate-400">Recently</span>
                    </div>
                  ))
                ) : (
                  <p className="p-4 text-center text-xs text-slate-400">No new alerts.</p>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Super Admin Profile Pill */}
        <div ref={profileRef} className="relative">
          <button
            type="button"
            onClick={() => setProfileOpen(!profileOpen)}
            className="flex items-center gap-2.5 p-1 sm:pr-2.5 rounded-full sm:rounded-2xl hover:bg-slate-100 transition border border-transparent hover:border-slate-200"
          >
            <div className="w-8 h-8 rounded-full bg-gradient-to-br from-[#0BAA4B] to-[#087C38] text-white flex items-center justify-center font-black text-xs shadow-sm">
              {currentUser?.full_name ? currentUser.full_name.substring(0, 2).toUpperCase() : 'MA'}
            </div>
            <div className="hidden sm:block text-left">
              <div className="flex items-center gap-1.5">
                <p className="text-xs font-black text-slate-900 truncate max-w-[120px]">
                  {currentUser?.full_name || 'Main Super Admin'}
                </p>
                <ChevronDown className="w-3 h-3 text-slate-400" />
              </div>
              <div className="flex items-center gap-1">
                <span className="text-[9px] font-black uppercase text-amber-600 flex items-center gap-0.5">
                  <Crown className="w-2.5 h-2.5 fill-amber-500 text-amber-500" />
                  {currentUser?.role || 'ADMIN'}
                </span>
              </div>
            </div>
          </button>

          {/* Profile Dropdown */}
          {profileOpen && (
            <div className="absolute right-0 mt-2 w-56 bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden z-50 animate-zoom-in">
              <div className="p-3 border-b border-slate-150 bg-slate-50">
                <p className="text-xs font-black text-slate-900 truncate">{currentUser?.full_name || 'Administrator'}</p>
                <p className="text-[11px] text-slate-500 truncate">{currentUser?.email || 'admin@dolly.in'}</p>
              </div>
              <div className="p-1.5 space-y-0.5">
                <button
                  type="button"
                  onClick={() => {
                    setProfileOpen(false);
                    onNavigateTab && onNavigateTab('inspection');
                  }}
                  className="w-full text-left px-3 py-2 rounded-xl text-xs font-semibold text-slate-700 hover:bg-emerald-50 hover:text-[#0BAA4B] flex items-center gap-2 transition"
                >
                  <UserCheck className="w-4 h-4 text-emerald-600" />
                  <span>Agent Inspection Portal</span>
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setProfileOpen(false);
                    onLogout && onLogout();
                  }}
                  className="w-full text-left px-3 py-2 rounded-xl text-xs font-semibold text-rose-600 hover:bg-rose-50 flex items-center gap-2 transition"
                >
                  <LogOut className="w-4 h-4 text-rose-500" />
                  <span>Sign Out</span>
                </button>
              </div>
            </div>
          )}
        </div>

      </div>

    </header>
  );
}
