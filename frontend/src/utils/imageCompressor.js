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
