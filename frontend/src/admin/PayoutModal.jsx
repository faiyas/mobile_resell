import React, { useState, useEffect } from 'react';
import { 
  X, QrCode, Upload, Copy, Check, AlertCircle, 
  ArrowRight, ShieldCheck, IndianRupee, Smartphone, FileImage 
} from 'lucide-react';
import QRCode from 'qrcode';
import { api } from '../services/api';
import { fileToBase64 } from '../utils/imageCompressor';

export default function PayoutModal({ sale, onClose, onPayoutSuccess }) {
  if (!sale) return null;

  const [qrCodeDataUrl, setQrCodeDataUrl] = useState('');
  const [copiedField, setCopiedField] = useState('');
  
  // Form fields
  const [amount, setAmount] = useState(sale.final_price || sale.estimated_price);
  const [paymentMethod, setPaymentMethod] = useState('GPAY');
  const [utrNumber, setUtrNumber] = useState('');
  const [proofBase64, setProofBase64] = useState('');
  const [adminNotes, setAdminNotes] = useState('');
  
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  // Generate dynamic UPI QR Code on mount
  useEffect(() => {
    async function generateQR() {
      try {
        const qrInfo = await api.getPaymentQR(sale.id);
        if (qrInfo.upi_uri) {
          const url = await QRCode.toDataURL(qrInfo.upi_uri, {
            width: 260,
            margin: 1,
            color: { dark: '#090d16', light: '#ffffff' }
          });
          setQrCodeDataUrl(url);
        }
      } catch (err) {
        console.error('Failed to generate UPI QR:', err);
      }
    }
    generateQR();
  }, [sale]);

  const copyToClipboard = (text, fieldName) => {
    navigator.clipboard.writeText(text);
    setCopiedField(fieldName);
    setTimeout(() => setCopiedField(''), 2000);
  };

  const handleFileChange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;

    try {
      // Compress and convert to Base64 in-browser
      const base64 = await fileToBase64(file, 1200, 0.75);
      setProofBase64(base64);
    } catch (err) {
      alert("Failed to process image: " + err.message);
    }
  };

  const handleRecordPayment = async (e) => {
    e.preventDefault();
    setErrorMsg('');

    if (!utrNumber.trim()) {
      setErrorMsg('Please enter the 12-digit UTR / Bank Reference number.');
      return;
    }

    if (!proofBase64) {
      setErrorMsg('Please upload the payment confirmation screenshot from your payment app.');
      return;
    }

    setLoading(true);
    try {
      const payload = {
        sale_id: sale.id,
        amount: amount,
        payment_method: paymentMethod,
        utr_number: utrNumber.trim(),
        payment_proof_base64: proofBase64,
        admin_notes: adminNotes,
      };

      const res = await api.recordPayout(payload);
      if (onPayoutSuccess) onPayoutSuccess(res);
      onClose();
    } catch (err) {
      setErrorMsg(err.message || 'Failed to record payment');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/70 backdrop-blur-sm animate-fade-in">
      <div className="bg-white rounded-3xl max-w-2xl w-full shadow-2xl overflow-hidden border border-slate-200 max-h-[94vh] flex flex-col">
        
        {/* Header */}
        <div className="bg-slate-900 text-white px-6 py-5 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center font-bold">
              <IndianRupee className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3 className="font-extrabold text-base">Authorize & Record Customer Payout</h3>
                <span className="font-mono text-xs bg-slate-800 text-slate-300 px-2 py-0.5 rounded">
                  {sale.sale_code}
                </span>
              </div>
              <p className="text-xs text-slate-400 mt-0.5">
                Pay customer via any UPI/Bank app, then upload proof & UTR to mark order as PAID
              </p>
            </div>
          </div>
          <button 
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable Content */}
        <form onSubmit={handleRecordPayment} className="p-6 overflow-y-auto space-y-6 text-xs">
          
          {errorMsg && (
            <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 font-semibold flex items-center gap-2">
              <AlertCircle className="w-4 h-4 text-rose-600 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* Section 1: Customer Beneficiary Info & Dynamic QR */}
          <div className="bg-slate-50 border border-slate-200 rounded-2xl p-5 space-y-4">
            <div className="flex items-center justify-between">
              <span className="font-extrabold text-slate-900 text-sm flex items-center gap-1.5">
                <Smartphone className="w-4 h-4 text-emerald-600" />
                Step 1: Pay Customer via UPI / Net Banking
              </span>
              <span className="text-xs font-bold text-slate-500">
                Device: {sale.brand_name} {sale.model_name}
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 items-center">
              
              {/* Beneficiary Details */}
              <div className="space-y-3">
                <div className="bg-white p-3 rounded-xl border border-slate-200">
                  <span className="text-[10px] text-slate-400 uppercase font-bold block">Approved Amount to Pay</span>
                  <div className="flex items-center justify-between mt-0.5">
                    <span className="text-2xl font-black text-emerald-600">
                      ₹{Number(amount).toLocaleString('en-IN')}
                    </span>
                    <button
                      type="button"
                      onClick={() => copyToClipboard(amount.toString(), 'amount')}
                      className="text-[11px] font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-2 py-1 rounded bg-slate-50"
                    >
                      {copiedField === 'amount' ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                      {copiedField === 'amount' ? 'Copied' : 'Copy'}
                    </button>
                  </div>
                </div>

                <div className="bg-white p-3 rounded-xl border border-slate-200 space-y-2">
                  <div className="flex justify-between items-center">
                    <div>
                      <span className="text-[10px] text-slate-400 uppercase font-bold block">Payee Name</span>
                      <strong className="text-slate-800 text-xs">{sale.beneficiary_name}</strong>
                    </div>
                  </div>

                  {sale.beneficiary_upi_id ? (
                    <div className="pt-2 border-t border-slate-100 flex items-center justify-between">
                      <div>
                        <span className="text-[10px] text-slate-400 uppercase font-bold block">UPI ID (VPA)</span>
                        <strong className="font-mono text-slate-900 text-xs">{sale.beneficiary_upi_id}</strong>
                      </div>
                      <button
                        type="button"
                        onClick={() => copyToClipboard(sale.beneficiary_upi_id, 'upi')}
                        className="text-[11px] font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-2 py-1 rounded bg-slate-50"
                      >
                        {copiedField === 'upi' ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                        {copiedField === 'upi' ? 'Copied' : 'Copy UPI'}
                      </button>
                    </div>
                  ) : (
                    <div className="pt-2 border-t border-slate-100 space-y-1">
                      <div className="flex justify-between items-center">
                        <div>
                          <span className="text-[10px] text-slate-400 uppercase font-bold block">Bank A/C Number</span>
                          <strong className="font-mono text-slate-900 text-xs">{sale.beneficiary_account_no}</strong>
                        </div>
                        <button
                          type="button"
                          onClick={() => copyToClipboard(sale.beneficiary_account_no, 'acct')}
                          className="text-[11px] font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-2 py-1 rounded bg-slate-50"
                        >
                          {copiedField === 'acct' ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                          Copy A/C
                        </button>
                      </div>
                      <div className="flex justify-between items-center">
                        <div>
                          <span className="text-[10px] text-slate-400 uppercase font-bold block">IFSC Code</span>
                          <strong className="font-mono text-slate-900 text-xs">{sale.beneficiary_ifsc}</strong>
                        </div>
                        <button
                          type="button"
                          onClick={() => copyToClipboard(sale.beneficiary_ifsc, 'ifsc')}
                          className="text-[11px] font-bold text-slate-600 hover:text-emerald-600 flex items-center gap-1 border border-slate-200 px-2 py-1 rounded bg-slate-50"
                        >
                          {copiedField === 'ifsc' ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                          Copy IFSC
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Dynamic Scan-to-Pay QR Code */}
              {qrCodeDataUrl ? (
                <div className="bg-white p-4 rounded-xl border border-slate-200 text-center flex flex-col items-center justify-center">
                  <span className="text-[11px] font-bold text-slate-700 flex items-center gap-1 mb-2">
                    <QrCode className="w-3.5 h-3.5 text-emerald-600" />
                    Scan with GPay / PhonePe on Phone:
                  </span>
                  <div className="p-2 bg-white rounded-lg border border-slate-200 shadow-sm">
                    <img src={qrCodeDataUrl} alt="UPI Payment QR Code" className="w-40 h-40 object-contain mx-auto" />
                  </div>
                  <span className="text-[10px] text-slate-400 mt-2 font-medium">
                    Pre-fills ₹{Number(amount).toLocaleString('en-IN')} & Customer UPI
                  </span>
                </div>
              ) : (
                <div className="bg-white p-6 rounded-xl border border-slate-200 text-center text-slate-400">
                  <p className="font-medium">Direct Bank Transfer required.</p>
                  <p className="text-[11px] mt-1">Copy A/C number & IFSC to your Net Banking portal.</p>
                </div>
              )}

            </div>
          </div>

          {/* Section 2: Upload Proof & UTR (Base64) */}
          <div className="bg-white border border-slate-200 rounded-2xl p-5 space-y-4 shadow-sm">
            <span className="font-extrabold text-slate-900 text-sm flex items-center gap-1.5">
              <Upload className="w-4 h-4 text-emerald-600" />
              Step 2: Upload Payment Proof & Record 12-Digit UTR
            </span>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Payment Method Used *</label>
                <select
                  value={paymentMethod}
                  onChange={(e) => setPaymentMethod(e.target.value)}
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
                >
                  <option value="GPAY">Google Pay (UPI)</option>
                  <option value="PHONEPE">PhonePe (UPI)</option>
                  <option value="PAYTM">Paytm UPI</option>
                  <option value="BHIM">BHIM UPI</option>
                  <option value="IMPS">Bank IMPS / NEFT Transfer</option>
                  <option value="CASH">Cash on Pickup</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  12-Digit UPI Ref / UTR Number *
                </label>
                <input
                  type="text"
                  required
                  value={utrNumber}
                  onChange={(e) => setUtrNumber(e.target.value)}
                  placeholder="e.g. 432109876543"
                  className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs font-mono uppercase focus:ring-2 focus:ring-emerald-500"
                />
                <span className="text-[10px] text-slate-400 mt-0.5 block">
                  Enforces uniqueness to prevent double payouts.
                </span>
              </div>
            </div>

            {/* Base64 Payment Screenshot Upload */}
            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">
                Upload Payment Screenshot (Converted to Base64) *
              </label>

              <div className="border-2 border-dashed border-slate-300 rounded-2xl p-4 text-center hover:border-emerald-500 transition cursor-pointer relative bg-slate-50">
                <input
                  type="file"
                  accept="image/*"
                  onChange={handleFileChange}
                  className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                />

                {proofBase64 ? (
                  <div className="flex flex-col items-center">
                    <img 
                      src={proofBase64} 
                      alt="Proof Preview" 
                      className="max-h-40 rounded-lg shadow-sm border border-slate-300 object-contain" 
                    />
                    <span className="text-emerald-700 font-bold text-xs mt-2 flex items-center gap-1">
                      <Check className="w-3.5 h-3.5" /> Screenshot loaded and converted to Base64 (Click to replace)
                    </span>
                  </div>
                ) : (
                  <div className="py-4 space-y-1">
                    <FileImage className="w-8 h-8 text-slate-400 mx-auto" />
                    <p className="font-bold text-slate-700">Click to upload GPay / PhonePe / Bank transfer receipt</p>
                    <p className="text-[11px] text-slate-400">PNG, JPG, or Screenshot · Automatically compressed & encoded to Base64</p>
                  </div>
                )}
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">Admin Notes (Optional)</label>
              <input
                type="text"
                value={adminNotes}
                onChange={(e) => setAdminNotes(e.target.value)}
                placeholder="e.g. Paid via company GPay account. Customer verified receipt."
                className="w-full px-3 py-2 border border-slate-300 rounded-xl text-xs focus:ring-2 focus:ring-emerald-500"
              />
            </div>
          </div>

          <div className="flex gap-3 pt-2">
            <button
              type="button"
              onClick={onClose}
              className="w-1/3 border border-slate-300 hover:bg-slate-50 font-bold py-3 rounded-xl text-slate-700 transition"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={loading}
              className="w-2/3 bg-emerald-600 hover:bg-emerald-700 text-white font-extrabold py-3 rounded-xl shadow-lg shadow-emerald-600/20 transition flex items-center justify-center gap-2"
            >
              {loading ? 'Recording Payout...' : 'Confirm Payment & Mark as PAID'}
              <ArrowRight className="w-4 h-4" />
            </button>
          </div>

        </form>

      </div>
    </div>
  );
}
