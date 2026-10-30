import { Global, Module } from '@nestjs/common';
import { IessIntegrationService } from './iess-integration.service';
import { MailerService } from './mailer.service';

@Global()
@Module({
  providers: [IessIntegrationService, MailerService],
  exports: [IessIntegrationService, MailerService],
})
export class IntegrationsModule {}

