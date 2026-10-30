import { Global, Module } from '@nestjs/common';
import { IessIntegrationService } from './iess-integration.service';

@Global()
@Module({
  providers: [IessIntegrationService],
  exports: [IessIntegrationService],
})
export class IntegrationsModule {}

