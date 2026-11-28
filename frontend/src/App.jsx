import React, { useState, useEffect, useRef, useCallback } from 'react';
import Navbar from './components/Navbar';
import Footer from './components/Footer';
import AuthModal from './components/AuthModal';
import ServerUnavailableModal from './components/ServerUnavailableModal';
import SellWizard from './customer/SellWizard';
import TrackOrder from './customer/TrackOrder';
import AdminDashboard from './admin/AdminDashboard';
import AgentInspectionView from './collection/AgentInspectionView';
import { api, getCurrentUser, removeAuthToken, removeCurrentUser } from './services/api';
import { 
  Smartphone, ShieldCheck, Truck, Banknote, Sparkles, 
  ArrowRight, CheckCircle2, Lock, Search, UserCheck, User, ShieldAlert, LogOut, Clock 
} from 'lucide-react';

const ADMIN_IDLE_TIMEOUT_MS = 15 * 60 * 1000; // 15 minutes for Admin / Super Admin
const USER_IDLE_TIMEOUT_MS = 30 * 60 * 1000;  // 30 minutes for Agents & Customers
const IDLE_WARNING_WINDOW_MS = 60 * 1000;     // Show 60-second countdown before auto-logout
const LAST_ACTIVITY_KEY = 'recell_last_activity';

