# SNIE Agent — Application mobile de terrain (Flutter)

Application de saisie de traçabilité pour les agents Revalis : création de lots,
transferts/pesées, GPS automatique, **file hors-ligne persistante** (les saisies
survivent à la fermeture de l'app et se synchronisent au retour du réseau).

## Prérequis
- Flutter SDK 3.22+ (`flutter doctor` sans erreur)
- Le schéma SQL exécuté dans Supabase : `SNIE_schema_supabase.sql` puis
  `SNIE_schema_v1_1_recoupements.sql`
- Pour chaque agent : un compte Supabase Auth **et** une ligne dans `agents`
  (`user_id`, `org_id`, `nom`, `role` = 'cooperative' ou 'operateur')

## Installation
```bash
flutter create . --platforms=android,ios --project-name snie_agent  # génère android/ et ios/
flutter pub get
```
Puis renseignez `lib/config.dart` (URL + clé anon du projet Supabase).

### Permissions à déclarer
**Android** — `android/app/src/main/AndroidManifest.xml` :
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
**iOS** — `ios/Runner/Info.plist` :
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>La position certifie le lieu de chaque pesée dans le registre SNIE.</string>
```

## Lancer / compiler
```bash
flutter run                      # test sur appareil branché
flutter build apk --release     # APK Android (distribution directe possible)
```

## Architecture
```
lib/
  config.dart                 # URL + clé Supabase
  theme.dart                  # charte SNIE (émeraude/lime/or)
  models.dart                 # LotResume, RefItem, étapes, matières
  services/
    snie_service.dart         # auth-profil, référentiels+cache, lots+cache, écritures
    offline_queue.dart        # file persistante (shared_preferences), flush idempotent
    location_service.dart     # GPS silencieux -> WKT PostGIS
  screens/
    login_screen.dart         # connexion + vérification du profil agents
    home_screen.dart          # 3 onglets + bandeau de synchro + synchro auto au resume
    nouveau_lot_screen.dart   # pré-collecte
    transfert_screen.dart     # transfert/pesée (recoupement serveur)
    mes_lots_screen.dart      # liste avec cache hors-ligne
```

## Principes offline-first
1. Écriture directe tentée ; échec réseau → file persistante (`client_ref` unique).
2. Le rejeu est idempotent : la contrainte UNIQUE du schéma absorbe les doublons
   (code 23505 traité comme succès).
3. Synchro automatique au retour de l'app au premier plan + bouton manuel.
4. Référentiels et lots mis en cache localement → l'app reste utilisable sans réseau
   après une première connexion.
5. Les erreurs métier (RLS, contraintes) ne sont PAS mises en file : elles remontent
   à l'agent immédiatement — seule la panne réseau justifie la file.

## Feuille de route v1.1 (préparée dans le schéma SQL)
- Confirmation de contrepartie (double déclaration) : écran "Transferts à confirmer"
  sur la vue `v_transferts_en_attente`
- Scan QR des lots (package `mobile_scanner`)
- Photo de la pesée (upload Supabase Storage)
