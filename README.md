> [!IMPORTANT] <h1>⚠️ AVIS DE NON-RESPONSABILITÉ ET LIMITATION DE RESPONSABILITÉ</h1>
<h2><br>1. Nature des contenus et risques associés<br>
L'utilisateur est expressément informé que les codes en langage assembleur (ASM) fournis au sein de ce dépôt GitHub manipulent directement les ressources matérielles et les composants d'infrastructure. Une utilisation incorrecte, non sécurisée ou détournée de ces codes comporte des risques importants de sécurité informatique, pouvant entraîner des dysfonctionnements matériels, des pertes de données ou l'exploitation de vulnérabilités par des tiers (hacking matériel).<br>
<br>2. Exclusion de responsabilité<br>
Ces codes sont mis à disposition à titre purement informatif, « en l'état » (as is), et sans aucune garantie d'aucune sorte, expresse ou implicite.<br>
En aucun cas l'auteur du code ne pourra être tenu responsable des dommages directs, indirects, accessoires ou consécutifs (y compris, sans s'y limiter, les intrusions informatiques, piratages, pertes de données ou bris de matériel) résultant de l'utilisation, de la modification ou de la distribution de ces codes, de quelque manière que ce soit.<br>
<br>3. Responsabilité de l'utilisateur<br>
Il incombe à l'utilisateur final de s'assurer de la sécurisation de son environnement, de la conformité de ses actions avec le Code pénal français (notamment les articles 323-1 et suivants relatifs aux atteintes aux systèmes de traitement automatisé de données), et d'assumer l'entière responsabilité des conséquences de l'exécution de ces programmes.</h2>

<br><br>

<h3>Bienvenue sur ce répertoire qui permet d'effectuer du DLL Engineering.
Il a été conçu dans le but de servir d'extension à un interpréteur (fr-simplecode, <a href="https://github.com/argentrocher/fr-simplecode">voir le github</a>).</h3>
<br><br>

<h3>frc_service.dll</h3>

La première version de frc_service.dll est un système qui permet d'appeler des dll en fournissant un argument (char*) sous le format :
<br>
<pre>dllname;functionname;returntype;arg1type;arg1content;arg2type;arg2content; ... </pre> Jusqu'à 10 arguments.
<br>
Le retour de la fonction varie en fonction du type selectionné comme retour de fonction si il est pris en charge par fr-simplecode (accepte: <code>char;bool;int;double</code> en entrée réel.)
<br><br>
Les arguments de retour <code>returntype</code> acceptés sont :
<br>
<code>char;bool;int;double;addr;hex</code>. 
<br><code>hex</code> attend un numéro int après hex. Ex: <code>hex10</code>. renvoie 10 oct en big endians sous format (char*).
<br><code>addr</code> renvoie l'addr d'entrée sous format (char*).
<br><code>pointor</code> : spécification qui signal que l'on appel pas une fonction mais une variable. L'ensemble des autres arguments peut être joint. Ex: <code>pointorint</code> attend un tampon mémoire contenant un int.
<br><br>
Les arguments d'entrée <code>argNtype</code> sont les mêmes à l'exception de <code>pointor</code>.
<br><br>

<h3>frc_service2.dll</h3>

Le même code que frc_service.dll à l'exception que le parsing d'argument accepte :
<br>
<code>;</code> comme séparateur sauf si il est précéder d'un anti slash <code>&#92;;</code>. 
<br>
Deux anti slash <code>&#92;&#92;</code> deviennent un anti slash <code>&#92;</code>.
<br>Ex: <pre>msvcrt.dll;printf;int;char;hello &#92;&#92; world &#92;; !
Affiche: 
hello &#92; world ; !</pre>

<br><br>

<h3>test_table.dll</h3>

L'API est en cour d'écriture pour rajouter à frc_service.dll le moyen de passer des structures en mémoire qui sont compatible en C/windows.
Le code est déjà fonctionnel pour l'écriture, il manque encore la modification de valeur de structure existante et la lecture d'une structure de réponse.

<br><br>

> [!TIP]  <h3>Pour compiler L'ASM, utiliser le compilateur asm_cpp64.exe de mon répertoire <a href="https://github.com/argentrocher/FRX">FRX</a></h3>


