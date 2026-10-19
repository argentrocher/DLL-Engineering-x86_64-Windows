ASM64CPP
//blob

include default:

; asm_cpp64 test_table.asm test_table.dll --dll

; 8oct=QWORD
; 4oct=DWORD
; 2oct=WORD
; 1oct=BYTE

; architecture du tableau (tampon global)
; |					reserver (8oct)					|  ; malloc si besoin
; |			taille global du tableau (8oct)			|  ; début inclu

; véritable contenu de chaque tableau (entête 20 oct constant), padding n'est pas inclu mais est toujours présent car rajouté après

; |		   addr du tableau suivant (8oct)			| ; entête
; |			taille de ce tableau (8oct)				| ; entête
; |		nombre de case dans le tableau (4oct)		| ; entête
; -	option active, enregistre le max padding (4oct)	- ; optionnel rajouter (donnée du tableau)
; |	   padding final après dernière case (4oct) 	| ; donnée du tableau
; |			taille de la case 1 (8oct)				| ; donnée du tableau
; |			taille de la case 2 (8oct)				| ; donnée du tableau
; |			taille de la case ... (8oct)			| ; donnée du tableau
; |		  contenu de la case 1 (variable)			| ; contenu formaté
; |		  contenu de la case 2 (variable)			| ; contenu formaté
; |		  contenu de la case ... (variable)			| ; contenu formaté
; |			   padding final de case 				|
; |				  nouveau tableau					|


; avant utilisation, faire appel à init_table_global qui vide le contenu global et instore l'adresse de taille du tampon.

global DllMain :  

section .data

;tampon static de mémoire
little table_size 0x000186A0 ; taille du tableau static
buffer table 100000 ; créer le tableau static
buffer marge 20 ; marge car l'analise de création peut dépasser de 20 oct pour vérifier que vide
little table_type 0x00000000 ; valeur 0 au démarage comme non Initialiser (on peut donc définir le paramètre au premier init_table_global)

;debug
ascii debug ">> %d.\n"
ascii debug1 ">> 0x%08x.\n"
ascii debug2 ">> 0x%016llx.\n"
ascii debug22 ">> 0x%016llx, 0x%016llx.\n"
ascii debug3 ">> %s.\n"
ascii debug33 ">> %s, %s.\n"
ascii debug4 "%02x "
ascii debug_zone "...\n"

ascii debug2_union "nombre d'element dans union restant : 0x%016llx.\n"
ascii debug2_pack "nombre de pack : 0x%016llx.\n"
ascii debug2_paddingmax "taille max de padding : 0x%08x.\n"
ascii debug2_arg "nombre d'argument : 0x%08x.\n"
ascii debug2_malloctmp "adresse du tampon malloc : 0x%016llx.\n"
ascii debug2_mallocsize "taille du tampon malloc : 0x%016llx.\n"

