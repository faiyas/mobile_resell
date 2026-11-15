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
  ArrowRight, CheckCircle2, Lock, Search, UserCheck 
} from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState('sell'); // 'sell' | 'track' | 'admin' | 'inspection'
  const [currentUser, setCurrentUser] = useState(null);
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [trackedSaleCode, setTrackedSaleCode] = useState('');

  useEffect(() => {
    const user = getCurrentUser();
    if (user) setCurrentUser(user);
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

      {/* Main Content Area with generous bottom padding on mobile so fixed bottom bar never overlaps */}
      <main className="flex-1 pb-24 md:pb-12">
        
        {/* Sell Phone Flow */}
        {activeTab === 'sell' && (
          <div>
            {/* Hero Banner */}
            <div className="bg-gradient-to-b from-white via-slate-50 to-slate-100 border-b border-slate-200 py-8 sm:py-16 text-center px-4 relative overflow-hidden">
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

            {/* Step-by-Step Selling Wizard */}
            <SellWizard 
              onOrderCreated={handleOrderCreated}
              currentUser={currentUser}
            />
          </div>
        )}

        {/* Track Order Flow */}
        {activeTab === 'track' && (
          <TrackOrder 
            initialSaleCode={trackedSaleCode}
            currentUser={currentUser}
          />
        )}

        {/* Super Admin Dashboard */}
        {activeTab === 'admin' && (
          <AdminDashboard currentUser={currentUser} />
        )}

        {/* Collection Agent Portal */}
        {activeTab === 'inspection' && (
          <AgentInspectionView currentUser={currentUser} />
        )}

      </main>

      {/* Modern Mobile Bottom Navigation Bar (Fixed for native app feel on small screens) */}
      <nav className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 backdrop-blur-md border-t border-slate-200 py-2 px-2 flex justify-around items-center shadow-2xl md:hidden">
        <button
          onClick={() => setActiveTab('sell')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition ${
            activeTab === 'sell' ? 'text-emerald-600 font-extrabold' : 'text-slate-500 hover:text-slate-900 font-medium'
          }`}
        >
          <Smartphone className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Sell Phone</span>
        </button>

        <button
          onClick={() => setActiveTab('track')}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition ${
            activeTab === 'track' ? 'text-emerald-600 font-extrabold' : 'text-slate-500 hover:text-slate-900 font-medium'
          }`}
        >
          <Search className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Track</span>
        </button>

        <button
          onClick={() => {
            if (!currentUser || currentUser.role !== 'ADMIN') {
              setAuthModalOpen(true);
            } else {
              setActiveTab('admin');
            }
          }}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition ${
            activeTab === 'admin' ? 'text-indigo-600 font-extrabold' : 'text-slate-500 hover:text-slate-900 font-medium'
          }`}
        >
          <ShieldCheck className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Admin</span>
        </button>

        <button
          onClick={() => {
            if (!currentUser || currentUser.role !== 'COLLECTION_AGENT') {
              setAuthModalOpen(true);
            } else {
              setActiveTab('inspection');
            }
          }}
          className={`flex flex-col items-center justify-center py-1 px-3 rounded-xl transition ${
            activeTab === 'inspection' ? 'text-amber-600 font-extrabold' : 'text-slate-500 hover:text-slate-900 font-medium'
          }`}
        >
          <UserCheck className="w-5 h-5 mb-0.5" />
          <span className="text-[10px]">Agent</span>
        </button>
      </nav>

      {/* Desktop Floating Quick Role Switcher Pill */}
      <div className="hidden md:flex fixed bottom-4 right-4 z-40 bg-slate-900/90 text-white backdrop-blur border border-slate-700 rounded-2xl p-2 shadow-2xl items-center gap-2 text-xs">
        <span className="font-bold text-[10px] text-slate-400 pl-2 uppercase">Switch View:</span>
        <button
          onClick={() => setActiveTab('sell')}
          className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'sell' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800 text-slate-300'}`}
        >
          Customer Sell
        </button>
        <button
          onClick={() => setActiveTab('track')}
          className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'track' ? 'bg-emerald-600 text-white' : 'hover:bg-slate-800 text-slate-300'}`}
        >
          Track Order
        </button>
        <button
          onClick={() => {
            if (!currentUser || currentUser.role !== 'ADMIN') {
              setAuthModalOpen(true);
            } else {
              setActiveTab('admin');
            }
          }}
          className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'admin' ? 'bg-indigo-600 text-white' : 'hover:bg-slate-800 text-indigo-300'}`}
        >
          Admin Desk
        </button>
        <button
          onClick={() => {
            if (!currentUser || currentUser.role !== 'COLLECTION_AGENT') {
              setAuthModalOpen(true);
            } else {
              setActiveTab('inspection');
            }
          }}
          className={`px-2.5 py-1.5 rounded-lg font-bold transition ${activeTab === 'inspection' ? 'bg-amber-600 text-white' : 'hover:bg-slate-800 text-amber-300'}`}
        >
          Agent Portal
        </button>
      </div>

      {/* Footer */}
      <Footer />

      {/* Auth Modal */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onAuthSuccess={(user) => {
          setCurrentUser(user);
          if (user.role === 'ADMIN') setActiveTab('admin');
          else if (user.role === 'COLLECTION_AGENT') setActiveTab('inspection');
          else setActiveTab('sell');
        }}
      />

    </div>
  );
}
