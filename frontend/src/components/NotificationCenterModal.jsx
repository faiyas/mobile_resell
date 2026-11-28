import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { 
  Bell, X, CheckCircle2, Truck, Banknote, Sparkles, AlertCircle, 
  Trash2, ExternalLink, ChevronRight 
} from 'lucide-react';
import { api } from '../services/api';

export default function NotificationCenterModal({ isOpen, onClose, onSelectOrder, currentUser }) {
  const [notifications, setNotifications] = useState([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [activeTab, setActiveTab] = useState('ALL'); // 'ALL' | 'ORDERS' | 'PAYOUTS' | 'SYSTEM'

  useEffect(() => {
    if (isOpen) {
      loadNotifications();
    }
  }, [isOpen]);

  const STORAGE_KEY = 'dolly_web_notifications_v1';
  const DISMISSED_KEY = 'dolly_web_notifications_dismissed_v1';

  const getLocalNotifs = () => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      return raw ? JSON.parse(raw) : [];
    } catch {
      return [];
    }
  };

  const getDismissedIds = () => {
    try {
      const raw = localStorage.getItem(DISMISSED_KEY);
      return new Set(raw ? JSON.parse(raw) : []);
    } catch {
      return new Set();
    }
  };

  const saveLocalNotifs = (list) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(list.slice(0, 100)));
    } catch {}
  };

  const loadNotifications = async () => {
    const cached = getLocalNotifs();
    if (cached.length > 0) {
      setNotifications(cached);
      setUnreadCount(cached.filter(n => !n.is_read).length);
    }
    setLoading(cached.length === 0);
    try {
      const res = await api.getNotifications(currentUser?.phone || '');
      const incoming = res && Array.isArray(res.results) ? res.results : (Array.isArray(res) ? res : []);
      const dismissed = getDismissedIds();
      const ackIds = [];
      const synced = [];
      incoming.forEach(n => {
        if (dismissed.has(n.id)) return;
        ackIds.push(n.id);
        synced.push(n);
      });
      const merged = synced.sort(
        (a, b) => new Date(b.created_at || 0) - new Date(a.created_at || 0)
      );
      saveLocalNotifs(merged);
      setNotifications(merged);
      setUnreadCount(merged.filter(n => !n.is_read).length);
      if (ackIds.length > 0) {
        api.ackNotifications(ackIds);
      }
    } catch (e) {
      console.warn('Failed to load notifications:', e);
    } finally {
      setLoading(false);
    }
  };

  const handleMarkAsRead = async (id) => {
    const updated = notifications.map(n => n.id === id ? { ...n, is_read: true } : n);
    saveLocalNotifs(updated);
    setNotifications(updated);
    setUnreadCount(updated.filter(n => !n.is_read).length);
    api.markNotificationRead(id).catch(() => {});
  };

  const handleDismiss = async (id, e) => {
    e?.stopPropagation();
    const dismissed = getDismissedIds();
    dismissed.add(id);
    try { localStorage.setItem(DISMISSED_KEY, JSON.stringify(Array.from(dismissed).slice(-200))); } catch {}
    const updated = notifications.filter(n => n.id !== id);
    saveLocalNotifs(updated);
    setNotifications(updated);
    setUnreadCount(updated.filter(n => !n.is_read).length);
    api.dismissNotification(id).catch(() => {});
  };

  const handleMarkAllRead = async () => {
    const updated = notifications.map(n => ({ ...n, is_read: true }));
    saveLocalNotifs(updated);
    setNotifications(updated);
    setUnreadCount(0);
    api.markAllNotificationsRead().catch(() => {});
  };

  const handleClearAll = async () => {
    const dismissed = getDismissedIds();
    notifications.forEach(n => dismissed.add(n.id));
    try { localStorage.setItem(DISMISSED_KEY, JSON.stringify(Array.from(dismissed).slice(-200))); } catch {}
    saveLocalNotifs([]);
    setNotifications([]);
    setUnreadCount(0);
    api.clearAllNotifications().catch(() => {});
  };

  if (!isOpen) return null;

  const filtered = notifications.filter(n => {
    if (activeTab === 'ALL') return true;
    return n.category === activeTab;
  });

  return createPortal(
    <div className="fixed inset-0 z-[9999] flex justify-end bg-slate-900/50 backdrop-blur-xs animate-fade-in">
      <div 
        className="w-full sm:max-w-md bg-white h-full shadow-2xl flex flex-col justify-between overflow-hidden animate-slide-left"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-slate-150 flex items-center justify-between bg-slate-50/80">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-xl bg-[#E8F8ED] text-[#0BAA4B]">
              <Bell className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-extrabold text-base text-slate-900">Notifications</h3>
              <p className="text-[11px] text-[#0BAA4B] font-bold">
                {unreadCount > 0 ? `${unreadCount} unread alert${unreadCount > 1 ? 's' : ''}` : 'All caught up!'}
              </p>
            </div>
          </div>
          <div className="flex items-center gap-1.5">
            {notifications.length > 0 && (
              <>
                <button
                  type="button"
                  onClick={handleMarkAllRead}
                  className="text-[11px] font-bold text-slate-600 hover:text-[#0BAA4B] px-2 py-1 rounded-lg hover:bg-slate-200 transition"
                >
                  Mark Read
                </button>
                <button
                  type="button"
                  onClick={handleClearAll}
                  className="text-[11px] font-bold text-red-600 hover:text-red-700 px-2 py-1 rounded-lg hover:bg-red-50 transition flex items-center gap-1"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  Delete All
                </button>
              </>
            )}
            <button
              type="button"
              onClick={onClose}
              className="p-1.5 rounded-full hover:bg-slate-200 text-slate-400 hover:text-slate-700 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Filter Tabs */}
        <div className="flex items-center gap-1.5 px-4 py-2 border-b border-slate-100 bg-white overflow-x-auto text-xs">
          {[
            { id: 'ALL', label: `All (${notifications.length})` },
            { id: 'ORDERS', label: 'Orders' },
            { id: 'PAYOUTS', label: 'Payouts' },
            { id: 'SYSTEM', label: 'System' },
          ].map(t => (
            <button
              key={t.id}
              onClick={() => setActiveTab(t.id)}
              className={`px-3 py-1.5 rounded-xl font-bold whitespace-nowrap transition ${
                activeTab === t.id
                  ? 'bg-[#E8F8ED] text-[#087C38] border border-[#0BAA4B]/30'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Notification List */}
        <div className="p-4 flex-1 overflow-y-auto space-y-2.5">
          {loading ? (
            <div className="text-center py-16 text-slate-400 text-xs font-medium">
              Checking notifications...
            </div>
          ) : filtered.length === 0 ? (
            <div className="text-center py-16 space-y-3">
              <div className="w-12 h-12 rounded-2xl bg-slate-100 text-slate-400 flex items-center justify-center mx-auto">
                <Bell className="w-6 h-6" />
              </div>
              <p className="text-xs font-bold text-slate-500">No notifications in this section</p>
            </div>
          ) : (
            filtered.map((item) => {
              const isUnread = !item.is_read;
              let Icon = Bell;
              let iconColor = 'text-blue-600 bg-blue-50';

              if (item.category === 'ORDERS') {
                Icon = Truck;
                iconColor = 'text-blue-600 bg-blue-50';
              } else if (item.category === 'PAYOUTS') {
                Icon = Banknote;
                iconColor = 'text-emerald-600 bg-emerald-50';
              } else if (item.category === 'SYSTEM') {
                Icon = Sparkles;
                iconColor = 'text-purple-600 bg-purple-50';
              }

              return (
                <div
                  key={item.id}
                  onClick={() => {
                    handleMarkAsRead(item.id);
                    const orderCode = item.sale_code || (item.redirect_route?.includes('code=') ? item.redirect_route.split('code=')[1]?.split('&')[0] : null);
                    if (orderCode && onSelectOrder) {
                      onSelectOrder(orderCode);
                      onClose();
                    } else if (item.redirect_route) {
                      if (item.redirect_route.startsWith('http')) {
                        window.open(item.redirect_route, '_blank');
                      } else {
                        window.location.href = item.redirect_route;
                      }
                      onClose();
                    }
                  }}
                  className={`p-3.5 rounded-2xl border transition cursor-pointer relative group flex items-start gap-3 ${
                    isUnread
                      ? 'bg-emerald-50/40 border-[#0BAA4B]/30 hover:border-[#0BAA4B]'
                      : 'bg-white border-slate-200 hover:bg-slate-50'
                  }`}
                >
                  <div className={`p-2 rounded-xl shrink-0 ${iconColor}`}>
                    <Icon className="w-4 h-4" />
                  </div>

                  <div className="flex-1 min-w-0 pr-4">
                    <div className="flex items-center justify-between gap-1">
                      <h4 className={`text-xs ${isUnread ? 'font-black text-slate-900' : 'font-bold text-slate-700'} truncate`}>
                        {item.title}
                      </h4>
                      {isUnread && (
                        <span className="w-2 h-2 rounded-full bg-[#0BAA4B] shrink-0" />
                      )}
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5 line-clamp-2 leading-relaxed">
                      {item.message}
                    </p>
                    <div className="flex items-center justify-between mt-2 pt-1.5 border-t border-slate-100/60 text-[10px]">
                      <span className="text-slate-400">
                        {new Date(item.created_at).toLocaleDateString('en-IN', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}
                      </span>
                      {item.sale_code && (
                        <span className="font-mono text-emerald-800 font-bold flex items-center gap-0.5">
                          #{item.sale_code} <ChevronRight className="w-3 h-3" />
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Dismiss button */}
                  <button
                    type="button"
                    onClick={(e) => handleDismiss(item.id, e)}
                    className="opacity-0 group-hover:opacity-100 p-1 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-rose-50 transition"
                    title="Dismiss"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              );
            })
          )}
        </div>

        {/* Footer */}
        {notifications.length > 0 && (
          <div className="p-3 border-t border-slate-150 bg-slate-50 flex items-center justify-between text-xs">
            <button
              type="button"
              onClick={handleClearAll}
              className="text-slate-500 hover:text-rose-600 font-bold transition flex items-center gap-1 text-[11px]"
            >
              <Trash2 className="w-3.5 h-3.5" /> Clear All
            </button>
            <span className="text-[10px] text-slate-400">
              Auto-syncs live milestone alerts
            </span>
          </div>
        )}
      </div>
    </div>,
    document.body
  );
}
