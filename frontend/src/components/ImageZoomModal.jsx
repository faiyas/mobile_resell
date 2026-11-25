import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { X, ZoomIn, ZoomOut, RotateCw, RotateCcw, ChevronLeft, ChevronRight } from 'lucide-react';

const normalizeSrc = (src) => {
  if (!src) return '';
  if (src.startsWith('data:') || src.startsWith('http://') || src.startsWith('https://') || src.startsWith('/')) {
    return src;
  }
  return `data:image/jpeg;base64,${src}`;
};

export default function ImageZoomModal({ images = [], initialIndex = 0, onClose }) {
  const [index, setIndex] = useState(initialIndex);
  const [scale, setScale] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [dragging, setDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });

  useEffect(() => {
    setIndex(initialIndex);
    setScale(1);
    setRotation(0);
    setOffset({ x: 0, y: 0 });
  }, [initialIndex]);

  useEffect(() => {
    const handleKey = (e) => {
      if (e.key === 'Escape') onClose?.();
      if (e.key === 'ArrowRight' && images.length > 1) {
        setIndex((i) => (i + 1) % images.length);
        setScale(1);
        setRotation(0);
        setOffset({ x: 0, y: 0 });
      }
      if (e.key === 'ArrowLeft' && images.length > 1) {
        setIndex((i) => (i - 1 + images.length) % images.length);
        setScale(1);
        setRotation(0);
        setOffset({ x: 0, y: 0 });
      }
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [images.length, onClose]);

  if (!images || images.length === 0) return null;

  const current = images[index] || images[0];
  const src = normalizeSrc(current.src || current.image_base64);
  const label = current.label || `Image ${index + 1}`;

  const clampScale = (val) => Math.min(4, Math.max(0.5, Number(val.toFixed(2))));

  const handleZoomIn = () => setScale((s) => clampScale(s + 0.5));
  const handleZoomOut = () => {
    setScale((s) => {
      const next = clampScale(s - 0.5);
      if (next <= 1) setOffset({ x: 0, y: 0 });
      return next;
    });
  };
  const handleReset = () => {
    setScale(1);
    setRotation(0);
    setOffset({ x: 0, y: 0 });
  };
  const handleWheel = (e) => {
    e.preventDefault();
    const delta = e.deltaY < 0 ? 0.25 : -0.25;
    setScale((s) => {
      const next = clampScale(s + delta);
      if (next <= 1) setOffset({ x: 0, y: 0 });
      return next;
    });
  };

  const handleMouseDown = (e) => {
    if (scale <= 1) return;
    e.preventDefault();
    setDragging(true);
    setDragStart({ x: e.clientX - offset.x, y: e.clientY - offset.y });
  };

  const handleMouseMove = (e) => {
    if (!dragging) return;
    setOffset({ x: e.clientX - dragStart.x, y: e.clientY - dragStart.y });
  };

  const handleMouseUp = () => setDragging(false);

  const switchTo = (nextIdx) => {
    setIndex(nextIdx);
    setScale(1);
    setRotation(0);
    setOffset({ x: 0, y: 0 });
  };

  return createPortal(
    <div
      className="fixed inset-0 z-[10050] flex flex-col bg-slate-950/90 backdrop-blur-md select-none"
      onClick={onClose}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
    >
      {/* Top Toolbar */}
      <div
        className="flex items-center justify-between px-4 py-3 bg-slate-900/90 border-b border-slate-800 text-white"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center gap-2 min-w-0">
          <span className="font-bold text-xs sm:text-sm truncate">{label}</span>
          {images.length > 1 && (
            <span className="text-[11px] font-mono text-slate-400 shrink-0">
              ({index + 1} / {images.length})
            </span>
          )}
        </div>

        <div className="flex items-center gap-1.5">
          <button
            type="button"
            onClick={handleZoomOut}
            title="Zoom Out"
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 transition"
          >
            <ZoomOut className="w-4 h-4" />
          </button>
          <span className="text-[11px] font-mono text-slate-300 min-w-[44px] text-center">
            {Math.round(scale * 100)}%
          </span>
          <button
            type="button"
            onClick={handleZoomIn}
            title="Zoom In"
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 transition"
          >
            <ZoomIn className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={() => setRotation((r) => (r + 90) % 360)}
            title="Rotate 90°"
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 transition"
          >
            <RotateCw className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={handleReset}
            title="Reset View"
            className="p-2 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 transition"
          >
            <RotateCcw className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={onClose}
            title="Close (Esc)"
            className="ml-2 p-2 rounded-lg bg-rose-600/80 hover:bg-rose-600 text-white transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Main Zoomable Canvas */}
      <div
        className="relative flex-1 flex items-center justify-center overflow-hidden p-4"
        onWheel={handleWheel}
        onClick={(e) => e.stopPropagation()}
      >
        {images.length > 1 && (
          <button
            type="button"
            onClick={() => switchTo((index - 1 + images.length) % images.length)}
            className="absolute left-3 z-10 p-2.5 rounded-full bg-slate-900/80 hover:bg-slate-800 text-white border border-slate-700 shadow-lg transition"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
        )}

        <img
          src={src}
          alt={label}
          draggable={false}
          onMouseDown={handleMouseDown}
          onDoubleClick={() => (scale > 1 ? handleReset() : setScale(2))}
          style={{
            transform: `translate(${offset.x}px, ${offset.y}px) scale(${scale}) rotate(${rotation}deg)`,
            transition: dragging ? 'none' : 'transform 150ms ease-out',
            cursor: scale > 1 ? (dragging ? 'grabbing' : 'grab') : 'zoom-in',
          }}
          className="max-h-[82vh] max-w-[90vw] object-contain rounded-xl shadow-2xl"
        />

        {images.length > 1 && (
          <button
            type="button"
            onClick={() => switchTo((index + 1) % images.length)}
            className="absolute right-3 z-10 p-2.5 rounded-full bg-slate-900/80 hover:bg-slate-800 text-white border border-slate-700 shadow-lg transition"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        )}
      </div>

      <div
        className="text-center py-2 text-[11px] text-slate-400 bg-slate-900/70 border-t border-slate-800"
        onClick={(e) => e.stopPropagation()}
      >
        Scroll or double-click to zoom · Drag to pan when zoomed · Press Esc to close
      </div>
    </div>,
    document.body
  );
}
