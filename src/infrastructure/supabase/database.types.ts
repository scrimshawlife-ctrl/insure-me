// Canonical database type contract for Slice 1.
// Keep synchronized with Supabase migrations. CI regenerates and diffs this file once the local
// Supabase CLI database is available in the workflow.

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      agencies: {
        Row: {
          agency_id: string;
          tenant_id: string;
          legal_name: string;
          display_name: string;
          status: Database['public']['Enums']['record_status'];
          created_at: string;
        };
        Insert: {
          agency_id?: string;
          tenant_id: string;
          legal_name: string;
          display_name: string;
          status?: Database['public']['Enums']['record_status'];
          created_at?: string;
        };
        Update: Partial<Database['public']['Tables']['agencies']['Insert']>;
        Relationships: [];
      };
      tenant_configurations: {
        Row: {
          tenant_configuration_id: string;
          tenant_id: string;
          agency_id: string;
          version: number;
          status: Database['public']['Enums']['record_status'];
          brand_configuration_ref: string | null;
          enabled_jurisdictions: string[];
          enabled_product_lines: string[];
          notice_policy_set_id: string | null;
          data_use_policy_set_id: string | null;
          retention_policy_set_id: string | null;
          effective_at: string | null;
          retired_at: string | null;
          created_at: string;
          created_by: string | null;
        };
        Insert: {
          tenant_configuration_id?: string;
          tenant_id: string;
          agency_id: string;
          version: number;
          status?: Database['public']['Enums']['record_status'];
          brand_configuration_ref?: string | null;
          enabled_jurisdictions?: string[];
          enabled_product_lines?: string[];
          notice_policy_set_id?: string | null;
          data_use_policy_set_id?: string | null;
          retention_policy_set_id?: string | null;
          effective_at?: string | null;
          retired_at?: string | null;
          created_at?: string;
          created_by?: string | null;
        };
        Update: Partial<Database['public']['Tables']['tenant_configurations']['Insert']>;
        Relationships: [];
      };
      roles: {
        Row: {
          role_id: string;
          tenant_id: string;
          agency_id: string;
          name: string;
          permissions: Database['public']['Enums']['permission_code'][];
          created_at: string;
        };
        Insert: {
          role_id?: string;
          tenant_id: string;
          agency_id: string;
          name: string;
          permissions?: Database['public']['Enums']['permission_code'][];
          created_at?: string;
        };
        Update: Partial<Database['public']['Tables']['roles']['Insert']>;
        Relationships: [];
      };
      agency_users: {
        Row: {
          agency_user_id: string;
          tenant_id: string;
          agency_id: string;
          workforce_identity_id: string;
          status: Database['public']['Enums']['record_status'];
          created_at: string;
        };
        Insert: {
          agency_user_id?: string;
          tenant_id: string;
          agency_id: string;
          workforce_identity_id: string;
          status?: Database['public']['Enums']['record_status'];
          created_at?: string;
        };
        Update: Partial<Database['public']['Tables']['agency_users']['Insert']>;
        Relationships: [];
      };
      agency_user_roles: {
        Row: { agency_user_id: string; role_id: string };
        Insert: { agency_user_id: string; role_id: string };
        Update: Partial<Database['public']['Tables']['agency_user_roles']['Insert']>;
        Relationships: [];
      };
      prospects: {
        Row: {
          prospect_id: string;
          tenant_id: string;
          agency_id: string;
          source_classification: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          prospect_id?: string;
          tenant_id: string;
          agency_id: string;
          source_classification?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: Partial<Database['public']['Tables']['prospects']['Insert']>;
        Relationships: [];
      };
      quote_cases: {
        Row: {
          quote_case_id: string;
          tenant_id: string;
          agency_id: string;
          tenant_configuration_id: string;
          tenant_configuration_version: number;
          jurisdiction: string;
          product_line: string;
          source_channel: string;
          state: Database['public']['Enums']['quote_case_state'];
          prospect_id: string;
          assigned_agent_id: string | null;
          selected_carrier_program_id: string | null;
          selected_carrier_program_version: number | null;
          created_at: string;
          updated_at: string;
          closed_at: string | null;
        };
        Insert: {
          quote_case_id?: string;
          tenant_id: string;
          agency_id: string;
          tenant_configuration_id: string;
          tenant_configuration_version: number;
          jurisdiction: string;
          product_line: string;
          source_channel: string;
          state?: Database['public']['Enums']['quote_case_state'];
          prospect_id: string;
          assigned_agent_id?: string | null;
          selected_carrier_program_id?: string | null;
          selected_carrier_program_version?: number | null;
          created_at?: string;
          updated_at?: string;
          closed_at?: string | null;
        };
        Update: Partial<Database['public']['Tables']['quote_cases']['Insert']>;
        Relationships: [];
      };
      permissible_purpose_decisions: {
        Row: {
          decision_id: string;
          tenant_id: string;
          quote_case_id: string;
          tenant_configuration_version: number;
          actor_id: string | null;
          jurisdiction: string;
          capability: string;
          purpose_code: string;
          outcome: Database['public']['Enums']['purpose_outcome'];
          reason_codes: string[];
          policy_version: string;
          evaluated_at: string;
        };
        Insert: {
          decision_id?: string;
          tenant_id: string;
          quote_case_id: string;
          tenant_configuration_version: number;
          actor_id?: string | null;
          jurisdiction: string;
          capability: string;
          purpose_code: string;
          outcome: Database['public']['Enums']['purpose_outcome'];
          reason_codes?: string[];
          policy_version: string;
          evaluated_at?: string;
        };
        Update: Partial<Database['public']['Tables']['permissible_purpose_decisions']['Insert']>;
        Relationships: [];
      };
      audit_events: {
        Row: {
          audit_event_id: string;
          tenant_id: string;
          agency_id: string | null;
          quote_case_id: string | null;
          event_type: string;
          actor_id: string | null;
          subject_ref: string | null;
          configuration_version_ref: string | null;
          policy_version_refs: string[];
          outcome: string;
          reason_codes: string[];
          occurred_at: string;
          integrity_hash: string;
          metadata: Json;
        };
        Insert: {
          audit_event_id?: string;
          tenant_id: string;
          agency_id?: string | null;
          quote_case_id?: string | null;
          event_type: string;
          actor_id?: string | null;
          subject_ref?: string | null;
          configuration_version_ref?: string | null;
          policy_version_refs?: string[];
          outcome: string;
          reason_codes?: string[];
          occurred_at?: string;
          integrity_hash: string;
          metadata?: Json;
        };
        Update: Partial<Database['public']['Tables']['audit_events']['Insert']>;
        Relationships: [];
      };
      idempotency_keys: {
        Row: {
          idempotency_record_id: string;
          tenant_id: string;
          scope: string;
          idempotency_key: string;
          request_hash: string;
          resource_type: string | null;
          resource_id: string | null;
          status: string;
          created_at: string;
          completed_at: string | null;
        };
        Insert: {
          idempotency_record_id?: string;
          tenant_id: string;
          scope: string;
          idempotency_key: string;
          request_hash: string;
          resource_type?: string | null;
          resource_id?: string | null;
          status: string;
          created_at?: string;
          completed_at?: string | null;
        };
        Update: Partial<Database['public']['Tables']['idempotency_keys']['Insert']>;
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: {
      current_tenant_id: { Args: Record<string, never>; Returns: string | null };
      workforce_mfa_satisfied: { Args: Record<string, never>; Returns: boolean };
      has_tenant_membership: { Args: { target_tenant: string }; Returns: boolean };
      has_permission: {
        Args: {
          target_tenant: string;
          target_agency: string;
          required_permission: Database['public']['Enums']['permission_code'];
        };
        Returns: boolean;
      };
      quote_transition_allowed: {
        Args: {
          from_state: Database['public']['Enums']['quote_case_state'];
          to_state: Database['public']['Enums']['quote_case_state'];
        };
        Returns: boolean;
      };
      transition_quote_case_with_audit: {
        Args: {
          p_quote_case_id: string;
          p_to_state: Database['public']['Enums']['quote_case_state'];
          p_event_type: string;
          p_reason_codes?: string[];
        };
        Returns: Database['public']['Tables']['quote_cases']['Row'];
      };
      claim_idempotency_key: {
        Args: {
          p_scope: string;
          p_idempotency_key: string;
          p_request_hash: string;
        };
        Returns: Database['public']['Tables']['idempotency_keys']['Row'];
      };
    };
    Enums: {
      record_status: 'DRAFT' | 'ACTIVE' | 'RETIRED';
      quote_case_state:
        | 'DRAFT'
        | 'NOTICE_REQUIRED'
        | 'CONSUMER_INPUT'
        | 'DATA_ENRICHMENT'
        | 'REVIEW_REQUIRED'
        | 'READY_FOR_CARRIER'
        | 'SUBMITTED_TO_CARRIER'
        | 'CARRIER_RESPONSE'
        | 'FOLLOW_UP'
        | 'CLOSED'
        | 'ABANDONED'
        | 'RETENTION_HOLD';
      permission_code:
        | 'CASE_READ'
        | 'CASE_WRITE'
        | 'REPORT_RETRIEVE'
        | 'PRIVACY_ADMIN'
        | 'EXPORT_DATA'
        | 'CARRIER_SUBMIT'
        | 'POLICY_ADMIN'
        | 'AUDIT_READ'
        | 'TENANT_ADMIN';
      purpose_outcome: 'ALLOW' | 'DENY';
    };
    CompositeTypes: Record<string, never>;
  };
};
