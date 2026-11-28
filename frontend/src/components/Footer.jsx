import React, { useState, useEffect } from 'react';
import { ShieldCheck, Truck, Banknote, RefreshCw, Smartphone, Award, Lock, Phone, Mail } from 'lucide-react';
import PrivacyPolicyModal from './PrivacyPolicyModal';
import { api } from '../services/api';

export default function Footer() {
  const [privacyOpen, setPrivacyOpen] = useState(false);
  const [biz, setBiz] = useState(() => {
    try {
      const raw = localStorage.getItem('dolly_cached_business_settings');
      return raw ? JSON.parse(raw) : {};
    } catch {
      return {};
    }
  });

  useEffect(() => {
    api.getBusinessSettings()
      .then((data) => {
        if (data && typeof data === 'object') {
          setBiz(data);
          try { localStorage.setItem('dolly_cached_business_settings', JSON.stringify(data)); } catch {}
        }
      })
      .catch(() => {});

    const onUpdate = (e) => {
      if (e?.detail) setBiz(e.detail);
    };
    window.addEventListener('dolly-biz-updated', onUpdate);
    return () => window.removeEventListener('dolly-biz-updated', onUpdate);
  }, []);

  const supportPhone = (biz?.customer_helpline || '+91 90252 32453').trim();
  const cleanTel = supportPhone.replace(/[^\d+]/g, '');
  const supportEmail = (biz?.support_email || 'support@dollyresell.com').trim();
  return (
    <footer className="bg-slate-900 text-slate-400 mt-12 sm:mt-20 border-t border-slate-800 pb-16 sm:pb-0">
      {/* Value props banner */}
      <div className="border-b border-slate-800 py-8 sm:py-10 bg-slate-950/40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-6 sm:gap-8 text-left">

            <div className="flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0">
                <Banknote className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-white font-bold text-sm">Instant UPI / Bank Payout</h4>
                <p className="text-xs text-slate-400 mt-1">Direct transfer to your GPay, PhonePe or Bank Account upon device verification.</p>
              </div>
            </div>

            <div className="flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-sky-500/10 border border-sky-500/20 text-sky-400 flex items-center justify-center shrink-0">
                <Truck className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-white font-bold text-sm">Free Doorstep Pickup</h4>
                <p className="text-xs text-slate-400 mt-1">Our verified field agent comes right to your home or office slot.</p>
              </div>
            </div>

            <div className="flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/20 text-purple-400 flex items-center justify-center shrink-0">
                <Lock className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-white font-bold text-sm">100% Data Protection</h4>
                <p className="text-xs text-slate-400 mt-1">Strict factory reset, military-grade wiping and signed legal bill of sale.</p>
              </div>
            </div>

            <div className="flex items-start gap-3.5">
              <div className="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-400 flex items-center justify-center shrink-0">
                <ShieldCheck className="w-5 h-5" />
              </div>
              <div>
                <h4 className="text-white font-bold text-sm">Zero Price Haggling</h4>
                <p className="text-xs text-slate-400 mt-1">Calculated fairly by our condition matrix. Customer can accept or reject anytime.</p>
              </div>
            </div>

          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 text-xs">
          <div className="flex items-center gap-2">
            <Smartphone className="w-4 h-4 text-emerald-400" />
            <span className="font-bold text-white text-sm">Dolly Buyback Platform</span>
            <span className="text-slate-500">· Strictly One-Way Buyback (No Retail Purchasing)</span>
          </div>

          <p className="text-slate-500 text-center">
            Copyrights reserved to 1103 TechStudios · Dolly Platform. Registered under Indian IT & Electronic Waste Guidelines.
          </p>

          <div className="flex flex-wrap items-center justify-center gap-4">
            <a href={`tel:${cleanTel}`} className="flex items-center gap-1.5 text-emerald-400 hover:text-emerald-300 font-semibold">
              <Phone className="w-3.5 h-3.5" />
              <span>{supportPhone}</span>
            </a>
            <a href={`mailto:${supportEmail}`} className="flex items-center gap-1.5 text-amber-400 hover:text-amber-300 font-semibold">
              <Mail className="w-3.5 h-3.5" />
              <span>{supportEmail}</span>
            </a>
            <span onClick={() => setPrivacyOpen(true)} className="text-slate-400 hover:text-white cursor-pointer">Terms & Conditions</span>
            <span onClick={() => setPrivacyOpen(true)} className="text-slate-400 hover:text-white cursor-pointer">Privacy & Data Wiping Policy</span>
            <span onClick={() => setPrivacyOpen(true)} className="text-slate-400 hover:text-white cursor-pointer">IMEI Verification Notice</span>
          </div>
        </div>
      </div>
      <PrivacyPolicyModal isOpen={privacyOpen} onClose={() => setPrivacyOpen(false)} />
    </footer>
  );
}
