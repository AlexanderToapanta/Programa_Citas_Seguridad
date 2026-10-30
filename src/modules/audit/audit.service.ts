import { Injectable, Module } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

export interface AuditRecordDto {
  userId?: string;
  action: string;
  resource: string;
  resourceId?: string;
  ipAddress: string;
  userAgent?: string;
  statusCode: number;
  metadata?: Record<string, any>;
}

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  /**
   * Sanitiza cualquier metadata para garantizar que NUNCA se guarden contraseñas,
   * tokens completos, pines o datos confidenciales (Cumplimiento RF09 / R09)
   */
  private sanitizeData(obj: any): any {
    if (!obj || typeof obj !== 'object') {
      return obj;
    }

    const sensitiveFields = [
      'password',
      'passwordHash',
      'temporaryPassword',
      'newPassword',
      'token',
      'accessToken',
      'refreshToken',
      'otp',
      'verificationProof',
      'creditCard',
      'bankAccount',
    ];

    const sanitized = Array.isArray(obj) ? [...obj] : { ...obj };

    for (const key of Object.keys(sanitized)) {
      if (sensitiveFields.some((field) => key.toLowerCase().includes(field.toLowerCase()))) {
        sanitized[key] = '[REDACTED_BY_AUDIT_POLICY]';
      } else if (typeof sanitized[key] === 'object') {
        sanitized[key] = this.sanitizeData(sanitized[key]);
      }
    }

    return sanitized;
  }

  async log(record: AuditRecordDto) {
    try {
      const sanitizedMeta = record.metadata ? this.sanitizeData(record.metadata) : undefined;
      return await this.prisma.auditLog.create({
        data: {
          userId: record.userId || null,
          action: record.action,
          resource: record.resource,
          resourceId: record.resourceId || null,
          ipAddress: record.ipAddress,
          userAgent: record.userAgent || null,
          statusCode: record.statusCode,
          metadata: sanitizedMeta,
        },
      });
    } catch (err) {
      // No interrumpir la operación del usuario si el log falla, pero registrar error
      console.error('[AUDIT_ERROR] Error al registrar evento de auditoría:', err);
    }
  }

  async findAll(limit = 100, skip = 0) {
    return this.prisma.auditLog.findMany({
      take: Math.min(limit, 200),
      skip,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: {
            idCard: true,
            fullName: true,
            email: true,
          },
        },
      },
    });
  }
}

@Module({
  providers: [AuditService],
  exports: [AuditService],
})
export class AuditModule {}

