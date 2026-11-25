import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X, Lock, Mail, User, Phone, ShieldCheck, ArrowRight, Check, KeyRound, PhoneCall, AlertTriangle, RefreshCw } from 'lucide-react';
import { api, setAuthToken, setCurrentUser } from '../services/api';

export default function AuthModal({ isOpen, onClose, onAuthSuccess }) {
  if (!isOpen) return null;

  // Modes: 'LOGIN', 'REGISTER', 'FORGOT_PASSWORD'
  const [mode, setMode] = useState('LOGIN');
  const [emailOrPhone, setEmailOrPhone] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [otpCode, setOtpCode] = useState('');
  const [newPassword, setNewPassword] = useState('');

  // OTP state
  const [otpSent, setOtpSent] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  // Fallback to Admin
  const [fallbackToAdmin, setFallbackToAdmin] = useState(false);
  const [adminPhone, setAdminPhone] = useState('9025232453');

  useEffect(() => {
    let timer;
    if (countdown > 0) {
      timer = setTimeout(() => setCountdown(countdown - 1), 1000);
    }
    return () => clearTimeout(timer);
  }, [countdown]);

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setFallbackToAdmin(false);

    try {
      const res = await api.login({ email: emailOrPhone.trim(), password });
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

  const handleSendRegisterOtp = async (e) => {
    e.preventDefault();
    if (!fullName.trim()) return setError('Please enter your full name');
    const cleanPh = phone.replace(/\D/g, '').slice(-10);
    if (cleanPh.length !== 10) return setError('Please enter a valid 10-digit mobile number');
    if (!password || password.length < 6) return setError('Password must be at least 6 characters');

    setLoading(true);
    setError('');
    setFallbackToAdmin(false);

    try {
      const res = await api.sendCustomerOtp({ phone: cleanPh, purpose: 'REGISTRATION' });
      if (res.success) {
        setOtpSent(true);
        setCountdown(60);
      } else {
        setError(res.message || 'Unable to send OTP');
        if (res.fallback_to_admin) {
          setFallbackToAdmin(true);
          setAdminPhone(res.admin_phone || '9025232453');
        }
      }
    } catch (err) {
      setError(err.message || 'Unable to send verification code');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyRegister = async (e) => {
    e.preventDefault();
    if (!otpCode || otpCode.trim().length < 4) return setError('Please enter the 6-digit code');

    setLoading(true);
    setError('');

    try {
      const cleanPh = phone.replace(/\D/g, '').slice(-10);
      const res = await api.verifyRegisterCustomer({
        full_name: fullName.trim(),
        phone: cleanPh,
        password: password,
        otp_code: otpCode.trim()
      });
      setAuthToken(res.token);
      setCurrentUser(res.user);
      onAuthSuccess(res.user);
      onClose();
    } catch (err) {
      setError(err.message || 'Registration failed');
    } finally {
      setLoading(false);
    }
  };

  const handleSendForgotOtp = async (e) => {
    e.preventDefault();
    const cleanPh = phone.replace(/\D/g, '').slice(-10);
    if (cleanPh.length !== 10) return setError('Please enter your registered 10-digit mobile number');

    setLoading(true);
    setError('');
    setFallbackToAdmin(false);

    try {
      const res = await api.sendCustomerOtp({ phone: cleanPh, purpose: 'PASSWORD_RESET' });
      if (res.success) {
        setOtpSent(true);
        setCountdown(60);
      } else {
        setError(res.message || 'Unable to send reset code');
        if (res.fallback_to_admin) {
          setFallbackToAdmin(true);
          setAdminPhone(res.admin_phone || '9025232453');
        }
      }
    } catch (err) {
      setError(err.message || 'Unable to send reset code');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyResetPassword = async (e) => {
    e.preventDefault();
    if (!otpCode || otpCode.trim().length < 4) return setError('Please enter the 6-digit code');
    if (!newPassword || newPassword.length < 6) return setError('New password must be at least 6 characters');

    setLoading(true);
    setError('');

    try {
      const cleanPh = phone.replace(/\D/g, '').slice(-10);
      const res = await api.resetCustomerPassword({
        phone: cleanPh,
        otp_code: otpCode.trim(),
        new_password: newPassword
      });
      setAuthToken(res.token);
      setCurrentUser(res.user);
      onAuthSuccess(res.user);
      onClose();
    } catch (err) {
      setError(err.message || 'Password reset failed');
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
        className="glass-panel rounded-t-3xl sm:rounded-3xl max-w-md w-full shadow-2xl overflow-hidden border border-white/80 max-h-[92vh] sm:max-h-[88vh] flex flex-col animate-slide-up sm:animate-zoom-in"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Mobile drag handle */}
        <div className="sm:hidden pt-3 pb-1 flex justify-center bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B]">
          <div className="w-12 h-1.5 bg-white/30 rounded-full" />
        </div>

        {/* Header */}
        <div className="bg-gradient-to-r from-[#0D4722] via-[#087C38] to-[#0BAA4B] px-5 sm:px-6 py-4 sm:py-5 text-white flex items-center justify-between shrink-0 border-b border-white/20">
          <div>
            <div className="flex items-center gap-1.5 mb-1">
              <img src="/dolly_icon.png" alt="Dolly" className="w-7 h-7 rounded-lg object-contain shadow-sm border border-white/40" />
              <span className="text-[11px] font-black uppercase tracking-wider text-emerald-200">DOLLY BUYBACK</span>
            </div>
            <h3 className="font-black text-base sm:text-lg">
              {mode === 'REGISTER'
                ? (otpSent ? 'Verify Mobile OTP' : 'Create Customer Account')
                : mode === 'FORGOT_PASSWORD'
                  ? (otpSent ? 'Enter Reset Code' : 'Reset Password')
                  : 'Welcome to Dolly'}
            </h3>
            <p className="text-[11px] sm:text-xs text-[#E8F8ED] mt-0.5">
              {mode === 'REGISTER'
                ? 'Instant doorstep payouts with verified account'
                : mode === 'FORGOT_PASSWORD'
                  ? 'Reset password via SMS verification'
                  : 'Sign in with your mobile number and password'}
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
        <div className="p-4 sm:p-6 overflow-y-auto space-y-3 sm:space-y-4">
          {error && (
            <div className="p-3 rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-bold animate-shake">
              {error}
            </div>
          )}

          {/* Fallback to Admin Card if SMS Delivery Failed */}
          {fallbackToAdmin && (
            <div className="p-4 rounded-2xl bg-amber-50 border-2 border-amber-300 space-y-2 text-xs">
              <div className="flex items-center gap-2 text-amber-900 font-extrabold text-sm">
                <AlertTriangle className="w-4 h-4 text-amber-600 shrink-0" />
                SMS Delivery Unavailable
              </div>
              <p className="text-amber-800 leading-relaxed font-medium">
                Don't worry! Our admin desk can immediately verify and create your account directly over the phone without any OTP.
              </p>
              <a
                href={`tel:+91${adminPhone}`}
                className="w-full mt-2 inline-flex items-center justify-center gap-2 bg-[#0BAA4B] hover:bg-[#087C38] text-white py-2.5 px-4 rounded-xl font-bold transition shadow-md"
              >
                <PhoneCall className="w-4 h-4" />
                Call Admin Desk (+91 {adminPhone})
              </a>
            </div>
          )}

          {/* ================= MODE 1: LOGIN ================= */}
          {mode === 'LOGIN' && (
            <form onSubmit={handleLogin} className="space-y-3 sm:space-y-4">
              <div>
                <label className="block text-xs font-extrabold text-[#17251C] mb-1">Mobile Number or Email *</label>
                <div className="relative">
                  <Phone className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="text"
                    required
                    autoComplete="username"
                    value={emailOrPhone}
                    onChange={(e) => setEmailOrPhone(e.target.value)}
                    placeholder="10-digit mobile number or email"
                    className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                  />
                </div>
              </div>

              <div>
                <div className="flex justify-between items-center mb-1">
                  <label className="block text-xs font-extrabold text-[#17251C]">Password *</label>
                  <button
                    type="button"
                    onClick={() => { setMode('FORGOT_PASSWORD'); setOtpSent(false); setError(''); setFallbackToAdmin(false); }}
                    className="text-[11px] font-bold text-[#0BAA4B] hover:underline"
                  >
                    Forgot Password?
                  </button>
                </div>
                <div className="relative">
                  <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                  <input
                    type="password"
                    required
                    autoComplete="current-password"
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
                className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg shadow-[#0BAA4B]/20 transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm"
              >
                {loading ? 'Signing in...' : 'Sign In to Account'}
                <ArrowRight className="w-4 h-4" />
              </button>

              <div className="text-center pt-2">
                <button
                  type="button"
                  onClick={() => { setMode('REGISTER'); setOtpSent(false); setError(''); setFallbackToAdmin(false); }}
                  className="text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] transition"
                >
                  New to Dolly? Create Verified Account
                </button>
              </div>
            </form>
          )}

          {/* ================= MODE 2: REGISTER WITH OTP ================= */}
          {mode === 'REGISTER' && (
            <form onSubmit={!otpSent ? handleSendRegisterOtp : handleVerifyRegister} className="space-y-3 sm:space-y-4">
              {!otpSent ? (
                <>
                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1">Full Name *</label>
                    <div className="relative">
                      <User className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                      <input
                        type="text"
                        required
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
                      <span className="text-xs font-bold text-slate-400 absolute left-3 top-3">+91</span>
                      <input
                        type="tel"
                        required
                        maxLength={10}
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                        placeholder="10-digit number"
                        className="w-full pl-11 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1">Set Password (min 6 characters) *</label>
                    <div className="relative">
                      <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                      <input
                        type="password"
                        required
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
                    className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm"
                  >
                    {loading ? 'Sending code...' : 'Send Verification OTP'}
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </>
              ) : (
                <>
                  <div className="text-center py-2">
                    <p className="text-xs text-slate-600">Enter the 6-digit code sent to</p>
                    <p className="font-extrabold text-sm text-[#17251C] font-mono">+91 {phone}</p>
                  </div>

                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1 text-center">6-Digit Verification Code</label>
                    <input
                      type="text"
                      required
                      maxLength={6}
                      value={otpCode}
                      onChange={(e) => setOtpCode(e.target.value)}
                      placeholder="123456"
                      className="w-full py-3 border-2 border-emerald-500 rounded-xl text-center text-xl font-mono font-black tracking-widest focus:outline-none focus:ring-2 focus:ring-[#0BAA4B] bg-emerald-50/50"
                    />
                  </div>

                  <div className="flex justify-between items-center text-xs">
                    <span className="text-slate-500">
                      {countdown > 0 ? `Resend in ${countdown}s` : "Didn't receive SMS?"}
                    </span>
                    <button
                      type="button"
                      disabled={countdown > 0 || loading}
                      onClick={handleSendRegisterOtp}
                      className="font-bold text-[#0BAA4B] hover:underline disabled:opacity-40"
                    >
                      Resend Code
                    </button>
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm"
                  >
                    {loading ? 'Verifying...' : 'Verify & Complete Registration'}
                    <Check className="w-4 h-4" />
                  </button>
                </>
              )}

              <div className="text-center pt-2">
                <button
                  type="button"
                  onClick={() => { setMode('LOGIN'); setOtpSent(false); setError(''); setFallbackToAdmin(false); }}
                  className="text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] transition"
                >
                  Already registered? Sign In with Password
                </button>
              </div>
            </form>
          )}

          {/* ================= MODE 3: FORGOT PASSWORD ================= */}
          {mode === 'FORGOT_PASSWORD' && (
            <form onSubmit={!otpSent ? handleSendForgotOtp : handleVerifyResetPassword} className="space-y-3 sm:space-y-4">
              {!otpSent ? (
                <>
                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1">Registered Mobile Number *</label>
                    <div className="relative">
                      <span className="text-xs font-bold text-slate-400 absolute left-3 top-3">+91</span>
                      <input
                        type="tel"
                        required
                        maxLength={10}
                        value={phone}
                        onChange={(e) => setPhone(e.target.value)}
                        placeholder="10-digit number"
                        className="w-full pl-11 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm"
                  >
                    {loading ? 'Sending code...' : 'Send Password Reset Code'}
                    <ArrowRight className="w-4 h-4" />
                  </button>
                </>
              ) : (
                <>
                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1 text-center">6-Digit Verification Code</label>
                    <input
                      type="text"
                      required
                      maxLength={6}
                      value={otpCode}
                      onChange={(e) => setOtpCode(e.target.value)}
                      placeholder="123456"
                      className="w-full py-3 border-2 border-emerald-500 rounded-xl text-center text-xl font-mono font-black tracking-widest focus:outline-none focus:ring-2 focus:ring-[#0BAA4B] bg-emerald-50/50"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-extrabold text-[#17251C] mb-1">New Password (min 6 characters) *</label>
                    <div className="relative">
                      <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                      <input
                        type="password"
                        required
                        value={newPassword}
                        onChange={(e) => setNewPassword(e.target.value)}
                        placeholder="••••••••"
                        className="w-full pl-9 pr-3 py-2.5 border border-[#E7EEE9] rounded-xl text-xs sm:text-sm focus:outline-none focus:ring-2 focus:ring-[#0BAA4B]"
                      />
                    </div>
                  </div>

                  <button
                    type="submit"
                    disabled={loading}
                    className="w-full bg-gradient-to-r from-[#087C38] to-[#0BAA4B] hover:brightness-105 text-white font-black py-3 rounded-2xl shadow-lg transition flex items-center justify-center gap-2 mt-2 text-xs sm:text-sm"
                  >
                    {loading ? 'Updating password...' : 'Save New Password & Sign In'}
                    <Check className="w-4 h-4" />
                  </button>
                </>
              )}

              <div className="text-center pt-2">
                <button
                  type="button"
                  onClick={() => { setMode('LOGIN'); setOtpSent(false); setError(''); setFallbackToAdmin(false); }}
                  className="text-xs font-bold text-[#0BAA4B] hover:text-[#087C38] transition"
                >
                  Remember password? Back to Sign In
                </button>
              </div>
            </form>
          )}

        </div>
      </div>
    </div>,
    document.body
  );
}
