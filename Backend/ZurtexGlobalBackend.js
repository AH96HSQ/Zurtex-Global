import express from "express";
import cors from "cors";
import mongoose from "mongoose";
import dotenv from "dotenv";
import nodemailer from "nodemailer";
import crypto from "crypto";
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
  email: { type: String, required: true, unique: true }, // ✅ Changed from deviceId to email
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
        enum: ["applied", "waiting", "error", "cancelled"], // ✅ added "cancelled"
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
  email: String, // ✅ Changed from deviceId to email
  upgradeId: String,
  username: String,
  timestamp: { type: Date, default: Date.now },
  success: Boolean,
  meta: mongoose.Schema.Types.Mixed, // optional: includes gigabyte, duration, errors, etc.
});

const Log = mongoose.model("Log", logSchema);

const Device = mongoose.model("Device", deviceSchema);

// User schema for authentication
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, lowercase: true },
  otpCode: { type: String },
  otpExpiry: { type: Date },
  isVerified: { type: Boolean, default: false },
  createdAt: { type: Date, default: Date.now },
  lastLogin: { type: Date },
});

const User = mongoose.model("User", userSchema);

// ============ AUTHENTICATION ENDPOINTS ============

// Check if email exists
app.post("/api/auth/check-email", async (req, res) => {
  console.log("📧 check-email called with body:", req.body);
  const { email } = req.body;

  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    console.log("❌ Invalid email format:", email);
    return res.status(400).json({ error: "Invalid email format" });
  }

  console.log("✅ Email format valid:", email);

  try {
    const user = await User.findOne({ email: email.toLowerCase() });
    console.log("🔍 User lookup result:", user ? "User found" : "User not found");
    
    if (user && user.isVerified) {
      // Existing verified user - send OTP automatically
      console.log("✅ Verified user - sending OTP automatically");
      const otp = generateOTP();
      const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);
      
      user.otpCode = otp;
      user.otpExpiry = otpExpiry;
      await user.save();
      
      console.log("📧 Attempting to send OTP email...");
      const emailSent = await sendOTPEmail(email, otp);
      
      if (!emailSent) {
        console.log("❌ Email send failed");
        return res.status(500).json({ error: "Failed to send OTP email" });
      }
      
      console.log("✅ OTP sent to existing user");
      return res.json({ exists: true, otpSent: true });
    } else {
      // New user - just inform client, don't create user yet
      console.log("🆕 New user - no account created yet");
      return res.json({ exists: false, otpSent: false });
    }
  } catch (err) {
    console.error("❌ Error in check-email:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

// Request OTP for existing user (now also for new users during registration)
app.post("/api/auth/request-otp", async (req, res) => {
  console.log("📧 request-otp called with body:", req.body);
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: "Email is required" });
  }

  try {
    const otp = generateOTP();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);
    console.log("📱 OTP generated:", otp);

    // Check if user exists
    let user = await User.findOne({ email: email.toLowerCase() });

    if (user && user.isVerified) {
      // Existing verified user
      user.otpCode = otp;
      user.otpExpiry = otpExpiry;
      await user.save();
      console.log("✅ OTP updated for existing user");
    } else {
      // New user - create temporary unverified record
      user = await User.findOneAndUpdate(
        { email: email.toLowerCase() },
        { 
          email: email.toLowerCase(),
          otpCode: otp,
          otpExpiry,
          isVerified: false
        },
        { upsert: true, new: true }
      );
      console.log("🆕 Temporary user record created for registration");
    }

    console.log("📧 Attempting to send OTP email...");
    const emailSent = await sendOTPEmail(email, otp);

    if (!emailSent) {
      console.log("❌ Email send failed");
      return res.status(500).json({ error: "Failed to send OTP email" });
    }

    console.log("✅ OTP email sent successfully");
    return res.json({ success: true, otpSent: true });
  } catch (err) {
    console.error("❌ Error in request-otp:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

// Login with OTP only
app.post("/api/auth/login", async (req, res) => {
  console.log("🔐 login called with body:", req.body);
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ error: "Email and OTP are required" });
  }

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user || !user.isVerified) {
      console.log("❌ User not found or not verified");
      return res.status(401).json({ error: "Invalid credentials" });
    }

    // Verify OTP
    if (user.otpCode === otp && user.otpExpiry > new Date()) {
      user.lastLogin = new Date();
      user.otpCode = undefined;
      user.otpExpiry = undefined;
      await user.save();

      console.log("✅ Login successful");
      return res.json({ 
        success: true, 
        email: user.email,
        message: "Login successful" 
      });
    }

    console.log("❌ Invalid or expired OTP");
    return res.status(401).json({ error: "Invalid or expired OTP" });
  } catch (err) {
    console.error("❌ Error in login:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

// Register new user (verify OTP only, no password needed)
app.post("/api/auth/register", async (req, res) => {
  console.log("📝 register called with body:", req.body);
  const { email, otp } = req.body;

  if (!email || !otp) {
    return res.status(400).json({ error: "Email and OTP are required" });
  }

  try {
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user) {
      console.log("❌ User not found");
      return res.status(404).json({ error: "User not found. Please start registration again." });
    }

    if (user.isVerified) {
      console.log("❌ User already verified");
      return res.status(400).json({ error: "User already registered. Please login." });
    }

    if (user.otpCode !== otp || user.otpExpiry < new Date()) {
      console.log("❌ Invalid or expired OTP");
      return res.status(401).json({ error: "Invalid or expired OTP" });
    }

    user.isVerified = true;
    user.otpCode = undefined;
    user.otpExpiry = undefined;
    user.lastLogin = new Date();
    await user.save();

    console.log("✅ Registration successful");
    return res.json({ 
      success: true, 
      email: user.email,
      message: "Registration successful" 
    });
  } catch (err) {
    console.error("❌ Error in register:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

// ============ END AUTHENTICATION ENDPOINTS ============

// Email transporter setup (using Limoo.host mail server - same as OpenMusic backend)
const transporter = nodemailer.createTransport({
  host: "mail8.limoo.host",
  port: 465,
  secure: true,
  auth: {
    user: "support@systemband.ir",
    pass: process.env.SMTP_PASS,
  },
});

// Helper function to generate OTP
function generateOTP() {
  return crypto.randomInt(100000, 999999).toString();
}

// Helper function to send OTP email
async function sendOTPEmail(email, otp) {
  console.log(`📤 Sending OTP email to ${email}, code: ${otp}`);
  try {
    const info = await transporter.sendMail({
      from: '"Zurtex Global" <support@systemband.ir>',
      to: email,
      subject: "Your Zurtex Global Verification Code",
      html: `
        <div style="font-family: Arial, sans-serif; padding: 20px; background: #000; color: #fff;">
          <h2 style="color: #fff;">Your Verification Code</h2>
          <p>Enter this code to login or register:</p>
          <h1 style="color: #fff; font-size: 32px; letter-spacing: 5px;">${otp}</h1>
          <p>This code is valid for 10 minutes.</p>
          <p style="color: #888; font-size: 12px;">If you didn't request this code, please ignore this email.</p>
        </div>
      `,
    });
    console.log("✅ Email sent successfully. MessageID:", info.messageId);
    return true;
  } catch (err) {
    console.error("❌ Failed to send OTP email:", err);
    return false;
  }
}
// Endpoint to return the VPN link for a device
app.post("/api/approve", async (req, res) => {
  const { email, upgradeId, gigabyte, durationInDays } = req.body;

  if (!email || !upgradeId || !gigabyte || !durationInDays) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    const device = await Device.findOne({ email: email.toLowerCase() });
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
        email,
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
      email,
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

    const sanitizedLogs = logs.map((log) => {
      const logObj = log.toObject(); // Convert Mongoose document to plain object
      const meta = logObj.meta || {};

      // Remove the actual base64 image if it exists
      if (meta.receiptData) {
        delete meta.receiptData;
        meta.hasReceipt = true;
        meta.receiptId = logObj._id.toString(); // Use log ID as receipt identifier
      } else {
        meta.hasReceipt = false;
      }

      return {
        ...logObj,
        meta,
      };
    });

    res.json({ logs: sanitizedLogs });
  } catch (err) {
    console.error("❌ Failed to fetch logs:", err);
    res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/user/history/:username", async (req, res) => {
  const { username } = req.params;

  if (!username) {
    return res.status(400).json({ error: "Username is required" });
  }

  try {
    const logs = await Log.find({ username })
      .sort({ timestamp: -1 })
      .limit(100);

    const parsedLogs = logs.map((log) => ({
      timestamp: log.timestamp,
      action: log.action,
      gigabyte: log.meta?.gigabyte ?? null,
      durationInDays: log.meta?.durationInDays ?? null,
    }));

    return res.json(parsedLogs);
  } catch (err) {
    console.error("❌ Error fetching user history:", err);
    return res.status(500).json({ error: "Server error" });
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
            email: device.email, // ✅ Changed from deviceId to email
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

  if (deviceId.length !== 95) {
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

    // ✅ Check for active pending crypto checkout
    const pendingCryptoUpgrade = device.upgrades?.find(
      (u) =>
        u.receiptStatus === "pending" &&
        u.receiptData?.type === "crypto" &&
        u.receiptData?.code &&
        u.receiptData?.link
    );

    // ✅ Get dynamic prices from /api/status
    let pricePerDay = 750;
    let pricePerGB = 3500;

    try {
      const statusRes = await fetch(
        "https://robot.wizardxray.shop/bot/api/v1/status",
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${process.env.VPN_API_KEY}`,
          },
        }
      );
      const statusData = await statusRes.json();

      if (statusData.ok) {
        pricePerDay = (statusData.result.per_day || 200) * 5;
        pricePerGB = (statusData.result.per_gb || 2000) * 5;
      } else {
        console.warn("⚠️ VPN status response not ok:", statusData);
      }
    } catch (err) {
      console.warn(
        "⚠️ Failed to fetch status. Falling back to default prices.",
        err
      );
    }

    // Flat list of packages
    const flatPackages = [
      { label: "075", days: 30, gb: 15, price: 75000 },
      { label: "115", days: 30, gb: 30, price: 115000 },
      { label: "180", days: 30, gb: 60, price: 180000 },
      { label: "300", days: 30, gb: 120, price: 300000 },
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
    const defaultMessage = "خوش آمدید!";
    const unread = device.messages?.find((msg) => !msg.read);
    const message = unread?.text || defaultMessage;

    return res.json({
      isPending,
      packages: grouped,
      cardNumber,
      message,
      pricePerDay,
      pricePerGB,
      pendingCrypto: pendingCryptoUpgrade
        ? {
            code: pendingCryptoUpgrade.receiptData.code,
            link: pendingCryptoUpgrade.receiptData.link,
          }
        : null,
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
  console.log("📱 subscription request received");
  console.log("📧 Request body:", req.body);
  const { email } = req.body;
  let vpnInfo = null;
  let hasPendingReceipt = false;

  // ✅ Add version and update URL
  const latestVersion = "1.1.3"; // You can pull this from DB/env later
  const updateUrl = "https://t.me/ZurtexV2rayApp"; // Direct APK link or download page

  if (!email) {
    console.log("❌ No email provided");
    return res.status(400).json({ error: "Email is required" });
  }

  console.log("🔍 Looking up user:", email);
  try {
    // Find authenticated user
    const user = await User.findOne({ email: email.toLowerCase() });

    if (!user || !user.isVerified) {
      console.log("❌ User not found or not verified");
      return res.status(401).json({ error: "User not authenticated" });
    }

    console.log("✅ User found:", user.email);
    
    // Find device by email (not deviceId)
    let device = await Device.findOne({ email: email.toLowerCase() });

    if (device) {
      hasPendingReceipt = device.upgrades?.some(
        (u) => u.receiptStatus === "pending"
      );
      console.log(`✅ Device already exists: ${device.username}`);
    }

    if (!device) {
      console.log(
        `🆕 No existing device found. Creating new VPN user for email: ${email}`
      );
      // Create VPN account with 3 days and 7 GB for new users
      const vpnUser = await createVpnUser({ isTest: false, gig: 7, day: 3 });

      if (!vpnUser) {
        return res.status(500).json({ error: "VPN creation failed" });
      }

      const linkToUse = vpnUser.sub_link || vpnUser.tak_links?.[0];

      device = new Device({
        email: email.toLowerCase(), // ✅ Use email instead of deviceId
        username: vpnUser.username,
        link: linkToUse,
        expiryTime: vpnUser.expiryTime,
        gig_byte: vpnUser.gig_byte,
        test: false, // Not a test account - real 3 day 7GB account
      });

      await device.save();
      
      console.log("💾 New device saved to DB (3 days, 7GB):", device);
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
    const currentDomain = "https://zurtexbackend569827.xyz/global";

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
      currentDomain, // ✅ New key replacing domainList
      remaining_bytes: remainingBytes,
      latestVersion, // ✅ NEW
      updateUrl, // ✅ NEW
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
  const { email, receiptData, gigabyte, durationInDays, price } = req.body;
  // ✅ Log the incoming request
  console.log("📥 Incoming receipt upload:", {
    email,
    gigabyte,
    durationInDays,
    price,
    receiptDataLength: receiptData?.length,
  });

  if (!email || !receiptData) {
    return res.status(400).json({ error: "Missing email or receiptData" });
  }

  try {
    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });
    
    if (!user || !user.isVerified) {
      return res.status(401).json({ error: "User not authenticated" });
    }

    // Find device linked to user by email
    const device = await Device.findOne({ email: email.toLowerCase() });

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
    console.log(`✅ Upgrade request recorded for ${email}`);

    return res.json({ success: true });
  } catch (err) {
    console.error("❌ Failed to save receipt:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.post("/api/message/read", async (req, res) => {
  const { email } = req.body;

  if (!email) {
    return res.status(400).json({ error: "Missing email" });
  }

  try {
    // Find user by email
    const user = await User.findOne({ email: email.toLowerCase() });
    
    if (!user || !user.isVerified) {
      return res.status(401).json({ error: "User not authenticated" });
    }

    // Find device linked to user by email
    const device = await Device.findOne({ email: email.toLowerCase() });

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
app.post("/api/checkout", async (_req) => {

  
  // const { deviceId, amountIRT, gigabyte = 0, durationInDays = 0 } = req.body;

  // if (!deviceId || !amountIRT) {
  //   return res.status(400).json({ error: "Missing required fields" });
  // }

  // try {
  //   const device = await Device.findOne({ deviceId });

  //   if (!device) {
  //     return res.status(404).json({ error: "Device not found" });
  //   }

  //   // 🔐 Call checkout API with fixed values
  //   const checkoutRes = await fetch("http://ezkeep.ir/api/merchant-request", {
  //     method: "POST",
  //     headers: { "Content-Type": "application/json" },
  //     body: JSON.stringify({
  //       crypto: "ltc",
  //       network: "ltc",
  //       address: "ltc1qmr2u6qhzrwe4adsvyzdahskeee8pmzjuv02lze",
  //       apiKey: "API-123456-ONE",
  //       amountIRT,
  //     }),
  //   });

  //   const data = await checkoutRes.json();

  //   if (!data.success || !data.link || !data.code) {
  //     console.error("❌ Failed to create checkout link:", data);
  //     return res.status(500).json({ error: "Failed to create checkout" });
  //   }

  //   // 🧠 Store this in upgrades list
  //   device.upgrades.push({
  //     price: amountIRT,
  //     gigabyte,
  //     durationInDays,
  //     receiptData: {
  //       type: "crypto",
  //       code: data.code,
  //       link: data.link,
  //       address: "ltc1qmr2u6qhzrwe4adsvyzdahskeee8pmzjuv02lze",
  //       network: "ltc",
  //       crypto: "ltc",
  //     },
  //     receiptStatus: "pending",
  //     upgradeStatus: "waiting",
  //   });

  //   await device.save();

  //   console.log(`✅ Crypto checkout created for ${deviceId}: ${data.code}`);
  //   return res.json({ success: true, link: data.link, code: data.code });
  // } catch (err) {
  //   console.error("❌ Error in /api/checkout:", err);
  //   return res.status(500).json({ error: "Server error" });
  // }
});
app.get("/api/receipt/:id", async (req, res) => {
  try {
    const log = await Log.findById(req.params.id);

    if (!log || !log.meta || !log.meta.receiptData) {
      return res.status(404).json({ error: "Receipt not found" });
    }

    const base64 = log.meta.receiptData;

    res.json({ base64 });
  } catch (err) {
    console.error(`❌ Failed to load receipt for ${req.params.id}:`, err);
    res.status(500).json({ error: "Server error" });
  }
});

app.get("/api/checkout-status/:code", async (req, res) => {
  const { code } = req.params;

  if (!code) {
    return res.status(400).json({ error: "Missing code" });
  }

  try {
    // 1️⃣ Call external checkout API
    const statusRes = await fetch(`http://ezkeep.ir/api/check-status/${code}`);
    const statusData = await statusRes.json();

    if (!statusRes.ok || !statusData || statusData.error) {
      console.error("❌ Failed to fetch status from checkout API:", statusData);
      return res.status(500).json({ error: "Failed to check status" });
    }

    const { status } = statusData;

    // 2️⃣ If confirmed, apply the upgrade
    if (status === "confirmed") {
      const device = await Device.findOne({
        "upgrades.receiptData.code": code,
      });

      if (!device) {
        return res
          .status(404)
          .json({ error: "Device not found for this code" });
      }

      const upgrade = device.upgrades.find(
        (u) => u.receiptData?.code === code && u.receiptStatus === "pending"
      );

      if (!upgrade) {
        return res.status(404).json({ error: "Matching upgrade not found" });
      }

      const username = device.username;
      const gigabyte = upgrade.gigabyte || 0;
      const durationInDays = upgrade.durationInDays || 0;

      const success = await upgradeVpnUser(username, gigabyte, durationInDays);

      if (!success) {
        await Log.create({
          action: "approve",
          email: device.email,
          upgradeId: upgrade._id,
          username,
          success: false,
          meta: { error: "VPN provider upgrade failed" },
        });
        return res.status(500).json({ error: "VPN provider upgrade failed" });
      }

      upgrade.receiptStatus = "approved";
      upgrade.upgradeStatus = "applied";

      device.messages.push({
        text: "تمدید شما با موفقیت انجام شد.",
        read: false,
      });

      await device.save();

      await Log.create({
        action: "approve",
        email: device.email,
        upgradeId: upgrade._id,
        username,
        success: true,
        meta: {
          gigabyte,
          durationInDays,
          code,
          receiptData: upgrade.receiptData,
        },
      });

      return res.json({
        success: true,
        status: "confirmed",
        message: "تمدید انجام شد",
      });
    }

    // 3️⃣ If not confirmed
    return res.json({ success: true, status });
  } catch (err) {
    console.error("❌ Error in /api/checkout-status:", err);
    return res.status(500).json({ error: "Server error" });
  }
});
app.get("/api/users", async (req, res) => {
  try {
    const users = await Device.find({}, "email username")
      .sort({ createdAt: -1 })
      .limit(200);
    res.json({ users });
  } catch (err) {
    console.error("Error fetching users:", err);
    res.status(500).json({ error: "Server error" });
  }
});

app.post("/api/checkout-cancel/:code", async (req, res) => {
  const { code } = req.params;

  if (!code) {
    return res.status(400).json({ error: "Missing code" });
  }

  try {
    const device = await Device.findOne({
      "upgrades.receiptData.code": code,
    });

    if (!device) {
      return res.status(404).json({ error: "Device not found" });
    }

    const upgrade = device.upgrades.find(
      (u) => u.receiptData?.code === code && u.receiptStatus === "pending"
    );

    if (!upgrade) {
      return res
        .status(404)
        .json({ error: "Matching upgrade not found or already processed" });
    }

    upgrade.receiptStatus = "rejected";
    upgrade.upgradeStatus = "cancelled"; // Optional: mark as explicitly cancelled

    device.messages.push({
      text: "تراکنش شما لغو شد.",
      read: false,
    });

    await device.save();

    await Log.create({
      action: "cancel",
      email: device.email,
      upgradeId: upgrade._id,
      username: device.username,
      success: true,
      meta: {
        reason: "User-initiated cancellation",
        code,
      },
    });

    return res.json({ success: true, message: "تراکنش لغو شد" });
  } catch (err) {
    console.error("❌ Error in /api/checkout-cancel:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

//functions
async function createVpnUser({ isTest = false, gig = 1, day = 7 } = {}) {
  console.log(`🔧 createVpnUser called with: isTest=${isTest}, gig=${gig}, day=${day}`);
  const params = new URLSearchParams();
  params.append("test", isTest ? "1" : "0");
  if (!isTest) {
    params.append("gig", gig.toString());
    params.append("day", day.toString());
  }
  
  console.log(`📤 Sending to VPN API: ${params.toString()}`);

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
    console.log(`📥 VPN API response:`, data);

    // ✅ Fix: access result as an object, not as an array
    if (!data.ok || !data.result?.username) {
      console.error("❌ VPN API error:", data.error || data);
      return null;
    }

    const user = data.result;
    const cleanSubLink = formatSubLink(user.sub_link);

    console.log(`✅ VPN user created: ${user.username}`);
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
    const sizeRes = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/upg_size",
      {
        method: "POST",
        headers,
        body: paramsGig,
      }
    );

    // Wait 2500 milliseconds (2.5 seconds)
    await new Promise((resolve) => setTimeout(resolve, 2000));

    const timeRes = await fetch(
      "https://robot.wizardxray.shop/bot/api/v1/upg_time",
      {
        method: "POST",
        headers,
        body: paramsDay,
      }
    );

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
app.get("/api/user/details/:username", async (req, res) => {
  const { username } = req.params;

  if (!username) {
    return res.status(400).json({ error: "Username is required" });
  }

  try {
    const device = await Device.findOne({ username });

    if (!device) {
      return res.status(404).json({ error: "User not found" });
    }

    const vpnInfo = await findVpnUserByUsername(username);

    let remainingBytes = 0;
    if (vpnInfo) {
      const usage = vpnInfo.online_info?.usage || 0;
      const total = vpnInfo.latest_info?.package_size || 0;
      remainingBytes = Math.max(total - usage, 0);
    }

    return res.json({
      username: device.username,
      expiryTime: vpnInfo?.latest_info?.expiration_time || device.expiryTime,
      gig_byte: remainingBytes,
      status: vpnInfo?.online_info?.status || "unknown",
    });
  } catch (err) {
    console.error("❌ Failed to fetch user details:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

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
app.post("/api/topup", async (req, res) => {
  const { username, gigabyte, days } = req.body;

  if (!username || gigabyte == null || days == null) {
    return res.status(400).json({ error: "Missing required fields" });
  }

  try {
    const success = await upgradeVpnUser(
      username,
      Number(gigabyte),
      Number(days)
    );

    if (success) {
      return res.json({ ok: true });
    } else {
      return res.status(500).json({ error: "VPN top-up failed" });
    }
  } catch (err) {
    console.error("❌ Error in /api/topup:", err);
    return res.status(500).json({ error: "Server error" });
  }
});

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
const PORT = process.env.PORT || 5005;
app.listen(PORT, "0.0.0.0", () => console.log(`Listening on ${PORT}`));
