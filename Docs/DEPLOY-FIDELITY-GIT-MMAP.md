# Déploiement `fidelity` quand `git push` échoue (`mmap` / Desktop iCloud)

## Ordre à suivre (toujours)

1. **D’abord** : `cd ~/Desktop/fidelity && npm run deploy`
2. Si `git push` échoue avec `fatal: mmap failed: Operation timed out` (**ne pas abandonner le déploiement**) : exécuter **dans l’ordre** la procédure de secours ci‑dessous (clone `/tmp` + `git diff origin/main..HEAD` + push avec `gh`).
3. **Prérequis** pour le secours : GitHub CLI **`gh`** installé et connecté (`gh auth login`) afin que `gh auth token` retourne un jeton valide.

## Ce qui n’est **pas** automatique

- **Chaque session Cursor / chaque agent** a son propre terminal et son propre état.
- **`npm run deploy`** dans `~/Desktop/fidelity` **ne contourne pas** tout seul le bug `mmap` : si `git push` plante, **rien n’arrive sur GitHub**, donc **pas de déploiement Railway/Vercel**.
- La **solution de contournement** (clone propre + copie des fichiers modifiés + push) doit être **réexécutée** quand le problème se reproduit — ce n’est **pas** une option globale « activée une fois pour toutes » **et ne s’applique pas toute seule entre sessions**.

## Pourquoi ça arrive (résumé)

Sur macOS, un dépôt Git **lourd** ou **sur le Bureau synchronisé iCloud** peut faire échouer `git pack-objects` / `send-pack` avec :

```text
fatal: mmap failed: Operation timed out
```

Ce n’est **pas** un rejet GitHub du projet : c’est un souci **local** (I/O disque, sync cloud, pack trop gros).

## Procédure standard (à tenter en premier)

Depuis le dépôt habituel :

```bash
cd ~/Desktop/fidelity && npm run deploy
```

Le script (`scripts/deploy.sh`) fait : commit s’il y a des changements, compare à `origin/main`, puis `git push origin main` quand il reste quelque chose à envoyer.

## Procédure de secours (quand `git push` échoue avec `mmap`)

**Prérequis** : même machine, [GitHub CLI `gh`](https://cli.github.com/) avec `gh auth login` déjà fait.

### 1) À jour sur la plage `origin/main..HEAD`

Dans `~/Desktop/fidelity` :

```bash
cd ~/Desktop/fidelity
git fetch origin main 2>/dev/null || true
# Vérifier qu’on a bien origin/main (sinon prendre le SHA de main sur github.com)
git rev-parse origin/main
git log --oneline origin/main..HEAD
```

Si `git fetch` est impossible, note le **SHA** du dernier commit `main` sur GitHub et remplace `origin/main` par ce SHA dans les commandes suivantes (ex. `abc1234..HEAD`).

### 2) Clone shallow dans `/tmp`

```bash
export GH_TOKEN=$(gh auth token)
rm -rf /tmp/myfidpass-deploy
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/amineprimesmr/myfidpass.git" /tmp/myfidpass-deploy
```

### 3) Appliquer **uniquement** les changements de `git diff origin/main..HEAD` (fichier de travail : `~/Desktop/fidelity`)

Copie des **ajouts** et **modifications** ; **suppressions** retirées du clone (pour rester aligné avec le diff).

```bash
SRC=~/Desktop/fidelity
cd "$SRC"
git fetch origin main 2>/dev/null || true

while IFS= read -r line; do
  [ -z "$line" ] && continue
  status=${line:0:1}
  f=${line:2}
  [ -z "$f" ] && continue
  case "$status" in
    A|M)
      mkdir -p "/tmp/myfidpass-deploy/$(dirname "$f")"
      cp -f "$f" "/tmp/myfidpass-deploy/$f"
      ;;
    D)
      rm -f "/tmp/myfidpass-deploy/$f"
      ;;
  esac
done < <(git diff --name-status --no-renames origin/main..HEAD)
```

*(Si tu utilises un SHA à la place de `origin/main`, remplace `origin/main..HEAD` par `TON_SHA..HEAD`. En cas de **rename** Git non couvert ici, refaire le rename à la main ou retirer `--no-renames` et adapter la boucle.)*

### 4) Commit + push **depuis** `/tmp/myfidpass-deploy`

Même session shell (pour réutiliser `GH_TOKEN`) :

```bash
cd /tmp/myfidpass-deploy
git add -A
git status
git commit -m "Deploy: <message court décrivant les changements>"
git push "https://x-access-token:${GH_TOKEN}@github.com/amineprimesmr/myfidpass.git" main
```

Un push réussi déclenche **GitHub → webhooks** habituels (**Railway** backend, **Vercel** frontend selon la config du repo).

### 5) (Recommandé) Réaligner le clone « cassé » sur le Bureau

Quand `git fetch` / `git pull` re-fonctionnent (ou après déplacement du dépôt hors iCloud) :

```bash
cd ~/Desktop/fidelity
git fetch origin
git reset --hard origin/main
```

Si `fetch` échoue toujours avec `mmap`, **ne pas insister** : le code à jour est sur **GitHub** ; recréer un clone neuf dans `~/Developer/fidelity` est souvent le plus simple.

## Ce qu’un **autre agent Cursor** doit faire

1. Modifier le code dans **`/Users/amine/Desktop/fidelity`** comme d’habitude.
2. Tenter **`cd ~/Desktop/fidelity && npm run deploy`** en premier.
3. Si **`git push`** échoue avec **`mmap`** (ou timeout similaire) :
   - **Ne pas** abandonner le déploiement ni renvoyer tout de suite vers une réparation Git « abstraite » si `gh` est dispo.
   - Appliquer la **procédure de secours** (clone shallow `/tmp` + aligner le working tree sur **`git diff --name-status origin/main..HEAD`** depuis `~/Desktop/fidelity` + **push** avec `GH_TOKEN` / `gh auth token`).
4. Confirmer le déploiement en vérifiant le dernier commit sur `main` (API `gh api repos/.../commits/main` ou page GitHub).
5. Expliquer clairement à l’utilisateur que le blocage venait du **Git local / disque / iCloud**, pas du SaaS.

## Prévention (pour l’utilisateur)

- Travailler dans **`~/Developer/...`** plutôt que **`~/Desktop/...`** si le Bureau est synchronisé iCloud.
- Garder **de l’espace disque** libre.
- Optionnel : remote **SSH** au lieu de HTTPS (`git@github.com:amineprimesmr/myfidpass.git`) si HTTPS pose problème en réseau.

## Historique (contexte projet)

- Dépôt GitHub : `amineprimesmr/myfidpass` (monorepo **fidelity** frontend + backend à la racine ou sous-dossiers selon structure actuelle).
- Déploiements : **Vercel** (frontend), **Railway** (backend Node) — déclenchés par push sur `main` après intégration GitHub.

---

*Document rédigé pour être copié-collé à un autre agent ou relu par un humain.*
