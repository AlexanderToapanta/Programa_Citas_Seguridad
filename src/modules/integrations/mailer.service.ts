import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';
import { Transporter } from 'nodemailer';

export type AppointmentAction = 'CONFIRMED' | 'CANCELLED' | 'RESCHEDULED';

export interface AppointmentNotificationDetails {
  patientName: string;
  appointmentDate: string;
  facilityName: string;
  doctorName: string;
  action: AppointmentAction;
}

@Injectable()
export class MailerService {
  private readonly logger = new Logger(MailerService.name);
  private readonly transporter: Transporter;
  private readonly fromAddress: string;

  constructor(private readonly configService: ConfigService) {
    this.fromAddress =
      this.configService.get<string>('SMTP_FROM') ??
      '"IESS - Turnos de Salud" <alexandertoapanta05@gmail.com>';

    this.transporter = nodemailer.createTransport({
      host: this.configService.get<string>('SMTP_HOST') ?? 'smtp.gmail.com',
      port: Number(this.configService.get<string>('SMTP_PORT') ?? '465'),
      secure: this.configService.get<string>('SMTP_SECURE') === 'true',
      auth: {
        user: this.configService.get<string>('SMTP_USER'),
        pass: this.configService.get<string>('SMTP_PASS'),
      },
    });
  }

  /**
   * Envía una notificación administrativa de turno médico al afiliado.
   * No incluye datos clínicos ni número de cédula (RF07 / R11).
   */
  async sendAppointmentNotification(
    recipientEmail: string,
    details: AppointmentNotificationDetails,
  ): Promise<boolean> {
    const { subject, html } = this.buildEmailContent(details);

    try {
      const info = await this.transporter.sendMail({
        from: this.fromAddress,
        to: recipientEmail,
        subject,
        html,
      });

      this.logger.log(
        `[MAILER] Correo enviado a ${recipientEmail} — messageId: ${info.messageId} — acción: ${details.action}`,
      );
      return true;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(
        `[MAILER] Error al enviar correo a ${recipientEmail}: ${message}`,
      );
      // No relanzar: una falla de correo no debe interrumpir la transacción de la cita
      return false;
    }
  }