;detection de type
ascii _bool "bool" ; valeur 0 ou 1 ou true false (1 oct)
ascii _CHAR "CHAR" ; 1 caractère converti en 1 octet directement
ascii _BYTE "BYTE" ; 1 octet hex (copier) (-> join avec hex1)
ascii _WORD "WORD" ; 2 octets hex (copier) (-> join avec hex2)
ascii _DWORD "DWORD" ; 4 octets hex (copier) (-> join avec hex4)
ascii _QWORD "QWORD" ; 8 octets hex (copier) (-> join avec hex8)
ascii _int "int" ; valeur int (taille DWORD signé)
ascii _long_int "long_int" ; valeur int étendu (taille QWORD signé)
ascii _double "double" ; valeur double (8 oct flotant)
ascii _char "char" ; chaine fournit copier avec \0 (pour n'enregistré que un ptr, utiliser addr)
ascii _addr "addr" ; ptr 8 octets hex (copier)
ascii _hex "hex" ; hex suivit d'un nombre int nombre d'octet (copier)
ascii _struct "struct" ; est une adresse d'une autre table d'ont l'ensemble sera copier, utiliser addr pour n'avoir que le pointeur

ascii _union "union" ; alignement de la structure (argument int corespond au nombre de valeur suivante que l'on veut à la même adresse, prend la taille la plus grande uniquement)
ascii _pack "pack" ; utiliser dans la structure pour dire si l'on veux respecter l'alignement automatique (0 valeur par défaut d'alignement, autre valeur, tasse a la valeur demander)

ascii _pointor "pointor" ; pas utiliser dans tableau

ascii _true "true"
ascii _false "false"

; erreur
utf16 error_mem "erreur : allocation mémoire !\n"
utf16 error_arg_invalid "erreur : arguments fournit invalide (doit être type;contenu).\n"
utf16 error_arg_invalid_key "erreur : aumoins un argument à un type inconnu (format type;contenu).\n"
utf16 error_arg_invalid_value "erreur : aumoins un argument à un contenu invalide (format type;contenu).\n"

section .idata

msvcrt.dll printf wprintf isdigit free malloc realloc _aligned_malloc _aligned_free memset memcpy
kernel32.dll GetProcessHeap HeapWalk

section .edata

local parse_table_argument parse_table_argument_new ; debug, sera supprimer

local init_table_global ; obligatoire pour choisir le mode de stockage et initialiser
local create_table ; créer un tableau en fournissant un char* return ptr de tableau ou NULL si err
local append_table ; ajoute des éléments dans un tableau existant en fournissant un ptr de tableau et un char* return nouveau ptr de tableau ou NULL si err (la conservation du tableau d'origine n'est pas garanti)
local get_struct_from_table ; return ptr de la structure compatible C/windows dans un tableau en fournissant un ptr de tableau (sans alignement)
local get_struct_from_table_alloc ; return ptr de la structure valide C/windows dans un tableau en fournissant un ptr de tableau (avec alignement, doit être free)
local free_struct_from_table_alloc ; libère structure valide C/windows fournit par ptr avec get_struct_from_table_alloc

section .text

proc DllMain
    mov eax, 1
    ret
end DllMain

proc est_alloue
    ; Prologue
    push rbp
    mov rbp, rsp
    sub rsp, 60h                ; Allouer de l'espace pour les variables locales

    ; Sauvegarder rcx (ptr) dans une variable locale
    mov [rbp-8h], rcx         ; ptr = rcx

	xor rcx, rcx

    ; Appeler GetProcessHeap()
	mov rax, [rip+@GetProcessHeap]
    call rax
    mov rcx, rax               ; rcx = HANDLE heap

    ; Initialiser PROCESS_HEAP_ENTRY
    lea rdx, [rbp-40h]         ; rdx = &entry
    mov qword ptr [rdx], 0     ; entry.lpData = NULL

.boucle_HeapWalk:
    ; Appeler HeapWalk(heap, &entry)
    xor r8, r8                 ; r8 = NULL (paramètre supplémentaire si nécessaire)
	mov rax, [rip+@HeapWalk]
    call rax

    ; Vérifier si HeapWalk a échoué
    test eax, eax
    jz .fin_boucle              ; Si HeapWalk retourne 0, fin de la boucle

    ; Vérifier si le bloc est occupé (PROCESS_HEAP_ENTRY_BUSY)
    movzx r8, word ptr [rbp-40h+12h] ; r8 = entry.wFlags
    and r8, 4                  ; PROCESS_HEAP_ENTRY_BUSY = 0x4
    jz .boucle_HeapWalk         ; Si non occupé, continuer

    ; Comparer entry.lpData avec ptr
    mov rax, [rbp-40h]          ; rax = entry.lpData
    mov r8, [rbp-8h]           ; r8 = ptr
    cmp rax, r8
    jne .boucle_HeapWalk        ; Si différent, continuer

    ; Si trouvé, retourner 1
    mov eax, 1
    jmp .fin

.fin_boucle:
    ; Si non trouvé, retourner 0
    xor eax, eax

.fin:
    ; Épilogue
    add rsp, 60h
    pop rbp
    ret
end est_alloue


;rcx pointeur, rax sortie hex
proc hex_addr_hex
	sub rsp, 28h
    mov [rsp+20h], rbx
    mov [rsp+18h], rsi
    mov [rsp+10h], rdi
    mov [rsp+8h], rcx

    mov rsi, rcx

    lea rax, [rip+@asm_strlen]
    call rax
	mov rbx, rax

    ; Vérifier si la longueur > 16 (64 bits max)
    cmp rax, 16
    ja .error

    xor rax, rax
    ; RSI = pointeur sur la chaîne, RDI = index
    xor rdi, rdi

	.convert_loop:
    ; Si index >= longueur, on a fini
    cmp rdi, rbx
    jae .done

    ; Charger le caractère actuel dans RCX (étendu sur 64 bits)
    mov cl, byte ptr [rsi + rdi]

    ; Vérifier si c'est un digit (0-9)
    cmp cl, '0'
    jb .invalid_char
    cmp cl, '9'
    jbe .is_digit

    ; Vérifier si c'est une lettre (A-F)
    cmp cl, 'A'
    jb .check_lowercase
    cmp cl, 'F'
    jbe .is_uppercase

	.check_lowercase:
    cmp cl, 'a'
    jb .invalid_char
    cmp cl, 'f'
    ja .invalid_char
    sub cl, 'a' - 10       ; Convertir a-f en 10-15
    jmp .got_value

	.is_uppercase:
    sub cl, 'A' - 10       ; Convertir A-F en 10-15
    jmp .got_value

	.is_digit:
    ; Convertir 0-9 en valeur (0-9)
    sub cl, '0'

	.got_value:
    ; Garder seulement les 4 bits bas (valeur 0-15)
    and rcx, 0Fh
    ; Déplacer RAX de 4 bits et ajouter la nouvelle valeur
    shl rax, 4
    or rax, rcx
    ; Passer au caractère suivant
    inc rdi
    jmp .convert_loop

	.invalid_char:
	.error:
    ; Erreur : RCX = 1
    mov rcx, 1
    jmp .cleanup

	.done:
    ; Succès : RCX = 0
    xor rcx, rcx

	.cleanup:
    ; Restaurer RBX, RSI, RDI (RCX contient le code d'erreur)
    mov rbx, [rsp+20h]
    mov rsi, [rsp+18h]
    mov rdi, [rsp+10h]
    add rsp, 28h
    ret
end hex_addr_hex

; RCX = ptr de chaine qui représente de l'hexadécimal
; RDX != 0 ajoute un cartet 0 à gauche si le nombre de cartet est impair
; return RAX = ptr de RCX en hexadécimal
; retrun RCX 1 = err 0 = ok
; return RDX = nombre d'octet
proc hex_char_hex_v2
	sub rsp, 38h
    mov [rsp+20h], rbx
    mov [rsp+18h], rsi
    mov [rsp+10h], rdi
	; sauvgarde du paramètre d'ajout de cartet à gauche
    mov [rsp+30h], rdx
	
    mov rsi, rcx
	
	lea rax, [rip+@asm_strlen]
    call rax
	cmp rax, 0
	je .error
	
	mov rcx, rsi
	.skip_space:
	dec rax
	mov dl, byte ptr [rcx+rax]
	cmp dl, ' '
	je .skip_space
	cmp dl, '\t'
	je .skip_space
	cmp dl, '\n'
	je .skip_space
	cmp dl, '\r'
	je .skip_space

	inc rax
	
    ; RSI = pointeur sur la chaîne, RDI = index
    xor rdi, rdi
	
	mov rdx, 0 ; savoir si on écrit dans le haut ou le bas (0 ou 1 de rax)
	mov rbx, 0 ; savoir sur quel emplacement écrire rax chargé

	test rax, 1 ; la taille de la chaine est impair donc on vérifie si on doit ajouter un cartet
	jnz .cartet_imp
	
	xor rax, rax
	jmp .convert_loop
	
	; vérifier si on veux un cartet 0 à gauche
	.cartet_imp:
	xor rax, rax
	mov rcx, [rsp+30h]
	test rcx, rcx
	jz .convert_loop
	
	; on doit ajouté un cartet 0 à gauche donc on met juste rdx à 1 pour dire qu'il y a déjà dans rax le haut
	mov rdx, 1 ; état écrire dans le bas

	.convert_loop:
    ; Charger le caractère actuel dans RCX (étendu sur 64 bits)
    mov cl, byte ptr [rsi + rdi]

    ; Vérifier si c'est un digit (0-9)
    cmp cl, '0'
    jb .invalid_char
    cmp cl, '9'
    jbe .is_digit

    ; Vérifier si c'est une lettre (A-F)
    cmp cl, 'A'
    jb .check_lowercase
    cmp cl, 'F'
    jbe .is_uppercase

	.check_lowercase:
    cmp cl, 'a'
    jb .invalid_char
    cmp cl, 'f'
    ja .invalid_char
    sub cl, 'a' - 10       ; Convertir a-f en 10-15
    jmp .got_value

	.is_uppercase:
    sub cl, 'A' - 10       ; Convertir A-F en 10-15
    jmp .got_value

	.is_digit:
    ; Convertir 0-9 en valeur (0-9)
    sub cl, '0'

	.got_value:
	; Garder seulement les 4 bits bas (valeur 0-15)
    and rcx, 0Fh
    ; Déplacer RAX de 4 bits et ajouter la nouvelle valeur
    shl rax, 4
    or rax, rcx
	
	cmp rdx, 0
	je .above
	
	;below on rend rax dans la chaine par 1 octet
	mov rdx, 0
	mov byte ptr [rsi + rbx], al
	xor rax, rax
	inc rbx
	inc rdi
	jmp .convert_loop
	
	.above:
	mov rdx, 1
    ; Passer au caractère suivant
    inc rdi
    jmp .convert_loop

	.error:
    ; Erreur : RCX = 1
    mov rcx, 1
    jmp .cleanup

	.drop_end:
	; finir si nombre impaire de charactère
	mov rdx, 0
	shl rax, 4
	mov byte ptr [rsi + rbx], al
	xor rax, rax
	inc rbx

	.invalid_char:
	cmp rdx, 1
	je .drop_end
	; ecrire le dernier octet en 00
	xor rax, rax
	mov byte ptr [rsi + rbx], al
	
    ; Succès : RCX = 0
    xor rcx, rcx
	
	mov rax, rsi ; donne l'adresse de rcx (car modifier le contenu)

	mov rdx, rbx ; donne le nombre d'octet sur rdx

	.cleanup:
    ; Restaurer RBX, RSI, RDI (RCX contient le code d'erreur)
    mov rbx, [rsp+20h]
    mov rsi, [rsp+18h]
    mov rdi, [rsp+10h]
    add rsp, 38h
    ret
end hex_char_hex_v2


; init du tableau contexte
; void * init_table_global(int table_type)
; la valeur int table_type est 0 par défaut, pas de tampon de 4 oct qui sauvgarde le max de padding
; int table_type = 1, active la sauvgarde avec le tampon de 4 oct qui sauvgarde le max de padding
; ecx = table_type
proc init_table_global
	sub rsp, 38h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	
	; changer l'état de table_type à 0
	mov dword ptr [rip+@table_type], 0
	test ecx, ecx
	jz .false_table_type
	; changer l'état de table_type à 1
	mov dword ptr [rip+@table_type], 1
	.false_table_type:
	
	lea rsi, [rip+@table]
	mov rcx, [rsi+16] ;adresse du premier sous tableau
	mov rdx, rsi ; adresse du tableau global
	; free les tableau malloc si présent
	lea rax, [rip+@free_all_table_memory]
	call rax
	
	; nétoyé la mémoire
	mov rcx, rsi ; adresse du début de la table
	mov rdx, 0 ; remplir de 0
	mov ebx, dword ptr [rip+@table_size] ; taille a effacer
	lea r8, dword ptr [ebx]
	mov rax, [rip+@memset]
	call rax
	
	;debug, affiche l'adresse de la table static
	lea rcx, [rip+@debug2]
	lea rdx, [rip+@table]
	mov rax, [rip+@printf]
	call rax
	; affiche la valeur de table_type
	lea rcx, [rip+@debug1]
	mov edx, [rip+@table_type]
	mov rax, [rip+@printf]
	call rax
	
	; écriture de la taille du tampon tableau global à l'adresse indiquer
	add rsi, 12
	mov dword ptr [rsi], ebx
	
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 38h
	ret
end init_table_global

; RCX = addr ;vérifie que l'adresse rcx est valide dans la plage, sinon, il faut maloc (RAX = 1 valide, 2 malloc, 0 invalide)
; RDX = addr du tampon tableau global
proc isvalid_zone
	mov r8, rdx
	cmp rcx, r8
	jb .alloc
	mov rdx, [r8+8] ;deuxième adresse = taille tampon global si init
	test rdx, rdx
	jz .invalid_val
	add r8, rdx
	cmp rcx, r8
	ja .alloc
	mov rax, 1
	jmp .end
	.alloc:
	mov rax, 2
	jmp .end
	.invalid_val:
	xor rax, rax
	.end:
	ret
end isvalid_zone

; RCX = addr ; ptr de tableau
; return RAX ; alignement estimé ou exacte si il y a table_type à 1 (l'estimation se fait par calcul et est une puissance de 2)
proc estimate_alignment_for_table
	sub rsp, 38h
	mov [rsp+20h], rbx
	mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	xor rbx, rbx
	
	; vérifer qu'il y a une taille
	mov rdx, [rcx+8]
	test rdx, rdx 
	jz .end ; NULL = invalide
	
	mov eax, [rip+@table_type]
	test rax, rax
	jnz .exact_value
	
	; vérifier qu'il y est une taille suffisante pour lire la valeur
	; minimum 20 d'entête + 4 de taille de padding final + 8 de première case + minimum 1 oct de contenu, soit 33 oct
	cmp rdx, 33
	jb .end ; insuffisant, return 0
	
	mov rsi, rcx ; sauvgarde du ptr pour analyse du contenu si il y a bien des 0 au début du contenu équivalent, on peut estimé que c'est du padding
	
	xor r8, r8
	mov r8d, dword ptr [rcx+16] ; récupérer le nombre de case à parcourir
	
	mov rax, 8 ; taille de l'entête de chaque case
	mul r8 ; rax*r8 = taille du début du contenu
	mov rdi, rax ; mettre dans rdi un compteur de taille pour pointer sur le début du contenu
	
	add rcx, 24 ; déplacer le ptr de 24 qui se place sur la première valeur de taille à lire
	mov rbx, 1 ; 1 minimum, est décaler avec shl pour faire les puissances et comparer
	
	xor rax, rax
	.boucle_estimate_alignment:
	cmp r8d, 0
	je .end
	add rdi, rax ; taille qui montre le début du contenu de la case visé
	dec r8d
	mov rax, [rcx] ; li la taille de la case
	add rcx, 8 ; ptr sur la taille de case suivante si présente
	cmp rax, rbx ; rax <= rbx on ignore
	jbe .boucle_estimate_alignment
	.boucle_add_alignement:
	shl rbx, 1 ; décalage de 1 bit vers la gauche donc augmente la puissance de 2
	mov rdx, 0x8000000000000000
	cmp rbx, rdx
	jae .end ; maximum possible
	cmp rax, rbx ; rax > rbx on continue
	ja .boucle_add_alignement
	; rax = rbx : strictement égaux donc il n'y a pas de padding
	je .boucle_estimate_alignment
	
	cmp rbx, 1
	je .boucle_estimate_alignment
	
	; vérifier si dans la différence de rbx-rax il n'y a pas que des 0, si oui, on peut estimé l'alignement bon sans réduire de une puissance de 2
	mov r9, rbx
	sub r9, rax
	.boucle_check_zero_padding:
	add rdi, r9
	mov dl, byte ptr [rsi+rdi-1] ; 8-7=1 mais on ne teste pas 1, on teste l'oct 0
	sub rdi, r9
	cmp dl, 0 ; pas que des 0 au début, on ne réduit pas 
	jne .boucle_estimate_alignment
	dec r9
	cmp r9, 0
	ja .boucle_check_zero_padding
	
	shr rbx, 1 ; remettre le décalge d'une puissance de 2 de moins car il y a le padding avec
	jmp .boucle_estimate_alignment
	
	
	.exact_value:
	; vérifier qu'il y est une taille suffisante pour lire la valeur
	; minimum 20 d'entête + 4 d'option max padding + 4 de taille de padding final + 8 de première case + minimum 1 oct de contenu, soit 37 oct
	cmp rdx, 37
	jb .end ; insuffisant, return 0
	
	; lire la valeur
	mov ebx, dword ptr [rcx+20]
	
	.end:
	mov rax, rbx
	mov rbx, [rsp+20h]
	mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 38h
	ret
end estimate_alignment_for_table

; RCX = addr ; depart des 0 à vérifier sur la taille
; RDX = taille ; vérifier si il n'y a que des 0, c'est qu'on a le droit de prendre la case car les cases sont netoyer 
proc have_place
	mov r8, 0
	
	.boucle:
	cmp r8, rdx ;r8 >= rdx
	jae .true
	mov al, byte ptr [rcx]
	cmp al, 0
	jne .false
	inc rcx
	inc r8
	jmp .boucle
	
	.false:
	xor rax, rax
	ret
	.true:
	mov rax, 1
	ret
end have_place

; RCX = addr du premier sous tableau, libère mais n'efface pas, il faut remettre tout à 0
; RDX = addr du tampon tableau global
; pas de return
proc free_all_table_memory
	sub rsp, 38h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	
	mov [rsp+48h], rdx ; mettre dans le tas du callee
	
	mov rsi, [rip+@free] ;on ne déplace qu'une fois à rsi pour avoir l'adresse de free
	
	.boucle:
	cmp rcx, 0
	je .end
	mov rbx, rcx
	mov rdx, [rsp+48h]
	lea rax, [rip+@isvalid_zone]
	call rax
	mov rcx, [rbx]
	cmp rax, 2
	jne .boucle
	
	; la variable est allouer, on la libère, on a déjà l'adresse de la suivante dans rcx que l'on sauvgarde dans rdi donc ok
	mov rdi, rcx
	mov rcx, rbx
	call rsi
	mov rcx, rdi
	jmp .boucle
	
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 38h
	ret
end free_all_table_memory

; RCX = addr ; premier sous tableau dans le tableau principal (premier addr du tableau suivant (8oct), normalement tableau principal + 16 oct)
; RDX = addr ; adresse à remplacer par une nouvelle
; R8 = addr ; adresse de remplacement
; return RAX = 1 si trouvé, 0 sinon
proc change_addr_refer_table
	.boucle:
	mov rax, rcx ; sauvgarde du pointeur pour changer sa valeur
	mov rcx, [rcx]
	cmp rcx, 0
	je .false
	cmp rdx, rcx
	jne .boucle
	mov [rax], r8
	jmp .true
	.false:
	xor rax, rax
	ret
	.true:
	mov rax, 1
	ret
end change_addr_refer_table

; RCX = addr ; début du tableau (static global)
; RDX = addr ; emplacement d'écriture du tableau (position : addr du tableau suivant (8oct))
; R8 = taille ; a allouer/modifier memoire (entête non inclu de 20 octets automatique)
; return RAX adresse RDX ok, 0 erreur
proc alloc_table
	sub rsp, 58h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	mov [rsp+40h], rdx
	mov [rsp+48h], r8
	
	; si rdx est nulle, c'est que l'on doit juste créer une nouvelle table
	test rdx, rdx
	jz .create_new_table
	
	; test que rdx est valide
	mov rdx, rcx
	mov rcx, [rsp+40h]
	lea rax, [rip+@isvalid_zone]
	call rax
	cmp rax, 1
	jne .in_malloc
	
	; Si 1, la taille disponible est elle suffisante ?
	; On regarde si c'est une case qui à un suivant car il faut décaler si insuffisant ou utiliser malloc/realloc
	mov rdx, [rsp+40h]
	mov rax, [rdx]
	cmp rax, 0
	jne .have_next_value
	
	; le suivant est allouer mais pas la position actuel, on verifie la taille disponible, sinon on alloc aussi un nouveau tampon
	.this_is_malloc:
	
	;verife la taille déjà présente si suffisante, juste changer ça valeur
	mov rdx, [rsp+40h]
	mov rdx, [rdx+8] ;taille déjà disponible
	mov r8, [rsp+48h]
	add r8, 20 ; taille + 20 d'entête
	cmp rdx, r8  ; rdx >= r8 ; la taille disponible est suiffisante, on change la taille
	jae .set_size
	
	; mettre rsi à la valeur finale
	mov rsi, [rsp+40h]
	add rsi, r8	; adresse du dernier octet à prendre
	mov rax, 0 ; rax = malloc
	jmp .have_not_next_value
	
	.have_next_value:
	;verifier si l'adresse suivante est ailleur que dans la table
	;récupérer la taille de ce tableau
	mov rcx, [rsp+38h]
	mov rdx, rcx
	mov r8, [rcx+8]
	add rcx, r8 ; adresse de fin du tableau
	cmp rax, rcx ; rax > rcx
	ja .this_is_malloc
	cmp rax, rdx ; rax < rdx
	jb .this_is_malloc
	
	;normal on décale si besoin/ si possible
	;verife la taille déjà présente si suffisante, juste changer ça valeur
	mov rdx, [rsp+40h]
	mov rdx, [rdx+8] ;taille déjà disponible
	mov r8, [rsp+48h]
	add r8, 20 ; taille + 20 d'entête
	cmp rdx, r8  ; rdx >= r8 ; la taille disponible est suiffisante, on change la taille
	jae .set_size
	
	; verifie par rapport à la taille de l'adresse suivante
	mov rsi, [rsp+40h]
	mov rdx, [rsi] ; adresse de la case suivante
	add rsi, r8	;adresse du dernier octet à prendre
	cmp rdx, rsi ; rdx > rsi donc l'adresse du tableau suivant (rdx) est plus loin et assez d'espace disponible (car rdx n'est pas null 0 ni alloc)
	ja .set_size
	
	; Ici, il n'y a pas de place ou pas de suivant. On regarde si il n'y a pas de suivant si on peut prendre.
	mov rax, 0 ; in_malloc doit malloc donc rax = 0
	cmp rdx, 0 ; rdx n'est pas nul, il y a donc une case après et pas assez de place, il faut malloc
	jne .in_malloc
	
	; l'adresse suivante est nulle
	.have_not_next_value:
	
	; recuperation de l'adresse de fin de tableau
	mov rcx, [rsp+38h]
	mov r8, [rcx+8]
	add rcx, r8
	cmp rcx, rsi ; rcx < rsi donc l'adresse de fin de tableau est avant le nombre d'octet requit, on doit malloc
	jb .in_malloc
	; on verifie que même si il n'y a pas de case de tableau, il peut y en avoir comme même mais pas directement,
	; comme la mémoire est nétoyer remise à 0 quand on quitte, déplace une case du tableau statique, on vérifie qu'il y a asser de 0.
	mov r8, [rsp+48h]
	add r8, 20 ; entête
	mov rdx, [rsp+40h]
	mov rdx, [rdx+8] ; taille déjà disponible potentielement déjà avec des valeurs (contient déjà l'entête)
	sub rsi, r8
	add rsi, rdx
	; supprimer car faux je pense car c une taille inc rsi ; +1 car le dernier octet pris peut être utiliser
	mov rcx, rsi ; debut des 0
	sub r8, rdx  ; retirer à la taille voulu la taille existante
	mov rdx, r8  ; taille de 0 attendu (si on rencontre une entête on stoppe)
	add rdx, 20  ; + taille d'entête pour ne pas en écrasé une par hazard
	lea rax, [rip+@have_place]
	call rax
	cmp rax, 0  ; rax = 0 donc in_malloc ok pour malloc
	je .in_malloc
	jmp .set_size ;ok, rien après, on peut définir la taille voulu
	
	; celui ci est à malloc/realloc (rax = 0 malloc sinon rax = 2 realloc)
	.in_malloc:
	mov rdx, [rsp+40h]
	; malloc ou realloc
	cmp rax, 0
	jne .for_realloc
	
	; sinon on verifie si il y a quelque chose à copier puis à netoyer
	mov rsi, rdx ; adresse du tampon à copier
	mov rdi, [rdx+8] ; taille avec entête à copier
	mov rcx, [rsp+48h] ; nouvelle taille + 20
	add rcx, 20 ; entête
	mov rax, [rip+@malloc]
	call rax
	cmp rax, 0
	je .erreur
	mov rbx, rax
	mov qword ptr [rbx], 0 ; pas de suivant pour ne pas lire du déchêt
	; changer l'adresse de référence sur les tableaux précédents si existe
	mov rcx, [rsp+38h]
	mov rcx, [rcx+16] ; addr premier sous tableau dans le tableau principal
	mov rdx, rsi ; adresse à remplacer
	mov r8, rbx ; adresse de remplacement
	lea rax, [rip+@change_addr_refer_table]
	call rax ; renvoie 1 si ok ou 0 mais pas besoin de la réponse
	
	; copie dans rbx = rax la taille indiquer rdi depuis la source rsi
	mov rax, 0
	.copy_byte:
	cmp rax, rdi
	jae .end_copy_byte
	mov cl, byte ptr [rsi+rax]
	mov byte ptr [rsi+rax], 0 ; netoyage de la source
	mov byte ptr [rbx+rax], cl
	inc rax
	jmp .copy_byte
	
	.end_copy_byte:
	mov [rsp+40h], rbx ; nouvelle adresse de rdx
	; si il n'y a pas encore d'adresse malloc à free, on l'ajoute dans l'entête du tableau global
	mov rcx, [rsp+38h]
	mov rdx, [rcx]
	cmp rdx, 0
	jne .set_size
	mov [rcx], rbx ; copie de l'adresse malloc
	jmp .set_size
	
	.for_realloc:
	mov rdi, rdx ; adresse du tampon d'origine
	; verifier si cette adresse est la première a avoir été alloué
	mov rcx, [rsp+38h]
	mov rax, [rcx]
	cmp rax, rdx ; rax = rdx donc c'est le premier à être malloc
	je .is_first_malloc
	mov rsi, 0 ; object rsi null
	jmp .is_not_first_malloc
	
	.is_first_malloc:
	mov rsi, rcx ; object rsi pour dire qu'il faut changer l'adresse
	
	.is_not_first_malloc:
	; pas besoin de copie, la copie est automatique et le netoyage inutile auto aussi
	mov rcx, rdx
	mov rdx, [rsp+48h] ; nouvelle taille + 20
	add rdx, 20 ; entête
	mov rax, [rip+@realloc]
	call rax
	cmp rax, 0
	je .erreur
	mov rbx, rax
	; changer l'adresse de référence sur les tableaux précédents si existe
	mov rcx, [rsp+38h]
	mov rcx, [rcx+16] ; addr premier sous tableau dans le tableau principal
	mov rdx, rdi ; adresse à remplacer
	mov r8, rbx ; adresse de remplacement
	lea rax, [rip+@change_addr_refer_table]
	call rax ; renvoie 1 si ok ou 0 mais pas besoin de la réponse
	
	mov [rsp+40h], rbx ; nouvelle adresse de rdx
	cmp rsi, 0
	jne .save_first_malloc
	jmp .set_size
	
	.save_first_malloc:
	mov [rsi], rbx ;Sauvegarder la nouvelle adresse dans la table globale
	jmp .set_size
	
	
	; créer une nouvelle table si l'on ne fournit pas de rdx
	.create_new_table:
	mov rcx, [rsp+38h]
	add rcx, 16 ; adresse de la première table parcourir toutes les tables jusqu'à trouver 0
	
	mov rdx, [rcx+8]
	cmp rdx, 0 ; rdx = 0 pas d'autre tableau, c'est le premier car aucune entête
	jne .start_table 
	mov rsi, rcx
	mov rcx, 0	;mise à 0 de rcx pour is_malloc
	jmp .create_first_table
	
	.start_table:
	;debuggeur
	;mov rdi, rcx
	;lea rcx, [rip+@debug2]
	;mov rdx, [rdi]
	;mov rax, [rip+@printf]
	;call rax
	;mov rcx, rdi
	
	mov rdx, [rcx]
	test rdx, rdx
	jz .continue_table
	mov rcx, rdx
	jmp .start_table
	
	.continue_table:
	; on vérifie si le précédent c'est un tableau créer dans un malloc ou si il est sur la table globale 
	mov rdx, [rsp+38h] ; adresse du tableau global
	mov rsi, rcx ; rcx = adresse à vérifier , sauvgarde dans rsi
	lea rax, [rip+@isvalid_zone]
	call rax
	mov rcx, rsi ; rcx = argument pour is_alloc pour emplacer l'adresse suivante par la nouvelle sans avoir besoin d'utiliser change_addr_refer_table
	cmp rax, 1
	jne .is_malloc
	
	; le dernier n'est pas allouer, on décale si possible
	add rsi, [rcx+8] ; adresse de la case précédente + taille = addr de début de la nouvelle table
	
	.create_first_table:
	
	mov rdi, rsi ; sauvgarde du début de l'écriture si taille suffisante
	add rsi, [rsp+48h] ; ajoute la taille demander 
	add rsi, 20 ; ajoute l'entête
	; recuperation de l'adresse de fin de tableau
	mov rdx, [rsp+38h]
	mov r8, [rdx+8]
	add rdx, r8
	cmp rdx, rsi ; rdx < rsi ; la taille réel du tableau est insuffisante, on doit alloué
	jb .is_malloc
	;on vérifie qu'il n'y a que des zero dans la mémoire ici 
	mov rbx, rcx ; sauvgarde de celui que l'on doit changer (tableau précédent)
	mov rcx, rdi
	mov rdx, [rsp+48h]
	add rdx, 40 ; ajout de l'entête 20 + 20 de marge pour être sur de ne pas rentrer dans un tampon interdit
	lea rax, [rip+@have_place]
	call rax
	mov rcx, rbx
	cmp rax, 0  ; rax = 0 donc is_malloc
	je .is_malloc
	
	;ok, on écrit la taille et renvoie le pointeur rdi
	mov [rsp+40h], rdi ; nouvelle adresse de rdx
	cmp rcx, 0 ; pas de tableau précédent, c'est le premier
	je .set_size
	mov [rcx], rdi ; changement du pointeur de tableau pour le précédent
	jmp .set_size
	
	.is_malloc:
	; On alloue la taille voulu change l'adresse et finit
	mov rdi, rcx ; sauvgarde de celui que l'on doit changer (tableau précédent)
	mov rcx, [rsp+48h] ; taille du nouveau tableau
	add rcx, 20 ; entête
	mov rax, [rip+@malloc]
	call rax
	cmp rax, 0
	je .erreur
	mov rbx, rax	; pour end_copy_byte avec rbx la nouvelle adresse
	mov qword ptr [rbx], 0 ; pas de suivant pour ne pas lire du déchêt
	cmp rdi, 0		; pas de tableau précédent, c'est le premier
	je .create_fake_table
	mov [rdi], rbx ; changement du pointeur de tableau pour le précédent
	jmp .end_copy_byte
	
	;créer un tableau vide de 0 cases qui redirige, donc juste une entête pour le premier qui est malloc
	.create_fake_table:
	mov rcx, [rsp+38h] ; adresse du tableau global
	mov rdx, [rcx+8] ; vérifie taille globale du tableau
	cmp rdx, 36
	jb .erreur
	mov [rcx+16], rbx ; écriture dans la fausse table l'adresse malloc
	mov qword ptr [rcx+24], 20 ; taille nulle, seulement entête
	mov dword ptr [rcx+32], 0 ; aucun contenu
	jmp .end_copy_byte
	
	; écrit la taille dans la case dédier et finit la fonction
	.set_size:
	mov rdx, [rsp+40h]
	mov r8, [rsp+48h]
	add r8, 20 ; entête
	mov [rdx+8], r8
	mov rax, [rsp+40h] ; adresse de la table (si elle change ou non)
	jmp .end
	
	.erreur:
	xor rax, rax
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 58h
	ret
end alloc_table 

; RCX = chaine à parser qui va être modifier ; de séparation remplacer par \0 et \\ remplacer par \
; return RAX = nombre de chaine dans rcx
proc parse_argument
	sub rsp, 48h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	
	mov rdi, 0 ; compteur d'argument 
	
	mov dl, byte ptr [rcx]
	cmp dl, 0
	je .end
	
	inc rdi ; un argument minimum
	
	.boucle:
	mov dl, byte ptr [rcx]
	cmp dl, 0
	je .end
	cmp dl, 0x5C ; '\\'
	je .parse_slash
	cmp dl, 0x3B ; ';'
	je .parse_arg
	.final_boucle:
	inc rcx
	jmp .boucle
	
	.parse_slash:
	mov dl, byte ptr [rcx+1]
	cmp dl, 0x5C ; '\\'
	je .move_source_1
	cmp dl, 0x3B ; ';'
	je .move_source_1
	; inconnu, on conserve le \, juste on avance de 1
	jmp .final_boucle
	
	.parse_arg:
	mov byte ptr [rcx], 0
	inc rdi
	jmp .final_boucle
	
	; déplacement de un caractère vers la gauche
	.move_source_1:
	mov rdx, rcx ; destination 
	inc rcx ; source
	mov rbx, rcx ; sauvgarde (déjà incrémenter pour lire le caractère encore suivant)
	xor r8, r8 ; taille nulle, automatique par \0
	lea rax, [rip+@asm_copy]
	call rax
	mov rcx, rbx ; restore
	jmp .boucle
	
	.end:
	mov rcx, [rsp+38h]
	mov rax, rdi
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 48h
	ret
end parse_argument

; RCX = ptr du type
; RDX = ptr de l'argument
; return RAX = taille de l'objet
; return RCX = pointeur malloc de l'objet
; return RDX = 1 object doit être aligné, 0 non
proc parse_type_argument
	sub rsp, 48h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rdx
	
	mov rbx, rcx
	; regarder le type et calculer 
	
	xor rsi, rsi ; si rsi est nulle, hex utilise la taille fournit, sinon hex utilise rsi comme limite (pour BYTE, WORD, DWORD ...)
	
	;bool
	lea rcx, [rip+@_bool]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_bool]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .bool
	
	;int
	lea rcx, [rip+@_int]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_int]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .int
	
	;long_int
	lea rcx, [rip+@_long_int]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_long_int]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .long_int
	
	;double
	lea rcx, [rip+@_double]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_double]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .double
	
	;BYTE
	lea rcx, [rip+@_BYTE]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_BYTE]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .BYTE
	
	;WORD
	lea rcx, [rip+@_WORD]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_WORD]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .WORD
	
	;DWORD
	lea rcx, [rip+@_DWORD]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_DWORD]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .DWORD
	
	;QWORD
	lea rcx, [rip+@_QWORD]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_QWORD]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .QWORD
	
	;CHAR
	lea rcx, [rip+@_CHAR]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_CHAR]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .CHAR
	
	;char
	lea rcx, [rip+@_char]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_char]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .char
	
	;hex
	lea rcx, [rip+@_hex]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_hex]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .hex
	
	;addr
	lea rcx, [rip+@_addr]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_addr]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .addr
	
	;struct
	lea rcx, [rip+@_struct]
	lea rax, [rip+@asm_strlen]
	call rax
	
	mov rcx, rbx
	lea rdx, [rip+@_struct]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .struct
	
	;type inconnu
	jmp .unknow
	
	
	.bool:
	mov rbx, [rsp+38h]
	lea rcx, [rip+@_true]
	lea rax, [rip+@asm_strlen]
	call rax
	; vérifie true
	mov rcx, rbx
	lea rdx, [rip+@_true]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .true
	
	lea rcx, [rip+@_false]
	lea rax, [rip+@asm_strlen]
	call rax
	; vérifie false
	mov rcx, rbx
	lea rdx, [rip+@_false]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .false
	
	; vérifie par valeur numérique
	mov rcx, rbx
	xor r8, r8
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	cmp rax, 0
	ja .true
	
	.false:
	mov bl, 0
	jmp .bool_end
	
	.true:
	mov bl, 1
	
	.bool_end:
	mov rcx, 1
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax
	mov rax, 1
	mov byte ptr [rcx], bl
	mov qword ptr [rsp+40h], 1 ; doit être aligné dans la structure (1 oct = info inutile)
	jmp .end
	
	.int:
	mov rcx, [rsp+38h]
	xor r8, r8
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	movsxd rax, eax ; converti le QWORD en DWORD
	mov ebx, eax
	mov rcx, 4
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax
	mov rax, 4
	mov dword ptr [rcx], ebx
	mov qword ptr [rsp+40h], 1 ; doit être aligné dans la structure
	jmp .end
	
	.long_int:
	mov rcx, [rsp+38h]
	xor r8, r8
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	mov rbx, rax
	mov rcx, 8
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax
	mov rax, 8
	mov qword ptr [rcx], rbx
	mov qword ptr [rsp+40h], 1 ; doit être aligné dans la structure
	jmp .end
	
	.double:
	mov rcx, [rsp+38h]
	lea rax, [rip+@asm_addr_ascii_double]
	call rax
	movq rbx, xmm0
	mov rcx, 8
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax
	mov rax, 8
	mov qword ptr [rcx], rbx
	mov qword ptr [rsp+40h], 1 ; doit être aligné dans la structure
	jmp .end
	
	.BYTE:
	mov rsi, 1
	jmp .hex
	
	.WORD:
	mov rsi, 2
	jmp .hex
	
	.DWORD:
	mov rsi, 4
	jmp .hex
	
	.QWORD:
	mov rsi, 8
	jmp .hex
	
	; copie que le premier caractère
	.CHAR:
	mov rcx, 1
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax
	mov rax, 1
	mov rdx, [rsp+38h]
	mov dl, byte ptr [rdx] ; copie le premier caractère
	mov byte ptr [rcx], dl
	mov qword ptr [rsp+40h], 0 ; ne doit pas être aligné dans la structure (1 oct = info inutile)
	jmp .end
	
	; attention, copie la chaine entière dans la structure, corespond à char[strlen(this)+1]
	.char:
	; on regarde si après char il y a une valeur numérique non nulle avec asm_addr_ascii_int
	lea rcx, [rip+@_char]
	lea rax, [rip+@asm_strlen]
	call rax
	add rbx, rax ; on ajoute au pointeur de la clé la taille de char
	mov rcx, rbx ; position possible de valeur numérique
	xor r8, r8 ; taille auto
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	cmp rax, 0 ; si rax <= 0 on prend la taille de la chaine, sinon on fait un tampon de la taille demander (taille long int max)
	jg .fixed_size_char 
	; tampon de taille de la chaine
	mov rcx, [rsp+38h]
	lea rax, [rip+@asm_strlen]
	call rax
	inc rax ; +1 pour \0
	.fixed_size_char:
	mov rbx, rax 
	mov rcx, rax
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rsi, rax ; enregistrer l'adresse de tampon retour
	mov rcx, [rsp+38h] ; source
	mov rdx, rsi ; destination
	mov r8, rbx ; taille calculer
	lea rax, [rip+@asm_copy]
	call rax
	mov rcx, rsi ; tampon
	mov rax, rbx ; taille
	mov byte ptr [rcx+rax-1], 0 ; terminaison NULL garanti
	mov qword ptr [rsp+40h], 0 ; ne doit pas être aligné dans la structure
	jmp .end
	
	.hex:
	mov qword ptr [rsp+40h], 1 ; savoir si l'on doit écrire à l'envers
	mov rcx, [rsp+38h]
	xor rdx, rdx
	test rsi, rsi 
	jz .hex_not_option
	mov rdx, 1 ; si il manque un cartet, ça l'ajoute à gauche et non à droite
	.hex_not_option:
	lea rax, [rip+@hex_char_hex_v2]
	call rax
	cmp rcx, 1
	je .error_other
	mov rbx, rax ; ptr de reponse
	test rsi, rsi
	jnz .continue_hex
	mov rsi, rdx ; nombre d'octet de réponse à copier si pas déjà définit par un objet fixe
	mov qword ptr [rsp+40h], 0 ; savoir que l'on ne doit pas écrire à l'envers
	.continue_hex:
	mov rdi, rdx ; sauvgarde de rdx, car si l'utilisateur fournit un nombre hex plus petit que la taille max, il ce retrouve dans les poids fort, alors que l'on veux poid faible
	mov rcx, rsi
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur 
	mov rcx, rax ; rcx = ptr de reponse malloc
	; remplir le contenu de la case en boucle
	mov rax, 0
	mov rdx, [rsp+40h]
	cmp rdx, 1
	jne .hex_boucle_big
	mov rax, rsi ; reprendre et copier à l'envers les octets pour little
	mov r8, rdi ; rdi-rsi = déplacement de départ pour ignorer les bits de poid trop fort si passe par la condition ci dessous
	sub r8, rsi
	cmp rsi, rdi ; rsi <= rdi donc ça fait un nombre neg donc on ignore
	jbe .hex_boucle_little
	mov rax, rdi
	.hex_zero_boucle:
	cmp rax, rsi
	jae .hex_next_zero_boucle
	mov byte ptr [rcx+rax], 0
	inc rax
	jmp .hex_zero_boucle
	.hex_next_zero_boucle:
	mov rax, rdi ; reprendre et copier à l'envers les octets pour little
	mov r8, 0
	.hex_boucle_little:
	test rax, rax ; rax = 0 donc terminer
	jz .end_hex_boucle_litte
	mov dl, byte ptr [rbx+r8]
	mov byte ptr [rcx+rax-1], dl
	inc r8
	dec rax
	jmp .hex_boucle_little
	; écrire la valeur de rax comme nombre d'octet
	.end_hex_boucle_litte:
	mov rax, rsi
	jmp .end
	; copie dans le cas où la source est hex copie tel quel
	.hex_boucle_big:
	cmp rax, rsi ; rax >= rsi donc rax atteint la taille de copie requise
	jae .end ; rax = taille donc ok
	mov dl, byte ptr [rbx+rax]
	mov byte ptr [rcx+rax], dl
	inc rax
	jmp .hex_boucle_big
	
	
	.addr:
	mov rcx, [rsp+38h]
	lea rax, [rip+@hex_addr_hex]
	call rax
	cmp rcx, 1
	je .error_other
	mov rbx, rax
	mov rcx, 8
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur
	mov rcx, rax
	mov rax, 8
	mov qword ptr [rcx], rbx
	mov qword ptr [rsp+40h], 1 ; doit être aligné dans la structure
	jmp .end
	
	.struct:
	; on doit parser l'addr qui doit être une adresse de tableau
	mov rcx, [rsp+38h]
	lea rax, [rip+@hex_addr_hex]
	call rax
	cmp rcx, 1
	je .error_other
	; l'adresse du tableau est dans rax, on récupère l'alignement avec estimate_alignment_for_table
	mov rbx, rax 
	mov rcx, rbx
	lea rax, [rip+@estimate_alignment_for_table]
	call rax
	test rax, rax
	jz .error_other ; valeur incorrect car adresse fournit invalide
	neg rax ; rendre negatif la réponse
	mov qword ptr [rsp+40h], rax ; doit être aligné dans la structure à la valeur fournit
	; on récupère le ptr de structure avec get_struct_from_table
	mov rcx, rbx ; adresse de tableau
	lea rax, [rip+@get_struct_from_table]
	call rax
	test rax, rax
	jz .error_other
	mov rbx, rax ; adresse de la structure
	mov rdi, rcx ; taille de la structure
	; allocation de la taille de rcx
	mov rax, [rip+@malloc]
	call rax
	test rax, rax 
	jz .erreur
	mov rcx, rax ; destionation
	mov rdx, rbx ; source
	mov r8, rdi ; taille de la copie
	mov rbx, rcx ; sauvgarde de l'adresse malloc de retour
	mov rax, [rip+@memcpy]
	call rax
	; valeur de retour
	mov rcx, rbx ; ptr malloc
	mov rax, rdi ; taille du malloc
	jmp .end
	
	.error_other:
	xor rcx, rcx
	mov rax, 2 ; code taille 2 mais pas de tampon réponse = valeur incorrect
	jmp .end
	.unknow:
	xor rcx, rcx
	mov rax, 1 ; code taille 1 mais pas de tampon réponse = clé inconnu
	jmp .end
	.erreur:
	xor rcx, rcx
	xor rax, rax
	.end:
	mov rdx, [rsp+40h] ; savoir si l'on doit aligné l'objet ou non
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 48h
	ret
