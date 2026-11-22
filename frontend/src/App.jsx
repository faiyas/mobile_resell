import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import AuthModal from './components/AuthModal';
import SellWizard from './customer/SellWizard';
import TrackOrder from './customer/TrackOrder';
import AdminDashboard from './admin/AdminDashboard';
import AgentInspectionView from './collection/AgentInspectionView';
import { api, getCurrentUser, removeAuthToken, removeCurrentUser } from './services/api';
import { 
  Smartphone, ShieldCheck, Truck, Banknote, Sparkles, 
  ArrowRight, CheckCircle2, Lock, Search, UserCheck, User, ShieldAlert, LogOut 
} from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('sell'); // 'sell' | 'track' | 'admin' | 'inspection'
  const [currentUser, setCurrentUser] = useState(null);
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [trackedSaleCode, setTrackedSaleCode] = useState('');
  const [cmsSections, setCmsSections] = useState([]);

  useEffect(() => {
    const handleAuthExpired = () => {
      setCurrentUser(null);
      setAuthModalOpen(true);
    };
    window.addEventListener('recell-auth-expired', handleAuthExpired);

    const user = getCurrentUser();
    if (user) {
      setCurrentUser(user);
      // Auto-route to dedicated workspace on load (never show guest landing page if logged in)
      if ((user.role === 'ADMIN' || user.role === 'SUPER_ADMIN')) {
        setActiveTab('admin');
      } else if (user.role === 'COLLECTION_AGENT') {
        setActiveTab('inspection');
      } else if (user.role === 'CUSTOMER') {
        setActiveTab('track');
      }
    }

    // Load dynamic CMS sections from Database
    api.getCMSSections().then(data => {
      if (Array.isArray(data) && data.length > 0) {
        setCmsSections(data);
      }
    }).catch(console.error);

    // Heartbeat Keep-Alive: Ping backend every 1 minute to prevent cloud backend idling
    api.pingHealth();
    const keepAliveTimer = setInterval(() => {
      api.pingHealth();
    }, 60000);

    return () => {
      window.removeEventListener('recell-auth-expired', handleAuthExpired);
      clearInterval(keepAliveTimer);
    };
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
    if ((user.role === 'ADMIN' || user.role === 'SUPER_ADMIN')) {
      setActiveTab('admin');
    } else if (user.role === 'COLLECTION_AGENT') {
      setActiveTab('inspection');
    } else {
      setActiveTab('track');
    }
  };

  // Route security guard: enforce permissions
  const canAccessAdmin = (currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN');
  const canAccessAgent = currentUser?.role === 'COLLECTION_AGENT' || (currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN');

  return (
    <div className="min-h-screen flex flex-col bg-mesh-canvas text-[#17251C] selection:bg-[#0BAA4B] selection:text-white antialiased">
      
      {/* Frosted Navbar */}
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
        {activeTab === 'sell' && (() => {
          const heroSection = cmsSections.find(s => s.section_type === 'hero_carousel');
          const heroTitle = heroSection?.title || 'Sell Your Old Device for Instant Cash';
          const heroSubtitle = heroSection?.subtitle || 'Get a fair, rule-based price estimate in 60 seconds. Our verified agent inspects your device at home and transfers money directly before leaving.';
          const heroBadge = heroSection?.data_json?.badge || '1103 RECELL · Certified Doorstep Buyback';
          const heroHighlights = heroSection?.data_json?.highlights || ['Free Doorstep Pickup', 'Instant UPI Payout', '100% Certified Data Wipe'];

          return (
            <div>
              {/* If NOT logged in (Guest): Render public marketing landing page */}
              {!currentUser ? (
                <>
                  {/* Dynamic Hero Banner (Glassmorphism Styled) */}
                  <div className="py-8 sm:py-14 text-center px-4 relative overflow-hidden">
                    <div className="max-w-4xl mx-auto space-y-3 sm:space-y-4 relative z-10">
                      <div className="inline-flex items-center gap-1.5 sm:gap-2 glass-pill px-4 py-1.5 rounded-full text-[11px] sm:text-xs font-black text-[#087C38] shadow-sm">
                        <Sparkles className="w-3.5 h-3.5 text-[#0BAA4B] shrink-0" />
                        <span>{heroBadge}</span>
                      </div>

                      <h1 className="text-2xl sm:text-5xl font-black text-[#17251C] tracking-tight leading-tight px-1">
                        {heroTitle.includes('Instant') ? (
                          <>
                            {heroTitle.split('Instant')[0]}
                            <span className="text-[#0BAA4B]">Instant Cash</span>
                            {heroTitle.split('Instant')[1]?.replace(/Cash/, '')}
                          </>
                        ) : (
                          <>{heroTitle}</>
                        )}
                      </h1>

                      <p className="text-xs sm:text-base text-[#7B8980] max-w-2xl mx-auto leading-relaxed px-2 font-medium">
                        {heroSubtitle}
                      </p>

                      {/* Highlights from DB CMS */}
                      <div className="flex flex-wrap items-center justify-center gap-2 sm:gap-4 pt-2 text-[11px] sm:text-xs font-bold text-[#17251C]">
                        {heroHighlights.map((hl, idx) => (
                          <span key={idx} className="flex items-center gap-1.5 glass-card px-3.5 py-1.5 rounded-xl border border-white/80 shadow-sm">
                            {idx === 0 ? <Truck className="w-3.5 h-3.5 text-[#0BAA4B] shrink-0" /> : idx === 1 ? <Banknote className="w-3.5 h-3.5 text-[#0BAA4B] shrink-0" /> : <Lock className="w-3.5 h-3.5 text-[#0BAA4B] shrink-0" />}
                            <span>{hl}</span>
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>

                  {/* 3 Giant Visual Glassmorphic Action Tiles */}
                  <div className="max-w-5xl mx-auto px-3 sm:px-6 pt-2 sm:pt-4">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3.5 sm:gap-5">
                      
                      {/* 1. SELL MY PHONE */}
                      <div 
                        onClick={() => {
                          const el = document.getElementById('sell-wizard-anchor');
                          if (el) el.scrollIntoView({ behavior: 'smooth' });
                        }}
                        className="cursor-pointer bg-gradient-to-br from-[#0BAA4B] to-[#06612A] text-white rounded-3xl p-5 sm:p-6 shadow-xl shadow-[#0BAA4B]/25 hover:scale-[1.02] transition flex flex-col justify-between group min-h-[140px] border border-white/30"
                      >
                        <div className="flex justify-between items-start">
                          <div className="w-12 h-12 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center border border-white/30">
                            <Smartphone className="w-6 h-6 text-white" />
                          </div>
                          <span className="text-[10px] font-black uppercase tracking-wider bg-white/20 backdrop-blur px-2.5 py-1 rounded-full border border-white/20">
                            Instant Value
                          </span>
                        </div>
                        <div>
                          <h3 className="text-lg sm:text-xl font-black mt-3">Check Resale Value</h3>
                          <p className="text-xs text-emerald-100 mt-0.5">Instant price estimate & free home pickup</p>
                          <span className="inline-flex items-center gap-1 font-black text-xs mt-2 text-white">
                            Get Instant Quote <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                          </span>
                        </div>
                      </div>

                      {/* 2. TRACK MY PHONE */}
                      <div 
                        onClick={() => setActiveTab('track')}
                        className="cursor-pointer glass-card glass-card-hover rounded-3xl p-5 sm:p-6 transition flex flex-col justify-between group min-h-[140px]"
                      >
                        <div className="flex justify-between items-start">
                          <div className="w-12 h-12 rounded-2xl bg-[#E8F8ED] text-[#087C38] flex items-center justify-center border border-[#0BAA4B]/20">
                            <Truck className="w-6 h-6" />
                          </div>
                          <span className="text-[10px] font-black uppercase tracking-wider bg-[#E8F8ED] text-[#087C38] px-2.5 py-1 rounded-full border border-[#0BAA4B]/20">
                            Orders
                          </span>
                        </div>
                        <div>
                          <h3 className="text-lg sm:text-xl font-black text-[#17251C] mt-3">Track My Device</h3>
                          <p className="text-xs text-[#7B8980] mt-0.5">Where is my assigned agent & inspection?</p>
                          <span className="inline-flex items-center gap-1 font-black text-xs mt-2 text-[#0BAA4B]">
                            Check Status <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                          </span>
                        </div>
                      </div>

                      {/* 3. MY PAYMENT */}
                      <div 
                        onClick={() => setActiveTab('track')}
                        className="cursor-pointer glass-card glass-card-hover rounded-3xl p-5 sm:p-6 transition flex flex-col justify-between group min-h-[140px]"
                      >
                        <div className="flex justify-between items-start">
                          <div className="w-12 h-12 rounded-2xl bg-[#E8F8ED] text-[#087C38] flex items-center justify-center border border-[#0BAA4B]/20">
                            <Banknote className="w-6 h-6" />
                          </div>
                          <span className="text-[10px] font-black uppercase tracking-wider bg-[#E8F8ED] text-[#087C38] px-2.5 py-1 rounded-full border border-[#0BAA4B]/20">
                            Payouts
                          </span>
                        </div>
                        <div>
                          <h3 className="text-lg sm:text-xl font-black text-[#17251C] mt-3">My Payout Receipt</h3>
                          <p className="text-xs text-[#7B8980] mt-0.5">UPI transfer receipt & UTR reference</p>
                          <span className="inline-flex items-center gap-1 font-black text-xs mt-2 text-[#0BAA4B]">
                            View Receipts <ArrowRight className="w-3.5 h-3.5 group-hover:translate-x-1 transition-transform" />
                          </span>
                        </div>
                      </div>

                    </div>
                  </div>
                </>
              ) : (
                /* Logged-in Customer/User Workspace Banner */
                <div className="max-w-5xl mx-auto px-4 pt-6 pb-2">
                  <div className="glass-card rounded-2xl p-4 sm:p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-3 border border-emerald-200/60 bg-emerald-50/40">
                    <div className="flex items-center gap-3">
                      <div className="w-11 h-11 rounded-2xl bg-gradient-to-br from-[#0BAA4B] to-[#087C38] text-white flex items-center justify-center font-black shadow-md shadow-[#0BAA4B]/20">
                        {currentUser.full_name ? currentUser.full_name[0].toUpperCase() : 'U'}
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <h2 className="text-base sm:text-lg font-black text-[#17251C]">
                            {currentUser.full_name || currentUser.email}
                          </h2>
                          <span className="text-[10px] font-black bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full border border-emerald-200 uppercase">
                            Verified {currentUser.role}
                          </span>
                        </div>
                        <p className="text-xs text-[#7B8980]">
                          1103 RECELL Smart Buyback Engine · Instant Valuation & Doorstep Payout
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setActiveTab('track')}
                        className="text-xs font-bold text-[#087C38] bg-white hover:bg-emerald-50 px-4 py-2 rounded-xl border border-emerald-200 shadow-sm transition flex items-center gap-1.5"
                      >
                        <Truck className="w-3.5 h-3.5" />
                        My Orders & Pickups
                      </button>
                    </div>
                  </div>
                </div>
              )}

              <div id="sell-wizard-anchor" className="pt-2" />

              {/* Step-by-Step Selling Wizard */}
              <SellWizard 
                onOrderCreated={handleOrderCreated}
                currentUser={currentUser}
                onOpenAuth={() => setAuthModalOpen(true)}
              />
            </div>
          );
        })()}

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
              <div className="w-16 h-16 rounded-full bg-rose-50 text-rose-600 flex items-center justify-center mx-auto border border-rose-200">
                <ShieldAlert className="w-8 h-8" />
              </div>
              <h3 className="text-xl font-extrabold text-[#17251C]">Admin Access Restricted</h3>
              <p className="text-xs text-[#7B8980]">
                You must be logged in with an authorized Administrator account to view the operations desk and authorize payouts.
              </p>
              <button
                onClick={() => setAuthModalOpen(true)}
                className="bg-[#0BAA4B] hover:bg-[#087C38] text-white font-bold px-6 py-2.5 rounded-xl text-xs shadow-md transition"
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
              <div className="w-16 h-16 rounded-full bg-amber-50 text-amber-600 flex items-center justify-center mx-auto border border-amber-200">
                <ShieldAlert className="w-8 h-8" />
              </div>
              <h3 className="text-xl font-extrabold text-[#17251C]">Field Agent Access Required</h3>
              <p className="text-xs text-[#7B8980]">
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
      <nav className="fixed bottom-0 left-0 right-0 z-40 glass-nav py-2 px-3 flex justify-around items-center shadow-2xl md:hidden">
        
        {/* Sell Phone (Always visible) */}
        <button
          onClick={() => setActiveTab('sell')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
            activeTab === 'sell' ? 'text-[#0BAA4B] font-black' : 'text-[#7B8980] font-medium'
          }`}
        >
          <Smartphone className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Sell Phone</span>
        </button>

        {/* Track Orders (Always visible) */}
        <button
          onClick={() => setActiveTab('track')}
          className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
            activeTab === 'track' ? 'text-[#0BAA4B] font-black' : 'text-[#7B8980] font-medium'
          }`}
        >
          <Search className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">{currentUser?.role === 'CUSTOMER' ? 'My Orders' : 'Track'}</span>
        </button>

        {/* Show Admin Desk ONLY to Admin */}
        {(currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN') && (
          <button
            onClick={() => setActiveTab('admin')}
            className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
              activeTab === 'admin' ? 'text-[#0BAA4B] font-black' : 'text-[#7B8980] font-medium'
            }`}
          >
            <ShieldCheck className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Admin Desk</span>
          </button>
        )}

        {/* Show Agent Portal ONLY to Collection Staff & Admin */}
        {(currentUser?.role === 'COLLECTION_AGENT' || (currentUser?.role === 'ADMIN' || currentUser?.role === 'SUPER_ADMIN')) && (
          <button
            onClick={() => setActiveTab('inspection')}
            className={`flex flex-col items-center justify-center py-1 px-2.5 rounded-xl transition ${
              activeTab === 'inspection' ? 'text-[#0BAA4B] font-black' : 'text-[#7B8980] font-medium'
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
            className="flex flex-col items-center justify-center py-1 px-2.5 rounded-xl text-[#7B8980] font-medium"
          >
            <User className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Login</span>
          </button>
        ) : (
          <button
            onClick={handleLogout}
            className="flex flex-col items-center justify-center py-1 px-2.5 rounded-xl text-[#7B8980] hover:text-rose-600 font-medium transition"
          >
            <LogOut className="w-5 h-5 mb-0.5" />
            <span className="text-[10px]">Logout</span>
          </button>
        )}
      </nav>

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