export default function App() {
  const [activeTab, setActiveTab] = useState('sell'); // 'sell' | 'track' | 'admin' | 'inspection'
  const [currentUser, setCurrentUser] = useState(null);
  const [authModalOpen, setAuthModalOpen] = useState(false);
  const [trackedSaleCode, setTrackedSaleCode] = useState('');
  const [cmsSections, setCmsSections] = useState([]);
  const [idleSecondsLeft, setIdleSecondsLeft] = useState(null);
  const [sessionExpiredNotice, setSessionExpiredNotice] = useState(false);
  const lastActivityWriteRef = useRef(0);

  useEffect(() => {
    const handleAuthExpired = () => {
      setCurrentUser(null);
      setAuthModalOpen(true);
    };
    window.addEventListener('recell-auth-expired', handleAuthExpired);

    const user = getCurrentUser();
    if (user) {
      setCurrentUser(user);
      const role = (user.role || '').toUpperCase();
      // Auto-route to dedicated workspace on load (never show guest landing page if logged in)
      if (role === 'ADMIN' || role === 'SUPER_ADMIN') {
        setActiveTab('admin');
      } else if (role === 'COLLECTION_AGENT' || role === 'AGENT' || role === 'FIELD_AGENT') {
        setActiveTab('inspection');
      } else if (role === 'CUSTOMER') {
        setActiveTab('track');
      }
    }

    // Load dynamic CMS sections from Database
    api.getCMSSections().then(data => {
      if (Array.isArray(data) && data.length > 0) {
        setCmsSections(data);
      }
    }).catch(console.error);

    return () => {
      window.removeEventListener('recell-auth-expired', handleAuthExpired);
    };
  }, []);

  const handleLogout = useCallback((isIdleTimeout = false) => {
    removeAuthToken();
    removeCurrentUser();
    localStorage.removeItem(LAST_ACTIVITY_KEY);
    setIdleSecondsLeft(null);
    setCurrentUser(null);
    setActiveTab('sell');
    if (isIdleTimeout === true) {
      setSessionExpiredNotice(true);
      setAuthModalOpen(true);
    }
  }, []);

  const resetIdleTimer = useCallback(() => {
    const now = Date.now();
    lastActivityWriteRef.current = now;
    localStorage.setItem(LAST_ACTIVITY_KEY, String(now));
    setIdleSecondsLeft(null);
  }, []);

  useEffect(() => {
    if (!currentUser) {
      setIdleSecondsLeft(null);
      return;
    }

    const role = (currentUser.role || '').toUpperCase();
    const isAdminUser = role === 'ADMIN' || role === 'SUPER_ADMIN';
    const timeoutMs = isAdminUser ? ADMIN_IDLE_TIMEOUT_MS : USER_IDLE_TIMEOUT_MS;

    // Initialize activity timestamp on login / mount if missing
    if (!localStorage.getItem(LAST_ACTIVITY_KEY)) {
      localStorage.setItem(LAST_ACTIVITY_KEY, String(Date.now()));
    }

    const recordActivity = () => {
      const now = Date.now();
      // Throttle localStorage writes to once every 5s while user is active
      if (now - lastActivityWriteRef.current >= 5000) {
        lastActivityWriteRef.current = now;
        localStorage.setItem(LAST_ACTIVITY_KEY, String(now));
      }
      setIdleSecondsLeft((prev) => (prev !== null ? null : prev));
    };

    const activityEvents = ['mousemove', 'mousedown', 'keydown', 'scroll', 'touchstart', 'click'];
    activityEvents.forEach((evt) => window.addEventListener(evt, recordActivity, { passive: true }));

    const handleStorageSync = (e) => {
      if (e.key === 'recell_token' && !e.newValue) {
        handleLogout(false);
      }
      if (e.key === LAST_ACTIVITY_KEY && e.newValue) {
        setIdleSecondsLeft(null);
      }
    };
    window.addEventListener('storage', handleStorageSync);

    const interval = setInterval(() => {
      const lastActive = Number(localStorage.getItem(LAST_ACTIVITY_KEY) || Date.now());
      const elapsed = Date.now() - lastActive;
      const remaining = timeoutMs - elapsed;

      if (remaining <= 0) {
        handleLogout(true);
      } else if (remaining <= IDLE_WARNING_WINDOW_MS) {
        setIdleSecondsLeft(Math.max(1, Math.ceil(remaining / 1000)));
      } else {
        setIdleSecondsLeft((prev) => (prev !== null ? null : prev));
      }
    }, 1000);

    return () => {
      activityEvents.forEach((evt) => window.removeEventListener(evt, recordActivity));
      window.removeEventListener('storage', handleStorageSync);
      clearInterval(interval);
    };
  }, [currentUser, handleLogout]);

  const handleOrderCreated = (order) => {
    setTrackedSaleCode(order.sale_code);
    setActiveTab('track');
  };

  const handleAuthSuccess = (user) => {
    setSessionExpiredNotice(false);
    resetIdleTimer();
    setCurrentUser(user);
    const role = (user?.role || '').toUpperCase();
    // Strict automatic role-based redirection
    if (role === 'ADMIN' || role === 'SUPER_ADMIN') {
      setActiveTab('admin');
    } else if (role === 'COLLECTION_AGENT' || role === 'AGENT' || role === 'FIELD_AGENT') {
      setActiveTab('inspection');
    } else {
      setActiveTab('track');
    }
  };

  const sessionTimeoutModal = idleSecondsLeft !== null && currentUser && (
    <div className="fixed inset-0 z-[10000] flex items-center justify-center p-4 bg-slate-950/70 backdrop-blur-sm">
      <div className="bg-white rounded-2xl max-w-sm w-full p-5 shadow-2xl border border-amber-200 space-y-4">
        <div className="flex items-start gap-3">
          <div className="w-10 h-10 rounded-xl bg-amber-100 text-amber-700 flex items-center justify-center shrink-0">
            <Clock className="w-5 h-5" />
          </div>
          <div>
            <h3 className="font-black text-slate-900 text-sm">Session Expiring Due to Inactivity</h3>
            <p className="text-xs text-slate-600 mt-1">
              For your security, you will be automatically logged out in{' '}
              <strong className="text-rose-600 font-black">{idleSecondsLeft}s</strong>.
            </p>
          </div>
        </div>
        <div className="flex items-center justify-end gap-2">
          <button
            type="button"
            onClick={() => handleLogout(false)}
            className="px-3.5 py-2 rounded-xl border border-slate-200 text-slate-600 hover:bg-slate-50 text-xs font-bold transition"
          >
            Logout Now
          </button>
          <button
            type="button"
            onClick={resetIdleTimer}
            className="px-4 py-2 rounded-xl bg-[#0BAA4B] hover:bg-[#087C38] text-white text-xs font-extrabold shadow transition"
          >
            Stay Logged In
          </button>
        </div>
      </div>
    </div>
  );

  // Route security guard: enforce permissions
  const userRole = (currentUser?.role || '').toUpperCase();
  const canAccessAdmin = userRole === 'ADMIN' || userRole === 'SUPER_ADMIN';
  const canAccessAgent = canAccessAdmin || userRole === 'COLLECTION_AGENT' || userRole === 'AGENT' || userRole === 'FIELD_AGENT';

  if (activeTab === 'admin' && canAccessAdmin) {
    return (
      <div className="h-screen w-screen overflow-hidden bg-slate-50 antialiased">
        <AdminDashboard 
          currentUser={currentUser} 
          onNavigate={(tab) => setActiveTab(tab)} 
          onLogout={() => handleLogout(false)} 
        />
        {sessionTimeoutModal}
        {authModalOpen && (
          <AuthModal
            isOpen={authModalOpen}
            onClose={() => setAuthModalOpen(false)}
            onAuthSuccess={handleAuthSuccess}
          />
        )}
      </div>
    );
  }

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
        {activeTab === 'sell' && (
          <div>
            {currentUser && (
              /* Logged-in Customer/User Workspace Banner */
              <div className="max-w-6xl mx-auto px-3 sm:px-6 pt-4 pb-1">
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
                        Dolly Smart Buyback Engine · Instant Valuation & Doorstep Payout
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

            {/* Main Selling Portal with Top Visual Hero Carousel */}
            <SellWizard 
              onOrderCreated={handleOrderCreated}
              currentUser={currentUser}
              onOpenAuth={() => setAuthModalOpen(true)}
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

      {/* Session Timeout Warning Modal */}
      {sessionTimeoutModal}

      {/* Inactivity Logout Banner */}
      {sessionExpiredNotice && !currentUser && (
        <div className="fixed top-20 right-4 z-[9998] bg-amber-50 border border-amber-300 text-amber-900 px-4 py-2.5 rounded-xl shadow-lg text-xs font-bold flex items-center gap-2">
          <Clock className="w-4 h-4 text-amber-600 shrink-0" />
          <span>You were logged out due to inactivity.</span>
          <button
            type="button"
            onClick={() => setSessionExpiredNotice(false)}
            className="ml-2 text-amber-700 hover:text-amber-950 font-black"
          >
            ✕
          </button>
        </div>
      )}

      {/* Auth Modal with strict role redirection */}
      <AuthModal
        isOpen={authModalOpen}
        onClose={() => setAuthModalOpen(false)}
        onAuthSuccess={handleAuthSuccess}
      />

      {/* Global Server Unavailable / Contact Admin Modal */}
      <ServerUnavailableModal />

    </div>
  );
}
