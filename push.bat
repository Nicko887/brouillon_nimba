@echo off
:: --- 1. Connexion avec token externe ---
git config --global credential.helper store

:: On copie le token depuis le fichier externe
copy "C:\Users\eunic\OneDrive\Documents\NICODEME\credentials.txt" "%USERPROFILE%\.git-credentials" > nul

:: --- 2. Ajout des fichiers + commit ---
git add .
git commit -F commit_message.txt

:: --- 3. Envoi sur GitHub ---
git push origin main

:: --- 4. Déconnexion (on supprime le token) ---
del "%USERPROFILE%\.git-credentials"
git config --global --unset credential.helper

echo ✅ Terminé : commit + push + déconnexion.
pause
```

---

### 3️⃣ `C:\Users\eunic\OneDrive\Documents\NICODEME\NimbaPro\commit_message.txt`
```
Mise à jour du projet NimbaPro