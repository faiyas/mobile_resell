/**
 * Compresses an image file in the browser canvas and returns a clean Base64 Data URL.
 * Keeps payload lightweight (< 150KB - 250KB) while maintaining visual clarity for receipts and inspection photos.
 */
export const fileToBase64 = (file, maxWidth = 1200, quality = 0.75) => {
  return new Promise((resolve, reject) => {
    if (!file) {
      reject(new Error("No file provided"));
      return;
    }

    const reader = new FileReader();
    reader.readAsDataURL(file);

    reader.onload = (event) => {
      const img = new Image();
      img.src = event.target.result;

      img.onload = () => {
        const canvas = document.createElement('canvas');
        let width = img.width;
        let height = img.height;

        // Scale down if larger than maxWidth
        if (width > maxWidth) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        }

        canvas.width = width;
        canvas.height = height;

        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, width, height);

        // Convert canvas back to compressed JPEG base64 data URI
        const base64String = canvas.toDataURL('image/jpeg', quality);
        resolve(base64String);
      };

      img.onerror = () => {
        // If image object fails to load (e.g. SVG or raw format), fallback to raw file reader output
        resolve(event.target.result);
      };
    };

    reader.onerror = (error) => reject(error);
  });
};

/**
 * Crops and scales an image to exact Hero Banner dimensions (Default: 1200 x 480 px, 2.5:1 ratio).
 * Keeps Base64 payload small (~70-110 KB) while ensuring pixel-perfect display across Web and Mobile.
 */
export const cropAndResizeToBanner = (
  fileOrDataUrl,
  targetWidth = 1200,
  targetHeight = 480,
  quality = 0.85,
  offsetY = 0.5,
  zoom = 1.0
) => {
  return new Promise((resolve, reject) => {
    const processImage = (src) => {
      const img = new Image();
      img.src = src;
      img.onload = () => {
        const canvas = document.createElement('canvas');
        canvas.width = targetWidth;
        canvas.height = targetHeight;
        const ctx = canvas.getContext('2d');

        const targetAspect = targetWidth / targetHeight; // 2.5
        const imgAspect = img.width / img.height;

        let sw, sh, sx, sy;

        if (imgAspect > targetAspect) {
          // Source is wider than banner aspect ratio -> Crop horizontal edges
          sh = img.height / Math.max(1, zoom);
          sw = sh * targetAspect;
          sx = Math.max(0, (img.width - sw) / 2);
          sy = Math.max(0, (img.height - sh) * offsetY);
        } else {
          // Source is taller than banner aspect ratio -> Crop vertical top/bottom
          sw = img.width / Math.max(1, zoom);
          sh = sw / targetAspect;
          sx = Math.max(0, (img.width - sw) / 2);
          sy = Math.max(0, (img.height - sh) * offsetY);
        }

        ctx.fillStyle = '#087C38';
        ctx.fillRect(0, 0, targetWidth, targetHeight);
        ctx.drawImage(img, sx, sy, sw, sh, 0, 0, targetWidth, targetHeight);

        const base64 = canvas.toDataURL('image/jpeg', quality);
        resolve(base64);
      };
      img.onerror = reject;
    };

    if (typeof fileOrDataUrl === 'string') {
      processImage(fileOrDataUrl);
    } else if (fileOrDataUrl instanceof File || fileOrDataUrl instanceof Blob) {
      const reader = new FileReader();
      reader.onload = (e) => processImage(e.target.result);
      reader.onerror = reject;
      reader.readAsDataURL(fileOrDataUrl);
    } else {
      reject(new Error("Invalid image source"));
    }
  });
};

/**
 * Safely formats any image string into a valid img src attribute.
 * If the string is raw base64 (without data: prefix), automatically prepends data:image/jpeg;base64,
 * Handles standard data URIs, web URLs, relative paths, and blobs cleanly.
 */
export const formatImageSrc = (src) => {
  if (!src || typeof src !== 'string') return '';
  const s = src.trim();
  if (
    s.startsWith('data:') ||
    s.startsWith('http://') ||
    s.startsWith('https://') ||
    s.startsWith('blob:') ||
    (s.startsWith('/') && !s.startsWith('/9j/'))
  ) {
    return s;
  }
  // If it's a raw base64 payload or starts with a slash from a base64 string (e.g. /9j/4AAQ...):
  return `data:image/jpeg;base64,${s}`;
};

