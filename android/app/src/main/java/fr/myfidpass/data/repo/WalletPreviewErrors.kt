package fr.myfidpass.data.repo

import kotlinx.serialization.SerializationException
import retrofit2.HttpException

fun mapWalletPreviewError(error: Throwable): String {
    if (error is SerializationException) {
        return "Réponse serveur invalide. Réessayez après actualisation du tableau de bord."
    }
    if (error is HttpException) {
        val parsed = parseHttpError(error)
        return when (error.code()) {
            404 -> parsed.message
                ?: "Membre ou carte introuvable. Actualisez le tableau de bord puis réessayez."
            503 -> when (parsed.code) {
                "google_wallet_unavailable" ->
                    "Google Wallet n'est pas encore configuré sur le serveur."
                "google_wallet_object_unavailable" ->
                    "Impossible de préparer la carte Google Wallet pour l'aperçu."
                else -> parsed.message ?: "Google Wallet indisponible pour le moment."
            }
            else -> parsed.message ?: "Impossible de tester la carte (${error.code()})."
        }
    }
    return error.message ?: "Impossible de tester la carte Wallet."
}