end parse_type_argument

proc create_parse_table_argument_dbg
	push rbp
    mov rbp, rsp
	sub rsp, 60h
	mov [rsp+58h], rcx ; pointeur de contenu à ajouté
	mov [rsp+50h], rdx ; taille du contenu à ajouté
	mov dword ptr [rsp+4Ch], r8d ; aligné 1 ou non 0 (un oct suffit mais place suffisante pour dword)
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+40h], rax
	
	; debug
	lea rcx, [rip+@debug2_union]
	mov rdx, [rbp+50h]
	mov rax, [rip+@printf]
	call rax
	lea rcx, [rip+@debug2_pack]
	mov rdx, [rbp+58h]
	mov rax, [rip+@printf]
	call rax
	lea rcx, [rip+@debug2_paddingmax]
	mov rdx, [rbp+70h]
	mov rax, [rip+@printf]
	call rax
	lea rcx, [rip+@debug2_arg]
	mov rdx, [rbp+74h]
	mov rax, [rip+@printf]
	call rax
	lea rcx, [rip+@debug2_malloctmp]
	mov rdx, [rbp+78h]
	mov rdi, rdx
	mov rax, [rip+@printf]
	call rax
	lea rcx, [rip+@debug2_mallocsize]
	mov rdx, [rbp+80h]
	mov rsi, rdx
	mov rax, [rip+@printf]
	call rax
	
	mov [rsp+38h], r15
	
	xor r15, r15
	test rdi, rdi
	jz .end_debug_boucle
	.dd_boucle:
	lea rcx, [rip+@debug4]
	xor rdx, rdx
	mov dl, byte ptr [rdi+r15]
	mov rax, [rip+@printf]
	call rax
	inc r15
	;lea rcx, [rip+@debug22]
	;mov rdx, rsi
	;mov r8, r15
	;mov rax, [rip+@printf]
	;call rax
	cmp r15, rsi ; r15 <= rsi continue
	jnc .end_debug_boucle
	jmp .dd_boucle
	;
	.end_debug_boucle:
	lea rcx, [rip+@debug_zone]
	mov rax, [rip+@printf]
	call rax
	
	mov r15, [rsp+38h]
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	mov rcx, [rsp+58h] ; conservé car le free est fait par l'appellant directement sur ce registre rcx
	mov rax, [rsp+40h]
	add rsp, 60h
	pop rbp
	ret
