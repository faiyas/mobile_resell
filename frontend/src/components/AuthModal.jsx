import React, { useState } from 'react';
import { createPortal } from 'react-dom';
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
        res = await api.register({ email: email.trim(), password, full_name: fullName.trim(), phone: phone.trim(), role: 'CUSTOMER' });
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

  return createPortal(
    <div 
      className="fixed inset-0 z-[9999] flex items-end sm:items-center justify-center p-0 sm:p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in overflow-y-auto"
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div 
        className="glass-panel rounded-t-3xl sm:rounded-3xl max-w-md w-full shadow-2xl overflow-hidden border border-white/80 max-h-[90vh] sm:max-h-[85vh] flex flex-col animate-slide-up sm:animate-zoom-in"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Mobile drag handle */}
        <div className="sm:hidden pt-3 pb-1 flex justify-center bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B]">
          <div className="w-12 h-1.5 bg-white/30 rounded-full" />
        </div>

        {/* Header (Dolly Green Gradient) */}
        <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] px-5 sm:px-6 py-4 sm:py-5 text-white flex items-center justify-between shrink-0 border-b border-white/20">
          <div>
            <div className="flex items-center gap-1.5 mb-1">
              <span className="px-1.5 py-0.5 rounded-lg bg-white/20 backdrop-blur text-white flex items-center justify-center font-black text-xs border border-white/30">Dolly</span>
              <span className="text-[11px] font-black uppercase tracking-wider text-emerald-200">DOLLY BUYBACK</span>
            </div>
            <h3 className="font-black text-base sm:text-lg">{isRegister ? 'Create Your Account' : 'Welcome to Dolly'}</h3>
            <p className="text-[11px] sm:text-xs text-[#E8F8ED] mt-0.5">
              {isRegister ? 'Register to evaluate, sell devices & receive instant payouts' : 'Sign in to Customer, Admin or Field Agent workspace'}
            </p>
          </div>
          <button 
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 text-white flex items-center justify-center transition shrink-0"
          >
            <X className="w-4 h-4" />
          </button>
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
            </>
          )}

          <div>
            <label className="block text-xs font-extrabold text-[#17251C] mb-1">
              {isRegister ? 'Email Address *' : 'Mobile Number or Email *'}
            </label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="text"
                required
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={isRegister ? "your.email@domain.com" : "10-digit mobile (e.g. 9025232453) or email"}
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
                <span>Create Dolly Account</span>
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
    </div>,
    document.body
  );
}
