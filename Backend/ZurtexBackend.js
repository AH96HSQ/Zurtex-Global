import express from "express";
import cors from "cors";
import mongoose from "mongoose";
import dotenv from "dotenv";
dotenv.config();

const app = express();
app.use(cors());
app.use((req, res, next) => {
  console.log(`➡️  Incoming: ${req.method} ${req.originalUrl}`);
  next();
});
app.use(express.json({ limit: "10mb" }));

// Connect to MongoDB
mongoose
  .connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true,
  })
  .then(() => console.log("✅ Connected to MongoDB"))
  .catch((err) => {
    console.error("❌ MongoDB connection error:", err);
    process.exit(1);
  });

// Define Mongoose schema
const deviceSchema = new mongoose.Schema({
  deviceId: { type: String, required: true, unique: true },
  username: { type: String, required: true, unique: true },
  link: { type: String, required: true },
  expiryTime: { type: Number },
  gig_byte: { type: Number },
  test: { type: Boolean, default: true },
  createdAt: { type: Date, default: Date.now },
  upgrades: [
    {
      price: Number,
      gigabyte: Number,
      durationInDays: Number,
      receiptData: mongoose.Schema.Types.Mixed,
      receiptStatus: {
        type: String,
        enum: ["pending", "approved", "rejected"],
        default: "pending",
      },
      upgradeStatus: {
        type: String,
        enum: ["applied", "waiting", "error"],
        default: "waiting",
      },
      createdAt: { type: Date, default: Date.now },
    },
  ],
  messages: [
    // ✅ new field
    {
      text: String,
      read: { type: Boolean, default: false },
    },
  ],
});
const logSchema = new mongoose.Schema({
  action: String, // e.g. "approve", "reject", "create"
  by: String, // optional: adminId if you support auth later
  deviceId: String,
  upgradeId: String,
  username: String,
  timestamp: { type: Date, default: Date.now },
  success: Boolean,
  meta: mongoose.Schema.Types.Mixed, // optional: includes gigabyte, duration, errors, etc.
});

const Log = mongoose.model("Log", logSchema);

