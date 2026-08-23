export type Jurisdiction = "CA";
export type ProductLine = "PRIVATE_PASSENGER_AUTO";

export type QuoteCaseState =
  | "DRAFT"
  | "NOTICE_REQUIRED"
  | "CONSUMER_INPUT"
  | "DATA_ENRICHMENT"
  | "REVIEW_REQUIRED"
  | "READY_FOR_CARRIER"
  | "SUBMITTED_TO_CARRIER"
  | "CARRIER_RESPONSE"
  | "FOLLOW_UP"
  | "CLOSED"
  | "ABANDONED"
  | "RETENTION_HOLD";

export interface TenantContext {
  tenantId: string;
  agencyId: string;
  configurationVersionId: string;
}

export interface QuoteCaseRef {
  quoteCaseId: string;
  tenantId: string;
  jurisdiction: Jurisdiction;
  productLine: ProductLine;
}

export interface ProvenanceEntry {
  sourceType: "USER" | "PROVIDER" | "CARRIER" | "SYSTEM";
  sourceId: string;
  retrievedAt?: string;
  reportId?: string;
  transformationVersion?: string;
}

export function assertCaliforniaPrivatePassengerAuto(ref: QuoteCaseRef): void {
  if (ref.jurisdiction !== "CA" || ref.productLine !== "PRIVATE_PASSENGER_AUTO") {
    throw new Error("UNSUPPORTED_JURISDICTION_OR_PRODUCT");
  }
}
