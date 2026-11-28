import React, { useState, useEffect } from 'react';
import { WifiOff, RefreshCw, Phone, MessageCircle, Mail, X, ArrowRight } from 'lucide-react';
import { api } from '../services/api';

export default function ServerUnavailableModal() {
  const [open, setOpen] = useState(false);
  const [contextInfo, setContextInfo] = useState({ endpoint: '', method: 'GET' });
  const [retrying, setRetrying] = useState(false);
  const [retryFailed, setRetryFailed] = useState(false);
  const [biz, setBiz] = useState(() => {
    try {
      const raw = localStorage.getItem('dolly_cached_business_settings');
      return raw ? JSON.parse(raw) : {};
    } catch {
      return {};
    }
  });

  useEffect(() => {
    const handler = (e) => {
      setContextInfo(e.detail || { endpoint: '', method: 'GET' });
      setRetryFailed(false);
      setOpen(true);
      try {
        const raw = localStorage.getItem('dolly_cached_business_settings');
        if (raw) setBiz(JSON.parse(raw));
      } catch {}
    };
    window.addEventListener('dolly-server-unavailable', handler);
    return () => window.removeEventListener('dolly-server-unavailable', handler);
  }, []);

  if (!open) return null;

  const helpline = biz?.customer_helpline || '+91 99885 52211';
  const whatsappRaw = (biz?.whatsapp_number || helpline).replace(/\D/g, '');
  const whatsappNum = whatsappRaw.length === 10 ? `91${whatsappRaw}` : whatsappRaw;
  const email = biz?.support_email || 'support@dollyresell.com';
  const company = biz?.company_name || 'Dolly Support';

  const isOrder = (contextInfo.endpoint || '').includes('/sales');
  const isAuth = (contextInfo.endpoint || '').includes('/auth');

  const waMessage = encodeURIComponent(
    isOrder
      ? `Hi ${company}, I tried placing a buyback order on the website, but the server is temporarily unavailable. Please help me complete my pickup request.`
      : isAuth
      ? `Hi ${company}, I'm unable to sign in/register right now as the server appears offline. Please assist.`
      : `Hi ${company}, the website server is temporarily unavailable. Please assist.`
  );

  const handleRetry = async () => {
    setRetrying(true);
    setRetryFailed(false);
    try {
      const res = await api.pingHealth();
      if (res && res.status === 'healthy') {
        setOpen(false);
        return;
      }
      setRetryFailed(true);
    } catch {
      setRetryFailed(true);
    } finally {
      setRetrying(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fadeIn">
      <div className="bg-white rounded-3xl max-w-md w-full overflow-hidden shadow-2xl border border-slate-200">
        <div className="p-6 bg-gradient-to-br from-[#082F1D] to-[#0BAA4B] text-white relative">
          <button
            onClick={() => setOpen(false)}
            className="absolute top-4 right-4 p-1.5 rounded-full bg-white/15 hover:bg-white/25 text-white transition"
            aria-label="Close"
          >
            <X className="w-4 h-4" />
          </button>
          <div className="w-12 h-12 rounded-2xl bg-white/20 flex items-center justify-center mb-3">
            <WifiOff className="w-6 h-6 text-white" />
          </div>
          <h2 className="text-xl font-black tracking-tight">We&apos;ll be back shortly</h2>
          <p className="text-xs text-emerald-100 mt-1 leading-relaxed">
            Our live services are temporarily unavailable. Your selections are safe — you can retry in a moment or contact our admin team directly.
          </p>
        </div>

        <div className="p-5 space-y-4">
          {retryFailed && (
            <div className="p-2.5 rounded-xl bg-amber-50 border border-amber-200 text-amber-800 text-xs font-bold text-center">
              Server is still waking up. Please try again in a few seconds or reach us below.
            </div>
          )}

          <div className="grid grid-cols-2 gap-2.5">
            <button
              onClick={handleRetry}
              disabled={retrying}
              className="w-full py-2.5 px-3 bg-[#0BAA4B] hover:bg-[#087C38] disabled:opacity-60 text-white rounded-xl font-extrabold text-xs flex items-center justify-center gap-1.5 shadow-sm transition"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${retrying ? 'animate-spin' : ''}`} />
              <span>{retrying ? 'Checking...' : 'Try Again'}</span>
            </button>
            <button
              onClick={() => setOpen(false)}
              className="w-full py-2.5 px-3 bg-slate-100 hover:bg-slate-200 text-slate-800 rounded-xl font-extrabold text-xs flex items-center justify-center gap-1.5 transition"
            >
              <span>Continue Browsing</span>
              <ArrowRight className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="border-t border-slate-100 pt-3">
            <p className="text-[11px] font-black uppercase tracking-wider text-slate-400 mb-2">
              Contact Admin Directly
            </p>
            <div className="space-y-2">
              <a
                href={`https://wa.me/${whatsappNum}?text=${waMessage}`}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full py-2.5 px-3.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 border border-emerald-200 text-emerald-900 font-bold text-xs flex items-center justify-between transition"
              >
                <span className="flex items-center gap-2">
                  <MessageCircle className="w-4 h-4 text-emerald-600" />
                  <span>WhatsApp Admin ({biz?.whatsapp_number || helpline})</span>
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-emerald-600" />
              </a>
              <a
                href={`tel:${helpline.replace(/\s+/g, '')}`}
                className="w-full py-2.5 px-3.5 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-800 font-bold text-xs flex items-center justify-between transition"
              >
                <span className="flex items-center gap-2">
                  <Phone className="w-4 h-4 text-slate-600" />
                  <span>Call Helpline ({helpline})</span>
                </span>
                <ArrowRight className="w-3.5 h-3.5 text-slate-500" />
              </a>
              <a
                href={`mailto:${email}`}
                className="w-full py-2 px-3.5 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 font-semibold text-xs flex items-center gap-2 transition"
              >
                <Mail className="w-3.5 h-3.5 text-slate-500" />
                <span>{email}</span>
              </a>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
