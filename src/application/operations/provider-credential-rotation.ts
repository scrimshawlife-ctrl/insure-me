export type CredentialSlot = 'CURRENT' | 'STANDBY' | 'PREVIOUS';

export type CredentialRotationState = {
  currentVersion: string;
  standbyVersion: string | null;
  previousVersion: string | null;
};

export interface ProviderCredentialRotationPort {
  readState(): Promise<CredentialRotationState>;
  stage(input: { version: string; credential: string }): Promise<void>;
  validate(input: { version: string }): Promise<'VALID' | 'REJECTED'>;
  activate(input: { version: string }): Promise<void>;
  verifyActive(input: { version: string }): Promise<'VALID' | 'REJECTED'>;
  revoke(input: { version: string }): Promise<void>;
  rollback(input: { version: string }): Promise<void>;
  recordAudit(input: {
    action: 'STAGED' | 'ACTIVATED' | 'REVOKED' | 'ROLLED_BACK';
    version: string;
  }): Promise<void>;
}

export type ProviderCredentialRotationResult = {
  status: 'ROTATED' | 'ROLLED_BACK';
  previousVersion: string;
  activeVersion: string;
  oldCredentialRevoked: boolean;
  reasonCode: string | null;
};

function assertVersion(value: string): void {
  if (!/^[a-z0-9][a-z0-9._-]{0,63}$/i.test(value)) {
    throw new Error('PROVIDER_CREDENTIAL_VERSION_INVALID');
  }
}

export async function rotateProviderCredential(input: {
  port: ProviderCredentialRotationPort;
  newVersion: string;
  newCredential: string;
}): Promise<ProviderCredentialRotationResult> {
  assertVersion(input.newVersion);
  if (input.newCredential.length < 32) {
    throw new Error('PROVIDER_CREDENTIAL_INVALID');
  }

  const initial = await input.port.readState();
  assertVersion(initial.currentVersion);
  if (input.newVersion === initial.currentVersion) {
    throw new Error('PROVIDER_CREDENTIAL_VERSION_REUSED');
  }

  await input.port.stage({ version: input.newVersion, credential: input.newCredential });
  await input.port.recordAudit({ action: 'STAGED', version: input.newVersion });

  const stagedValidation = await input.port.validate({ version: input.newVersion });
  if (stagedValidation !== 'VALID') {
    return {
      status: 'ROLLED_BACK',
      previousVersion: initial.currentVersion,
      activeVersion: initial.currentVersion,
      oldCredentialRevoked: false,
      reasonCode: 'STANDBY_CREDENTIAL_REJECTED',
    };
  }

  await input.port.activate({ version: input.newVersion });
  await input.port.recordAudit({ action: 'ACTIVATED', version: input.newVersion });

  const activeValidation = await input.port.verifyActive({ version: input.newVersion });
  if (activeValidation !== 'VALID') {
    await input.port.rollback({ version: initial.currentVersion });
    await input.port.recordAudit({ action: 'ROLLED_BACK', version: initial.currentVersion });
    return {
      status: 'ROLLED_BACK',
      previousVersion: initial.currentVersion,
      activeVersion: initial.currentVersion,
      oldCredentialRevoked: false,
      reasonCode: 'ACTIVE_CREDENTIAL_VERIFICATION_FAILED',
    };
  }

  await input.port.revoke({ version: initial.currentVersion });
  await input.port.recordAudit({ action: 'REVOKED', version: initial.currentVersion });

  return {
    status: 'ROTATED',
    previousVersion: initial.currentVersion,
    activeVersion: input.newVersion,
    oldCredentialRevoked: true,
    reasonCode: null,
  };
}
