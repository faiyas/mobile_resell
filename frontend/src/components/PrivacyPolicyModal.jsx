import React from 'react';
import { Shield, X, CheckCircle2, Lock } from 'lucide-react';

export default function PrivacyPolicyModal({ isOpen, onClose }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-white rounded-3xl max-w-2xl w-full max-h-[85vh] overflow-hidden shadow-2xl flex flex-col">
        {/* Header */}
        <div className="p-6 bg-gradient-to-r from-emerald-600 to-teal-700 text-white flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-white/20 rounded-2xl backdrop-blur-md">
              <Shield className="w-6 h-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-black">Dolly Privacy Policy</h2>
              <p className="text-xs text-emerald-100">Last Updated: November 2026 · 1103 TechStudios</p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-white/80 hover:text-white hover:bg-white/10 rounded-full transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="p-6 overflow-y-auto space-y-5 text-sm text-slate-700 leading-relaxed">
          <section>
            <h3 className="font-bold text-slate-900 text-base mb-1.5 flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              1. Information We Collect
            </h3>
            <p>
              When you sell a gadget through the Dolly Platform, we collect basic contact information (full name, phone number, and physical doorstep pickup address) to dispatch our certified field evaluation specialists and execute secure instant buyback payouts.
            </p>
          </section>

          <section>
            <h3 className="font-bold text-slate-900 text-base mb-1.5 flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              2. Certified Device Data Wiping
            </h3>
            <p>
              Before any pre-owned device is processed, Dolly guarantees complete, irreversible data sanitization and factory resetting following ISO/IEC 27001 data protection standards. We never inspect or store private files, photos, or accounts from collected phones.
            </p>
          </section>

          <section>
            <h3 className="font-bold text-slate-900 text-base mb-1.5 flex items-center gap-2">
              <Lock className="w-4 h-4 text-emerald-600" />
              3. Data Security & Storage
            </h3>
            <p>
              Your personal records and inspection timestamps are transmitted over 256-bit TLS encrypted channels. We do not sell, rent, or trade your personal information with third-party advertising networks.
            </p>
          </section>

          <section>
            <h3 className="font-bold text-slate-900 text-base mb-1.5 flex items-center gap-2">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              4. Account & Data Deletion
            </h3>
            <p>
              Under global privacy frameworks and Apple/Google store guidelines, you maintain the right to delete your customer profile and personal records at any time directly through the mobile app profile page or by contacting support at support@dollyresell.com.
            </p>
          </section>

          <section className="pt-2 border-t border-slate-100 text-xs text-slate-500">
            <p>
              Dolly is an authorized gadget buyback technology platform operated by 1103 TechStudios. For legal inquiries: legal@1103techstudios.com.
            </p>
          </section>
        </div>

        {/* Footer */}
        <div className="p-4 bg-slate-50 border-t border-slate-100 flex justify-end">
          <button
            onClick={onClose}
            className="px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-sm shadow-md transition-all"
          >
            I Understand
          </button>
        </div>
      </div>
    </div>
  );
}