  /**
   * Envía las credenciales temporales de acceso al afiliado tras su registro o reseteo (RF05).
   */
  async sendTemporaryPasswordNotification(
    recipientEmail: string,
    fullName: string,
    temporaryPassword: string,
    expiresInMinutes: number = 15,
  ): Promise<boolean> {
    const subject = '🔐 Credencial Temporal de Acceso — IESS Turnos de Salud';
    const html = `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${subject}</title>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;padding:32px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0"
               style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">
          <tr>
            <td style="background:#1e40af;padding:24px 32px;">
              <p style="margin:0;font-size:22px;font-weight:bold;color:#ffffff;">
                🏥 IESS — Sistema de Turnos de Salud
              </p>
              <span style="display:inline-block;margin-top:8px;padding:4px 14px;
                           background:#0284c7;color:#fff;border-radius:20px;
                           font-size:13px;font-weight:bold;letter-spacing:.5px;">
                CREDENCIAL DE ACCESO
              </span>
            </td>
          </tr>
          <tr>
            <td style="padding:32px 32px 8px;">
              <p style="margin:0 0 16px;font-size:16px;color:#374151;">
                Estimado/a <strong>${fullName}</strong>,
              </p>
              <p style="margin:0 0 20px;font-size:15px;color:#374151;">
                Se ha generado su credencial temporal para acceder al Sistema de Turnos Médicos del IESS.
              </p>

              <div style="background:#f8fafc;border:2px dashed #0284c7;border-radius:8px;padding:20px;text-align:center;margin-bottom:24px;">
                <p style="margin:0 0 8px;font-size:13px;color:#64748b;text-transform:uppercase;letter-spacing:1px;font-weight:bold;">
                  Su Contraseña Temporal:
                </p>
                <div style="font-size:26px;font-weight:bold;letter-spacing:3px;color:#1e40af;font-family:monospace;">
                  ${temporaryPassword}
                </div>
                <p style="margin:12px 0 0;font-size:13px;color:#b91c1c;font-weight:bold;">
                  ⏱️ Vigencia: ${expiresInMinutes} minutos
                </p>
              </div>

              <div style="background:#eff6ff;border-left:4px solid #3b82f6;padding:12px 16px;border-radius:4px;margin-bottom:20px;">
                <p style="margin:0;font-size:14px;color:#1e40af;line-height:1.5;">
                  <strong>Importante:</strong> Al ingresar al sistema con esta clave temporal, se le solicitará de forma obligatoria crear una nueva contraseña personal y definitiva.
                </p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 32px 8px;">
              <p style="margin:0;font-size:12px;color:#6b7280;border-top:1px solid #e5e7eb;padding-top:16px;">
                Por motivos de seguridad, nunca comparta esta clave con terceros. El personal del IESS jamás le solicitará su contraseña por teléfono ni correo.
              </p>
            </td>
          </tr>
          <tr>
            <td style="background:#f9fafb;padding:16px 32px;border-top:1px solid #e5e7eb;">
              <p style="margin:0;font-size:12px;color:#9ca3af;text-align:center;">
                © ${new Date().getFullYear()} Instituto Ecuatoriano de Seguridad Social (IESS)
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();

    try {
      const info = await this.transporter.sendMail({
        from: this.fromAddress,
        to: recipientEmail,
        subject,
        html,
      });

      this.logger.log(
        `[MAILER] Contraseña temporal enviada a ${recipientEmail} — messageId: ${info.messageId}`,
      );
      return true;
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(
        `[MAILER] Error al enviar credencial temporal a ${recipientEmail}: ${message}`,
      );
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers privados
  // ─────────────────────────────────────────────

  private buildEmailContent(details: AppointmentNotificationDetails): {
    subject: string;
    html: string;
  } {
    const formattedDate = this.formatDate(details.appointmentDate);

    const actionConfig: Record<
      AppointmentAction,
      { subject: string; badge: string; badgeColor: string; bodyLine: string }
    > = {
      CONFIRMED: {
        subject: '✅ Cita médica confirmada — IESS Turnos de Salud',
        badge: 'CONFIRMADA',
        badgeColor: '#16a34a',
        bodyLine: 'Su cita médica ha sido <strong>reservada exitosamente</strong>.',
      },
      RESCHEDULED: {
        subject: '🔄 Cita médica reprogramada — IESS Turnos de Salud',
        badge: 'REPROGRAMADA',
        badgeColor: '#d97706',
        bodyLine: 'Su cita médica ha sido <strong>reprogramada</strong> a la siguiente fecha.',
      },
      CANCELLED: {
        subject: '❌ Cita médica cancelada — IESS Turnos de Salud',
        badge: 'CANCELADA',
        badgeColor: '#dc2626',
        bodyLine:
          'Su cita médica ha sido <strong>cancelada</strong>. Si necesita asistencia, acuda al establecimiento de salud.',
      },
    };

    const cfg = actionConfig[details.action];

    const html = `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${cfg.subject}</title>
</head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f3f4f6;padding:32px 0;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0"
               style="background:#ffffff;border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">

          <!-- Cabecera -->
          <tr>
            <td style="background:#1e40af;padding:24px 32px;">
              <p style="margin:0;font-size:22px;font-weight:bold;color:#ffffff;">
                🏥 IESS — Sistema de Turnos de Salud
              </p>
              <span style="display:inline-block;margin-top:8px;padding:4px 14px;
                           background:${cfg.badgeColor};color:#fff;border-radius:20px;
                           font-size:13px;font-weight:bold;letter-spacing:.5px;">
                ${cfg.badge}
              </span>
            </td>
          </tr>

          <!-- Cuerpo -->
          <tr>
            <td style="padding:32px 32px 8px;">
              <p style="margin:0 0 16px;font-size:16px;color:#374151;">
                Estimado/a <strong>${details.patientName}</strong>,
              </p>
              <p style="margin:0 0 24px;font-size:15px;color:#374151;">
                ${cfg.bodyLine}
              </p>

              <!-- Detalles de la cita -->
              <table width="100%" cellpadding="0" cellspacing="0"
                     style="background:#f0f9ff;border-left:4px solid #1e40af;border-radius:4px;padding:0;">
                <tr>
                  <td style="padding:20px 24px;">
                    <table width="100%" cellpadding="4" cellspacing="0" style="font-size:14px;color:#1e3a5f;">
                      <tr>
                        <td style="width:40%;font-weight:bold;">📅 Fecha y hora:</td>
                        <td>${formattedDate}</td>
                      </tr>
                      <tr>
                        <td style="font-weight:bold;">🏢 Establecimiento:</td>
                        <td>${details.facilityName}</td>
                      </tr>
                      <tr>
                        <td style="font-weight:bold;">👨‍⚕️ Médico:</td>
                        <td>${details.doctorName}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Aviso de privacidad -->
          <tr>
            <td style="padding:24px 32px 8px;">
              <p style="margin:0;font-size:13px;color:#6b7280;border-top:1px solid #e5e7eb;padding-top:16px;">
                Este mensaje es de carácter informativo y administrativo. No contiene información clínica ni datos sensibles del afiliado. Si usted no realizó esta acción, comuníquese con el establecimiento de salud inmediatamente.
              </p>
            </td>
          </tr>

          <!-- Pie -->
          <tr>
            <td style="background:#f9fafb;padding:16px 32px;border-top:1px solid #e5e7eb;">
              <p style="margin:0;font-size:12px;color:#9ca3af;text-align:center;">
                © ${new Date().getFullYear()} Instituto Ecuatoriano de Seguridad Social (IESS) &nbsp;|&nbsp; Sistema Académico de Gestión de Turnos Médicos
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`.trim();

    return { subject: cfg.subject, html };
  }

  private formatDate(isoDate: string): string {
    try {
      return new Intl.DateTimeFormat('es-EC', {
        dateStyle: 'full',
        timeStyle: 'short',
        timeZone: 'America/Guayaquil',
      }).format(new Date(isoDate));
    } catch {
      return isoDate;
    }
  }
}

