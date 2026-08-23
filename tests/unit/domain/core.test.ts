import { describe, expect, it } from "vitest";

import { assertCaliforniaPrivatePassengerAuto, type QuoteCaseRef } from "@/src/domain/core";

describe("canonical MVP scope", () => {
  it("accepts California private-passenger auto", () => {
    const ref: QuoteCaseRef = {
      quoteCaseId: "quote_synthetic_001",
      tenantId: "tenant_synthetic_001",
      jurisdiction: "CA",
      productLine: "PRIVATE_PASSENGER_AUTO",
    };

    expect(() => assertCaliforniaPrivatePassengerAuto(ref)).not.toThrow();
  });
});
