import express from "express";
import bodyParser from "body-parser";
import axios from "axios";

const app = express();
app.use(bodyParser.json({ limit: '10mb' }));

const MAIN_BACKEND_URL = "http://5.78.94.88:5000/api/receipt";

app.post("/api/receipt", async (req, res) => {
  const { deviceId, receiptData, gigabyte, durationInDays, price } = req.body;

  console.log("🇮🇷 📥 Incoming receipt on Iran server:", {
    deviceId,
    gigabyte,
    durationInDays,
    price,
    receiptDataLength: receiptData?.length,
  });

  if (!deviceId || !receiptData) {
    return res.status(400).json({ error: "Missing deviceId or receiptData" });
  }

  try {
    const response = await axios.post(MAIN_BACKEND_URL, {
      deviceId,
      receiptData,
      gigabyte,
      durationInDays,
      price,
    });

    console.log("📤 Forwarded to main backend ✅", response.data);
    res.json(response.data); // or wrap in { success: true, ... }
  } catch (err) {
    console.error("❌ Failed to forward to main backend:", err.message);
    res.status(500).json({ error: "Failed to forward to main backend" });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`🟢 Receipt forwarder running on port ${PORT}`);
});
