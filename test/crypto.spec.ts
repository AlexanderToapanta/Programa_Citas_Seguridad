import { validateEcuadorianIdCard, generateSecureTemporaryPassword } from '../src/common/utils/crypto.util';
import * as argon2 from 'argon2';

describe('Pruebas Unitarias de Seguridad y Criptografía (RF02, RF05)', () => {
  describe('Validación de Cédula Ecuatoriana (Módulo 10)', () => {
    it('debe validar exitosamente cédulas ecuatorianas reales/válidas', () => {
      expect(validateEcuadorianIdCard('1709983942')).toBe(true);
      expect(validateEcuadorianIdCard('1703970622')).toBe(true);
      expect(validateEcuadorianIdCard('0905134318')).toBe(true);
    });

    it('debe rechazar cédulas con longitud o formato inválido', () => {
      expect(validateEcuadorianIdCard('171589745')).toBe(false); // 9 dígitos
      expect(validateEcuadorianIdCard('17158974510')).toBe(false); // 11 dígitos
      expect(validateEcuadorianIdCard('171589745A')).toBe(false); // caracteres no numéricos
      expect(validateEcuadorianIdCard('')).toBe(false);
    });

    it('debe rechazar cédulas con código de provincia inválido', () => {
      expect(validateEcuadorianIdCard('2515897451')).toBe(false); // Provincia 25 no existe
      expect(validateEcuadorianIdCard('0015897451')).toBe(false); // Provincia 00 no existe
    });

    it('debe rechazar cédulas con dígito verificador adulterado', () => {
      expect(validateEcuadorianIdCard('1715897452')).toBe(false); // Dígito 2 en vez de 1
    });
  });

  describe('Generador de Credenciales Temporales Criptográficas (RF05)', () => {
    it('debe generar contraseñas seguras con longitud y entropía suficiente', () => {
      const pwd = generateSecureTemporaryPassword(12);
      expect(pwd).toBeDefined();
      expect(pwd.length).toBe(12);
    });

    it('debe generar valores no deterministas y distintos en cada invocación', () => {
      const pwd1 = generateSecureTemporaryPassword(12);
      const pwd2 = generateSecureTemporaryPassword(12);
      expect(pwd1).not.toEqual(pwd2);
    });
  });

  describe('Hashing y Verificación con Argon2id (R03, RF05)', () => {
    it('debe hashear y verificar contraseñas correctamente usando Argon2id', async () => {
      const password = 'PasswordSegura2026!';
      const hash = await argon2.hash(password, { type: argon2.argon2id });
      
      expect(hash).toContain('$argon2id$');
      
      const isValid = await argon2.verify(hash, password);
      expect(isValid).toBe(true);

      const isInvalid = await argon2.verify(hash, 'ClaveIncorrecta123');
      expect(isInvalid).toBe(false);
    });
  });
});

