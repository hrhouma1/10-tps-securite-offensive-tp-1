# Laboratoire noté 01 — Parcours d'accès contrôlé à un serveur privé virtuel

## Objectif

Vous devez analyser un serveur privé virtuel (VPS, *Virtual Private Server*) de
laboratoire et démontrer, preuves à l'appui, comment trois services exposés
peuvent former un parcours d'accès :

1. reconnaissance réseau ;
2. accès au service FTP (*File Transfer Protocol*) anonyme ;
3. récupération d'indices ;
4. test contrôlé du compte SSH (*Secure Shell*) ;
5. connexion avec l'utilisateur autorisé ;
6. vérification du service HTTP (*HyperText Transfer Protocol*).

**Vous travaillez uniquement sur l'adresse IP fournie par le script de mise en
place.**

## Scénario

L'entreprise fictive **Atelier Boréal** vous demande d'auditer un ancien
serveur de test. Le serveur contient :

- un service FTP accessible anonymement ;
- un fichier contenant une liste de mots de passe de test ;
- un fichier donnant un indice sur un compte local ;
- un service SSH ;
- un site Web accessible en HTTP.

Votre mission est de comprendre le chemin d'accès et de démontrer chaque étape
**sans modifier le serveur**.

## Prérequis (matériel requis)

- **Une machine Kali Linux vierge** (machine virtuelle ou installation physique), à jour ;
- les droits **sudo** sur cette machine ;
- une connexion Internet (clonage du dépôt + installation de Docker) ;
- les outils sont déjà présents sur Kali : `nmap`, `hydra`, `ftp`, `curl`, `git`.

> Si Docker n'est pas installé : `sudo apt update && sudo apt install -y docker.io`
> puis `sudo systemctl start docker`.

## Identification obligatoire (anti-plagiat)

**Avant toute chose**, personnalisez votre machine avec vos vrais prénom et nom
(minuscules, sans accents) :

```bash
# Le hostname de votre Kali doit contenir votre nom
sudo hostnamectl set-hostname kali-prenom-nom

# Si votre nom d'utilisateur ne contient pas votre nom, créez un compte à votre nom
sudo adduser prenom.nom
sudo usermod -aG sudo prenom.nom
```

Fermez puis rouvrez le terminal : le prompt doit afficher
`prenom.nom@kali-prenom-nom`.

> **Toute capture d'écran remise doit montrer ce prompt identifié.**
> Une capture sans identification visible, ou identique à celle d'un autre
> étudiant, vaut **0** au critère correspondant et peut entraîner un
> signalement pour plagiat.

## Mise en place (obligatoire avant de commencer)

Depuis votre Kali Linux :

```bash
git clone https://github.com/hrhouma2/offensive-labs-1.git
cd offensive-labs-1
bash setup-lab.sh
```

📸 **Capture 0 (obligatoire)** : la fin du script montrant l'adresse IP du VPS,
avec votre prompt identifié visible.

Le script construit votre VPS de laboratoire et **affiche son adresse IP** à la
fin. Notez-la immédiatement et enregistrez-la dans une variable :

```bash
export IP=<IP_DU_VPS>
```

> Chaque groupe obtient une instance indépendante : les mots de passe et les
> jetons de preuve sont **différents pour chaque déploiement**. Les preuves
> d'un autre groupe ne sont donc pas réutilisables.

## Règles d'engagement

- Vous ne touchez **que** l'adresse IP du VPS de laboratoire. Aucun scan
  d'Internet ni d'aucune autre machine.
- Le VPS est un conteneur sur votre machine, mais vous devez agir **comme
  s'il était distant**. Sont donc **interdits** : `docker exec`,
  `docker inspect`, `docker logs`, la lecture du dossier `.lab-data/` ou de
  tout fichier du dépôt autre que ce README.
- Aucune modification du serveur : pas de suppression, pas d'écriture, pas
  d'installation, pas d'élévation de privilèges, pas de persistance.
- Pour le test de mot de passe : **uniquement** la liste `locks.txt` fournie
  par le serveur. Les listes Internet (ex. `rockyou.txt`) sont interdites,
  sauf autorisation explicite de l'enseignant dans une variante séparée.
