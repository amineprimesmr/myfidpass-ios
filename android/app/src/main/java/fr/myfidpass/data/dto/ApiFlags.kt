package fr.myfidpass.data.dto

/** API MyFidpass envoie souvent 0/1 au lieu de booléens JSON (aligné iOS). */
fun Int?.isApiTrue(): Boolean = (this ?: 0) != 0

fun Boolean?.toApiFlag(): Int = if (this == true) 1 else 0
