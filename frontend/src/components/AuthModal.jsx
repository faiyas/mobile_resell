import React, { useState } from 'react';
import { X, Lock, Mail, User, Phone, ShieldCheck, ArrowRight, Check, UserCheck, Sparkles } from 'lucide-react';
import { api, setAuthToken, setCurrentUser } from '../services/api';

export default function AuthModal({ isOpen, onClose, onAuthSuccess }) {
  if (!isOpen) return null;

  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState('CUSTOMER');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      let res;
      if (isRegister) {
        res = await api.register({ email: email.trim(), password, full_name: fullName.trim(), phone: phone.trim(), role });
      } else {
        res = await api.login({ email: email.trim(), password });
      }

      setAuthToken(res.token);
      setCurrentUser(res.user);
      onAuthSuccess(res.user);
      onClose();
    } catch (err) {
      setError(err.message || 'Authentication failed. Please check credentials.');
    } finally {
      setLoading(false);
    }
  };

  const handleQuickLogin = async (quickEmail, quickPassword) => {
    setLoading(true);
    setError('');
    try {
      const res = await api.login({ email: quickEmail, password: quickPassword });
      setAuthToken(res.token);
      setCurrentUser(res.user);
      onAuthSuccess(res.user);
      onClose();
    } catch (err) {
      setError(err.message || 'Quick login failed. Verify test account.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/70 backdrop-blur-sm animate-fade-in overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-md w-full shadow-2xl overflow-hidden border border-[#E7EEE9] my-auto max-h-[92vh] flex flex-col">
        
        {/* Header (X-PHONES Green Gradient) */}
        <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] px-5 sm:px-6 py-4 sm:py-5 text-white flex items-center justify-between shrink-0">
          <div>
            <div className="flex items-center gap-1.5 mb-1">
              <span className="w-5 h-5 rounded-lg bg-white/20 backdrop-blur text-white flex items-center justify-center font-black text-xs">X</span>
              <span className="text-[11px] font-black uppercase tracking-wider text-emerald-200">X-PHONES BUYBACK</span>
            </div>
            <h3 className="font-black text-base sm:text-lg">{isRegister ? 'Create Your Account' : 'Welcome to X-PHONES'}</h3>
            <p className="text-[11px] sm:text-xs text-[#E8F8ED] mt-0.5">
              {isRegister ? 'Register to evaluate, sell devices & receive instant payouts' : 'Sign in to Customer, Admin or Field Agent workspace'}
            </p>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 rounded-xl text-white/80 hover:text-white hover:bg-white/10 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Quick Demo 1-Click Logins */}
        <div className="bg-[#F7FAF8] border-b border-[#E7EEE9] p-3 sm:p-4 shrink-0">
          <p className="text-[10px] font-extrabold text-[#7B8980] uppercase tracking-wider mb-2 flex items-center gap-1">
            <Sparkles className="w-3 h-3 text-[#0BAA4B]" />
            <span>1-Click Fast Role Sign-in:</span>
          </p>
          <div className="grid grid-cols-3 gap-2">
            <button
              type="button"
              onClick={() => handleQuickLogin('admin@buyback.in', 'admin123')}
              className="px-2 py-2 rounded-xl bg-slate-900 hover:bg-black text-white text-[11px] font-extrabold shadow-sm transition flex flex-col items-center justify-center text-center active:scale-95"
            >
              <ShieldCheck className="w-4 h-4 mb-0.5 text-emerald-400" />
              <span>Super Admin</span>
              <span className="text-[8px] text-slate-400 font-mono">admin@buyback.in</span>
            </button>
            <button
              type="button"
              onClick={() => handleQuickLogin('agent@buyback.in', 'agent123')}
              className="px-2 py-2 rounded-xl bg-[#087C38] hover:bg-[#0D4722] text-white text-[11px] font-extrabold shadow-sm transition flex flex-col items-center justify-center text-center active:scale-95"
            >
              <UserCheck className="w-4 h-4 mb-0.5 text-emerald-300" />
              <span>Pickup Agent</span>
              <span className="text-[8px] text-emerald-200 font-mono">agent@buyback.in</span>
            </button>
            <button
              type="button"
              onClick={() => handleQuickLogin('customer@example.com', 'customer123')}
              className="px-2 py-2 rounded-xl bg-[#0BAA4B] hover:bg-[#087C38] text-white text-[11px] font-extrabold shadow-sm transition flex flex-col items-center justify-center text-center active:scale-95"
            >
              <User className="w-4 h-4 mb-0.5 text-white" />
              <span>Customer</span>
              <span className="text-[8px] text-emerald-100 font-mono">customer@example.com</span>
            </button>
          </div>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="p-4 sm:p-6 overflow-y-auto space-y-3 sm:space-y-4">
          {error && (
            <div className="p-3 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-bold animate-shake">
              {error}
            </div>
          )}

          {isRegister && (
            <>
              <div>
                <label className="block text-xs font-extrabold text-[#17251C] mb-1">Full Name *</label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="text"
                    required
                    autoComplete="name"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="e.g. Ramesh Patel"
                    className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-extrabold text-[#17251C] mb-1">Mobile Number *</label>
                <div className="relative">
                  <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="tel"
                    required
                    autoComplete="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="10-digit mobile number"
                    className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-extrabold text-[#17251C] mb-1">Account Role *</label>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
                  className="w-full px-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B] bg-white font-bold"
                >
                  <option value="CUSTOMER">Customer (Sell Devices & Get Paid)</option>
                  <option value="COLLECTION_AGENT">Collection Agent (Field Team Inspection)</option>
                  <option value="ADMIN">Administrator (Full Desk Operations)</option>
                </select>
              </div>
            </>
          )}

          <div>
            <label className="block text-xs font-extrabold text-[#17251C] mb-1">Email Address *</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@domain.com"
                className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-extrabold text-[#17251C] mb-1">Password *</label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="password"
                required
                autoComplete={isRegister ? "new-password" : "current-password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm active:scale-98"
          >
            {loading ? (
              <span>Authenticating...</span>
            ) : isRegister ? (
              <>
                <span>Create X-PHONES Account</span>
                <ArrowRight className="w-4 h-4" />
              </>
            ) : (
              <>
                <span>Sign In to Account</span>
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>

          <div className="text-center pt-2">
            <button
              type="button"
              onClick={() => { setIsRegister(!isRegister); setError(''); }}
              className="text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] transition"
            >
              {isRegister ? 'Already have an account? Sign in here' : "New user? Create an account with role selection"}
            </button>
          </div>
        </form>

      </div>
    </div>
  );
}
