import React, { useState } from 'react';
import { X, Lock, Mail, User, Phone, ShieldCheck, ArrowRight, Check, UserCheck } from 'lucide-react';
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
        res = await api.register({ email, password, full_name: fullName, phone, role });
      } else {
        res = await api.login({ email, password });
      }

      setAuthToken(res.token);
      setCurrentUser(res.user);
      onAuthSuccess(res.user);
      onClose();
    } catch (err) {
      setError(err.message || 'Authentication failed');
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
      setError(err.message || 'Quick login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-slate-900/70 backdrop-blur-sm animate-fade-in overflow-y-auto">
      <div className="bg-white rounded-3xl max-w-md w-full shadow-2xl overflow-hidden border border-slate-200 my-auto max-h-[92vh] flex flex-col">
        
        {/* Header (Sticky) */}
        <div className="bg-slate-900 px-5 sm:px-6 py-4 sm:py-5 text-white flex items-center justify-between shrink-0">
          <div>
            <h3 className="font-extrabold text-base sm:text-lg">{isRegister ? 'Create Account' : 'Welcome to ReCell'}</h3>
            <p className="text-[11px] sm:text-xs text-slate-400 mt-0.5">
              {isRegister ? 'Register to sell phones and track payouts' : 'Login to Customer, Admin or Agent Portal'}
            </p>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Quick Demo 1-Click Logins */}
        <div className="bg-slate-50 border-b border-slate-200 p-3 sm:p-4 shrink-0">
          <p className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-2">⚡ Quick 1-Click Role Logins:</p>
          <div className="grid grid-cols-3 gap-1.5 sm:gap-2">
            <button
              type="button"
              onClick={() => handleQuickLogin('admin@buyback.in', 'admin123')}
              className="px-2 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white text-[11px] font-bold shadow-sm transition flex flex-col items-center justify-center text-center"
            >
              <ShieldCheck className="w-3.5 h-3.5 mb-0.5" />
              <span>Admin</span>
            </button>
            <button
              type="button"
              onClick={() => handleQuickLogin('agent@buyback.in', 'agent123')}
              className="px-2 py-2 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-[11px] font-bold shadow-sm transition flex flex-col items-center justify-center text-center"
            >
              <UserCheck className="w-3.5 h-3.5 mb-0.5" />
              <span>Agent</span>
            </button>
            <button
              type="button"
              onClick={() => handleQuickLogin('customer@example.com', 'customer123')}
              className="px-2 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-[11px] font-bold shadow-sm transition flex flex-col items-center justify-center text-center"
            >
              <User className="w-3.5 h-3.5 mb-0.5" />
              <span>Customer</span>
            </button>
          </div>
        </div>

        {/* Form Body (Scrollable if height exceeds screen) */}
        <form onSubmit={handleSubmit} className="p-4 sm:p-6 overflow-y-auto space-y-3 sm:space-y-4">
          {error && (
            <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold">
              {error}
            </div>
          )}

          {isRegister && (
            <>
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Full Name</label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="text"
                    required
                    autoComplete="name"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder="e.g. Ramesh Patel"
                    className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Mobile Number</label>
                <div className="relative">
                  <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="tel"
                    required
                    autoComplete="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="10-digit mobile number"
                    className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Account Role</label>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="CUSTOMER">Customer (Selling Device)</option>
                  <option value="COLLECTION_AGENT">Collection Agent (Field Team)</option>
                  <option value="ADMIN">Company Administrator</option>
                </select>
              </div>
            </>
          )}

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Email Address</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@domain.com"
                className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 mb-1">Password</label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
              <input
                type="password"
                required
                autoComplete={isRegister ? "new-password" : "current-password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-9 pr-3 py-2 border border-slate-300 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-emerald-500"
              />
            </div>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-slate-900 hover:bg-black text-white font-bold py-3 rounded-xl shadow-md transition flex items-center justify-center gap-2 mt-2"
          >
            {loading ? 'Authenticating...' : isRegister ? 'Create Account' : 'Sign In'}
            <ArrowRight className="w-4 h-4" />
          </button>

          <div className="text-center pt-2">
            <button
              type="button"
              onClick={() => { setIsRegister(!isRegister); setError(''); }}
              className="text-xs font-semibold text-emerald-600 hover:text-emerald-700 transition"
            >
              {isRegister ? 'Already have an account? Sign in here' : "Don't have an account? Register as Customer"}
            </button>
          </div>
        </form>

      </div>
    </div>
  );
}
