import React from 'react';
import {
  Smartphone, Search, User, LogOut, ShieldCheck,
  ArrowRight, UserCheck, MapPin, ChevronDown, CheckCircle2
} from 'lucide-react';

export default function Navbar({ activeTab, setActiveTab, currentUser, onOpenAuth, onLogout, selectedCity = '', onSelectCity }) {
  const categories = [
    { label: 'Sell Old Mobile', slug: 'mobile' },
    { label: 'Tablet', slug: 'tablet' },
    { label: 'Laptop', slug: 'laptop' },
    { label: 'Smartwatch', slug: 'smartwatch' },
    { label: 'Dead Phone', slug: 'dead-phone' },
  ];

  return (
    <header className="sticky top-0 z-30 glass-nav shadow-sm">
      {/* Top micro bar for categories */}
      <div className="hidden lg:block bg-white/60 backdrop-blur-md border-b border-white/80 py-1.5 px-4 text-xs font-semibold text-[#17251C]">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-4">
            <span className="text-[10px] font-black uppercase text-[#0BAA4B] tracking-wider">Fast Services:</span>
            <div className="flex items-center gap-3">
              {categories.map((cat, i) => (
                <button
                  key={i}
                  onClick={() => setActiveTab('sell')}
                  className="hover:text-[#0BAA4B] transition-colors flex items-center gap-1 text-[11px]"
                >
                  <span className="text-[#0BAA4B]">●</span> {cat.label}
                </button>
              ))}
            </div>
          </div>
          <div className="flex items-center gap-3 text-[11px] text-[#7B8980]">
            {selectedCity ? (
              <>
                <span className="flex items-center gap-1 text-[#17251C] font-bold">
                  <MapPin className="w-3.5 h-3.5 text-[#0BAA4B]" /> {selectedCity}
                </span>
                <span>|</span>
              </>
            ) : null}
            <span className="text-[#0BAA4B] font-bold">Free Doorstep Pickup</span>
          </div>
        </div>
      </div>

      {/* Main Navbar */}
      <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16 sm:h-18">

          {/* Dolly Brand Logo */}
          <div
            onClick={() => setActiveTab((currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN') ? 'admin' : currentUser?.role === 'COLLECTION_AGENT' ? 'inspection' : 'sell')}
            className="flex items-center gap-2.5 cursor-pointer group shrink-0 select-none"
          >
            <img 
              src="/dolly_icon.png" 
              alt="Dolly Emblem" 
              className="w-9 h-9 sm:w-11 sm:h-11 rounded-2xl object-cover shadow-lg shadow-[#0BAA4B]/20 group-hover:scale-105 transition-transform border border-emerald-200/50" 
            />
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-xl sm:text-2xl font-black tracking-tight text-[#17251C]">
                  Dolly
                </span>
                <span className="text-[8px] sm:text-[9px] font-black uppercase tracking-wider bg-[#E8F8ED] text-[#087C38] px-1.5 py-0.5 rounded-full border border-[#0BAA4B]/20">
                  Buyback
                </span>
              </div>
              <p className="text-[9px] sm:text-[10px] text-[#7B8980] font-bold tracking-wider uppercase -mt-0.5 hidden xs:block">
                Device Buyback Platform · 1103 TechStudios
              </p>
            </div>
          </div>

          {/* Desktop Navigation Links */}
          <nav className="hidden md:flex items-center gap-1.5 text-xs sm:text-sm font-bold">
            <button
              onClick={() => setActiveTab('sell')}
              className={`px-3.5 py-2 rounded-xl transition ${activeTab === 'sell'
                ? 'bg-[#E8F8ED] text-[#087C38] border border-[#0BAA4B]/20 font-black shadow-sm'
                : 'text-[#17251C] hover:bg-white/60 hover:text-[#0BAA4B]'
                }`}
            >
              Sell Device
            </button>

            <button
              onClick={() => setActiveTab('track')}
              className={`px-3.5 py-2 rounded-xl transition flex items-center gap-1.5 ${activeTab === 'track'
                ? 'bg-[#E8F8ED] text-[#087C38] border border-[#0BAA4B]/20 font-black shadow-sm'
                : 'text-[#17251C] hover:bg-white/60 hover:text-[#0BAA4B]'
                }`}
            >
              <Search className="w-4 h-4 text-[#0BAA4B]" />
              {currentUser?.role === 'CUSTOMER' ? 'My Orders' : 'Track Status'}
            </button>

            {/* Show Admin Dashboard ONLY to Admin */}
            {(currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN') && (
              <button
                onClick={() => setActiveTab('admin')}
                className={`px-3.5 py-2 rounded-xl transition flex items-center gap-1.5 font-extrabold ${activeTab === 'admin'
                  ? 'bg-[#0BAA4B] text-white shadow-md shadow-[#0BAA4B]/25'
                  : 'text-[#087C38] bg-[#E8F8ED] hover:bg-[#0BAA4B] hover:text-white'
                  }`}
              >
                <ShieldCheck className="w-4 h-4" />
                Admin Desk
              </button>
            )}

            {/* Show Agent Portal ONLY to Collection Staff & Admin */}
            {(currentUser?.role === 'COLLECTION_AGENT' || (currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN')) && (
              <button
                onClick={() => setActiveTab('inspection')}
                className={`px-3.5 py-2 rounded-xl transition flex items-center gap-1.5 font-extrabold ${activeTab === 'inspection'
                  ? 'bg-amber-600 text-white shadow-md'
                  : 'text-amber-800 bg-amber-50 hover:bg-amber-100'
                  }`}
              >
                <UserCheck className="w-4 h-4" />
                Agent Inspection
              </button>
            )}
          </nav>

          {/* Right Action / Auth */}
          <div className="flex items-center gap-2 sm:gap-3">
            {currentUser ? (
              <div className="flex items-center gap-2 sm:gap-3">
                <div className="text-right">
                  <p className="text-xs font-black text-[#17251C] leading-none truncate max-w-[85px] xs:max-w-[120px] sm:max-w-none">
                    {currentUser.full_name || currentUser.email}
                  </p>
                  <span className={`text-[9px] sm:text-[10px] font-black uppercase tracking-wide ${(currentUser.role === 'ADMIN' || currentUser.role === 'SUPER_ADMIN') ? 'text-[#087C38]' :
                    currentUser.role === 'COLLECTION_AGENT' ? 'text-amber-600' : 'text-[#0BAA4B]'
                    }`}>
                    {(currentUser.role === 'ADMIN' || currentUser.role === 'SUPER_ADMIN') ? '👑 Admin' : currentUser.role === 'COLLECTION_AGENT' ? '🛵 Agent' : '👤 Customer'}
                  </span>
                </div>
                <button
                  onClick={onLogout}
                  title="Logout"
                  className="p-2 rounded-xl border border-white/80 bg-white/70 backdrop-blur text-[#7B8980] hover:text-rose-600 hover:border-rose-200 hover:bg-rose-50 transition"
                >
                  <LogOut className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={onOpenAuth}
                className="flex items-center gap-1.5 text-xs font-black text-white bg-[#0BAA4B] hover:bg-[#087C38] px-3.5 sm:px-4 py-2 rounded-xl shadow-md shadow-[#0BAA4B]/20 transition"
              >
                <User className="w-4 h-4" />
                <span>Login</span>
              </button>
            )}

            <button
              onClick={() => setActiveTab('sell')}
              className={`${currentUser ? 'hidden sm:flex' : 'hidden md:flex'} bg-[#087C38] hover:bg-[#0D4722] text-white font-black text-xs sm:text-sm px-3.5 sm:px-4 py-2 rounded-xl shadow-md transition items-center gap-1.5 shrink-0 whitespace-nowrap`}
            >
              <span>Sell Device</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

        </div>
      </div>
    </header>
  );
}
