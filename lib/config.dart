/// ============================================================================
/// SNIE Agent — CONFIGURATION
/// Renseignez les valeurs de votre projet (Supabase > Settings > API).
/// Prérequis : SNIE_schema_supabase.sql + SNIE_schema_v1_1_recoupements.sql
/// exécutés, et un enregistrement `agents` lié au user_id de chaque compte.
/// ============================================================================
class SnieConfig {
  static const supabaseUrl = 'https://xmhxyejjqjiqnayqcilc.supabase.co/rest/v1/';
  static const supabaseAnonKey = 'sb_publishable_CESp3-L3J3IlpsgrS9GAbA__H7CEUrx';
}