end create_parse_table_argument_dbg

; RCX tampon à ajouté dans le comptenu
; RDX taille du tampon à ajouté
; R8 objet doit être aligné 1 ou non 0 (valeur négative = valeur de l'alignement, non automatique pour des types spéciaux comme d'autres structures)
; [rsp+40h] automatique du nombre d'élément dans union restant (lecture dans le caller à rbp+50h)
; [rsp+48h] automatique de l'état de pack pour l'alignement des éléments (lecture dans le caller à rbp+58h)
; [rsp+60h] (dword) automatique stocke la taille max d'un élément avec padding pour le calcul du padding final (lecture dans le caller à rbp+70h)
; [rsp+64h] (dword) nombre d'argument édité automatiquement (lecture dans le caller à rbp+74h)
; [rsp+68h] adresse fournit pour écrire l'addresse du malloc qui contient le contenu formaté (lecture dans le caller à rbp+78h)
; [rsp+70h] taille du malloc (lecture dans le caller à rbp+80h)
; return RAX = 0 erreur, 1 = ok
proc create_parse_table_argument
	push rbp
    mov rbp, rsp
	sub rsp, 60h
	mov [rsp+58h], rcx ; pointeur de contenu à ajouté
	mov [rsp+50h], rdx ; taille du contenu à ajouté
	mov dword ptr [rsp+4Ch], r8d ; aligné 1 ou non 0 (ou neg: aligné à la valeur en positif)
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	; [rsp+40h] libre, différentes fonctions
	
	mov dword ptr [rsp+38h], 0 ; pour la taille du padding final avant realloc
	mov dword ptr [rsp+3Ch], 0 ; pour activation du paramètre taille du padding final
	
	; vérifier si il y a déjà du contenu donc un tampon malloc non NULL
	mov rcx, [rbp+78h]
	test rcx, rcx
	jz .create_first_malloc
	
	mov rcx, [rbp+50h] ; si il y a union positif, on cherche la dernière case et on modifie son contenu (car neg, cela veux dire que c'est le premier élément, il créer donc une nouvelle case)
	cmp rcx, 0
	jg .edit_union
	
	; normal, même si union est négatif, car il n'a pas encore commencé, on soustrait 1 et ou le met en positif
	cmp rcx, 0
	je .ignore_change_union
	neg rcx ; inversion en positif
	dec rcx
	mov [rbp+50h], rcx ; sauvgarde
	
	.ignore_change_union:
	mov ecx, dword ptr [rbp+74h] ; récupérer le nombre de case pour savoir quand arrêté la boucle
	mov rax, [rbp+78h] ; addresse du malloc
	add rax, 4 ; saute l'emplacement du padding
	xor rdx, rdx
	; rdx = taille qui indique l'emplacement du contenu de la nouvelle case
	.search_end_case:
	cmp ecx, 0 ; on cherche la dernière case
	je .find_end_case
	add rdx, [rax]
	add rax, 8 ; chaque taille de case est écrit sur 8 oct
	dec ecx
	jmp .search_end_case
	
	.find_end_case:
	mov rsi, rdx ; sauvgarde de la taille de la structure pour controller l'alignement
	;sub rax, 8 ; peut être pas car rdi est l'emplacement de la nouvelle entête
	mov rdi, rax ; sauvgarde de l'emplacement ou l'on doit écrire la nouvelle entête de case de taille 8, et décaler tout les octets après
	sub rdi, [rbp+78h] ; retire l'addresse du malloc pour que cela devienne une taille et reste valide après realloc
	xor rbx, rbx ; taille du padding à ajouter avant la valeur
	
	; vérifier si le contenu ajouté doit être aligné
	mov ecx, dword ptr [rsp+4Ch] ; booléen si contenu doit être aligné (ou valeur neg qui détermine le padding)
	test ecx, ecx ; valeur 0, pas d'alignement
	jz .edit_case_not_align
	
	mov rax, qword ptr [rsp+50h] ; taille du contenu à ajouté
	mov qword ptr [rsp+40h], rax ; valeur de la taille du contenu ajouté par défaut 
	; si la valeur est neg, on définit cette valeur comme la taille de l'élément pour le padding sur [rsp+40h]
	cmp ecx, 0
	jg .edit_case_not_fixe_element_size
	neg ecx ; remise en positif
	movsxd rcx, ecx ; conversion 32 en 64 bit positif seulement pour écrasé les restes de la partie poid fort sur rcx possible
	mov qword ptr [rsp+40h], rcx ; enregistrement
	.edit_case_not_fixe_element_size:
	
	; vérifier si ça taille est plus grande que la taille max d'un élément avec padding [rbp+70h]
	mov ecx, dword ptr [rbp+70h] ; taille max d'un élément avec padding
	mov rdx, qword ptr [rsp+40h] ; taille de l'élément pour le padding
	cmp ecx, edx ; ecx >= edx : on ne change pas la taille max
	jae .continue_case_not_align
	mov dword ptr [rbp+70h], edx ; changement de taille max de l'élément avec padding
	;mov dword ptr [rsp+3Ch], 1 ; activation du paramètre taille du padding final
	
	.continue_case_not_align:
	xor rdx, rdx
	mov rcx, [rsp+40h] ; taille de l'élément pour le padding
	; vérifier si le padding de la taille n'est pas suppérieur à pack, sinon limité à sa valeur
	mov rax, [rbp+58h] ; valeur de pack
	test rax, rax ; valeur nul, on laisse automatique
	jz .next_case_align
	cmp rax, rcx ; rax >= rcx le pack est plus grand, on ignore
	jae .next_case_align
	mov rcx, rax ; sinon l'alignement se fait à la taille de pack
	.next_case_align:
	mov rax, rsi
	div rcx ; rsi/rcx
	; rdx = modulo de la division de la taille global/taille voulu
	test rdx, rdx ; mod = 0 donc pas de padding à compter
	jz .edit_case_not_align
	
	mov rbx, [rsp+40h] ; taille de l'élément pour le padding
	sub rbx, rdx ; rbx = taille de padding à ajouté avant la valeur dans la case
	
	.edit_case_not_align:
	; calculer le nouveau padding final
	xor rcx, rcx
	xor rax, rax ; pas besoin de l'emplacement du début, juste d'une taille
	add rax, rsi ; ajouter à l'adresse la taille du contenu pour l'emplacement d'écriture
	add rax, rbx ; ajouter le padding local
	add rax, [rsp+50h] ; ajouter la taille à créer
	mov ecx, dword ptr [rbp+70h] ; charger dans ecx la valeur de taille maximum avec padding
	mov rdx, [rbp+58h] ; valeur de pack
	test rdx, rdx ; pack est NULL, on ignore
	jz .change_final_pad_div_case
	cmp rdx, rcx ; rdx >= rcx le pack est plus grand, on ignore
	jae .change_final_pad_div_case
	mov rcx, rdx
	.change_final_pad_div_case:
	xor rdx, rdx
	div rcx ; taille globale/taille max avec padding (rax/rcx)
	; rdx = modulo de la division
	xor rcx, rcx
	test rdx, rdx ; 0 on ne soustrait pas mais on enregistre
	jz .continue_case_change_final_pad
	xor rcx, rcx
	mov ecx, dword ptr [rbp+70h] ; charger dans ecx la valeur de taille maximum avec padding
	sub ecx, edx ; ecx = taille du padding final
	.continue_case_change_final_pad:
	mov rdx, [rbp+78h] ; récupérer le tampon malloc/realloc
	mov eax, dword ptr [rdx] ; récupérer la valeur du padding
	mov dword ptr [rdx], ecx ; écrire la nouvelle taille du padding à l'emplacement dédié
	sub ecx, eax ; la valeur peut être négative si le padding est réduit, ce qui réduit malloc/realloc
	mov dword ptr [rsp+38h], ecx ; valeur ajouter dans realloc (+ ou -)
	
	; calculer la taille du nouveau tampon alloc
	mov rax, [rsp+50h] ; taille du contenu à ajouté
	add rax, rbx ; padding avant le contenu
	movsxd rcx, ecx ; convertir la valeur + ou - du realloc en signé
	add rax, rcx ; ajouté la différence de padding
	add rax, 8 ; ajouté la taille de la nouvelle entête de case
	mov rdx, [rbp+80h] ; taille du malloc/realloc global
	add rdx, rax ; nouvelle taille du realloc
	mov rcx, [rbp+78h] ; adresse du malloc
	mov [rsp+40h], rdi ; conserver rdi
	mov rdi, rdx ; enregistrer la nouvelle taille dans rdi
	mov rax, [rip+@realloc]
	call rax
	test rax, rax
	jz .erreur
	mov [rbp+78h], rax ; nouvelle adresse du malloc/realloc
	mov [rbp+80h], rdi ; nouvelle taille du malloc/realloc global
	mov rdi, [rsp+40h] ; restorer rdi
	
	; déplacer tout les octets de l'adresse rdi à l'adresse rdi+8 dans la limite de la taille du realloc
	mov rdx, rax ; adresse de départ malloc/realloc
	add rdx, rdi ; + taille du dernier oct d'origine
	mov r8, rdx  ; sauvgarde du pointeur de fin qui reste identique
	add rdx, rsi ; + taille du contenu existant
	; mov rax, [rbp+78h] ; adresse du malloc/realloc inutile, déjà le cas
	add rax, [rbp+80h] ; adresse final maximum
	.mov_data_8:
	cmp rdx, r8 ; rdx <= r8 donc on a tout copier, on sort
	jbe .end_mov_data_8
	dec rdx
	mov rcx, rdx
	add rcx, 8 ; adresse d'écriture
	cmp rcx, rax ; rcx >= rax donc on écrit hors limite, interdit !
	jae .mov_data_8
	mov cl, byte ptr [rdx]
	mov byte ptr [rdx+8], cl
	jmp .mov_data_8
	
	.end_mov_data_8:
	; écrire la taille de la nouvelle case dans l'entête à r8
	mov rax, [rsp+50h] ; taille du contenu à ajouté
	add rax, rbx ; padding avant le contenu
	mov [r8], rax ; écrit taille de la nouvelle case
	
	; écrire le contenu de la case via write_content
	mov rax, r8
	add rax, 8 ; car il faut sauter là ou l'on vient d'écrire
	add rax, rsi ; ajouter à l'adresse la taille du contenu pour l'emplacement d'écriture
	mov rdx, 1 ; write_content doit incrémenter le nombre de case
	xor r8, r8
	.case_padding:
	cmp r8, rbx ; r8 >= rbx on arrête et on écrit la valeur
	jae .write_content ; écrit à rax donc ok
	mov byte ptr [rax], 0
	inc rax
	inc r8
	jmp .case_padding
	
	.edit_union:
	dec rcx ; retirer 1 à union positif pour dire qu'on le traite
	mov [rbp+50h], rcx
	
	mov ecx, dword ptr [rbp+74h] ; récupérer le nombre de case pour savoir quand arrêté la boucle
	mov rax, [rbp+78h] ; addresse du malloc
	add rax, 4 ; saute l'emplacement du padding
	xor rdx, rdx
	
	; rdx = taille qui indique l'emplacement du contenu de la dernière case que l'on doit modifier
	.search_edit_union:
	cmp ecx, 1 ; on cherche l'avant dernière
	jbe .find_edit_union
	add rdx, [rax]
	add rax, 8 ; chaque taille de case est écrit sur 8 oct
	dec ecx
	jmp .search_edit_union
	
	.find_edit_union:
	test ecx, ecx ; impossible, il ne peut pas y avoir 0 case si union est positif
	jz .erreur
	
	mov rsi, rdx ; sauvgarde de la taille de la structure pour controller l'alignement
	mov rdi, [rax] ; sauvgarde de la taille actuel du contenu de la case
	xor rbx, rbx ; taille du padding à ajouter avant la valeur 
	
	; vérifier si le contenu ajouté doit être aligné
	mov ecx, dword ptr [rsp+4Ch] ; booléen si contenu doit être aligné (ou valeur neg qui détermine le padding)
	test ecx, ecx ; valeur 0, pas d'alignement
	jz .edit_union_not_align
	
	mov rax, qword ptr [rsp+50h] ; taille du contenu à ajouté
	mov qword ptr [rsp+40h], rax ; valeur de la taille du contenu ajouté par défaut 
	; si la valeur est neg, on définit cette valeur comme la taille de l'élément pour le padding sur [rsp+40h]
	cmp ecx, 0
	jg .edit_union_not_fixe_element_size
	neg ecx ; remise en positif
	movsxd rcx, ecx ; conversion 32 en 64 bit positif seulement pour écrasé les restes de la partie poid fort sur rcx possible
	mov qword ptr [rsp+40h], rcx ; enregistrement
	.edit_union_not_fixe_element_size:
	
	; vérifier si ça taille est plus grande que la taille max d'un élément avec padding [rbp+70h]
	mov ecx, dword ptr [rbp+70h] ; taille max d'un élément avec padding
	mov rdx, qword ptr [rsp+40h] ; taille de l'élément pour le padding
	cmp ecx, edx ; ecx >= edx : on ne change pas la taille max
	jae .continue_edit_union_not_align
	mov dword ptr [rbp+70h], edx ; changement de taille max de l'élément avec padding
	mov dword ptr [rsp+3Ch], 1 ; activation du paramètre taille du padding final
	
	.continue_edit_union_not_align:
	xor rdx, rdx
	mov rcx, [rsp+40h] ; taille de l'élément pour le padding
	; vérifier si le padding de la taille n'est pas suppérieur à pack, sinon limité à sa valeur
	mov rax, [rbp+58h] ; valeur de pack
	test rax, rax ; valeur nul, on laisse automatique
	jz .next_union_align
	cmp rax, rcx ; rax >= rcx le pack est plus grand, on ignore
	jae .next_union_align
	mov rcx, rax ; sinon l'alignement se fait à la taille de pack
	.next_union_align:
	mov rax, rsi
	div rcx ; rsi/rcx
	; rdx = modulo de la division de la taille global/taille voulu
	test rdx, rdx ; mod = 0 donc pas de padding à compter
	jz .edit_union_not_align
	
	mov rbx, [rsp+40h] ; taille de l'élément pour le padding
	sub rbx, rdx ; rbx = taille de padding à ajouté avant la valeur dans la case
	
	.edit_union_not_align:
	; vérifier si on a une taille suffisante déjà dans le union
	mov rax, [rsp+50h] ; taille du contenu à ajouté
	add rax, rbx ; ajout du padding si présent
	cmp rdi, rax ; rdi >= rax la taille disponible est suffisante, on ne realloc pas (comme dans union ça ne change rien au padding de fin si plus petit)
	jb .edit_union_need_realloc
	; vérifier aussi si il y a besoin de changer le padding de fin
	mov ecx, dword ptr [rsp+3Ch]
	test ecx, ecx 
	jnz .edit_union_need_realloc_pad
	jmp .edit_union_not_realloc
	
	.edit_union_need_realloc:
	; vérifier si il y a besoin de changer le padding de fin
	mov ecx, dword ptr [rsp+3Ch]
	test ecx, ecx 
	jz .edit_union_not_change_final_pad
	
	.edit_union_need_realloc_pad:
	; calculer le nouveau padding final
	mov [rsp+40h], rax ; sauvgarde de rax
	;mov ecx, dword ptr [rbp+74h] ; nombre de fois que l'on doit multiplier par 8 pour sauter les entêtes de case
	;mov rax, 8
	;mul ecx  ; multiplier rcx par 8 resulat rax
	;mov rdx, rax ; sauvgarde
	;mov rax, [rbp+78h] ; addresse du malloc
	;add rax, 4 ; saute l'emplacement de la taille du padding final
	;add rax, rdx ; saute la taille des entêtes de case
	xor rax, rax ; pas besoin de l'emplacement du début, juste d'une taille
	add rax, rsi ; ajouter à l'adresse la taille du contenu pour l'emplacement d'écriture
	add rax, rbx ; ajouter le padding local
	add rax, [rsp+50h] ; ajouter la taille à créer
	mov ecx, dword ptr [rbp+70h] ; charger dans ecx la valeur de taille maximum avec padding
	mov rdx, [rbp+58h] ; valeur de pack
	test rdx, rdx ; pack est NULL, on ignore
	jz .change_final_pad_div
	cmp rdx, rcx ; rdx >= rcx le pack est plus grand, on ignore
	jae .change_final_pad_div
	mov rcx, rdx
	.change_final_pad_div:
	xor rdx, rdx
	div rcx ; taille globale/taille max avec padding (rax/rcx)
	; rdx = modulo de la division
	xor rcx, rcx
	test rdx, rdx ; 0 on ne soustrait pas mais on enregistre
	jz .continue_edit_union_change_final_pad
	xor rcx, rcx
	mov ecx, dword ptr [rbp+70h] ; charger dans ecx la valeur de taille maximum avec padding
	sub ecx, edx ; ecx = taille du padding final
	.continue_edit_union_change_final_pad:
	mov rdx, [rbp+78h] ; récupérer le tampon malloc/realloc
	mov eax, dword ptr [rdx] ; récupérer la valeur du padding
	mov dword ptr [rdx], ecx ; écrire la nouvelle taille du padding à l'emplacement dédié
	sub ecx, eax ; la valeur peut être négative si le padding est réduit, ce qui réduit malloc/realloc
	mov dword ptr [rsp+38h], ecx ; valeur ajouter dans realloc (+ ou -)
	mov rax, [rsp+40h] ; restore de rax
	
	.edit_union_not_change_final_pad:
	sub rax, rdi ; taille à ajouter à la taille globale (différence)
	mov rdx, [rbp+80h] ; taille du malloc/realloc global
	add rdx, rax ; nouvelle taille
	mov ecx, dword ptr [rsp+38h]
	movsxd rcx, ecx
	add rdx, rcx ; + ou - de taille final en fonction du padding
	mov rcx, [rbp+78h] ; adresse du malloc
	mov rdi, rdx ; enregistrer la nouvelle taille dans rdi car la taille précédente est inutile désormais
	mov rax, [rip+@realloc]
	call rax
	test rax, rax
	jz .erreur
	mov [rbp+78h], rax ; nouvelle adresse du malloc/realloc
	mov [rbp+80h], rdi ; nouvelle taille du malloc/realloc global
	
	.edit_union_not_realloc:
	mov ecx, dword ptr [rbp+74h] ; nombre de fois que l'on doit multiplier par 8 pour sauter les entêtes de case
	mov rax, 8
	mul ecx  ; multiplier rcx par 8 resulat rax
	mov rdx, rax ; sauvgarde
	mov rax, [rbp+78h] ; addresse du malloc
	add rax, 4 ; saute l'emplacement de la taille du padding final
	add rax, rdx ; saute la taille des entêtes de case
	sub rax, 8 ; décendre de 8 pour regarder la taille du comptenu pour le changer si le nouveau contenu est plus grand
	mov rcx, rbx ; valeur du padding
	add rcx, [rsp+50h] ; + récupérer la taille à créer
	mov rdx, [rax] ; verifier si la taille actuel est plus grande pour ne pas la modifier
	cmp rdx, rcx ; rdx >= rcx, ne pas changer
	jae .continue_edit_union_write
	mov [rax], rcx ; écrire la taille de la case
	.continue_edit_union_write:
	add rax, 8 ; remettre pour continuer
	add rax, rsi ; ajouter à l'adresse la taille du contenu pour l'emplacement d'écriture
	; mettre le padding à 0
	xor rdx, rdx ; pas d'ajout de nombre de case pour write_content
	xor r8, r8
	.edit_union_padding:
	cmp r8, rbx ; r8 >= rbx on arrête et on écrit la valeur
	jae .write_content ; écrit à rax donc ok
	mov byte ptr [rax], 0
	inc rax
	inc r8
	jmp .edit_union_padding
	
	
	;utilitaire pour dec le union la première fois au malloc
	.dec_union_first_malloc:
	cmp rcx, 0
	jg .not_neg_union_first_malloc
	neg rcx
	.not_neg_union_first_malloc:
	dec rcx
	mov [rbp+50h], rcx
	jmp .after_dec_union_first_malloc
	
	; pas de contenu, c'est le début (padding NULL car un seul élément)
	.create_first_malloc:
	mov rcx, [rbp+50h] ; si il y a union on le dec de 1 car c'est la première valeur, ça n'a pas d'influence
	cmp rcx, 0
	jne .dec_union_first_malloc
	.after_dec_union_first_malloc:
	mov rcx, [rsp+50h] ; récupérer la taille à créer
	add rcx, 4 ; pour le tampon de padding final
	add rcx, 8 ; ajouter la taille de la première case dans l'entête qui enregistre sa taille pour passer d'un élément à l'autre facilement
	mov rax, [rip+@malloc]
	call rax
	test rax, rax
	jz .erreur
	mov dword ptr [rax], 0 ; pas de padding pour le moment car un seul élément
	mov rcx, [rsp+50h] ; récupérer la taille à créer
	mov [rax+4], rcx ; écrire la taille dans l'entête de case
	; sauvgarde du tampon malloc et de ça taille aux adresses fournit
	mov [rbp+78h], rax ; addr malloc
	add rcx, 4 ; + pour le tampon de padding final
	add rcx, 8 ; + taille première case entête
	mov [rbp+80h], rcx ; taille du malloc
	mov dword ptr [rbp+74h], 0 ; nétoyer le nombre de case avant de l'écrire car write_content incrémente de 1 automatiquement
	add rax, 12 ; position d'écriture pour write_content
	
	; vérifier si le contenu ajouté doit être aligné (pour enregistrer dans taille max avec padding)
	mov rdx, 1 ; pour dire à write_content qu'il doit ajouter 1 au nombre de case
	mov ecx, dword ptr [rsp+4Ch] ; booléen si contenu doit être aligné (ou valeur negatif)
	test ecx, ecx ; valeur 0, pas d'alignement
	jz .write_content
	mov ecx, dword ptr [rsp+50h] ; taille à créer
	mov dword ptr [rbp+70h], ecx ; taille max d'un élément avec padding (comme c'est le premier, pas de vérif)
	; vérifier qu'il n'y est pas de valeur neg dans 4Ch pour corrigé que ce n'est pas la taille qu'il faut prendre
	mov ecx, dword ptr [rsp+4Ch] ; booléen si contenu doit être aligné (ou valeur negatif)
	cmp ecx, 0 ; ecx > 0 signé donc positif, on ne change pas
	jg .write_content
	neg ecx ; on inverse la valeur négative
	mov dword ptr [rbp+70h], ecx ; taille max d'un élément avec padding (comme c'est le premier, pas de vérif)
	jmp .write_content
	
	; écrit le contenu demander de la taille fournit à l'emplacement RAX (! il faut avoir de l'espace) et finit
	; rdx si 0, on n'ajoute pas le nombre de case+1
	.write_content:
	test rdx, rdx
	jz .not_add_case_write_content
	mov ecx, dword ptr [rbp+74h]
	inc ecx ; ajouter un au nombre de case
	mov dword ptr [rbp+74h], ecx
	.not_add_case_write_content:
	mov rcx, [rsp+58h] ; emplacement du contenu à copier
	mov rdx, [rsp+50h] ; taille du contenu à copier
	mov r8, 0 ; index de copie
	.write_content_boucle:
	cmp r8, rdx
	jae .ok
	mov bl, byte ptr [rcx+r8] ; copie
	mov byte ptr [rax+r8], bl ; écrire
	inc r8
	jmp .write_content_boucle
	
	.ok:
	mov rax, 1
	jmp .end
	.erreur:
	xor rax, rax
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	mov rcx, [rsp+58h] ; conservé car le free est fait par l'appellant directement sur ce registre rcx
	add rsp, 60h
	pop rbp
	ret
