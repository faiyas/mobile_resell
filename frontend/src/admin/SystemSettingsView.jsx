import React, { useState } from 'react';
import { 
  Settings, ShieldCheck, CheckCircle2, Clock, IndianRupee, 
  MapPin, Bell, Globe, Save, RefreshCw, Key, Shield, UserCheck
} from 'lucide-react';

export default function SystemSettingsView({ mode = 'settings' }) {
  const [activeTab, setActiveTab] = useState(mode); // 'settings' | 'roles'
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Settings form state
  const [form, setForm] = useState({
    minPayoutFloor: 500,
    doorstepFee: 0,
    inspectionWindowHours: 24,
    autoAssignAgents: true,
    whatsappAlerts: true,
    pincodesServed: '605001, 605002, 605003, 605004, 605005, 605006, 605007, 605008, 605009, 605010, 605014',
    payoutMethods: ['UPI_QR', 'IMPS_BANK', 'INSTANT_CASH'],
    supportPhone: '+91 99885 52211',
    companyName: 'Dolly Buyback Services Pvt Ltd'
  });

  const handleSave = (e) => {
    e.preventDefault();
    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 3000);
  };

  return (
    <div className="space-y-6 animate-fade-in p-2 sm:p-4 max-w-5xl">
      <div className="flex items-center justify-between">
        <div>
          <span className="text-[11px] font-black uppercase text-[#0BAA4B] tracking-wider">System Administration</span>
          <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight mt-0.5">
            {activeTab === 'settings' ? 'Operations & Buyback Settings' : 'Access Control & User Roles'}
          </h2>
          <p className="text-xs text-slate-500">
            {activeTab === 'settings'
              ? 'Configure doorstep inspection rules, payout floor thresholds, and operational service areas.'
              : 'Enterprise permission boundaries, field agent privilege scoping, and supervisor roles.'}
          </p>
        </div>

        <div className="bg-slate-100 p-1 rounded-2xl flex items-center gap-1 border border-slate-200">
          <button
            type="button"
            onClick={() => setActiveTab('settings')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition ${
              activeTab === 'settings' ? 'bg-[#0BAA4B] text-white shadow-xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Settings
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('roles')}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition ${
              activeTab === 'roles' ? 'bg-[#0BAA4B] text-white shadow-xs' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            User Roles
          </button>
        </div>
      </div>

      {saveSuccess && (
        <div className="p-3 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold flex items-center gap-2 animate-fade-in">
          <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>System configuration successfully updated and synced across all nodes!</span>
        </div>
      )}

      {activeTab === 'settings' ? (
        <form onSubmit={handleSave} className="space-y-5">
          
          {/* Card 1: Valuation & Pricing Safeguards */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-extrabold text-sm border-b border-slate-100 pb-3">
              <IndianRupee className="w-4 h-4 text-[#0BAA4B]" />
              <h3>Pricing & Payout Safeguards</h3>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Guaranteed Minimum Payout Floor (₹)
                </label>
                <input
                  type="number"
                  value={form.minPayoutFloor}
                  onChange={(e) => setForm({ ...form, minPayoutFloor: Number(e.target.value) })}
                  className="w-full p-2.5 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold font-mono focus:bg-white focus:border-[#0BAA4B] outline-none"
                />
                <span className="text-[10px] text-slate-400 mt-1 block">
                  Prevents valuation deductions from driving salvage devices below this base floor.
                </span>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">
                  Doorstep Pickup Convenience Fee (₹)
                </label>
                <input
                  type="number"
                  value={form.doorstepFee}
                  onChange={(e) => setForm({ ...form, doorstepFee: Number(e.target.value) })}
                  className="w-full p-2.5 bg-slate-50 border border-slate-300 rounded-xl text-xs font-bold font-mono focus:bg-white focus:border-[#0BAA4B] outline-none"
                />
                <span className="text-[10px] text-slate-400 mt-1 block">
                  Set to 0 for 100% Free Doorstep Pickup promotion.
                </span>
              </div>
            </div>
          </div>

          {/* Card 2: Service Coverage & Logistics */}
          <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
            <div className="flex items-center gap-2 text-slate-900 font-extrabold text-sm border-b border-slate-100 pb-3">
              <MapPin className="w-4 h-4 text-emerald-600" />
              <h3>Logistics & Service Pincodes</h3>
            </div>

            <div>
              <label className="block text-xs font-bold text-slate-700 mb-1">
                Active Operational Pincodes (Comma-separated)
              </label>
              <textarea
                rows={3}
                value={form.pincodesServed}
                onChange={(e) => setForm({ ...form, pincodesServed: e.target.value })}
                className="w-full p-2.5 bg-slate-50 border border-slate-300 rounded-xl text-xs font-mono font-medium focus:bg-white focus:border-[#0BAA4B] outline-none"
              />
              <span className="text-[10px] text-slate-400 mt-1 block">
                Doorstep pickup scheduling checks these pincodes during customer address submission.
              </span>
            </div>

            <div className="flex items-center gap-2 pt-2">
              <input
                type="checkbox"
                id="autoAssignAgents"
                checked={form.autoAssignAgents}
                onChange={(e) => setForm({ ...form, autoAssignAgents: e.target.checked })}
                className="w-4 h-4 accent-[#0BAA4B] rounded"
              />
              <label htmlFor="autoAssignAgents" className="text-xs font-bold text-slate-700">
                Auto-assign pickup requests to nearest available field agent in zone
              </label>
            </div>
          </div>

          <div className="flex justify-end">
            <button
              type="submit"
              className="bg-[#0BAA4B] hover:bg-[#087C38] text-white text-xs font-bold px-6 py-2.5 rounded-xl shadow-md transition flex items-center gap-2"
            >
              <Save className="w-4 h-4" />
              <span>Save System Settings</span>
            </button>
          </div>
        </form>
      ) : (
        <div className="bg-white rounded-2xl p-5 border border-slate-200 shadow-xs space-y-4">
          <div className="flex items-center gap-2 text-slate-900 font-extrabold text-sm border-b border-slate-100 pb-3">
            <Shield className="w-4 h-4 text-emerald-600" />
            <h3>Role-Based Access Control (RBAC) Matrix</h3>
          </div>

          <div className="divide-y divide-slate-100 text-xs">
            <div className="py-3 flex items-start justify-between gap-4">
              <div>
                <span className="font-extrabold text-slate-900 flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500" />
                  SUPER_ADMIN / ADMIN
                </span>
                <p className="text-slate-500 text-[11px] mt-0.5">
                  Full unrestricted platform authority: Catalogue management, pricing rules, agent creation, customer deletion, and payout clearance.
                </p>
              </div>
              <span className="text-[10px] font-bold bg-amber-50 text-amber-800 border border-amber-200 px-2 py-0.5 rounded-full uppercase shrink-0">
                All Permissions
              </span>
            </div>

            <div className="py-3 flex items-start justify-between gap-4">
              <div>
                <span className="font-extrabold text-slate-900 flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500" />
                  COLLECTION_AGENT (FIELD AGENT)
                </span>
                <p className="text-slate-500 text-[11px] mt-0.5">
                  Doorstep mobile app and web portal: View assigned pickups, perform physical hardware evaluation, input IMEI, and issue handover receipt.
                </p>
              </div>
              <span className="text-[10px] font-bold bg-emerald-50 text-emerald-800 border border-emerald-200 px-2 py-0.5 rounded-full uppercase shrink-0">
                Inspection Only
              </span>
            </div>

            <div className="py-3 flex items-start justify-between gap-4">
              <div>
                <span className="font-extrabold text-slate-900 flex items-center gap-1.5">
                  <span className="w-2.5 h-2.5 rounded-full bg-blue-500" />
                  CUSTOMER
                </span>
                <p className="text-slate-500 text-[11px] mt-0.5">
                  Device valuation calculator, pickup booking, doorstep tracking timeline, and order status dashboard.
                </p>
              </div>
              <span className="text-[10px] font-bold bg-blue-50 text-blue-800 border border-blue-200 px-2 py-0.5 rounded-full uppercase shrink-0">
                End User
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
