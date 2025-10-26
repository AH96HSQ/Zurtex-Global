const QRCode = require('qrcode');

/**
 * Generate QR code for payment
 * Returns base64 encoded PNG image
 */
async function generateQRCode(data) {
  try {
    const qrCodeImage = await QRCode.toDataURL(data, {
      errorCorrectionLevel: 'M',
      type: 'image/png',
      width: 300,
      margin: 2,
      color: {
        dark: '#000000',
        light: '#FFFFFF',
      },
    });

    return qrCodeImage;

  } catch (error) {
    console.error('❌ Error generating QR code:', error);
    throw error;
  }
}

/**
 * Generate QR code as buffer (for saving to file)
 */
async function generateQRCodeBuffer(data) {
  try {
    const buffer = await QRCode.toBuffer(data, {
      errorCorrectionLevel: 'M',
      type: 'png',
      width: 300,
      margin: 2,
    });

    return buffer;

  } catch (error) {
    console.error('❌ Error generating QR code buffer:', error);
    throw error;
  }
}

module.exports = {
  generateQRCode,
  generateQRCodeBuffer,
};
