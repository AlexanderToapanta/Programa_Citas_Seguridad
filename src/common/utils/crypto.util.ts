/**
 * Algoritmo de validación de cédula de identidad de Ecuador (Módulo 10)
 */
export function validateEcuadorianIdCard(idCard: string): boolean {
  if (!idCard || idCard.length !== 10 || !/^\d+$/.test(idCard)) {
    return false;
  }

  const provinceCode = parseInt(idCard.substring(0, 2), 10);
  if ((provinceCode < 1 || provinceCode > 24) && provinceCode !== 30) {
    return false;
  }

  const thirdDigit = parseInt(idCard.charAt(2), 10);
  if (thirdDigit < 0 || thirdDigit > 5) {
    return false; // Personas naturales
  }

  const coefficients = [2, 1, 2, 1, 2, 1, 2, 1, 2];
  let sum = 0;

  for (let i = 0; i < 9; i++) {
    let val = parseInt(idCard.charAt(i), 10) * coefficients[i];
    if (val >= 10) {
      val -= 9;
    }
    sum += val;
  }

  const verifierDigit = parseInt(idCard.charAt(9), 10);
  const nextTen = Math.ceil(sum / 10) * 10;
  let computedDigit = nextTen - sum;
  if (computedDigit === 10) computedDigit = 0;

  return computedDigit === verifierDigit;
}

/**
 * Generador criptográficamente seguro de contraseñas temporales
 */
import * as crypto from 'crypto';

export function generateSecureTemporaryPassword(length = 10): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%&*';
  let password = '';
  const randomBytes = crypto.randomBytes(length);
  for (let i = 0; i < length; i++) {
    password += chars[randomBytes[i] % chars.length];
  }
  return password;
}

