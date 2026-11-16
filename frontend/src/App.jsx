import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import AuthModal from './components/AuthModal';
import SellWizard from './customer/SellWizard';
import TrackOrder from './customer/TrackOrder';
import AdminDashboard from './admin/AdminDashboard';
import AgentInspectionView from './collection/AgentInspectionView';
import { getCurrentUser, removeAuthToken, removeCurrentUser } from './services/api';
import { 
  Smartphone, ShieldCheck, Truck, Banknote, Sparkles, 
  ArrowRight, CheckCircle2, Lock, Search, UserCheck, User, ShieldAlert, LogOut 
} from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('sell'); // 'sell' | 'track' | 'admin' | 'inspection'
  const [currentUser, setCurrentUser] = useState(null);
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [trackedSaleCode, setTrackedSaleCode] = useState('');

  useEffect(() => {
    const user = getCurrentUser();
    if (user) {
      setCurrentUser(user);
      // Auto-route staff to their dedicated workspace on load
      if (user.role === 'ADMIN' && activeTab === 'sell') {
        setActiveTab('admin');
      } else if (user.role === 'COLLECTION_AGENT' && activeTab === 'sell') {
        setActiveTab('inspection');
      }
    }
  }, []);

  const handleLogout = () => {
    removeAuthToken();
    removeCurrentUser();
    setCurrentUser(null);
    setActiveTab('sell');
  };

  const handleOrderCreated = (order) => {
    setTrackedSaleCode(order.sale_code);
    setActiveTab('track');
  };

  const handleAuthSuccess = (user) => {
    setCurrentUser(user);
    // Strict automatic role-based redirection
    if (user.role === 'ADMIN') {
      setActiveTab('admin');
    } else if (user.role === 'COLLECTION_AGENT') {
      setActiveTab('inspection');
    } else {
      setActiveTab('track');
    }
  };

  // Route security guard: enforce permissions
  const canAccessAdmin = currentUser?.role === 'ADMIN';
  const canAccessAgent = currentUser?.role === 'COLLECTION_AGENT' || currentUser?.role === 'ADMIN';

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 text-slate-900 selection:bg-emerald-500 selection:text-white">
      
      {/* Navbar */}
      <Navbar
        activeTab={activeTab}
        setActiveTab={setActiveTab}
        currentUser={currentUser}
        onOpenAuth={() => setAuthModalOpen(true)}
        onLogout={handleLogout}
      />

      {/* Main Content Area */}
      <main className="flex-1 pb-24 md:pb-12">
        
        {/* ================= 1. SELL PHONE (Customer & All) ================= */}
        {activeTab === 'sell' && (
          <div>
            {/* Hero Banner */}
            <div className="bg-gradient-to-b from-white via-slate-50 to-slate-100 border-b border-slate-200 py-8 sm:py-14 text-center px-4 relative overflow-hidden">
              <div className="max-w-4xl mx-auto space-y-3 sm:space-y-4 relative z-10">
                <div className="inline-flex items-center gap-1.5 sm:gap-2 bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-full text-[11px] sm:text-xs font-extrabold text-emerald-800">
                  <Sparkles className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                  <span>One-Way Buyback Platform · Strictly Sell Only</span>
                </div>

                <h1 className="text-2xl sm:text-5xl font-black text-slate-900 tracking-tight leading-tight px-1">
                  Sell Your Old Phone for <span className="text-emerald-600">Instant Cash</span> at Your Doorstep
                </h1>

                <p className="text-xs sm:text-base text-slate-600 max-w-2xl mx-auto leading-relaxed px-2">
                  Get a fair, rule-based price estimate in 60 seconds. Our verified agent inspects your device at home and transfers money directly to your <strong>Google Pay, PhonePe, or Bank account</strong> before leaving.
                </p>

                {/* Badges */}
                <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-4 pt-2 text-[11px] sm:text-xs font-bold text-slate-700">
                  <span className="flex items-center gap-1.5 bg-white px-2.5 py-1 sm:px-3 sm:py-1.5 rounded-lg border border-slate-200 shadow-sm">
                    <Truck className="w-3.5 h-3.5 text-emerald-600 shrink-0" /> Free Doorstep Pickup
                  </span>
                  <span className="flex items-center gap-1.5 bg-white px-2.5 py-1 sm:px-3 sm:py-1.5 rounded-lg border border-slate-200 shadow-sm">
                    <Banknote className="w-3.5 h-3.5 text-emerald-600 shrink-0" /> Instant UPI Payout
                  </span>
                  <span className="flex items-center gap-1.5 bg-white px-2.5 py-1 sm:px-3 sm:py-1.5 rounded-lg border border-slate-200 shadow-sm">
                    <Lock className="w-3.5 h-3.5 text-emerald-600 shrink-0" /> 100% Certified Data Wipe
                  </span>
                </div>
              </div>
            </div>

            {/* 3 Giant Visual Action Tiles */}
            <div className="max-w-5xl mx-auto px-3 sm:px-6 pt-6 sm:pt-8">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5 sm:gap-5">
                
                {/* 1. SELL MY PHONE */}
                <div 
                  onClick={() => {
                    const el = document.getElementById('sell-wizard-anchor');
                    if (el) el.scrollIntoView({ behavior: 'smooth' });
                  }}
                  className="cursor-pointer bg-gradient-to-br from-emerald-600 to-teal-700 text-white rounded-3xl p-5 sm:p-6 shadow-xl shadow-emerald-600/20 hover:scale-[1.02] transition flex flex-col justify-between group min-h-[140px]"
                >
                  <div className="flex justify-between items-start">
                    <div className="w-12 h-12 rounded-2xl bg-white/20 backdrop-blur flex items-center justify-center">
                      <Smartphone className="w-6 h-6 text-white" />
                    </div>
                    <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 px-2.5 py-1 rounded-full">
                      Sell Old Phone
                    </span>
                  </div>
                  <div>
                    <h3 className="text-lg sm:text-xl font-black mt-3">Sell Old Mobile</h3>
                    <p className="text-xs text-emerald-100 mt-0.5">Instant price estimate & free home pickup</p>
                    <span className="inline-flex items-center gap-1 font-bold text-xs mt-2 text-white">
                      Start Selling <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                    </span>
                  </div>
                </div>

                {/* 2. TRACK MY PHONE */}
                <div 
                  onClick={() => setActiveTab('track')}
                  className="cursor-pointer bg-white border-2 border-slate-200 hover:border-amber-400 hover:shadow-lg rounded-3xl p-5 sm:p-6 transition flex flex-col justify-between group min-h-[140px]"
                >
                  <div className="flex justify-between items-start">
                    <div className="w-12 h-12 rounded-2xl bg-amber-50 text-amber-600 flex items-center justify-center">
                      <Truck className="w-6 h-6" />
                    </div>
                    <span className="text-[10px] font-black uppercase tracking-wider bg-amber-100 text-amber-800 px-2.5 py-1 rounded-full">
                      Orders
                    </span>
                  </div>
                  <div>
                    <h3 className="text-lg sm:text-xl font-black text-slate-900 mt-3">Track My Phone</h3>
                    <p className="text-xs text-slate-500 mt-0.5">Where is my assigned agent & inspection?</p>
                    <span className="inline-flex items-center gap-1 font-bold text-xs mt-2 text-amber-700">
                      Check Status <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                    </span>
                  </div>
                </div>

                {/* 3. MY PAYMENT */}
                <div 
                  onClick={() => setActiveTab('track')}
                  className="cursor-pointer bg-white border-2 border-slate-200 hover:border-indigo-400 hover:shadow-lg rounded-3xl p-5 sm:p-6 transition flex flex-col justify-between group min-h-[140px]"
                >
                  <div className="flex justify-between items-start">
                    <div className="w-12 h-12 rounded-2xl bg-indigo-50 text-indigo-600 flex items-center justify-center">
                      <Banknote className="w-6 h-6" />
                    </div>
                    <span className="text-[10px] font-black uppercase tracking-wider bg-indigo-100 text-indigo-800 px-2.5 py-1 rounded-full">
                      Payouts
                    </span>
                  </div>
                  <div>
                    <h3 className="text-lg sm:text-xl font-black text-slate-900 mt-3">My Payment</h3>
                    <p className="text-xs text-slate-500 mt-0.5">UPI transfer receipt & UTR reference</p>
                    <span className="inline-flex items-center gap-1 font-bold text-xs mt-2 text-indigo-700">
                      View Receipts <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                    </span>
                  </div>
                </div>

              </div>
            </div>

            <div id="sell-wizard-anchor" className="pt-2" />

            {/* Step-by-Step Selling Wizard */}
            <SellWizard 
              onOrderCreated={handleOrderCreated}
              currentUser={currentUser}
            />
          </div>
        )}

        {/* ================= 2. TRACK ORDER (Customer & All) ================= */}
        {activeTab === 'track' && (
          <TrackOrder 
            initialSaleCode={trackedSaleCode}
            currentUser={currentUser}
          />
        )}

        {/* ================= 3. SUPER ADMIN DASHBOARD ================= */}
        {activeTab === 'admin' && (
          canAccessAdmin ? (
            <AdminDashboard currentUser={currentUser} />
          ) : (
            <div className="max-w-lg mx-auto px-4 py-16 text-center space-y-4">
              <div className="w-16 h-16 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto">
                <ShieldAlert className="w-8 h-8" />
              </div>
              <h3 className="text-xl font-extrabold text-slate-900">Admin Access Restricted</h3>
              <p className="text-xs text-slate-500">
                You must be logged in with an authorized Administrator account to view the operations desk and authorize payouts.
              </p>
              <button
                onClick={() => setAuthModalOpen(true)}
                className="bg-slate-900 text-white font-bold px-6 py-2.5 rounded-xl text-xs hover:bg-black transition"
              >
                Sign In as Admin
              </button>
            </div>
          )
        )}

        {/* ================= 4. COLLECTION AGENT PORTAL ================= */}
        {activeTab === 'inspection' && (
          canAccessAgent ? (
            <AgentInspectionView currentUser={currentUser} />
          ) : (
            <div className="max-w-lg mx-auto px-4 py-16 text-center space-y-4">
              <div className="w-16 h-16 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center mx-auto">
                <ShieldAlert className="w-8 h-8" />
              </div>
              <h3 className="text-xl font-extrabold text-slate-900">Field Agent Access Required</h3>
              <p className="text-xs text-slate-500">
                Please log in with your assigned Collection Agent credentials to record device inspections and IMEI checks.
              </p>
              <button
                onClick={() => setAuthModalOpen(true)}
                className="bg-amber-600 text-white font-bold px-6 py-2.5 rounded-xl text-xs hover:bg-amber-700 transition"
              >
                Sign In as Field Agent
              </button>
            </div>
          )
        )}

      </main>

      {/* ================= MODERN MOBILE BOTTOM NAVIGATION BAR ================= */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200 py-1.5 px-3 flex justify-around items-center shadow-2xl md:hidden">
        
        {/* Sell Phone (Always visible) */}
        <button
          onClick={() => setActiveTab('sell')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
            activeTab === 'sell' ? 'text-emerald-600 font-extrabold' : 'text-slate-500 font-medium'
          }`}
        >
          <Smartphone className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Sell Phone</span>
        </button>

        {/* Track Orders (Always visible) */}
        <button
          onClick={() => setActiveTab('track')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
            activeTab === 'track' ? 'text-emerald-600 font-extrabold' : 'text-slate-500 font-medium'
          }`}
        >
          <Search className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">{currentUser?.role === 'CUSTOMER' ? 'My Orders' : 'Track'}</span>
        </button>

        {/* Show Admin Desk ONLY to Admin */}
        {currentUser?.role === 'ADMIN' && (
          <button
            onClick={() => setActiveTab('admin')}
            className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
              activeTab === 'admin' ? 'text-indigo-600 font-extrabold' : 'text-slate-500 font-medium'
            }`}
          >
            <ShieldCheck className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Admin Desk</span>
          </button>
        )}

        {/* Show Agent Portal ONLY to Collection Staff & Admin */}
        {(currentUser?.role === 'COLLECTION_AGENT' || currentUser?.role === 'ADMIN') && (
          <button
            onClick={() => setActiveTab('inspection')}
            className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
              activeTab === 'inspection' ? 'text-amber-600 font-extrabold' : 'text-slate-500 font-medium'
            }`}
          >
            <UserCheck className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Agent</span>
          </button>
        )}

        {/* Account / Login button */}
        {!currentUser ? (
          <button
            onClick={() => setAuthModalOpen(true)}
            className="flex flex-col items-center justify-center py-1 px-2.5 rounded-xl text-slate-500 font-medium"
          >
            <User className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Login</span>
          </button>
        ) : (
          <button
            onClick={handleLogout}
            className="flex flex-col items-center justify-center py-1 px-2.5 rounded-xl text-slate-500 hover:text-rose-600 font-medium transition"
          >
            <LogOut className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Logout</span>
          </button>
        )}
      </nav>

      {/* Desktop Role Switcher (Visible on medium+ screens for convenience) */}
      {currentUser?.role === 'ADMIN' && (
        <div className="hidden md:flex fixed bottom-4 right-4 z-40 bg-slate-900/90 text-white backdrop-blur border border-slate-700 rounded-2xl p-1.5 shadow-2xl items-center gap-1.5 text-xs">
          <span className="font-bold text-[10px] text-slate-400 pl-2 uppercase">Quick Switch:</span>
          <button
            onClick={() => setActiveTab('admin')}
            className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'admin' ? 'bg-indigo-600 text-white' : 'hover:bg-slate-800 text-indigo-300'}`}
          >
            👑 Admin Desk
          </button>
          <button
            onClick={() => setActiveTab('inspection')}
            className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'inspection' ? 'bg-amber-600 text-white' : 'hover:bg-slate-800 text-amber-300'}`}
          >
            🛵 Agent View
          </button>
          <button
            onClick={() => setActiveTab('sell')}
            className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'sell' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800 text-slate-300'}`}
          >
            📱 Customer Sell
          </button>
        </div>
      )}

      {/* Footer */}
      <Footer />

      {/* Auth Modal with strict role redirection */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onAuthSuccess={handleAuthSuccess}
      />

    </div>
  );
}
