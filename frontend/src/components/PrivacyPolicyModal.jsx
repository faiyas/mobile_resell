import React, { useState, useEffect } from 'react';
import { Shield, X, CheckCircle2, Lock, ExternalLink } from 'lucide-react';
import { api } from '../services/api';

export default function PrivacyPolicyModal({ isOpen, onClose }) {
  const [settings, setSettings] = useState(null);

  useEffect(() => {
    if (isOpen) {
      api.getBusinessSettings()
        .then(data => setSettings(data))
        .catch(() => {});
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const email = settings?.support_email || 'support@dollyresell.com';
  const company = settings?.company_name || '1103 TechStudios · Dolly Platform';
  const policyUrl = settings?.privacy_policy_url || '';
  const termsUrl = settings?.terms_url || '';
  const websiteUrl = settings?.website_url || '';

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
          {(policyUrl || termsUrl || websiteUrl) && (
            <div className="flex flex-wrap gap-2 pb-2 border-b border-slate-100">
              {policyUrl && (
                <a
                  href={policyUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 font-bold text-xs border border-emerald-200 transition"
                >
                  <span>Full Privacy Policy</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
              {termsUrl && (
                <a
                  href={termsUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-xs border border-slate-200 transition"
                >
                  <span>Terms &amp; Conditions</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
              {websiteUrl && (
                <a
                  href={websiteUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold text-xs border border-slate-200 transition"
                >
                  <span>Visit Website</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>
              )}
            </div>
          )}
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
              Under global privacy frameworks and Apple/Google store guidelines, you maintain the right to delete your customer profile and personal records at any time directly through the mobile app profile page or by contacting support at {email}.
            </p>
          </section>

          <section className="pt-2 border-t border-slate-100 text-xs text-slate-500">
            <p>
              Dolly is an authorized gadget buyback technology platform operated by {company}. For legal inquiries: {email}.
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
