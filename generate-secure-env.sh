#!/bin/bash

set -eu

generate_password() {
    openssl rand -base64 32 | tr -d /=+ | cut -c -24
}

# Fonction pour remplacer ou ajouter une variable dans le fichier .env
set_env_var() {
    local key=$1
    local value=$2
    local file=.env
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        echo "${key}=${value}" >> "$file"
    fi
}

# Vérifier si le fichier .env existe, sinon le copier depuis .env-example
if [ ! -f .env ]; then
    cp .env-example .env
    echo "Fichier .env créé à partir de .env-example"
fi

# Générer et définir les mots de passe
set_env_var "MYSQL_ROOT_PASSWORD" "$(generate_password)"
set_env_var "MYSQL_PASSWORD" "$(generate_password)"
set_env_var "WORDPRESS_DB_PASSWORD" "$(generate_password)"
set_env_var "WP_ADMIN_PASSWORD" "$(generate_password)"

# Générer un nom d'utilisateur admin WordPress aléatoire
set_env_var "WP_ADMIN_USER" "admin_$(openssl rand -hex 4)"

echo "Les mots de passe sécurisés ont été générés et ajoutés au fichier .env"
echo "Assurez-vous de compléter les autres variables comme DOMAIN, EMAIL, SERVER_IP, etc."
echo "IMPORTANT : Conservez une copie sécurisée de ces informations d'identification."

# Définir les permissions appropriées pour le fichier .env
chmod 600 .env

echo "Les permissions du fichier .env ont été restreintes (chmod 600)."