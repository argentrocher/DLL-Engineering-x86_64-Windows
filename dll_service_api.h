//dll_service_api.h contient les déclarations nécessaire au linker en C
//By argentropcher Tous droits réservés

#include <stdio.h>
#include <string.h>
#include <windows.h>

#pragma once

#define DLL_SERVICE_API_VERSION 1

//optionnel si c'est fr-simplecode, code d'identification vérifier
#define DLL_SERVICE_EXPECTED_ID 4475980

//type          = objet de type requit                              EX: 'int'
//type_value    = objet de type requit;contenu de l'object          EX: 'int;12'
//type_valueX   = type_value * X séparer par ;                      EX: 'int;12;double;46.4462'
//dll_command   = nom de dll;fonction;typederetour;type_valueX      EX: 'msvcrt.dll;printf;int;char;hello word !\n'

//version de l'api
typedef unsigned int (*fn_version)(void);
//code d'identifiant pour fr-simplecode
typedef unsigned long long (*fn_frc_code_id)(void);


//appel de dll
//fonction de type de retour dynamique
typedef long long (*fn_dll_service)(char *dll_command);
typedef double (*fn_double_dll_service)(char *dll_command);
//version avec concervation de mémoire
typedef long long (*fn_dll_service_mem)(char *dll_command);
typedef double (*fn_double_dll_service_mem)(char *dll_command);
//mémoire de retour de fonction appeler (type de retour également dynamique)
typedef long long (*fn_dll_return)(char *type);
typedef double (*fn_double_dll_return)(char *type);

// Structure compatible C quelconque retournée par la DLL
typedef void *STRUCT;

// En-tête fixe d'un TABLE
typedef struct {
    void *next;  //ptr vers TABLE_HEADER suivant ou NULL si pas de suivant
    unsigned long long size; //taille globale de la TABLE
    unsigned int case_count; //nombre d'élément dans la struct
    //Autres champs non fixes
    //uint32_t max_padding; //optionnel n'existe pas forcément, il peut y avoir final_padding à cette emplacement
    //uint32_t final_padding;
    //uint64_t taille de case X ... *case_count
    //contenu reel de STRUCT potentiel
} TABLE_HEADER;

// Pointeur vers un tableau interne
typedef TABLE_HEADER *TABLE;

#define DLL_RETURN_BUFFER(api) (*(api).return_addr_buffer) //accès au buffer return_addr_buffer directement

typedef struct {
    HMODULE dll; //DLL

    fn_version version; //renvoie la version de la dll
    fn_frc_code_id frc_code_id; //renvoie un code correspondant au module pour fr-simplecode

    long long *return_addr_buffer; //ce n'est pas une fonction mais un tampon de la taille d'un registre 64 qui contient le retour de la dernière fonction appeler

    //partie table
    void (*init_table_global)(int mode); //Initialiser la partie table
    TABLE (*create_table)(char *type_valueX);  //créer une table
    TABLE (*append_table)(TABLE, char *type_valueX); //ajouter à la fin d'un table existante
    unsigned long long (*edit_table)(TABLE, unsigned int case_number, char *type_value, unsigned long long pack_value); //change la valeur d'une case de même type dans une structure
    //type retour dynamique séparer en deux mais même fonction
    long long (*read_table)(TABLE, unsigned int case_number, char *type, unsigned long long pack_value, unsigned long long *size_response); //size_response est 0 en cas d'erreur sinon, la taille de l'objet
    double (*double_read_table)(TABLE, unsigned int case_number, char *type, unsigned long long pack_value, unsigned long long *size_response);
    unsigned long long (*move_struct_in_equal_table) (TABLE, STRUCT); //copie le ptr STRUCT qui doit correspondre au champs dans TABLE
    unsigned long long (*move_return_struct_in_equal_table) (TABLE, STRUCT); //copie la STRUCT qui doit correspondre au champs dans TABLE (attention, l'entrée n'est pas toujours un ptr de structure si la structure fais 1, 2, 4 ou 8 oct, c'est la structure elle même)
    STRUCT (*get_struct_from_table)(TABLE); //renvoie la position de la structure dans TABLE sans vérifier l'alignement
    STRUCT (*get_struct_from_table_alloc)(TABLE); //vérifie l'alignement et corrige si besoin dans un _align_malloc (ATTENTION, n'est pas toujours alloué si l'alignement est correct de base)
    void (*free_struct_from_table_alloc)(STRUCT); //libère la structure si besoin

    //fonction de type de retour dynamique séparer en deux
    fn_dll_service dll_service;
    fn_double_dll_service double_dll_service;
    //version avec dll non libérer
    fn_dll_service_mem dll_service_mem;
    fn_double_dll_service_mem double_dll_service_mem;

    //return de fonction appeler séparer en deux
    fn_dll_return dll_return;
    fn_double_dll_return double_dll_return;

    // fonction qui libère les dlls
    void *(*free_dll_mem)(void);
} DllService;