end create_parse_table_argument

; utilitaire, simplifie les arguments de parse_table_argument pour la création (même return que parse_table_argument)
; void* parse_table_argument_new(char *rcx) (compatible en entré format C pour dbg)
proc parse_table_argument_new
	sub rsp, 28h
	mov [rsp+20h], r10
	mov rdx, 0 ; pas d'adresse fournit pour alloc, donc création
	mov r8, 0 ; pas de taille d'alloc
	mov r9d, 0 ; pas de nombre de case déjà présente
	mov r10d, 0 ; pas de max de padding déjà présent
	lea rax, [rip+@parse_table_argument]
	call rax
	mov r10, [rsp+20h]
	add rsp, 28h
	ret
end parse_table_argument_new

; RCX = chaine à parser
; RDX = adresse d'alloc si existe sinon 0
; r8 = taille d'allocation si existe sinon 0
; r9d = nombre de case déjà présente si existe sinon 0
; r10d = max de padding déjà présent si existe, sinon 0 (attention, en fonction du mode, il faut estimé le max de padding si la valeur n'existe pas encore)
; void* parse_table_argument(char *rcx, void *rdx, long int r8, int r9d, int r10d) (incompatible C)
; return RAX = pointeur du contenu du tableau sans entête (doit être free) sauf si NULL car erreur
; return RCX = taille de la reponse du contenu du tableau sans entête (globale)
; return EDX = nombre d'argument
; return r8d = max de padding (optionnel en fonction du mode, peut être ajouté sur 4 oct avant le tampon de taille dans le tableau)
proc parse_table_argument
	sub rsp, 78h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	
	mov qword ptr [rsp+40h], 0 ; valeur du nombre d'élément compris dans union restant
	mov qword ptr [rsp+48h], 0 ; valeur de la marge pack (0 = automatique pour l'alignement des éléments)
	
	mov dword ptr [rsp+60h], r10d ; taille d'élément avec du padding maximum (gestion automatique)
	mov dword ptr [rsp+64h], r9d ; nombre d'argument renvoyé
	mov qword ptr [rsp+68h], rdx ; adresse fournit pour écrire l'addresse du malloc qui contient le contenu formaté
	mov qword ptr [rsp+70h], r8 ; taille du tampon malloc de reponse
	
	;parse les arguments dans la même chaine rcx (equivaut à long long parse_argument(&rcx))
	lea rax, [rip+@parse_argument]
	call rax
	
	; si le nombre d'argument est 0, erreur
	test rax, rax
	jz .erreur_arg_invalid
	
	; si le nombre d'argument est impair, erreur
	test rax, 1  ; rax & 1 = 1 impair
	jnz .erreur_arg_invalid
	
	mov rsi, rcx
	mov rdi, rax
	mov rbx, 0
	
	.boucle:
	mov [rsp+50h], rbx
	
	mov rcx, rsi
	lea rax, [rip+@asm_strlen]
	call rax
	; calcul de la taille pour la position du prochain mot dans le parsing
	mov rdx, rsi ; rdx = pointeur à utiliser
	add rsi, rax
	inc rsi ; prochain pointeur
	
	; décaler pour sauter l'argument paramètre avant qu'il ne soit modifier
	mov rbx, rsi ; sauvgarde
	mov rcx, rsi
	lea rax, [rip+@asm_strlen]
	call rax
	add rsi, rax
	inc rsi ; prochain pointeur
	mov [rsp+58h], rsi ; sauvgarde du prochain pointeur
	mov rsi, rbx ; restore
	
	; programme utilise rdx comme argument 1 -> clé
	; programme utilise rsi comme argument 2 -> valeur
	
	mov rbx, rdx ; sauvgarde
	
	lea rcx, [rip+@_union]
	lea rax, [rip+@asm_strlen]
	call rax
	; vérifier si il y a un union sur un nombre d'argument donné pour alloué que la taille de l'élément maximum
	mov rcx, rbx ; clé
	lea rdx, [rip+@_union]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .union
	
	lea rcx, [rip+@_pack]
	lea rax, [rip+@asm_strlen]
	call rax
	; vérifier si il y a un pack pour savoir si on applique la marge automatique, ou la marge maximum de pack
	mov rcx, rbx ; clé
	lea rdx, [rip+@_pack]
	mov r8, rax
	lea rax, [rip+@asm_strcmp]
	call rax
	cmp rax, 1
	je .pack
	
	; sinon mode normal, passage des arguments individuel
	mov rcx, rbx ; clé
	mov rdx, rsi
	lea rax, [rip+@parse_type_argument]
	call rax
	
	test rcx, rcx
	jz .error_arg_x
	
	; debug affiche chaque octet un par un (pas d'autre code avec ! sinon invalid corruption memoire)
    ;mov [rsp+40h], rcx ; ptr malloc de réponse
	;mov [rsp+48h], rax ; taille de la réponse
	;lea rcx, [rip+@debug]
	;mov rdx, rax
	;mov rax, [rip+@printf]
	;call rax
	;mov rbx, 0
	;.view_boucle:
	;mov r8, [rsp+48h]
	;cmp rbx, r8 ; rbx >= r8 fin
	;jae .next_boucle
	;mov rcx, [rsp+40h]
	;xor rdx, rdx 
	;mov dl, byte ptr [rcx+rbx]
	;lea rcx, [rip+@debug4]
	;mov rax, [rip+@printf]
	;call rax
	;inc rbx
	;jmp .view_boucle
	
	; rcx est déjà le tampon à ajouté 
	mov r8, rdx ; r8 = récupérer si on doit aligné ou non
	mov rdx, rax ;  rdx = taille de l'entrée
	; [rsp+40h] automatique du nombre d'élément dans union restant (lecture dans le caller à rbp+50h)
	; [rsp+48h] automatique de l'état de pack pour l'alignement des éléments (lecture dans le caller à rbp+58h)
	; [rsp+60h] automatique stocke la taille max d'un élément avec padding pour le calcul du padding final
	; [rsp+64h] (dword) nombre d'argument édité automatiquement (lecture dans le caller à rbp+74h)
	; [rsp+68h] adresse fournit pour écrire l'adresse du malloc qui contient le contenu formaté (lecture dans le caller à rbp+78h)
	; [rsp+70h] taille du malloc (lecture dans le caller à rbp+80h)
	lea rax, [rip+@create_parse_table_argument]
	call rax
	
	test rax, rax
	jz .erreur_alloc
	
	;lea rax, [rip+@create_parse_table_argument_dbg]
	;call rax
	
	jmp .next_boucle
	
	.union:
	; lecture de la valeur numérique fournit
	mov rcx, rsi ; ptr
	xor r8, r8 ; taille auto
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	cmp rax, 0 ; valeur nul ou neg, on ignore
	jle .end_boucle
	mov rdx, [rsp+40h]
	mov rcx, rdx ; on conserve, si la valeur est 0, on doit mettre en neg car premier (pour dire qu'il doit comme même créer une case avant de dire que l'on est dans le union)
	cmp rcx, 0 ; si rcx est déjà neg, c'est qu'il y a deux union collé ou plus et qu'ils n'ont pas commencé, on fait une somme negatif
	jl .sub_union_more
	add rdx, rax
	mov [rsp+40h], rdx
	cmp rcx, 0
	jne .end_boucle
	; c'est le premier car il est à 0 on le met en neg
	neg rdx
	mov [rsp+40h], rdx
	jmp .end_boucle
	
	; rajouté du neg
	.sub_union_more:
	sub rdx, rax 
	mov [rsp+40h], rdx
	jmp .end_boucle
	
	.pack:
	; lecture de la valeur numérique fournit
	mov rcx, rsi ; ptr
	xor r8, r8 ; taille auto
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	cmp rax, 0 ; valeur nul ou neg, on remet 0
	jle .pack_set_0
	mov [rsp+48h], rax
	jmp .end_boucle
	
	.pack_set_0:
	mov qword ptr [rsp+48h], 0
	jmp .end_boucle
	
	.next_boucle:
	; rcx est valide et conserver par create_parse_table_argument
	mov rax, [rip+@free]
	call rax
	
	.end_boucle:
	mov rsi, [rsp+58h]
	mov rbx, [rsp+50h]
	add rbx, 2
	cmp rbx, rdi
	jb .boucle

	; valeur de retour
	mov rax, [rsp+68h] ; ptr malloc de réponse
	mov rcx, [rsp+70h] ; taille du malloc de réponse 
	mov edx, dword ptr [rsp+64h] ; nombre de case de réponse (le contenu après l'entête est déjà formaté dans le malloc donc ok)
	mov r8d, dword ptr [rsp+60h] ; taille max de padding (optionnel dans l'enregistrement) pour pouvoir agrantir la structure après
	test r8d, r8d
	jnz .end
	; si la valeur est 0 et que le nombre de case n'est pas NULL, on met par défaut à 1
	test edx, edx ; nombre de case de réponse = 0, on ignore
	jz .end
	mov r8d, 1
	jmp .end
	
	; gestion des erreurs
	.error_arg_x:
	cmp rax, 1
	je .erreur_arg_invalid_key
	cmp rax, 2
	je .erreur_arg_invalid_value
	jmp .erreur
	
	.erreur_alloc:
	lea rcx, [rip+@error_mem]
	mov rax, [rip+@wprintf]
	call rax
	xor rax, rax
	mov rcx, 1 ; pour dire erreur d'alloc, le tableau est perdu
	jmp .end
	
	.erreur_arg_invalid_value:
	lea rcx, [rip+@error_arg_invalid_value]
	mov rax, [rip+@wprintf]
	call rax
	jmp .erreur
	
	.erreur_arg_invalid_key:
	lea rcx, [rip+@error_arg_invalid_key]
	mov rax, [rip+@wprintf]
	call rax
	jmp .erreur
	
	.erreur_arg_invalid:
	lea rcx, [rip+@error_arg_invalid]
	mov rax, [rip+@wprintf]
	call rax
	
	.erreur:
	xor rax, rax
	xor rcx, rcx ; vider rcx pour faire différence entre erreur d'allocation où rcx = 1, pour dire que l'on peut conserver la table (pas utile si on ne fait que créer car on n'ajoute pas d'élément)
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 78h
	ret
end parse_table_argument

; RCX = char ; valeur numérique entière positive ou chaine d'argument a organiser séparer par ; \; ignore le séparateur et \\ devient \ . Doit contenir type;value ...
; return rax pointeur de tableau (avec entête) ou NULL pour erreur
; void* create_table(char *rcx)
proc create_table
	push rbp
	mov rbp, rsp
	sub rsp, 50h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	
	;récupérer les arguments de la chaine fournit rcx si ce n'est pas un nombre unique (taille)
	lea rax, [rip+@asm_strlen]
	call rax
	mov rdi, rax
	
	xor rcx, rcx
	
	.isnum:
	cmp rdi, 0
	jbe .endnum
	mov rdx, [rsp+38h]
	mov cl, byte ptr [rdx+rdi-1] ; sinon on pointe sur \0 après
	mov rax, [rip+@isdigit]
	call rax
	cmp rax, 0
	je .isnotnum
	dec rdi
	jmp .isnum
	
	.isnotnum:
	; appel du formateur d'argument (simplifier pour création uniquement)
	mov rcx, [rsp+38h] ; chaine
	lea rax, [rip+@parse_table_argument_new]
	call rax
	
	test rax, rax
	jz .end ; pas besoin de erreur, rax ne vaut rien
	
	; vérifier si on doit enregistrer le padding max, si oui, on doit ajouter 4 oct
	mov [rsp+40h], rax ; sauvgarde du ptr malloc
	mov rsi, rcx ; sauvgarde de la taille du malloc
	mov dword ptr [rsp+48h], edx ; nombre de case de réponse
	mov dword ptr [rsp+4Ch], r8d ; taille max de padding
	
	
	mov eax, dword ptr [rip+@table_type]
	test eax, eax ; pas de valeur, on n'ajoute pas l'élément de 4 oct max padding
	jz .not_add_padding_max
	add rcx, 4 ; ajout de 4 oct à la taille de réponse 
	.not_add_padding_max:
	
	;créer la case vide de la taille demander avec alloc_table
	mov r8, rcx ; taille du nouveau tableau sans entête
	mov rdi, rcx ; sauvgarde de la taille
	lea rcx, [rip+@table] ; argument 1 début du tableau global
	mov rdx, 0 ; adresse d'écriture NULL car nouvelle table
	lea rax, [rip+@alloc_table]
	call rax
	
	mov rbx, rax ; sauvgarde de l'adresse du tableau à retourné
	
	test rax, rax
	jz .free_parse_table_argument ; pas de case fournit rax ne vaut rien, on libère juste le malloc
	
	; copier le nombre de case de réponse
	add rax, 16 ; position d'écriture du nombre de case (fait partie de l'entête renvoyé par alloc_table)
	mov ecx, dword ptr [rsp+48h]
	mov dword ptr [rax], ecx ; copie le nombre de case
	
	add rax, 4
	
	; copie de la valeur max de padding si besoin
	mov ecx, dword ptr [rip+@table_type]
	test ecx, ecx ; pas de valeur, on n'ajoute pas l'élément de 4 oct max padding
	jz .not_add_padding_max2
	mov ecx, dword ptr [rsp+4Ch] ; taille max de padding
	mov dword ptr [rax], ecx ; écriture du max de padding
	add rax, 4
	.not_add_padding_max2:
	
	; copie le contenu du malloc vers l'emplacement dédier avec memcpy
	mov rcx, rax ; destination de la copie
	mov rdx, [rsp+40h] ; source de la copie
	mov r8, rsi ; taille de la source de copie pour remplir la case
	mov rax, [rip+@memcpy]
	call rax
	
//-------------------------------------------- debut de debug ----------------------------------------------	
	
	; debug affiche le contenu (tableau complet)
	add rdi, 20 ; plus entête de 20 auto
	xor rsi, rsi
	.dd_boucle:
	lea rcx, [rip+@debug4]
	xor rdx, rdx
	mov dl, byte ptr [rbx+rsi]
	mov rax, [rip+@printf]
	call rax
	inc rsi
	cmp rsi, rdi ; rsi <= rdi continue
	jae .end_debug_boucle
	jmp .dd_boucle
	.end_debug_boucle:
	lea rcx, [rip+@debug_zone]
	mov rax, [rip+@printf]
	call rax
	; suite, on appel get_struct_from_table et on affiche que le contenu de la structure
	mov rcx, rbx
	lea rax, [rip+@get_struct_from_table_alloc]
	call rax
	mov rdi, rax ; ptr de réponse
	test rax, rax
	jz .end_debug_boucle2
	mov [rsp+48h], rcx ; taille de la structure [rsp+48h] n'est plus utiliser après, là on ne sent sert que pour dbg
	; affiche l'adresse de réponse
	mov rdx, rax
	lea rcx, [rip+@debug2]
	mov rax, [rip+@printf]
	call rax
	xor rsi, rsi
	.dd_boucle2:
	lea rcx, [rip+@debug4]
	xor rdx, rdx
	mov dl, byte ptr [rdi+rsi]
	mov rax, [rip+@printf]
	call rax
	inc rsi
	cmp rsi, [rsp+48h] ; rsi <= [rsp+48h] continue
	jae .end_debug_boucle2
	jmp .dd_boucle2
	.end_debug_boucle2:
	lea rcx, [rip+@debug_zone]
	mov rax, [rip+@printf]
	call rax
	; libérer l'allocation de la structure
	mov rcx, rdi
	lea rax, [rip+@free_struct_from_table_alloc]
	call rax
	
	; vérifier la sortie d'alignement
	mov rcx, rbx ; tableau
	lea rax, [rip+@estimate_alignment_for_table]
	call rax
	mov rdx, rax
	lea rcx, [rip+@debug2]
	mov rax, [rip+@printf]
	call rax
	
//-------------------------------------------- fin de debug ----------------------------------------------
	
	.free_parse_table_argument:
	; fin de copie, libérer et renvoyé la case
	mov rcx, [rsp+40h] ; adresse du malloc à libérer de la réponse de parse_table_argument_new
	mov rax, [rip+@free]
	call rax
	mov rax, rbx
	jmp .end
	
	.endnum:
	; nombre donc taille à alloué, valeur à déterminer
	mov rcx, [rsp+38h]
	mov r8, 0
	lea rax, [rip+@asm_addr_ascii_int]
	call rax
	mov rdi, rax
	
	;debug affiche la taille du tableau -20 d'entête automatique 
	lea rcx, [rip+@debug]
	mov rdx, rdi
	mov rax, [rip+@printf]
	call rax
	
	;créer la case vide de la taille demander avec alloc_table si la source est locale
	lea rcx, [rip+@table] ; argument 1 début du tableau global
	mov rdx, 0 ; adresse d'écriture NULL car nouvelle table
	mov r8, rdi ; taille du nouveau tableau sans entête
	lea rax, [rip+@alloc_table]
	call rax
	; réponse déjà dans rax donc on finit
	
	mov rbx, rax
	;debug affiche l'adresse du tableau fournit 
	lea rcx, [rip+@debug2]
	mov rdx, rax
	mov rax, [rip+@printf]
	call rax
	mov rax, rbx
	
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 50h
	pop rbp
	ret
end create_table

; RCX = ptr de tableau à ajouter des éléments
; RDX = char ; chaine d'argument a organiser séparer par ; \; ignore le séparateur et \\ devient \ . Doit contenir type;value ...
; return rax pointeur de tableau (avec entête) ou NULL pour erreur
; void* append_table(ptr *rcx, char *rdx)
proc append_table
	push rbp
	mov rbp, rsp
	sub rsp, 60h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	mov [rsp+40h], rdx
	mov [rsp+48h], r10
	
	; faire une allocation du contenu uniquement a partir des cases sans entête et sans max padding si existe
	; calculer le début du contenu
	mov rax, [rcx+8] ; récupérer la taille globale du tableau avec entête
	test rax, rax ; pas de taille erreur
	jz .end ; rax est déjà null donc erreur ok
	
	cmp rax, 20 
	jbe .erreur ; taille invalide ou pas de contenu
	
	sub rax, 20 ; retirer 20
	mov rsi, rcx ; ptr de tableau
	add rsi, 20 ; début du contenu ; sauvgarde de l'adresse de début de la structure
	
	mov r8d, dword ptr [rip+@table_type]
	test r8d, r8d  ; pas de valeur, on ne compte pas l'élément de 4 oct max padding
	jz .not_max_padding
	add rsi, 4 ; décale de 4 de la taille de max padding
	cmp rax, 4 
	jbe .erreur ; taille invalide ou pas de contenu
	sub rax, 4
	.not_max_padding:
	
	mov rdi, rax ; sauvgarde de la taille du contenu actuel
	
	; malloc de la taille fournit
	mov rcx, rdi ; taille
	mov rax, [rip+@malloc]
	call rax
	test rax, rax
	jz .end ; rax est déjà null donc erreur ok
	
	;copie du contenu
	mov rcx, rax ; destination
	mov rdx, rsi ; source
	mov r8, rdi ; taille
	mov rsi, rax ; sauvgarde du ptr malloc
	mov rax, [rip+@memcpy]
	call rax
	
	; récupérer le max padding (déduit ou exacte)
	mov rcx, [rsp+38h] ; ptr de tableau
	lea rax, [rip+@estimate_alignment_for_table]
	call rax
	test rax, rax
	jz .end ; rax est déjà null donc erreur ok
	
	mov r10, rax ; max de padding
	
	; récupérer le nombre de case
	mov rcx, [rsp+38h] ; ptr de tableau
	mov r9d, dword ptr [rcx+16] ; position du dword du nombre de case
	
	mov rcx, [rsp+40h] ; chaine à parser
	mov rdx, rsi ; ptr malloc
	mov r8, rdi ; taille du malloc de la structure
	; r9d est déjà le nombre de case actuel
	; r10 est le max padding
	lea rax, [rip+@parse_table_argument]
	call rax
	
	test rax, rax
	jz .end ; pas besoin de erreur, rax ne vaut rien
	
	; vérifier si on doit enregistrer le padding max, si oui, on doit ajouter 4 oct
	mov [rsp+50h], rax ; sauvgarde du ptr malloc
	mov rsi, rcx ; sauvgarde de la taille du malloc
	mov dword ptr [rsp+58h], edx ; nombre de case de réponse
	mov dword ptr [rsp+5Ch], r8d ; taille max de padding
	
	mov eax, dword ptr [rip+@table_type]
	test eax, eax ; pas de valeur, on n'ajoute pas l'élément de 4 oct max padding
	jz .not_add_padding_max
	add rcx, 4 ; ajout de 4 oct à la taille de réponse 
	.not_add_padding_max:
	
	;modifier la case de la taille demander avec alloc_table
	mov r8, rcx ; taille du nouveau tableau sans entête
	mov rdi, rcx ; sauvgarde de la taille
	lea rcx, [rip+@table] ; argument 1 début du tableau global
	mov rdx, [rsp+38h] ; adresse d'écriture de la table précédente
	lea rax, [rip+@alloc_table]
	call rax
	
	mov rbx, rax ; sauvgarde de l'adresse du tableau à retourné
	
	test rax, rax
	jz .free_parse_table_argument ; pas de case fournit rax ne vaut rien, on libère juste le malloc
	
	; copier le nombre de case de réponse
	add rax, 16 ; position d'écriture du nombre de case (fait partie de l'entête renvoyé par alloc_table)
	mov ecx, dword ptr [rsp+58h]
	mov dword ptr [rax], ecx ; copie le nombre de case
	
	add rax, 4
	
	; copie de la valeur max de padding si besoin
	mov ecx, dword ptr [rip+@table_type]
	test ecx, ecx ; pas de valeur, on n'ajoute pas l'élément de 4 oct max padding
	jz .not_add_padding_max2
	mov ecx, dword ptr [rsp+5Ch] ; taille max de padding
	mov dword ptr [rax], ecx ; écriture du max de padding
	add rax, 4
	.not_add_padding_max2:
	
	; copie le contenu du malloc vers l'emplacement dédier avec memcpy
	mov rcx, rax ; destination de la copie
	mov rdx, [rsp+50h] ; source de la copie
	mov r8, rsi ; taille de la source de copie pour remplir la case
	mov rax, [rip+@memcpy]
	call rax
	
	.free_parse_table_argument:
	; fin de copie, libérer et renvoyé la case
	mov rcx, [rsp+50h] ; adresse du malloc à libérer de la réponse de parse_table_argument
	mov rax, [rip+@free]
	call rax
	mov rax, rbx
	jmp .end
	
	.erreur:
	xor rax, rax
	.end:
	mov r10, [rsp+48h]
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 60h
	pop rbp
	ret
end append_table

; RCX = pointeur de tableau (avec entête)
; return rax pointeur de struct windows AUCUN ALIGNEMENT GARANTI OCT DE DEPART ! (appeler get_struct_from_table_alloc) ou NULL si erreur
; return rcx taille de la struct
proc get_struct_from_table
	sub rsp, 48h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	mov [rsp+38h], rcx
	
	add rcx, 8 ; recuperer la taille de la struct
	mov rsi, [rcx]
	test rsi, rsi ; pas de taille, erreur
	jz .erreur
	cmp rsi, 20 ; la taille est inférieur à l'entête, et il doit y avoir aumoins un oct de contenu
	jbe .erreur
	
	add rcx, 8 ; récupérer le nombre de case
	xor rbx, rbx
	mov ebx, dword ptr [rcx]
	test ebx, ebx ; aucune case, erreur car pas de contenu ou data invalide
	jz .erreur
	
	add rcx, 4
	
	; vérifier si il y a les 4oct à sauter de max padding
	mov eax, dword ptr [rip+@table_type]
	test eax, eax ; pas de valeur, on ne compte pas l'élément de 4 oct max padding
	jz .not_add_padding_max
	add rcx, 4 ;  + 4 oct
	.not_add_padding_max:
	
	; sauter les 4 oct de padding final
	add rcx, 4
	
	; on multiplie ebx qui contient le nombre de case par 8 pour sauter les entêtes donnée de tableau
	xor rdx, rdx
	mov rax, 8
	mul rbx ; rax*rbx
	add rcx, rax ; début de la structure à rendre
	mov rax, rcx ; rax ok
	
	; comme on connait la taille global de l'élément avec entête, 
	; on calcul le pointeur final et on soustrait au pointeur de réponse pour avoir la taille de la struct
	mov rcx, [rsp+38h]
	add rcx, rsi ; ajoute au ptr de début la taille globale
	sub rcx, rax ; soustrait au ptr de début, rcx = taille donc ok
	jmp .end
	
	.erreur:
	xor rax, rax
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 48h
	ret
end get_struct_from_table

; RCX = pointeur de tableau (avec entête)
; return rax doit être free_struct_from_table_alloc (car le contenu de réponse n'est pas forcément _aligned_malloc, si l'alignement est déjà valide)
; return rax pointeur de struct windows ou NULL si erreur. ALIGNEMENT GARANTI 16oct si le mode option n'est pas actif, sinon adapte automatiquement
; return rcx taille de la struct
proc get_struct_from_table_alloc
	sub rsp, 38h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	
	mov rdi, rcx ; sauvgarde du ptr pour chercher si besoin le max padding pour l'alignement
	
	lea rax, [rip+@get_struct_from_table]
	call rax
	test rax, rax
	jz .erreur
	
	mov rbx, rax ; sauvgarde de l'adresse de réponse
	mov rsi, rcx ; sauvgarde de la taille de réponse
	mov rdx, 16 ; alignement
	
	; vérifier si il y a les 4oct de max padding
	mov eax, dword ptr [rip+@table_type]
	test eax, eax ; pas de valeur, on laisse l'alignement à 16oct par défaut
	jz .not_padding_max
	
	mov edx, dword ptr [rdi+20] ; emplacement du padding max et copie de la valeur
	
	.not_padding_max:
	; vérifier si on est déjà aligné, pas besoin d'allocation
	mov r8, rdx ; sauvgarde de l'alignement car div écrase rdx et rax
	xor rdx, rdx
	mov rax, rbx ; ptr de la structure
	div r8 ; rax/r8 = modulo dans rdx
	
	mov rax, rbx ; adresse de réponse si on finit car le modulo est 0 donc valide
	; rcx est déjà la taille que l'on veut
	
	test rdx, rdx ; modulo 0 = ok, on finit
	jz .end
	
	; rcx est déjà la taille que l'on veut comme malloc
	mov rdx, r8 ; rdx est l'alignement
	mov rax, [rip+@_aligned_malloc]
	call rax
	test rax, rax ; erreur d'allocation
	jz .erreur
	
	mov rdi, rax ; rdi ne sert plus, on sauvgarde le ptr de return
	
	;copie du contenu à l'emplacement fournit
	mov rcx, rax ; destination de la copie
	mov rdx, rbx ; source de la copie
	mov r8, rsi ; taille de la source de copie pour remplir la case
	mov rax, [rip+@memcpy]
	call rax
	
	; fin et réponse
	mov rax, rdi ; ptr source
	mov rcx, rsi ; taille
	jmp .end
	
	.erreur:
	xor rax, rax
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 38h
	ret
end get_struct_from_table_alloc

; RCX = pointeur de struct qui provient de get_struct_from_table_alloc
; si le pointeur fournit n'est pas bon, cela va crash
proc free_struct_from_table_alloc
	sub rsp, 38h
	mov [rsp+20h], rbx
    mov [rsp+28h], rsi
    mov [rsp+30h], rdi
	
	test rcx, rcx
	jz .end
	
	mov rdi, rcx ; sauvgarde du ptr à free si besoin
	
	; rcx est déjà l'adresse que l'on cherche
	lea rdx, [rip+@table] ; adresse du tableau static
	lea rax, [rip+@isvalid_zone]
	call rax
	
	cmp rax, 2
	jnz .end ; n'est pas alloc ou adresse invalide
	
	mov rcx, rdi
	mov rax, [rip+@_aligned_free]
	call rax
	
	.end:
	mov rbx, [rsp+20h]
    mov rsi, [rsp+28h]
    mov rdi, [rsp+30h]
	add rsp, 38h
	ret
end free_struct_from_table_alloc

