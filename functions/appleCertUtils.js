const fs = require("fs");
const path = require("path");

/**
 * Shared Apple certificate utilities
 * Used by both appleWebhook.js and convertAppleCerts.js
 */

// Apple Root Certificate paths - Download from Apple PKI site
const APPLE_ROOT_CAS = ["certificates/AppleRootCA-G3.pem", "certificates/AppleRootCA-G2.pem"];

/**
 * Get standard certificate paths to check
 * @returns {string[]} Array of certificate file paths
 */
function getCertificatePaths() {
  return [
    path.join(__dirname, "certificates", "AppleRootCA-G3.pem"),
    path.join(__dirname, "certificates", "AppleRootCA-G2.pem"),
    path.join(__dirname, "certificates", "AppleRootCA-G3.cer"),
    path.join(__dirname, "certificates", "AppleRootCA-G2.cer"),
    path.join(__dirname, "..", "certs", "AppleRootCA-G3.pem"),
    path.join(__dirname, "..", "certs", "AppleRootCA-G2.pem"),
    path.join(__dirname, "..", "local_tests", "certs", "AppleRootCA-G3.pem"),
    path.join(__dirname, "..", "local_tests", "certs", "AppleRootCA-G2.pem"),
  ];
}

/**
 * Load Apple Root CA certificates from local files
 * @returns {Promise<Buffer[]>} Array of certificate buffers
 */
async function loadAppleRootCAs() {
  try {
    const rootCAs = [];
    const certPaths = getCertificatePaths();

    // Load certificates from files
    for (const certPath of certPaths) {
      if (fs.existsSync(certPath)) {
        try {
          const certBuffer = fs.readFileSync(certPath);
          rootCAs.push(certBuffer);
          // console.log(`✅ Loaded Apple Root CA from: ${certPath}`);
        } catch (error) {
          console.error(
            `❌ Error loading certificate from ${certPath}:`,
            error.message
          );
        }
      }
    }

    if (rootCAs.length === 0) {
      console.warn(
        "⚠️ No Apple Root CA certificates found - verification will fail"
      );
      console.warn(
        "   Download certificates from: https://www.apple.com/certificateauthority/"
      );
      console.warn(
        "   Place them in functions/certs/ or functions/local_tests/certs/"
      );
      console.warn("   Required files: AppleRootCA-G3.cer, AppleRootCA-G2.cer");
    } else {
      console.log(`✅ Loaded ${rootCAs.length} Apple Root CA certificates`);
    }

    return rootCAs;
  } catch (error) {
    console.error("❌ Error loading Apple Root CAs:", error);
    return [];
  }
}

/**
 * Convert certificate file to base64 string
 * @param {string} certPath - Path to certificate file
 * @returns {string|null} Base64 encoded certificate or null if failed
 */
function convertCertToBase64(certPath) {
  try {
    if (!fs.existsSync(certPath)) {
      console.error(`❌ Certificate file not found: ${certPath}`);
      return null;
    }

    const certBuffer = fs.readFileSync(certPath);
    const base64Cert = certBuffer.toString("base64");

    console.log(`✅ Converted ${path.basename(certPath)} to base64`);
    return base64Cert;
  } catch (error) {
    console.error(`❌ Error converting ${certPath}:`, error.message);
    return null;
  }
}

/**
 * Convert all found certificates to base64 and display environment variable format
 * @returns {Object} Object with certificate data
 */
function convertAllCertsToBase64() {
  console.log("🔐 Apple Root CA Certificate Converter");
  console.log("=====================================\n");

  const certPaths = getCertificatePaths();
  let foundCerts = 0;
  const certData = {};

  for (const certPath of certPaths) {
    if (fs.existsSync(certPath)) {
      const base64Cert = convertCertToBase64(certPath);
      if (base64Cert) {
        const envVarName = `APPLE_ROOT_CA_${path
          .basename(certPath, ".cer")
          .split("-")
          .pop()}`;

        console.log(`📋 Environment variable value:`);
        console.log(`${envVarName}=${base64Cert}`);
        console.log("");

        certData[envVarName] = base64Cert;
        foundCerts++;
      }
    }
  }

  if (foundCerts === 0) {
    console.log("❌ No Apple Root CA certificates found");
    console.log("");
    console.log("📋 To use this script:");
    console.log("1. Download Apple Root CA certificates from:");
    console.log("   https://www.apple.com/certificateauthority/");
    console.log(
      "2. Place them in functions/certs/ or functions/local_tests/certs/"
    );
    console.log("3. Run this script again");
    console.log("");
    console.log("📋 Required certificates:");
    console.log("- AppleRootCA-G3.cer (Apple Root CA G3)");
    console.log("- AppleRootCA-G2.cer (Apple Root CA G2)");
  } else {
    console.log("🎉 Certificate conversion complete!");
    console.log("");
    console.log("📋 Next steps:");
    console.log("1. Copy the environment variable values above");
    console.log("2. Add them to your Firebase Functions environment variables");
    console.log("3. Deploy your function");
  }

  return certData;
}

module.exports = {
  APPLE_ROOT_CAS,
  getCertificatePaths,
  loadAppleRootCAs,
  convertCertToBase64,
  convertAllCertsToBase64,
};
