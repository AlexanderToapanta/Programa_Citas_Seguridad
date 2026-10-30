import {
  Injectable,
  NestInterceptor,
  ExecutionContext,
  CallHandler,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { Request, Response } from 'express';
import { AuditService } from '../../modules/audit/audit.service';

@Injectable()
export class AuditInterceptor implements NestInterceptor {
  constructor(private readonly auditService: AuditService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const ctx = context.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    const startTime = Date.now();
    const user = (request as any).user;
    const method = request.method;
    const url = request.url;

    // Solo auditar mutaciones y endpoints críticos de autenticación/citas
    const shouldAudit =
      ['POST', 'PATCH', 'PUT', 'DELETE'].includes(method) ||
      url.includes('/auth') ||
      url.includes('/appointments');

    return next.handle().pipe(
      tap({
        next: () => {
          if (shouldAudit) {
            const ip = request.ip || request.headers['x-forwarded-for'] || request.socket.remoteAddress || 'unknown';
            this.auditService.log({
              userId: user?.id,
              action: `${method} ${url}`,
              resource: this.inferResource(url),
              ipAddress: String(ip),
              userAgent: request.headers['user-agent'],
              statusCode: response.statusCode || 200,
              metadata: {
                query: request.query,
                params: request.params,
                durationMs: Date.now() - startTime,
              },
            });
          }
        },
        error: (err) => {
          if (shouldAudit) {
            const ip = request.ip || request.headers['x-forwarded-for'] || request.socket.remoteAddress || 'unknown';
            this.auditService.log({
              userId: user?.id,
              action: `${method} ${url} - ERROR`,
              resource: this.inferResource(url),
              ipAddress: String(ip),
              userAgent: request.headers['user-agent'],
              statusCode: err.status || 500,
              metadata: {
                errorMessage: err.message,
                durationMs: Date.now() - startTime,
              },
            });
          }
        },
      }),
    );
  }

  private inferResource(url: string): string {
    if (url.includes('/auth')) return 'AUTH';
    if (url.includes('/appointments')) return 'APPOINTMENTS';
    if (url.includes('/representatives')) return 'REPRESENTATIVES';
    if (url.includes('/users')) return 'USERS';
    if (url.includes('/specialties')) return 'SPECIALTIES';
    return 'GENERAL';
  }
}