//fonction de chargement dynamique de toutes les fonctions api v0.1. Retour 1 ok, 0 erreur, si la version change il faudra changer le code, renvoie 2 dans ce cas, 3 si erreur de fonction introuvable, 4 si il y a une restriction de frc_code_id avec id invalide
int InitDllService(DllService *api, char* dll_path) {
    if (!api || !dll_path || !*dll_path)
        return 0;

    memset(api, 0, sizeof(*api));

    api->dll = LoadLibraryA(dll_path);
    if (!api->dll)
        return 0;

    // Fonctions obligatoires pour identifier la DLL
    api->version = (fn_version)
        GetProcAddress(api->dll, "version");

    api->frc_code_id = (fn_frc_code_id)
        GetProcAddress(api->dll, "frc_code_id");

    if (!api->version || !api->frc_code_id)
        goto missing_function;

    // Vérifier la version de l'API avant de charger le reste
#ifdef DLL_SERVICE_API_VERSION
    if (api->version() != DLL_SERVICE_API_VERSION)
        goto incompatible_version;
#endif // DLL_SERVICE_API_VERSION

    // Vérifier l'identité de la DLL si nécessaire
#ifdef DLL_SERVICE_EXPECTED_ID
    if (api->frc_code_id() != DLL_SERVICE_EXPECTED_ID)
        goto invalid_dll;
#endif // DLL_SERVICE_EXPECTED_ID

    // Buffer exporté : adresse de la variable, pas appel de fonction
    api->return_addr_buffer = (long long *)
        GetProcAddress(api->dll, "return_addr_buffer");

    // Partie table
    api->init_table_global = (void (*)(int))
        GetProcAddress(api->dll, "init_table_global");

    api->create_table = (TABLE (*)(char *))
        GetProcAddress(api->dll, "create_table");

    api->append_table = (TABLE (*)(TABLE, char *))
        GetProcAddress(api->dll, "append_table");

    api->edit_table = (unsigned long long (*)(TABLE, unsigned int,
        char *, unsigned long long))
        GetProcAddress(api->dll, "edit_table_case");

    api->read_table = (long long (*)(TABLE, unsigned int, char *,
        unsigned long long, unsigned long long *))
        GetProcAddress(api->dll, "read_table_case");

    // Même fonction exportée, type de retour différent
    api->double_read_table = (double (*)(TABLE, unsigned int, char *,
        unsigned long long, unsigned long long *))
        GetProcAddress(api->dll, "read_table_case");

    api->move_struct_in_equal_table =
        (unsigned long long (*)(TABLE, STRUCT))
        GetProcAddress(api->dll, "move_struct_in_equal_table");

    api->move_return_struct_in_equal_table =
        (unsigned long long (*)(TABLE, STRUCT))
        GetProcAddress(api->dll, "move_return_struct_in_equal_table");

    api->get_struct_from_table = (STRUCT (*)(TABLE))
        GetProcAddress(api->dll, "get_struct_from_table");

    api->get_struct_from_table_alloc = (STRUCT (*)(TABLE))
        GetProcAddress(api->dll, "get_struct_from_table_alloc");

    api->free_struct_from_table_alloc = (void (*)(STRUCT))
        GetProcAddress(api->dll, "free_struct_from_table_alloc");

    // Appels génériques
    api->dll_service = (fn_dll_service)
        GetProcAddress(api->dll, "dll_service");

    api->double_dll_service = (fn_double_dll_service)
        GetProcAddress(api->dll, "dll_service");

    api->dll_service_mem = (fn_dll_service_mem)
        GetProcAddress(api->dll, "dll_service_mem");

    api->double_dll_service_mem = (fn_double_dll_service_mem)
        GetProcAddress(api->dll, "dll_service_mem");

    // Résultat de la fonction appelée
    api->dll_return = (fn_dll_return)
        GetProcAddress(api->dll, "dll_return");

    api->double_dll_return = (fn_double_dll_return)
        GetProcAddress(api->dll, "dll_return");

    // Libération des DLL conservées
    api->free_dll_mem = (void *(*)(void))
        GetProcAddress(api->dll, "free_dll_mem");

    // Vérifier toutes les fonctions obligatoires
    if (!api->init_table_global ||
        !api->create_table ||
        !api->append_table ||
        !api->edit_table ||
        !api->read_table ||
        !api->double_read_table ||
        !api->move_struct_in_equal_table ||
        !api->move_return_struct_in_equal_table ||
        !api->get_struct_from_table ||
        !api->get_struct_from_table_alloc ||
        !api->free_struct_from_table_alloc ||
        !api->dll_service ||
        !api->double_dll_service ||
        !api->dll_service_mem ||
        !api->double_dll_service_mem ||
        !api->dll_return ||
        !api->double_dll_return ||
        !api->free_dll_mem ||
        !api->return_addr_buffer)
    {
        goto missing_function;
    }

    return 1;

#ifdef DLL_SERVICE_API_VERSION
incompatible_version:
    FreeLibrary(api->dll);
    memset(api, 0, sizeof(*api));
    return 2;
#endif // DLL_SERVICE_API_VERSION

missing_function:
    FreeLibrary(api->dll);
    memset(api, 0, sizeof(*api));
    return 3;

#ifdef DLL_SERVICE_EXPECTED_ID
invalid_dll:
    FreeLibrary(api->dll);
    memset(api, 0, sizeof(*api));
    return 4;
#endif // DLL_SERVICE_EXPECTED_ID
}

void CloseDllService(DllService *api) {
    if (!api)
        return;

    if (api->dll) {
        if (api->free_dll_mem) api->free_dll_mem();
        FreeLibrary(api->dll);
    }
    memset(api, 0, sizeof(*api));
}
