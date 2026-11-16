import React from 'react';
import { Smartphone, CheckCircle, Search, User, LogOut, ShieldCheck, ArrowRight, UserCheck } from 'lucide-react';

export default function Navbar({ activeTab, setActiveTab, currentUser, onOpenAuth, onLogout }) {
  return (
    <header className="sticky top-0 z-30 bg-white/95 backdrop-blur border-b border-slate-200">
      <div className="max-w-7xl mx-auto px-3 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-14 sm:h-16">

          {/* Logo */}
          <div
            onClick={() => setActiveTab(currentUser?.role === 'ADMIN' ? 'admin' : currentUser?.role === 'COLLECTION_AGENT' ? 'inspection' : 'sell')}
            className="flex items-center gap-2 cursor-pointer group shrink-0"
          >
            <div className="w-8 h-8 sm:w-10 sm:h-10 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center text-white shadow-md shadow-emerald-500/20 group-hover:scale-105 transition-transform">
              <Smartphone className="w-4 h-4 sm:w-5 sm:h-5" />
            </div>
            <div>
              <div className="flex items-center gap-1">
                <span className="text-lg sm:text-xl font-extrabold tracking-tight text-slate-900">ReCell</span>
                <span className="text-[9px] sm:text-[10px] font-bold uppercase tracking-wider bg-emerald-100 text-emerald-800 px-1 py-0.2 rounded">India</span>
              </div>
              <p className="text-[10px] sm:text-[11px] text-slate-500 font-medium -mt-1 hidden sm:block">Sell Phone · Instant Cash</p>
            </div>
          </div>

          {/* Desktop Navigation Links (Strict Role-Based) */}
          <nav className="hidden md:flex items-center gap-1">
            <button
              onClick={() => setActiveTab('sell')}
              className={`px-3 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-colors ${activeTab === 'sell'
                  ? 'bg-emerald-50 text-emerald-700'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                }`}
            >
              Sell Old Phone
            </button>
            <button
              onClick={() => setActiveTab('track')}
              className={`px-3 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-colors flex items-center gap-1.5 ${activeTab === 'track'
                  ? 'bg-emerald-50 text-emerald-700'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                }`}
            >
              <Search className="w-4 h-4" />
              {currentUser?.role === 'CUSTOMER' ? 'My Orders' : 'Track Status'}
            </button>

            {/* Show Admin Dashboard ONLY to Admin */}
            {currentUser?.role === 'ADMIN' && (
              <button
                onClick={() => setActiveTab('admin')}
                className={`px-3 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-colors flex items-center gap-1.5 ${activeTab === 'admin'
                    ? 'bg-indigo-50 text-indigo-700'
                    : 'text-indigo-600 hover:bg-indigo-50'
                  }`}
              >
                <ShieldCheck className="w-4 h-4" />
                Admin Dashboard
              </button>
            )}

            {/* Show Agent Portal ONLY to Collection Staff & Admin */}
            {(currentUser?.role === 'COLLECTION_AGENT' || currentUser?.role === 'ADMIN') && (
              <button
                onClick={() => setActiveTab('inspection')}
                className={`px-3 py-1.5 rounded-lg text-xs sm:text-sm font-semibold transition-colors flex items-center gap-1.5 ${activeTab === 'inspection'
                    ? 'bg-amber-50 text-amber-700'
                    : 'text-amber-600 hover:bg-amber-50'
                  }`}
              >
                <UserCheck className="w-4 h-4" />
                Collection Agent Portal
              </button>
            )}
          </nav>

          {/* Right Action / Auth */}
          <div className="flex items-center gap-2 sm:gap-3">
            {currentUser ? (
              <div className="flex items-center gap-2 sm:gap-3">
                <div className="text-right">
                  <p className="text-xs font-bold text-slate-800 leading-none truncate max-w-[85px] xs:max-w-[120px] sm:max-w-none">
                    {currentUser.full_name || currentUser.email}
                  </p>
                  <span className={`text-[9px] sm:text-[10px] font-bold uppercase tracking-wide ${
                    currentUser.role === 'ADMIN' ? 'text-indigo-600' :
                    currentUser.role === 'COLLECTION_AGENT' ? 'text-amber-600' : 'text-emerald-600'
                  }`}>
                    {currentUser.role === 'ADMIN' ? '👑 Admin' : currentUser.role === 'COLLECTION_AGENT' ? '🛵 Agent' : '👤 Customer'}
                  </span>
                </div>
                <button
                  onClick={onLogout}
                  title="Logout"
                  className="p-1.5 sm:p-2 rounded-lg border border-slate-200 text-slate-600 hover:text-rose-600 hover:border-rose-200 hover:bg-rose-50 transition-colors"
                >
                  <LogOut className="w-3.5 h-3.5 sm:w-4 sm:h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={onOpenAuth}
                className="flex items-center gap-1 text-[11px] sm:text-xs font-bold uppercase tracking-wider text-slate-700 hover:text-emerald-600 bg-slate-100 hover:bg-slate-200 px-2.5 sm:px-3 py-1.5 rounded-lg transition-colors"
              >
                <User className="w-3.5 h-3.5" />
                Login
              </button>
            )}

            <button
              onClick={() => setActiveTab('sell')}
              className={`${currentUser ? 'hidden sm:flex' : 'flex'} bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs sm:text-sm px-2.5 sm:px-4 py-1.5 sm:py-2 rounded-xl shadow-sm transition items-center gap-1 shrink-0 whitespace-nowrap`}
            >
              <span>Get Price</span>
              <ArrowRight className="w-3.5 h-3.5 hidden sm:inline" />
            </button>
          </div>

        </div>
      </div>
    </header>
  );
}