const Device = mongoose.model("Device", deviceSchema);
// Endpoint to return the VPN link for a device
app.post("/api/approve", async (req, res) => {
  const { deviceId, upgradeId, gigabyte, durationInDays } = req.body;

  if (!deviceId || !upgradeId || !gigabyte || !durationInDays) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    const device = await Device.findOne({ deviceId });
    if (!device) {
      return res.status(404).json({ error: "Device not found" });
    }

    const upgrade = device.upgrades.id(upgradeId);
    if (!upgrade || upgrade.receiptStatus !== "pending") {
      return res
        .status(400)
        .json({ error: "Invalid or already processed upgrade" });
    }

    const username = device.username;
    const success = await upgradeVpnUser(username, gigabyte, durationInDays);

    if (!success) {
      await Log.create({
        action: "approve",
        deviceId,
        upgradeId,
        username,
        success: false,
        meta: { error: "VPN provider upgrade failed" },
      });
      return res.status(500).json({ error: "VPN provider upgrade failed" });
    }

    // ✅ Mark upgrade as successful
    upgrade.receiptStatus = "approved";
    upgrade.upgradeStatus = "applied";

    // ✅ Push success message
    device.messages.push({
      text: "تمدید شما با موفقیت انجام شد.",
      read: false,
    });

    await device.save();
    await Log.create({
      action: "approve",
      deviceId,
      upgradeId,
      username,
      success: true,
      meta: {
        gigabyte,
        durationInDays,
        message: "تمدید شما با موفقیت انجام شد.",
        receiptData: upgrade.receiptData, // optional: safe if already in DB
      },
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Error in /api/approve:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/logs", async (req, res) => {
  try {
    const logs = await Log.find().sort({ timestamp: -1 }).limit(100);
    res.json({ logs });
  } catch (err) {
    console.error("❌ Failed to fetch logs:", err);
    res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/pending", async (req, res) => {
  console.log("Pending Request Received");
  try {
    const pendingUpgrades = [];

    // Find all devices that have pending upgrades
    const devices = await Device.find({
      "upgrades.receiptStatus": "pending",
    });

    // Collect all pending upgrades
    for (const device of devices) {
      for (const upgrade of device.upgrades) {
        if (upgrade.receiptStatus === "pending") {
          pendingUpgrades.push({
            deviceId: device.deviceId,
            price: upgrade.price, // ✅ new field
            gigabyte: upgrade.gigabyte,
            durationInDays: upgrade.durationInDays,
            receiptData: upgrade.receiptData, // base64 string
            _id: upgrade._id, // needed for later approval/rejection
          });
        }
      }
    }

    return res.json({ list: pendingUpgrades });
  } catch (err) {
    console.error("❌ Failed to fetch pending receipts:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/renewal", async (req, res) => {
  const deviceId = req.query.deviceId;

  if (!deviceId) {
    return res.status(400).json({ error: "Missing deviceId" });
  }

  if (!deviceId || deviceId.length !== 95) {
    console.log("Invalid deviceId format or length");
    return res.status(400).json({ error: "Invalid deviceId length" });
  }

  try {
    const device = await Device.findOne({ deviceId });

    if (!device) {
      return res.status(404).json({ error: "Device not found" });
    }

    const isPending = device.upgrades?.some(
      (upgrade) => upgrade.receiptStatus === "pending"
    );

    // Flat list of packages
    const flatPackages = [
      { label: "075", days: 30, gb: 15, price: 75000 },
      { label: "115", days: 30, gb: 30, price: 115000 },
      { label: "180", days: 30, gb: 60, price: 180000 },
      { label: "300", days: 30, gb: 120, price: 300000 },
      // { label: "200", days: 90, gb: 45, price: 200000 },
      // { label: "300", days: 90, gb: 90, price: 300000 },
      // { label: "450", days: 90, gb: 180, price: 450000 },
      // { label: "600", days: 90, gb: 240, price: 600000 },
      // { label: "360", days: 180, gb: 90, price: 360000 },
      // { label: "540", days: 180, gb: 180, price: 540000 },
      // { label: "720", days: 180, gb: 360, price: 720000 },
      // { label: "900", days: 180, gb: 480, price: 900000 },
    ];

    const grouped = {
      "1 ماهه": [],
      "3 ماهه": [],
      "6 ماهه": [],
    };

    for (const pkg of flatPackages) {
      if (pkg.days === 30) grouped["1 ماهه"].push(pkg);
      else if (pkg.days === 90) grouped["3 ماهه"].push(pkg);
      else if (pkg.days === 180) grouped["6 ماهه"].push(pkg);
    }

    const cardNumber = "5022291543724593";

    // ✅ Add message logic here
    const defaultMessage = "خوش آمدید!";
    const unread = device.messages?.find((msg) => !msg.read);
    const message = unread?.text || defaultMessage;

    return res.json({
      isPending,
      packages: grouped,
      cardNumber,
      message,
      pricePerDay: 750,
      pricePerGB: 3500,
    });
  } catch (err) {
    console.error("❌ Error in /api/renewal:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.post("/api/reject", async (req, res) => {
  const { upgradeId, message } = req.body;

  if (!upgradeId) {
    return res.status(400).json({ error: "Missing upgradeId" });
  }

  try {
    const device = await Device.findOne({
      "upgrades._id": upgradeId,
    });

    if (!device) {
      return res
        .status(404)
        .json({ error: "Device with this upgrade not found" });
    }

    const upgrade = device.upgrades.id(upgradeId);
    if (!upgrade) {
      return res.status(404).json({ error: "Upgrade not found" });
    }

    // Reject the receipt
    upgrade.receiptStatus = "rejected";

    // Add message to device
    if (message) {
      device.messages.push({ text: message, read: false });
    }

    await device.save();
    await Log.create({
      action: "reject",
      deviceId: device.deviceId,
      upgradeId,
      username: device.username,
      success: true,
      meta: {
        message,
        receiptData: upgrade.receiptData, // base64 or structured
      },
    });

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Error rejecting receipt:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.post("/api/subscription", async (req, res) => {
  const { deviceId } = req.body;
  let vpnInfo = null;
  let hasPendingReceipt = false;

  // ✅ Add version and update URL
  const latestVersion = "1.1.0"; // You can pull this from DB/env later
  const updateUrl = "https://github.com/HoseinSadeqi96/Zurtex-Releases"; // Direct APK link or download page

  if (!deviceId || deviceId.length !== 95) {
    console.log("Invalid deviceId format or length");
    return res.status(400).json({ error: "Invalid deviceId length" });
  }

  try {
    let device = await Device.findOne({ deviceId });

    if (device) {
      hasPendingReceipt = device.upgrades?.some(
        (u) => u.receiptStatus === "pending"
      );
      console.log(`✅ Device already exists: ${device.username}`);
    }

    if (!device) {
      console.log(
        `🆕 No existing device found. Creating new VPN user for deviceId: ${deviceId}`
      );
      const vpnUser = await createVpnUser();

      if (!vpnUser) {
        return res.status(500).json({ error: "VPN creation failed" });
      }

      const linkToUse = vpnUser.sub_link || vpnUser.tak_links?.[0];

      device = new Device({
        deviceId,
        username: vpnUser.username,
        link: linkToUse,
        expiryTime: vpnUser.expiryTime,
        gig_byte: vpnUser.gig_byte,
        test: true,
      });

      await device.save();
      console.log("💾 New device saved to DB:", device);
    }

    vpnInfo = await findVpnUserByUsername(device.username);
    console.log("🔎 VPN info:", vpnInfo);

    if (vpnInfo) {
      const updatedLink =
        formatSubLink(vpnInfo.latest_info?.sub_link) ||
        vpnInfo.online_info?.tak_links?.[0];

      if (!updatedLink) {
        console.error("❌ Cannot update device: no link found in VPN info");
      } else {
        device.link = updatedLink;
        device.expiryTime = vpnInfo.latest_info?.expiration_time;
        device.gig_byte = vpnInfo.latest_info?.package_size;
        await device.save();
        console.log("🔁 Updated device info from VPN API");
      }
    } else {
      console.warn("⚠️ No VPN info found for existing user, using saved data");
    }

    const status = vpnInfo?.online_info?.status;
    const domainList = [
      "zurtex.net",
      "zurtexbackend198267.xyz",
      "zurtexbackend256934.xyz",
      "zurtexbackend569827.xyz",
    ];

    let usage = vpnInfo?.online_info?.usage || 0;
    let total = vpnInfo?.latest_info?.package_size || 0;
    let remainingBytes = total - usage;
    if (remainingBytes < 0) remainingBytes = 0;

    const responsePayload = {
      username: device.username,
      test: device.test,
      expiryTime: device.expiryTime,
      gig_byte: remainingBytes,
      tak_links: vpnInfo?.online_info?.tak_links || [],
      status: ["expired", "active"].includes(status) ? status : "unknown",
      hasPendingReceipt: hasPendingReceipt,
      domains: domainList,
      remaining_bytes: remainingBytes,
      latestVersion,      // ✅ NEW
      updateUrl           // ✅ NEW
    };

    console.log("📤 Responding to client with:", responsePayload);
    return res.json(responsePayload);
  } catch (err) {
    console.error("❌ Server error:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/status", async (req, res) => {
  console.log("Status Request Received");

  try {
    const response = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/status",
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${process.env.VPN_API_KEY}`,
        },
      }
    );

    const data = await response.json();

    if (!data.ok) {
      return res.status(500).json({
        error: "VPN provider error",
        detail: data.error,
      });
    }

    return res.json({
      status: {
        wallet: data.result.balance,
        perGb: data.result.per_gb,
        perDay: data.result.per_day,
        ping: data.result.ping,
        system: data.result.system,
      },
    });
  } catch (err) {
    console.error("❌ Status check failed:", err);
    return res.status(500).json({ error: "Failed to fetch VPN status" });
  }
});
app.post("/api/receipt", async (req, res) => {
  const { deviceId, receiptData, gigabyte, durationInDays, price } = req.body;
  // ✅ Log the incoming request
  console.log("📥 Incoming receipt upload:", {
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
    const device = await Device.findOne({ deviceId });

    if (!device) {
      return res.status(404).json({ error: "Device not found" });
    }

    // Add the new upgrade entry
    device.upgrades.push({
      gigabyte,
      durationInDays,
      receiptData,
      price,
      receiptStatus: "pending",
      upgradeStatus: "waiting",
    });

    await device.save();
    console.log(`✅ Upgrade request recorded for ${deviceId}`);

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Failed to save receipt:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.post("/api/message/read", async (req, res) => {
  const { deviceId } = req.body;

  if (!deviceId) {
    return res.status(400).json({ error: "Missing deviceId" });
  }

  try {
    const device = await Device.findOne({ deviceId });

    if (!device) {
      return res.status(404).json({ error: "Device not found" });
    }

    // ✅ Find the first unread message and mark it as read
    const unread = device.messages?.find((msg) => !msg.read);
    if (unread) {
      unread.read = true;
      await device.save();
    }

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Failed to mark message as read:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.get("/ping", (req, res) => {
  console.log("✅ Received a ping");
  res.send("pong");
});

//functions
async function createVpnUser({ isTest = false, gig = 3, day = 7 } = {}) {
  const params = new URLSearchParams();
  params.append("test", isTest ? "1" : "0");
  if (!isTest) {
    params.append("gig", gig.toString());
    params.append("day", day.toString());
  }

  try {
    const response = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/create",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${process.env.VPN_API_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: params,
      }
    );

    const data = await response.json();

    // ✅ Fix: access result as an object, not as an array
    if (!data.ok || !data.result?.username) {
      console.error("❌ VPN API error:", data.error || data);
      return null;
    }

    const user = data.result;
    const cleanSubLink = formatSubLink(user.sub_link);

    return {
      username: user.username,
      sub_link: cleanSubLink,
      tak_links: user.tak_links,
      expiryTime: user.expiryTime,
      gig_byte: user.gig_byte,
    };
  } catch (err) {
    console.error("❌ Fetch error:", err);
    return null;
  }
}
// async function getAllServices() {
//   try {
//     const response = await fetch(
//       "https://robot.wizardxray.shop/bot/api/v1/clients",
//       {
//         method: "GET",
//         headers: {
//           Authorization: `Bearer ${process.env.VPN_API_KEY}`,
//         },
//       }
//     );

//     const data = await response.json();

//     const list = data.result?.list;

//     if (!data.ok || !Array.isArray(list)) {
//       console.error("❌ Failed to fetch services:", data.error || data);
//       return [];
//     }

//     return list;
//   } catch (err) {
//     console.error("❌ Error fetching services:", err);
//     return [];
//   }
// }
// async function deleteAllServices() {
//   const services = await getAllServices(); // already returns result.list

//   if (!services.length) {
//     console.log("⚠️ No services to delete.");
//     return;
//   }

//   for (const svc of services) {
//     const username = svc.username;
//     if (!username) continue;

//     try {
//       const response = await fetch(
//         "https://robot.wizardxray.shop/bot/api/v1/delsv",
//         {
//           method: "POST",
//           headers: {
//             Authorization: `Bearer ${process.env.VPN_API_KEY}`,
//             "Content-Type": "application/x-www-form-urlencoded",
//           },
//           body: new URLSearchParams({ username }),
//         }
//       );

//       const result = await response.json();

//       if (result.ok) {
//         console.log(`✅ Deleted: ${username}`);
//       } else {
//         console.warn(
//           `⚠️ Failed to delete ${username}:`,
//           result.error || result
//         );
//       }
//     } catch (err) {
//       console.error(`❌ Error deleting ${username}:`, err);
//     }
//   }
// }
async function findVpnUserByUsername(username) {
  const params = new URLSearchParams();
  params.append("username", username);

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000); // 4 sec timeout

  try {
    const response = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/find",
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${process.env.VPN_API_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: params,
        signal: controller.signal,
      }
    );

    clearTimeout(timeout); // clear timeout if fetch completes

    const data = await response.json();

    if (!data.ok || !data.result) {
      console.error(`❌ Failed to find user ${username}:`, data.error || data);
      return null;
    }

    return data.result;
  } catch (err) {
    if (err.name === "AbortError") {
      console.error(`⏰ Timeout while fetching user ${username}`);
    } else {
      console.error("❌ Fetch error during /find:", err);
    }
    return null;
  }
}

function formatSubLink(raw) {
  const hash = raw?.split("/").pop();
  return hash ? `https://iranisystem.com/bot/sub/?hash=${hash}` : null;
}
async function upgradeVpnUser(username, extraGig, extraDay) {
  const paramsGig = new URLSearchParams({ username, gig: extraGig.toString() });
  const paramsDay = new URLSearchParams({ username, day: extraDay.toString() });

  const headers = {
    Authorization: `Bearer ${process.env.VPN_API_KEY}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };

  try {
    const [sizeRes, timeRes] = await Promise.all([
      fetch("https://robot.wizardxray.shop/bot/api/v1/upg_size", {
        method: "POST",
        headers,
        body: paramsGig,
      }),
      fetch("https://robot.wizardxray.shop/bot/api/v1/upg_time", {
        method: "POST",
        headers,
        body: paramsDay,
      }),
    ]);

    const sizeData = await sizeRes.json();
    const timeData = await timeRes.json();

    if (!sizeData.ok || !timeData.ok) {
      console.error("❌ Upgrade failed:", {
        sizeError: sizeData.error || sizeData,
        timeError: timeData.error || timeData,
      });
      return false;
    }

    return true;
  } catch (err) {
    console.error("❌ Exception during VPN upgrade:", err);
    return false;
  }
}
async function getVpnStatus() {
  try {
    const response = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/status",
      {
        method: "GET",
        headers: {
          Authorization: `Bearer ${process.env.VPN_API_KEY}`,
        },
      }
    );

    const data = await response.json();

    if (!data.ok) {
      console.error("❌ VPN provider returned error:", data.error);
      return null;
    }

    return data.result; // Contains overall status, active users, wallet, price per GB/day, etc.
  } catch (err) {
    console.error("❌ Failed to fetch VPN status:", err);
    return null;
  }
}

// Test Runs
// getAllServices().then((svcs) => console.log(svcs));
// deleteAllServices();
getVpnStatus().then((status) => {
  if (status) {
    console.log("✅ VPN System Status:", status);
  } else {
    console.warn("⚠️ Could not fetch VPN status");
  }
});
// Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, "0.0.0.0", () => console.log(`Listening on ${PORT}`));
