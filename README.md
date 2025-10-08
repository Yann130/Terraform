# 🚀 Déploiement d'une infrastructure Azure avec Terraform et Vault

## 🧩 Objectif

Ce projet a pour but de **déployer automatiquement une infrastructure Azure** prête à accueillir un cluster Kubernetes léger (**K3s**) à l’aide de **Terraform**.  
La configuration met également en place une intégration avec **HashiCorp Vault** pour la gestion sécurisée des secrets (clé SSH, nom d’utilisateur, IP publique…).

---

## 🏗️ Architecture déployée

L’infrastructure déployée comprend :

- **1 groupe de ressources Azure**
  - `rg-k3s-demo`

- **1 réseau virtuel (VNet)**  
  - `vnet-k3s` avec le CIDR `10.0.0.0/16`

- **2 sous-réseaux (subnets)**  
  - `subnet-master` : pour le nœud maître K3s  
  - `subnet-worker` : pour le nœud worker

- **1 Network Security Group (NSG)**  
  - `nsg-k3s` : autorise SSH (port 22) et les communications internes entre les VMs

- **1 adresse IP publique (Standard SKU)**  
  - `publicip-k3s` : associée à la machine virtuelle master

- **2 interfaces réseau (NIC)**  
  - `nic-master` connectée au subnet master  
  - `nic-worker` connectée au subnet worker

- **2 machines virtuelles Linux (Ubuntu 20.04 LTS)**  
  - `vm-master` : servira de control plane  
  - `vm-worker` : servira de nœud worker  

---

## 🔐 Gestion des secrets avec HashiCorp Vault

Les secrets sensibles (utilisateur SSH, clé publique, IP publique) ne sont **pas stockés dans le code Terraform**.  
Ils sont **gérés dynamiquement** dans Vault :

L'IP public est récuperer automatiquement avec le fichier **vault.tf** après le déploiement et est stock" dans le vault.

Le token du vault est stocké dans un fichier **variable.tf** qui est en local.

Le username et la clé ssh sont également stocké dans le vault.



