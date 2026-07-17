-- ============================================================================
--  SNIE — MIGRATION v1.2 · FOURNISSEURS & PLASTIQUE NON TRIÉ
--  À exécuter APRÈS SNIE_schema_supabase.sql (v1.0) et
--  SNIE_schema_v1_1_recoupements.sql. Migration additive.
--
--  Contenu :
--   · La notion de "coopérative" s'élargit en "fournisseur" : particulier,
--     coopérative ou entreprise (la colonne lots.cooperative_id est conservée
--     pour compatibilité — elle référence désormais tout type de fournisseur).
--   · Nouvelle matière PLASTIQUE_NON_TRIE (lot de plastique en vrac) + tarif.
--   · Création des référentiels (fournisseurs, points de collecte) depuis
--     l'app mobile pour les agents de rôle 'operateur'.
-- ============================================================================

-- ---------- 1. FOURNISSEURS : élargir les types d'organisation ----------
alter table organisations drop constraint organisations_type_check;
alter table organisations add constraint organisations_type_check
  check (type in ('cooperative','particulier','entreprise',
                  'operateur','industriel','collectivite','etat'));

-- ---------- 2. MATIÈRE : plastique non trié (vrac) ----------
alter type type_matiere add value if not exists 'PLASTIQUE_NON_TRIE';

-- Tarif associé (utilisé par fn_calculer_paiements de la v1.1).
insert into parametres (cle, valeur, unite, source) values
 ('TARIF_FCFA_KG_PLASTIQUE_NON_TRIE', 60, 'FCFA/kg', 'grille fournisseurs 2026')
on conflict (cle, valide_de) do nothing;

-- ---------- 3. CRÉATION DES RÉFÉRENTIELS DEPUIS L'APP ----------
-- Les agents 'operateur' peuvent créer fournisseurs et points de collecte.
create policy p_org_i on organisations for insert to authenticated
  with check (jwt_role() = 'operateur'
              and type in ('cooperative','particulier','entreprise'));

create policy p_sites_i on sites for insert to authenticated
  with check (jwt_role() = 'operateur');

create policy p_coll_i on collectivites for insert to authenticated
  with check (jwt_role() = 'operateur');

-- ============================================================================
--  NOTE : si "alter type ... add value" échoue avec un message de transaction,
--  exécutez cette ligne SEULE dans une query séparée, puis relancez le reste.
-- ============================================================================
