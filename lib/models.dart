/// Modèles légers alignés sur le schéma SNIE v1.0/v1.1.
class RefItem {
  final String id;
  final String nom;
  const RefItem(this.id, this.nom);
  factory RefItem.fromJson(Map<String, dynamic> j, {String nameKey = 'nom'}) =>
      RefItem(j['id'] as String, (j[nameKey] ?? j['code'] ?? '—') as String);
}

class LotResume {
  final String dbId;
  final String numero;
  final String matiere;
  final num poidsKg;
  final String etape;
  final String commune;
  const LotResume({
    required this.dbId,
    required this.numero,
    required this.matiere,
    required this.poidsKg,
    required this.etape,
    required this.commune,
  });
  factory LotResume.fromJson(Map<String, dynamic> j) => LotResume(
        dbId: j['id'],
        numero: j['numero'] ?? '—',
        matiere: j['matiere'] ?? '—',
        poidsKg: j['poids_initial_kg'] ?? 0,
        etape: j['etape_courante'] ?? 'pre_collecte',
        commune: (j['collectivites']?['nom'] ?? '—') as String,
      );
  Map<String, dynamic> toJson() => {
        'id': dbId, 'numero': numero, 'matiere': matiere,
        'poids_initial_kg': poidsKg, 'etape_courante': etape,
        'collectivites': {'nom': commune},
      };
}

const etapesDb = ['pre_collecte','regroupement','tri','valorisation','produit_expedie'];
const etapesFr = {
  'pre_collecte': 'Pré-collecte',
  'regroupement': 'Regroupement',
  'tri': 'Tri & caractérisation',
  'valorisation': 'Valorisation',
  'produit_expedie': 'Produit / Expédition',
};
const matieres = ['PET','PEHD','PP','FILMS_PE','PAPIER','CARTON','PLASTIQUE_NON_TRIE'];
const matieresFr = {
  'PET': 'PET',
  'PEHD': 'PEHD',
  'PP': 'PP',
  'FILMS_PE': 'Films PE',
  'PAPIER': 'Papier',
  'CARTON': 'Carton',
  'PLASTIQUE_NON_TRIE': 'Plastique non trié',
};
String matiereFr(String m) => matieresFr[m] ?? m;

/// Un fournisseur est une organisation qui apporte de la matière :
/// particulier, coopérative ou entreprise.
const typesFournisseur = {
  'particulier': 'Particulier',
  'cooperative': 'Coopérative',
  'entreprise': 'Entreprise',
};
