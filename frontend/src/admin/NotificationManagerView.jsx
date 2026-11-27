import React, { useState, useEffect } from 'react';
import { 
  Bell, Send, Users, ShieldAlert, Sparkles, RefreshCw, 
  Trash2, CheckCircle2, Clock, Megaphone 
} from 'lucide-react';
import { api } from '../services/api';

export default function NotificationManagerView() {
  const [notifications, setNotifications] = useState([]);
  const [loading, setLoading] = useState(false);
  const [sending, setSending] = useState(false);
  const [statusMsg, setStatusMsg] = useState({ type: '', text: '' });

  const [form, setForm] = useState({
    title: '',
    message: '',
    category: 'SYSTEM',
    target_audience: 'ALL',
    redirect_route: '',
  });

  useEffect(() => {
    loadNotifications();
  }, []);

  const loadNotifications = async () => {
    setLoading(true);
    try {
      const res = await api.getNotifications();
      if (res && Array.isArray(res.results)) {
        setNotifications(res.results);
      } else if (Array.isArray(res)) {
        setNotifications(res);
      }
    } catch (e) {
      console.warn(e);
    } finally {
      setLoading(false);
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!form.title.trim() || !form.message.trim()) {
      setStatusMsg({ type: 'error', text: 'Title and Message are required.' });
      return;
    }

    setSending(true);
    setStatusMsg({ type: '', text: '' });
    try {
      await api.broadcastNotification(form);
      setStatusMsg({ type: 'success', text: 'Broadcast notification dispatched successfully!' });
      setForm({
        title: '',
        message: '',
        category: 'SYSTEM',
        target_audience: 'ALL',
        redirect_route: '',
      });
      loadNotifications();
    } catch (err) {
      setStatusMsg({ type: 'error', text: err.message || 'Failed to dispatch broadcast alert.' });
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-6 animate-fade-in p-2 sm:p-4 max-w-5xl">
      <div>
        <span className="text-[11px] font-black uppercase text-[#0BAA4B] tracking-wider">Communication & Alerts</span>
        <h2 className="text-2xl sm:text-3xl font-black text-slate-900 tracking-tight mt-0.5">
          Push Notification Desk
        </h2>
        <p className="text-xs text-slate-500">
          Broadcast instant milestone alerts, promotional updates, and operational notices to mobile apps and website customers.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 1-Col: Broadcast Form */}
        <div className="lg:col-span-1 bg-white rounded-3xl p-5 border border-slate-200 shadow-xs space-y-4">
          <div className="flex items-center gap-2 border-b border-slate-100 pb-3">
            <Send className="w-4 h-4 text-[#0BAA4B]" />
            <h3 className="font-extrabold text-sm text-slate-900">Compose Broadcast</h3>
          </div>

          <form onSubmit={handleSubmit} className="space-y-3 text-xs">
            <div>
              <label className="block font-bold text-slate-700 mb-1">Target Audience</label>
              <select
                value={form.target_audience}
                onChange={(e) => setForm({ ...form, target_audience: e.target.value })}
                className="w-full p-2.5 rounded-xl border border-slate-300 bg-white font-bold"
              >
                <option value="ALL">🌐 All Users (Public Broadcast)</option>
                <option value="CUSTOMERS">👤 Customers Only</option>
                <option value="AGENTS">🛵 Field Pickup Agents Only</option>
              </select>
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Alert Category</label>
              <select
                value={form.category}
                onChange={(e) => setForm({ ...form, category: e.target.value })}
                className="w-full p-2.5 rounded-xl border border-slate-300 bg-white font-bold"
              >
                <option value="SYSTEM">✨ System & Announcement</option>
                <option value="ORDERS">📦 Order Milestone</option>
                <option value="PAYOUTS">💰 Payout Alert</option>
              </select>
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Alert Title</label>
              <input
                type="text"
                placeholder="e.g. Exclusive Weekend Buyback Bonus!"
                value={form.title}
                onChange={(e) => setForm({ ...form, title: e.target.value })}
                className="w-full p-2.5 rounded-xl border border-slate-300 font-bold"
                required
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Message Body</label>
              <textarea
                rows={3}
                placeholder="Get an extra ₹500 on all iPhone models booked before Sunday midnight..."
                value={form.message}
                onChange={(e) => setForm({ ...form, message: e.target.value })}
                className="w-full p-2.5 rounded-xl border border-slate-300 font-medium"
                required
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Target Route / URL (Optional)</label>
              <input
                type="text"
                placeholder="e.g. /sell or /track"
                value={form.redirect_route}
                onChange={(e) => setForm({ ...form, redirect_route: e.target.value })}
                className="w-full p-2.5 rounded-xl border border-slate-300 font-mono text-[11px]"
              />
            </div>

            {statusMsg.text && (
              <div className={`p-2.5 rounded-xl text-xs font-bold ${
                statusMsg.type === 'success' ? 'bg-emerald-50 text-emerald-800 border border-emerald-200' : 'bg-rose-50 text-rose-800 border border-rose-200'
              }`}>
                {statusMsg.text}
              </div>
            )}

            <button
              type="submit"
              disabled={sending}
              className="w-full py-3 bg-[#0BAA4B] hover:bg-[#087C38] disabled:opacity-50 text-white font-black rounded-xl shadow-md transition flex items-center justify-center gap-2 mt-2"
            >
              {sending ? <RefreshCw className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              <span>{sending ? 'Broadcasting...' : 'Send Broadcast'}</span>
            </button>
          </form>
        </div>

        {/* Right 2-Cols: Notification Feed History */}
        <div className="lg:col-span-2 bg-white rounded-3xl p-5 border border-slate-200 shadow-xs space-y-4 flex flex-col">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-slate-500" />
              <h3 className="font-extrabold text-sm text-slate-900">Recent Notifications & Dispatches</h3>
            </div>
            <button
              onClick={loadNotifications}
              className="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 transition"
              title="Refresh"
            >
              <RefreshCw className="w-3.5 h-3.5" />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto space-y-2.5 max-h-[500px]">
            {loading ? (
              <div className="text-center py-16 text-slate-400 text-xs">Loading history...</div>
            ) : notifications.length === 0 ? (
              <div className="text-center py-16 text-slate-400 text-xs">No notifications sent yet.</div>
            ) : (
              notifications.map((n) => (
                <div key={n.id} className="p-3.5 rounded-2xl border border-slate-150 hover:bg-slate-50/70 transition flex items-start justify-between gap-3 text-xs">
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-black text-slate-900">{n.title}</span>
                      <span className="text-[10px] font-black px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 uppercase border border-slate-200">
                        {n.target_audience}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-600 leading-relaxed">{n.message}</p>
                    <div className="flex items-center gap-3 text-[10px] text-slate-400 pt-1">
                      <span>{new Date(n.created_at).toLocaleString('en-IN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
                      <span>·</span>
                      <span className="font-bold text-[#0BAA4B]">{n.category}</span>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
