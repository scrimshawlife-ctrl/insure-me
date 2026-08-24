export interface ComplianceEvidenceExportSummary {
  complianceEvidenceExportId: string;
  quoteCaseId: string;
  schemaVersion: 'compliance-evidence-bundle-v1';
  asOf: string;
  manifestHash: string;
  evidenceRecordCount: number;
  createdAt: string;
}

export interface ComplianceEvidenceExportArtifact
  extends ComplianceEvidenceExportSummary {
  manifest: Record<string, unknown>;
}
