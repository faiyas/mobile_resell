import React, { useState, useEffect } from 'react';
import { 
  Smartphone, ShieldCheck, Camera, Check, AlertCircle, 
  MapPin, Clock, ArrowRight, UserCheck, Lock, Upload, CheckCircle2 
} from 'lucide-react';
import { api } from '../services/api';
import { fileToBase64 } from '../utils/imageCompressor';

export default function AgentInspectionView({ currentUser }) {
  const [assignedSales, setAssignedSales] = useState([]);
  const [selectedSale, setSelectedSale] = useState(null);
  const [loading, setLoading] = useState(false);

  // Inspection form
  const [switchesOn, setSwitchesOn] = useState(true);
  const [screenWorking, setScreenWorking] = useState(true);
  const [screenGlassBroken, setScreenGlassBroken] = useState(false);
  const [touchWorking, setTouchWorking] = useState(true);
  const [cameraWorking, setCameraWorking] = useState(true);
  const [batteryHealthy, setBatteryHealthy] = useState(true);
  const [bodyCondition, setBodyCondition] = useState('GOOD');
  
  // Security locks & IMEI
  const [cloudLocksRemoved, setCloudLocksRemoved] = useState(true);
  const [verifiedImei, setVerifiedImei] = useState('');
  const [customerIdVerified, setCustomerIdVerified] = useState(true);

  // Photos (Base64)
  const [photos, setPhotos] = useState([]);
  const [suggestedFinalPrice, setSuggestedFinalPrice] = useState('');
  const [inspectorNotes, setInspectorNotes] = useState('');

  const [submitting, setSubmitting] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');

  useEffect(() => {
    loadAssignedSales();
  }, []);

  const loadAssignedSales = async () => {
    setLoading(true);
    try {
      const data = await api.getSales();
      setAssignedSales(data);
      if (data.length > 0 && !selectedSale) {
        selectOrderForInspection(data[0]);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const selectOrderForInspection = (sale) => {
    setSelectedSale(sale);
    setSuggestedFinalPrice(sale.final_price || sale.estimated_price);
    setVerifiedImei(sale.imei_number || '');
    setSuccessMsg('');
  };

  const handlePhotoUpload = async (e, label) => {
    const file = e.target.files[0];
    if (!file) return;

    try {
      const base64 = await fileToBase64(file, 1000, 0.7);
      setPhotos([...photos, { label, image_base64: base64 }]);
    } catch (err) {
      alert("Failed to process photo: " + err.message);
    }
  };

  const handleSubmitInspection = async (e) => {
    e.preventDefault();
    if (!selectedSale) return;

    if (!cloudLocksRemoved) {
      alert("CRITICAL: iCloud / Google FRP Account must be removed by the customer before taking possession!");
      return;
    }

    if (!verifiedImei.trim() || verifiedImei.length < 8) {
      alert("Please enter the verified device IMEI number (dial *#06# on phone).");
      return;
    }

    setSubmitting(true);
    try {
      const payload = {
        sale_id: selectedSale.id,
        switches_on: switchesOn,
        screen_working: screenWorking,
        screen_glass_broken: screenGlassBroken,
        touch_working: touchWorking,
        camera_working: cameraWorking,
        battery_healthy: batteryHealthy,
        body_condition: bodyCondition,
        cloud_locks_removed: cloudLocksRemoved,
        imei_verified: true,
        verified_imei: verifiedImei.trim(),
        customer_id_verified: customerIdVerified,
        suggested_final_price: suggestedFinalPrice,
        inspector_notes: inspectorNotes,
        photos: photos,
      };

      await api.recordInspection(payload);
      setSuccessMsg(`Inspection recorded for ${selectedSale.sale_code}! Final price set to ₹${Number(suggestedFinalPrice).toLocaleString('en-IN')}`);
      loadAssignedSales();
    } catch (err) {
      alert(err.message || 'Failed to submit inspection');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto px-4 py-8 space-y-6 animate-fade-in">
      
      {/* Top Banner */}
      <div className="bg-slate-900 text-white p-6 rounded-3xl shadow-xl flex items-center justify-between">
        <div>
          <span className="text-[11px] font-bold uppercase tracking-wider text-amber-400 bg-amber-500/10 border border-amber-500/20 px-2 py-0.5 rounded">
            Field Collection Agent Portal
          </span>
          <h2 className="text-xl sm:text-2xl font-black mt-1">
            Doorstep Device Inspection & Handover
          </h2>
          <p className="text-xs text-slate-400 mt-0.5">
            Logged in as: {currentUser?.full_name || 'Pickup Specialist'}
          </p>
        </div>
      </div>

      {successMsg && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-2xl text-xs font-bold flex items-center gap-2">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span>{successMsg}</span>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Left: Pickup Queue */}
        <div className="space-y-3">
          <h4 className="font-extrabold text-slate-900 text-sm">Assigned Pickups:</h4>
          
          <div className="space-y-2">
            {assignedSales.map((s) => (
              <div
                key={s.id}
                onClick={() => selectOrderForInspection(s)}
                className={`cursor-pointer p-3.5 rounded-2xl border transition ${
                  selectedSale?.id === s.id
                    ? 'bg-amber-50 border-amber-500 shadow-sm ring-2 ring-amber-500/20'
                    : 'bg-white border-slate-200 hover:border-slate-300'
                }`}
              >
                <div className="flex justify-between items-start">
                  <span className="font-mono text-[10px] font-bold bg-slate-100 text-slate-800 px-1.5 py-0.5 rounded">
                    {s.sale_code}
                  </span>
                  <span className="text-[10px] font-bold text-emerald-700">
                    Est: ₹{Number(s.estimated_price).toLocaleString('en-IN')}
                  </span>
                </div>
                <h5 className="font-bold text-slate-900 text-xs mt-1.5">
                  {s.brand_name} {s.model_name}
                </h5>
                <p className="text-[11px] text-slate-500 mt-0.5 truncate">{s.customer_name} · {s.pickup_city}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Right: Active Inspection Checklist */}
        {selectedSale ? (
          <form onSubmit={handleSubmitInspection} className="md:col-span-2 bg-white border border-slate-200 rounded-3xl p-6 shadow-sm space-y-6 text-xs">
            
            <div className="flex justify-between items-start border-b border-slate-100 pb-4">
              <div>
                <span className="text-[10px] font-bold text-slate-400 uppercase">Inspecting Order</span>
                <h3 className="text-lg font-black text-slate-900">
                  {selectedSale.brand_name} {selectedSale.model_name} ({selectedSale.variant_details?.storage})
                </h3>
                <p className="text-slate-500 text-xs mt-0.5">
                  Customer: {selectedSale.customer_name} ({selectedSale.customer_phone})
                </p>
              </div>
              <div className="text-right">
                <span className="text-[10px] text-slate-400 uppercase block">Indicative Offer</span>
                <span className="text-xl font-black text-slate-700">
                  ₹{Number(selectedSale.estimated_price).toLocaleString('en-IN')}
                </span>
              </div>
            </div>

            {/* Hardware Checklist */}
            <div className="space-y-3">
              <h4 className="font-extrabold text-slate-900 text-xs flex items-center gap-1.5">
                <Smartphone className="w-4 h-4 text-emerald-600" /> 1. Functional Verification
              </h4>

              <div className="grid grid-cols-2 gap-2">
                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={switchesOn}
                    onChange={(e) => setSwitchesOn(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span className="font-bold text-slate-800">Phone powers on</span>
                </label>

                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={screenWorking}
                    onChange={(e) => setScreenWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span className="font-bold text-slate-800">Display (No lines/spots)</span>
                </label>

                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={touchWorking}
                    onChange={(e) => setTouchWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span className="font-bold text-slate-800">Touch responsiveness OK</span>
                </label>

                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={cameraWorking}
                    onChange={(e) => setCameraWorking(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span className="font-bold text-slate-800">Camera & Sensors OK</span>
                </label>

                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={batteryHealthy}
                    onChange={(e) => setBatteryHealthy(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span className="font-bold text-slate-800">Battery healthy (&gt;80%)</span>
                </label>

                <label className="flex items-center gap-2 p-2.5 rounded-xl border border-slate-200 bg-slate-50 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={screenGlassBroken}
                    onChange={(e) => setScreenGlassBroken(e.target.checked)}
                    className="w-4 h-4 text-rose-600 rounded"
                  />
                  <span className="font-bold text-rose-800">Screen Glass Broken?</span>
                </label>
              </div>
            </div>

            {/* Body Condition */}
            <div>
              <label className="block font-bold text-slate-700 mb-1">Body & Frame Cosmetic Grade</label>
              <select
                value={bodyCondition}
                onChange={(e) => setBodyCondition(e.target.value)}
                className="w-full p-2.5 border border-slate-300 rounded-xl"
              >
                <option value="FLAWLESS">Flawless (No scratches, Like New)</option>
                <option value="GOOD">Good (Light micro-scratches)</option>
                <option value="FAIR">Fair (Visible scuffs / small dents)</option>
                <option value="HEAVY_WEAR">Heavy Wear (Cracked back or bent frame)</option>
              </select>
            </div>

            {/* Security & Ownership Check */}
            <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4 space-y-3">
              <h4 className="font-extrabold text-amber-900 flex items-center gap-1.5">
                <Lock className="w-4 h-4 text-amber-700" /> 2. Security & IMEI Verification (Mandatory)
              </h4>

              <div className="space-y-2">
                <label className="flex items-center gap-2 font-bold text-amber-950 cursor-pointer">
                  <input
                    type="checkbox"
                    required
                    checked={cloudLocksRemoved}
                    onChange={(e) => setCloudLocksRemoved(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span>Apple iCloud / Google FRP Account has been removed & factory reset</span>
                </label>

                <label className="flex items-center gap-2 font-bold text-amber-950 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={customerIdVerified}
                    onChange={(e) => setCustomerIdVerified(e.target.checked)}
                    className="w-4 h-4 text-emerald-600 rounded"
                  />
                  <span>Seller Aadhaar / Govt ID verified</span>
                </label>
              </div>

              <div>
                <label className="block font-bold text-amber-950 mb-1">Verified IMEI Number (Dial *#06#) *</label>
                <input
                  type="text"
                  required
                  value={verifiedImei}
                  onChange={(e) => setVerifiedImei(e.target.value)}
                  placeholder="15-digit IMEI number"
                  className="w-full p-2 border border-amber-300 rounded-xl font-mono uppercase bg-white text-xs"
                />
              </div>
            </div>

            {/* Base64 Device Photo Evidence */}
            <div className="space-y-2">
              <span className="font-bold text-slate-800 flex items-center gap-1.5">
                <Camera className="w-4 h-4 text-emerald-600" />
                3. Device Condition Photographs (Base64 Stored)
              </span>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                {['Front Screen', 'Back Body', 'Defect Close-up'].map((label, idx) => (
                  <label key={idx} className="border-2 border-dashed border-slate-300 rounded-xl p-3 text-center cursor-pointer hover:border-emerald-500 bg-slate-50 transition block">
                    <input
                      type="file"
                      accept="image/*"
                      capture="environment"
                      onChange={(e) => handlePhotoUpload(e, label)}
                      className="hidden"
                    />
                    <Upload className="w-4 h-4 text-slate-400 mx-auto mb-1" />
                    <span className="text-[11px] font-bold text-slate-700 block">{label}</span>
                    <span className="text-[9px] text-slate-400">Tap to snap</span>
                  </label>
                ))}
              </div>

              {photos.length > 0 && (
                <div className="flex gap-2 pt-2 overflow-x-auto">
                  {photos.map((p, i) => (
                    <div key={i} className="w-16 h-16 rounded-lg border border-slate-200 overflow-hidden shrink-0 relative bg-black">
                      <img src={p.image_base64} alt={p.label} className="w-full h-full object-cover" />
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Final Offer Calculation */}
            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 space-y-3">
              <div className="flex items-center justify-between">
                <label className="font-extrabold text-slate-900">
                  Recommended Final Buyback Price (₹) *
                </label>
                <span className="text-[10px] text-slate-500">Subject to customer acceptance</span>
              </div>

              <input
                type="number"
                step="100"
                required
                value={suggestedFinalPrice}
                onChange={(e) => setSuggestedFinalPrice(e.target.value)}
                className="w-full p-3 border border-slate-300 rounded-xl text-xl font-black text-emerald-600 bg-white"
              />

              <input
                type="text"
                value={inspectorNotes}
                onChange={(e) => setInspectorNotes(e.target.value)}
                placeholder="Inspection notes for customer (e.g. Minor scratches observed on frame, -₹500 applied)"
                className="w-full p-2.5 border border-slate-300 rounded-xl text-xs bg-white"
              />
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="w-full bg-slate-900 hover:bg-black text-white font-extrabold py-3.5 rounded-2xl shadow transition flex items-center justify-center gap-2 text-sm"
            >
              {submitting ? 'Submitting Inspection...' : 'Confirm Inspection & Submit Final Offer'}
              <ArrowRight className="w-4 h-4" />
            </button>

          </form>
        ) : (
          <div className="md:col-span-2 bg-white rounded-3xl border border-slate-200 p-12 text-center text-slate-400">
            Select a pickup order from the queue to start device inspection.
          </div>
        )}

      </div>

    </div>
  );
}
