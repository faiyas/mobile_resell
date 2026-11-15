import React from 'react';
import { ShieldCheck, Truck, Banknote, RefreshCw, Smartphone, Award, Lock } from 'lucide-react';

export default function Footer() {
  return (
    <footer className="bg-slate-900 text-slate-400 mt-20 border-t border-slate-800">
      {/* Value props banner */}
      <div className="border-b border-slate-800 py-10 bg-slate-950/40">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid grid-cols-1 md:grid-cols-4 gap-8 text-center md:text-left">
            
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
            <span className="font-bold text-white text-sm">ReCell Buyback Platform</span>
            <span className="text-slate-500">· Strictly One-Way Buyback (No Retail Purchasing)</span>
          </div>

          <p className="text-slate-500 text-center">
            © 2026 ReCell Mobile Buyback Ltd. All rights reserved. Registered under Indian IT & Electronic Waste Guidelines.
          </p>

          <div className="flex gap-4">
            <span className="text-slate-400 hover:text-white cursor-pointer">Terms & Conditions</span>
            <span className="text-slate-400 hover:text-white cursor-pointer">Privacy & Data Wiping Policy</span>
            <span className="text-slate-400 hover:text-white cursor-pointer">IMEI Verification Notice</span>
          </div>
        </div>
      </div>
    </footer>
  );
}
