import React from 'react';
import { 
  Home, ShoppingCart, Users, IndianRupee, Clock, UserCheck, 
  LayoutGrid, Smartphone, Layers, Database, FileText, Percent, 
  Monitor, Image, Megaphone, Settings, ShieldCheck, ChevronLeft, ChevronRight,
  Sparkles
} from 'lucide-react';

export default function AdminSidebar({ 
  currentView, 
  onSelectView, 
  collapsed, 
  onToggleCollapse,
  counts = {}
}) {
  const navSections = [
    {
      title: 'OVERVIEW',
      items: [
        { id: 'dashboard', label: 'Dashboard', icon: Home }
      ]
    },
    {
      title: 'SALES',
      items: [
        { id: 'sales', label: 'Customer Sales', icon: ShoppingCart, count: counts.sales },
        { id: 'customers', label: 'Customers', icon: Users, count: counts.customers }
      ]
    },
    {
      title: 'OPERATIONS',
      items: [
        { id: 'payouts', label: 'Payout Desk', icon: IndianRupee, count: counts.awaitingPayouts },
        { id: 'history', label: 'Payout History', icon: Clock, count: counts.payments },
        { id: 'agents', label: 'Field Agents', icon: UserCheck, count: counts.agents }
      ]
    },
    {
      title: 'CATALOGUE & PRICING',
      items: [
        { id: 'device_categories', label: 'Categories', icon: LayoutGrid, count: counts.deviceCategories },
        { id: 'brands', label: 'Brands', icon: Smartphone, count: counts.brands },
        { id: 'models', label: 'Series & Models', icon: Layers, count: counts.models },
        { id: 'variants', label: 'Storage & Prices', icon: Database, count: counts.variants }
      ]
    },
    {
      title: 'VALUATION',
      items: [
        { id: 'questionnaire', label: 'Questionnaire Builder', icon: FileText, count: counts.questions },
        { id: 'deductions', label: 'Deduction Rules', icon: Percent, count: counts.deductions },
        { id: 'simulator', label: 'Valuation Simulator', icon: Sparkles }
      ]
    },
    {
      title: 'WEBSITE CMS',
      items: [
        { id: 'cms', label: 'Hero Banners (CMS)', icon: Image, count: counts.cms }
      ]
    },
    {
      title: 'SYSTEM',
      items: [
        { id: 'settings', label: 'Settings', icon: Settings },
        { id: 'roles', label: 'User Roles', icon: ShieldCheck }
      ]
    }
  ];

  return (
    <aside 
      className={`bg-[#082F1D] text-slate-200 transition-all duration-300 ease-in-out shrink-0 flex flex-col border-r border-[#0D442B] select-none z-30 ${
        collapsed ? 'w-20' : 'w-64'
      }`}
    >
      {/* Brand Header */}
      <div className="h-16 flex items-center justify-between px-4 border-b border-[#0D442B] shrink-0 bg-[#062617]/70">
        <div className="flex items-center gap-2.5 overflow-hidden">
          <img 
            src="/dolly_icon.png" 
            alt="Dolly" 
            className="w-9 h-9 rounded-xl object-contain shadow-md shrink-0 bg-white/10 p-0.5 border border-emerald-400/20" 
          />
          {!collapsed && (
            <div className="flex items-center gap-2 truncate">
              <span className="font-black text-lg text-white tracking-tight">Dolly</span>
              <span className="text-[9px] font-black uppercase tracking-wider bg-[#10B981]/20 text-[#34D399] border border-[#10B981]/30 px-1.5 py-0.5 rounded">
                BUYBACK
              </span>
            </div>
          )}
        </div>
        <button
          type="button"
          onClick={onToggleCollapse}
          title={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          className="text-slate-400 hover:text-white p-1.5 rounded-lg hover:bg-white/10 transition shrink-0"
        >
          {collapsed ? <ChevronRight className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
        </button>
      </div>

      {/* Navigation Scrollable Area */}
      <div className="flex-1 overflow-y-auto overflow-x-hidden p-3 space-y-5 scrollbar-thin scrollbar-thumb-emerald-900 scrollbar-track-transparent">
        {navSections.map((section, sIdx) => (
          <div key={sIdx} className="space-y-1">
            {!collapsed && (
              <p className="px-3 text-[10px] font-black uppercase tracking-wider text-emerald-400/60 mb-1.5">
                {section.title}
              </p>
            )}
            {section.items.map((item) => {
              const Icon = item.icon;
              const isActive = currentView === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={() => onSelectView(item.id)}
                  title={collapsed ? item.label : undefined}
                  className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl text-xs font-bold transition-all group ${
                    isActive
                      ? 'bg-[#E8F8ED] text-[#087C38] shadow-sm font-extrabold'
                      : 'text-slate-300 hover:text-white hover:bg-white/5'
                  }`}
                >
                  <div className="flex items-center gap-3 truncate">
                    <Icon className={`w-4 h-4 shrink-0 transition-transform group-hover:scale-110 ${
                      isActive ? 'text-[#0BAA4B]' : 'text-slate-400 group-hover:text-emerald-400'
                    }`} />
                    {!collapsed && <span className="truncate">{item.label}</span>}
                  </div>
                  {!collapsed && item.count !== undefined && (
                    <span className={`text-[10px] px-2 py-0.5 rounded-full font-mono font-black ${
                      isActive 
                        ? 'bg-[#0BAA4B] text-white' 
                        : 'bg-white/10 text-emerald-300 group-hover:bg-white/20'
                    }`}>
                      {item.count}
                    </span>
                  )}
                </button>
              );
            })}
          </div>
        ))}
      </div>

      {/* Footer System Status */}
      {!collapsed ? (
        <div className="p-3 border-t border-[#0D442B] bg-[#062617]/50 text-[10px] text-emerald-400/80 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            <span className="font-semibold">Engine Online · v2.4</span>
          </div>
          <span className="text-slate-400">Dolly © 1103</span>
        </div>
      ) : (
        <div className="p-3 border-t border-[#0D442B] flex justify-center shrink-0">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" title="System Online" />
        </div>
      )}
    </aside>
  );
}
