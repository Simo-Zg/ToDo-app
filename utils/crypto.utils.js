const crypto = require("crypto");

const ALGORITHM = "aes-256-gcm";
const ENCODING = "hex";

function getKey() {
  const keyHex = process.env.AES_KEY;
  if (!keyHex) throw new Error("Missing AES_KEY in environment variables");
  return Buffer.from(keyHex, "hex");
}

function encryptText(text) {
  if (!text) return text;

  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, getKey(), iv);

  let encrypted = cipher.update(text, "utf8", ENCODING);
  encrypted += cipher.final(ENCODING);

  const authTag = cipher.getAuthTag().toString(ENCODING);

  // Format: iv:encrypted:authTag
  return `${iv.toString(ENCODING)}:${encrypted}:${authTag}`;
}

function decryptText(cipherText) {
  if (!cipherText || typeof cipherText !== "string" || !cipherText.includes(":")) {
    return cipherText; // Return original if not natively encrypted
  }

  try {
    const [ivHex, encryptedHex, authTagHex] = cipherText.split(":");

    if (!ivHex || !encryptedHex || !authTagHex) return cipherText;

    const iv = Buffer.from(ivHex, ENCODING);
    const authTag = Buffer.from(authTagHex, ENCODING);

    const decipher = crypto.createDecipheriv(ALGORITHM, getKey(), iv);
    decipher.setAuthTag(authTag);

    let decrypted = decipher.update(encryptedHex, ENCODING, "utf8");
    decrypted += decipher.final("utf8");

    return decrypted;
  } catch (err) {
    console.error("Decryption failed for block:", err.message);
    return "[Encrypted Content Unreadable]";
  }
}

module.exports = {
  encryptText,
  decryptText
};
