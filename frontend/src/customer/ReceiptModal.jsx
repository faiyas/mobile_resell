import React from 'react';
import { createPortal } from 'react-dom';
import { X, Printer, ShieldCheck, CheckCircle2, Smartphone, Download, ExternalLink } from 'lucide-react';

export default function ReceiptModal({ receiptData, onClose }) {
  if (!receiptData) return null;

  const handlePrint = () => {
    window.print();
  };

  return createPortal(
    <div className="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-slate-950/75 backdrop-blur-md animate-fade-in">
      <div className="bg-white rounded-2xl max-w-2xl w-full shadow-2xl overflow-hidden border border-slate-200 max-h-[92vh] flex flex-col">
        
        {/* Modal Top Bar */}
        <div className="bg-slate-900 text-white px-6 py-4 flex items-center justify-between print:hidden">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
            <h3 className="font-bold text-sm">Official Handover & Payment Voucher</h3>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold flex items-center gap-1.5 transition"
            >
              <Printer className="w-4 h-4" /> Print / Save PDF
            </button>
            <button
              onClick={onClose}
              className="p-1 rounded-lg text-slate-400 hover:text-white transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Printable Receipt Body */}
        <div className="p-4 sm:p-8 overflow-y-auto space-y-5 sm:space-y-6 text-slate-800 text-sm print:p-0">
          
          {/* Header */}
          <div className="flex flex-col sm:flex-row justify-between sm:items-start gap-3 border-b border-slate-200 pb-4 sm:pb-5">
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xl sm:text-2xl font-black tracking-tight text-slate-900">ReCell</span>
                <span className="text-[10px] font-bold bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded">VERIFIED BUYBACK</span>
              </div>
              <p className="text-[11px] sm:text-xs text-slate-500 mt-1">ReCell Buyback Services India Pvt. Ltd.</p>
              <p className="text-[11px] sm:text-xs text-slate-500">GSTIN: 29AAAAA0000A1Z5 · Bengaluru, KA</p>
            </div>
            <div className="text-left sm:text-right bg-slate-50 sm:bg-transparent p-2.5 sm:p-0 rounded-lg">
              <span className="text-[10px] sm:text-xs font-bold text-slate-400 uppercase">Receipt No.</span>
              <p className="font-mono font-bold text-slate-900 text-xs sm:text-sm">{receiptData.receipt_number}</p>
              <span className="text-[10px] sm:text-xs text-slate-400 block mt-0.5">Date & Time:</span>
              <p className="text-[11px] sm:text-xs font-medium text-slate-700">{receiptData.date}</p>
            </div>
          </div>

          {/* Status Stamp */}
          <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-3.5 sm:p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            <div>
              <span className="text-[10px] sm:text-xs font-bold uppercase tracking-wider text-emerald-800">Payment Status</span>
              <h4 className="text-base sm:text-lg font-black text-emerald-700 mt-0.5">COMPLETED & VERIFIED (PAID)</h4>
              <p className="text-[11px] sm:text-xs text-emerald-900 mt-0.5">
                Bank / UPI Reference (UTR): <strong className="font-mono text-emerald-800">{receiptData.utr_number}</strong>
              </p>
            </div>
            <div className="text-left sm:text-right border-t sm:border-t-0 pt-2 sm:pt-0 border-emerald-200">
              <span className="text-[10px] sm:text-xs text-slate-500 block">Total Payout Disbursed:</span>
              <span className="text-xl sm:text-2xl font-extrabold text-emerald-700">
                ₹{Number(receiptData.payout_amount).toLocaleString('en-IN')}
              </span>
            </div>
          </div>

          {/* Details Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4 text-xs">
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 space-y-1.5">
              <span className="font-bold text-slate-400 uppercase">Seller / Customer</span>
              <p className="font-bold text-slate-900 text-sm">{receiptData.customer_name}</p>
              <p className="text-slate-600">Phone: {receiptData.customer_phone}</p>
              <p className="text-slate-600">Sale Order ID: {receiptData.sale_code}</p>
            </div>

            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 space-y-1.5">
              <span className="font-bold text-slate-400 uppercase">Handed-Over Device</span>
              <p className="font-bold text-slate-900 text-sm">{receiptData.device} ({receiptData.storage})</p>
              <p className="text-slate-600">Verified IMEI: <strong className="font-mono">{receiptData.imei}</strong></p>
              <p className="text-slate-600">Payment Method: {receiptData.payment_method}</p>
            </div>
          </div>

          {/* Beneficiary Details */}
          <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 text-xs">
            <span className="font-bold text-slate-400 uppercase block mb-1">Beneficiary Account Disbursed To:</span>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <span className="text-slate-500">Beneficiary Name:</span>{' '}
                <strong className="text-slate-800">{receiptData.beneficiary?.name}</strong>
              </div>
              {receiptData.beneficiary?.upi_id ? (
                <div>
                  <span className="text-slate-500">UPI ID:</span>{' '}
                  <strong className="text-slate-800 font-mono">{receiptData.beneficiary.upi_id}</strong>
                </div>
              ) : (
                <div>
                  <span className="text-slate-500">Bank A/C:</span>{' '}
                  <strong className="text-slate-800 font-mono">{receiptData.beneficiary?.account_no} ({receiptData.beneficiary?.ifsc})</strong>
                </div>
              )}
            </div>
          </div>

          {/* Base64 Payment Proof Screenshot Preview */}
          {receiptData.payment_proof_base64 && (
            <div className="border border-slate-200 rounded-xl p-4 bg-white">
              <span className="text-xs font-bold text-slate-700 block mb-2">
                📸 Uploaded Bank / UPI Payment Confirmation Proof (Base64 Stored):
              </span>
              <div className="max-h-60 overflow-hidden rounded-lg bg-slate-950 flex items-center justify-center p-2 border border-slate-300">
                <img 
                  src={receiptData.payment_proof_base64} 
                  alt="Payment Proof" 
                  className="max-h-56 max-w-full object-contain"
                />
              </div>
            </div>
          )}

          {/* Legal Handover statement */}
          <div className="text-[11px] text-slate-500 border-t border-slate-200 pt-3 space-y-1">
            <p className="font-semibold text-slate-700">Legal Ownership Transfer Declaration:</p>
            <p>
              The seller hereby confirms full legal ownership of the device described above, confirms that the device is free from financial liens, lost/stolen reports, and iCloud/Google locks, and transfers ownership to ReCell Buyback Services upon receipt of payment. Authorized data wipe procedure commenced.
            </p>
          </div>

        </div>

      </div>
    </div>,
    document.body
  );
}
