#!/usr/bin/env node
/**
 * Generates a PBKDF2-SHA256 password hash in the format used by
 * Backend/src/middleware/auth.ts.
 *
 * Usage:
 *   node scripts/hash-password.mjs "YourPassword"
 */
import { webcrypto } from "node:crypto";

const ITERATIONS = 10_000;

const toBase64 = (bytes) => Buffer.from(bytes).toString("base64");

async function hashPassword(password) {
  const salt = webcrypto.getRandomValues(new Uint8Array(16));
  const keyMaterial = await webcrypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await webcrypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: ITERATIONS, hash: "SHA-256" },
    keyMaterial,
    256,
  );
  return `pbkdf2$${ITERATIONS}$${toBase64(salt)}$${toBase64(new Uint8Array(bits))}`;
}

const password = process.argv[2];
if (!password) {
  console.error('Usage: node scripts/hash-password.mjs "YourPassword"');
  process.exit(1);
}

const hash = await hashPassword(password);
console.log(hash);