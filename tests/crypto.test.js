const { encryptText, decryptText } = require("../utils/crypto.utils");

describe("AES-GCM task encryption", () => {
  beforeAll(() => {
    process.env.AES_KEY = Buffer.alloc(32, 1).toString("hex");
  });

  test("encrypts and decrypts task content", () => {
    const plainText = "Prepare DevSecOps demo";

    const encrypted = encryptText(plainText);
    const decrypted = decryptText(encrypted);

    expect(encrypted).not.toBe(plainText);
    expect(decrypted).toBe(plainText);
  });

  test("leaves plain legacy values readable", () => {
    expect(decryptText("legacy note")).toBe("legacy note");
  });
});
