const { getFirestore } = require("firebase-admin/firestore");
const { initializeApp } = require("firebase-admin/app");
const nodemailer = require("nodemailer");

// Load environment variables for Firebase Functions v2
require("dotenv").config();

// Initialize Firebase Admin (only if not already initialized)
try {
  initializeApp();
} catch (error) {
  // Firebase already initialized, continue
  console.log("Firebase already initialized");
}
const db = getFirestore();

// Initialize email transporter
const createTransporter = () => {
  // Use environment variables directly
  const email = process.env.GMAIL_EMAIL || "app.noreply@gmail.com";
  const password = process.env.GMAIL_PASSWORD;

  if (!password) {
    throw new Error(
      "Gmail password not configured. Please set GMAIL_PASSWORD environment variable."
    );
  }

  return nodemailer.createTransporter({
    service: "gmail",
    auth: {
      user: email,
      pass: password, // Use App Password, not regular password
    },
  });
};

module.exports = {
  db,
  createTransporter,
};
