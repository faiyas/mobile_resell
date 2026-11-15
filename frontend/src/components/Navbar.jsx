import React from 'react';
import { Smartphone, CheckCircle, Search, User, LogOut, ShieldCheck, ArrowRight } from 'lucide-react';

export default function Navbar({ activeTab, setActiveTab, currentUser, onOpenAuth, onLogout }) {
  return (
    <header className="sticky top-0 z-50 bg-white/95 backdrop-blur border-b border-slate-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          
          {/* Logo */}
          <div 
            onClick={() => setActiveTab('sell')} 
            className="flex items-center gap-2 cursor-pointer group"
          >
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-500 flex items-center justify-center text-white shadow-md shadow-emerald-500/20 group-hover:scale-105 transition-transform">
              <Smartphone className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-1.5">
                <span className="text-xl font-extrabold tracking-tight text-slate-900">ReCell</span>
                <span className="text-[10px] font-bold uppercase tracking-wider bg-emerald-100 text-emerald-800 px-1.5 py-0.5 rounded">India</span>
              </div>
              <p className="text-[11px] text-slate-500 font-medium -mt-1">Sell Phone · Instant Cash</p>
            </div>
          </div>

          {/* Navigation Links */}
          <nav className="hidden md:flex items-center gap-1">
            <button
              onClick={() => setActiveTab('sell')}
              className={`px-3.5 py-2 rounded-lg text-sm font-semibold transition-colors ${
                activeTab === 'sell' 
                  ? 'bg-emerald-50 text-emerald-700' 
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              Sell Old Phone
            </button>
            <button
              onClick={() => setActiveTab('track')}
              className={`px-3.5 py-2 rounded-lg text-sm font-semibold transition-colors flex items-center gap-1.5 ${
                activeTab === 'track' 
                  ? 'bg-emerald-50 text-emerald-700' 
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              <Search className="w-4 h-4" />
              Track Sale Status
            </button>
            
            {/* Staff / Admin navigation */}
            {currentUser?.role === 'ADMIN' && (
              <button
                onClick={() => setActiveTab('admin')}
                className={`px-3.5 py-2 rounded-lg text-sm font-semibold transition-colors flex items-center gap-1.5 ${
                  activeTab === 'admin' 
                    ? 'bg-indigo-50 text-indigo-700' 
                    : 'text-indigo-600 hover:bg-indigo-50'
                }`}
              >
                <ShieldCheck className="w-4 h-4" />
                Admin Dashboard
              </button>
            )}

            {currentUser?.role === 'COLLECTION_AGENT' && (
              <button
                onClick={() => setActiveTab('inspection')}
                className={`px-3.5 py-2 rounded-lg text-sm font-semibold transition-colors flex items-center gap-1.5 ${
                  activeTab === 'inspection' 
                    ? 'bg-amber-50 text-amber-700' 
                    : 'text-amber-600 hover:bg-amber-50'
                }`}
              >
                <Smartphone className="w-4 h-4" />
                Collection Agent Portal
              </button>
            )}
          </nav>

          {/* Right Action / Auth */}
          <div className="flex items-center gap-3">
            {currentUser ? (
              <div className="flex items-center gap-3">
                <div className="text-right hidden sm:block">
                  <p className="text-xs font-bold text-slate-800 leading-none">{currentUser.full_name || currentUser.email}</p>
                  <span className="text-[10px] font-semibold text-emerald-600 uppercase tracking-wide">
                    {currentUser.role === 'ADMIN' ? 'Super Admin' : currentUser.role === 'COLLECTION_AGENT' ? 'Pickup Agent' : 'Customer'}
                  </span>
                </div>
                <button
                  onClick={onLogout}
                  title="Logout"
                  className="p-2 rounded-lg border border-slate-200 text-slate-600 hover:text-rose-600 hover:border-rose-200 hover:bg-rose-50 transition-colors"
                >
                  <LogOut className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <button
                onClick={onOpenAuth}
                className="flex items-center gap-1.5 text-xs font-bold uppercase tracking-wider text-slate-700 hover:text-emerald-600 bg-slate-100 hover:bg-slate-200 px-3 py-2 rounded-lg transition-colors"
              >
                <User className="w-4 h-4" />
                Staff / Login
              </button>
            )}

            <button
              onClick={() => setActiveTab('sell')}
              className="bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-sm px-4 py-2 rounded-xl shadow-sm hover:shadow transition flex items-center gap-1"
            >
              Get Price <ArrowRight className="w-4 h-4" />
            </button>
          </div>

        </div>
      </div>
    </header>
  );
}