- Le test de mot de passe est limité au **seul compte indiqué** par les
  indices, à l'IP du VPS et à la durée prévue par l'enseignant.

---

## Parcours attendu

> Pour chaque étape, **la commande exacte n'est pas fournie** : c'est à vous
> de la construire à l'aide des objectifs, des pages de manuel (`man <outil>`)
> et de l'aide intégrée (`<outil> --help`). Consignez chaque commande utilisée
> et sa sortie dans votre rapport.

### Étape 1 — Reconnaissance

**Objectif :** identifier tous les services accessibles sur le VPS.

**À vous de jouer :** avec `nmap`, construisez une commande qui :

- scanne **la totalité des 65 535 ports TCP** (pas seulement les 1000 ports
  par défaut) ;
- détecte le **logiciel et sa version** pour chaque port ouvert.

<details>
<summary>Indice (à ne dérouler qu'en cas de blocage)</summary>

Étudiez les options `-p` et `-sV` dans `man nmap`.
</details>

**À consigner :** pour chaque service trouvé — le port, le protocole, le
logiciel détecté et sa version lorsqu'elle est affichée. Vous devriez trouver
trois services : FTP, SSH et HTTP.

📸 **Capture 1 (obligatoire)** : la commande `nmap` et son résultat complet,
avec votre prompt identifié visible.

### Étape 2 — Connexion FTP anonyme

**Objectif :** tester si le serveur accepte une connexion FTP anonyme et
récupérer les fichiers exposés.

**À vous de jouer :**

- connectez-vous au service FTP avec le client `ftp` et le nom d'utilisateur
  conventionnel des accès anonymes (le mot de passe est libre : une adresse
  courriel ou une valeur vide) ;
- listez le contenu du répertoire distant ;
- téléchargez **en local** les fichiers trouvés (ils ne doivent être ni
  supprimés ni modifiés sur le serveur).

<details>
<summary>Indice</summary>

Le nom d'utilisateur conventionnel est `anonymous`. Dans la session FTP,
étudiez les commandes `ls`, `get` et `mget` (tapez `help` dans le client).
</details>

**À consigner :** la liste des fichiers trouvés (noms et tailles).

📸 **Capture 2 (obligatoire)** : la session FTP complète — connexion anonyme,
`ls`, téléchargements — avec votre prompt identifié visible.

**Questions à traiter dans le rapport :**

1. Que signifie « FTP anonyme » ?
2. Pourquoi cette configuration est-elle dangereuse ?
3. Quelle différence existe-t-il entre *lire un fichier* via FTP et *obtenir
   une session* SSH ?

### Étape 3 — Analyse des fichiers récupérés

**Objectif :** exploiter les indices pour préparer l'étape suivante.

**À vous de jouer :** lisez **localement** les fichiers téléchargés
(`task.txt` et `locks.txt`) et identifiez :

- le **nom du compte** autorisé à se connecter au serveur ;
- la nature exacte de la liste de mots de passe.

**À consigner :** une copie locale de `task.txt`, le nom du compte identifié,
et votre raisonnement (pourquoi ces deux fichiers, ensemble, forment un risque).

📸 **Capture 3 (obligatoire)** : l'affichage de `task.txt` dans votre terminal
identifié.

### Étape 4 — Test SSH contrôlé avec Hydra

**Objectif :** vérifier si un mot de passe de la liste permet une connexion au
compte de test — et **uniquement cela**.

**À vous de jouer :** avec `hydra`, construisez une commande qui respecte
**toutes** ces contraintes :

- un **seul** compte testé : celui identifié à l'étape 3 ;
- une **seule** liste : le fichier `locks.txt` récupéré sur le serveur ;
- un **seul** service ciblé : SSH de l'IP du VPS ;
- au maximum **4 tentatives simultanées** (charge limitée) ;
- **arrêt automatique** dès la première correspondance trouvée.

<details>
<summary>Indice</summary>

`hydra --help` : repérez les options pour un identifiant unique, pour un
fichier de mots de passe, pour limiter les tâches parallèles et pour stopper
au premier succès. La cible s'écrit sous la forme `ssh://<IP_DU_VPS>`.
</details>

**À consigner :** la commande complète utilisée et sa sortie montrant la
correspondance trouvée.

📸 **Capture 4 (obligatoire)** : la sortie d'Hydra montrant la ligne
`[22][ssh] ... login: ... password: ...`, avec votre prompt identifié visible.

### Étape 5 — Connexion SSH

**Objectif :** ouvrir une session avec le compte de laboratoire et prouver
votre identité.

**À vous de jouer :** connectez-vous en SSH avec le compte et le mot de passe
trouvés, puis exécutez **uniquement** ces commandes de vérification :

```bash
whoami
hostname
pwd
id
```

📸 **Capture 5 (obligatoire)** : elle doit montrer **à la fois** votre prompt
Kali identifié (la commande `ssh` tapée) **et** la session distante
`lin@atelier-boreal-vps` avec les sorties des quatre commandes.

**À consigner :** la sortie de ces quatre commandes. Vous devez démontrer que :

- vous êtes connecté avec l'utilisateur attendu ;
- vous êtes bien sur le VPS (comparez le hostname avec la page Web de
  l'étape 6) ;
- vous n'êtes **pas** administrateur ;
- vous n'avez rien modifié.

**Bonus (facultatif) :** un fichier `preuve-lab.txt` se trouve dans le
répertoire personnel du compte. Relevez le jeton `BOREAL-SSH-...` qu'il
contient, puis déconnectez-vous.

### Étape 6 — Vérification HTTP

**Objectif :** vérifier le service Web **sans l'exploiter**.

**À vous de jouer :** avec `curl`, interrogez la page racine du serveur en
affichant **les en-têtes de la réponse** en plus du contenu.

<details>
<summary>Indice</summary>

Cherchez dans `man curl` l'option qui inclut les en-têtes (*headers*) de la
réponse dans la sortie.
</details>

**À consigner :**

- le code de réponse HTTP ;
- le serveur Web annoncé (en-tête `Server`) ;
- le titre ou le contenu de la page ;
- le **jeton de vérification** `BOREAL-WEB-...` qui confirme que vous
  consultez bien le VPS.

📸 **Capture 6 (obligatoire)** : la réponse HTTP complète (en-têtes + jeton),
avec votre prompt identifié visible.

Cette étape sert à comparer les trois services exposés et leurs rôles.

---

## Preuves à remettre

1. Le résultat de la reconnaissance réseau (commande + sortie) ;
2. une capture de la connexion FTP anonyme ;
3. la liste des fichiers trouvés ;
4. une copie locale de `task.txt` ;
5. la preuve que `locks.txt` a été utilisé ;
6. le résultat contrôlé d'Hydra (commande + sortie) ;
7. la sortie de `whoami`, `hostname` et `id` ;
8. la réponse HTTP (en-têtes + jeton) ;
9. un court rapport expliquant le risque ;
10. trois mesures correctives.

## Barème — 100 points

| Critère | Points |
|---|---|
| Respect du périmètre et des règles d'engagement | 10 |
| Reconnaissance correcte des services | 15 |
| Connexion FTP anonyme et récupération des fichiers | 20 |
| Analyse des indices et raisonnement | 15 |
| Utilisation contrôlée d'Hydra | 20 |
| Connexion SSH et preuves d'identité | 10 |
| Vérification HTTP | 5 |
| Rapport, explications et recommandations | 5 |
| **Total** | **100** |

## Mesures correctives attendues

Votre rapport doit proposer au moins trois mesures, par exemple :

- désactiver l'accès FTP anonyme ;
- remplacer FTP par SFTP (*SSH File Transfer Protocol*) ;
- supprimer les fichiers sensibles du répertoire public ;
- utiliser un mot de passe robuste et unique ;
- appliquer une limitation des tentatives SSH ;
- utiliser une authentification par clé ;
- limiter SSH à des adresses autorisées ;
- surveiller les journaux de connexion ;
- supprimer ou désactiver le compte de test après l'évaluation.

## Fin de session

Quand le laboratoire est terminé (ou pour tout recommencer à zéro avec de
nouveaux identifiants) :

```bash
bash cleanup-lab.sh   # arrêter et supprimer le VPS
bash setup-lab.sh     # redéployer une instance neuve
```
