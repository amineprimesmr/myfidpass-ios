package fr.myfidpass.data.repo

import fr.myfidpass.data.dto.FlyerAiGenerateRequest
import fr.myfidpass.data.dto.FlyerAiGenerateSyncResponse
import fr.myfidpass.data.dto.FlyerAiJobStatusResponse
import fr.myfidpass.data.network.MyfidpassApi
import fr.myfidpass.data.network.jsonNet
import kotlinx.coroutines.delay
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

class FlyerAiGenerateException(message: String) : Exception(message)

/** POST flyer/ai-generate puis polling — aligné iOS `FlyerAIGenerateAPI`. */
suspend fun generateFlyerAiAndWait(
    api: MyfidpassApi,
    slug: String,
    request: FlyerAiGenerateRequest,
): FlyerAiJobStatusResponse {
    val body = jsonNet.encodeToJsonElement(FlyerAiGenerateRequest.serializer(), request).jsonObject
    val initial: JsonObject = api.dashboardFlyerAiGenerate(slug, body)

    val jobId = initial["job_id"]?.jsonPrimitive?.content?.trim().orEmpty()
    if (jobId.isNotEmpty()) {
        return pollFlyerAiJob(api, slug, jobId)
    }

    val sync = runCatching {
        jsonNet.decodeFromJsonElement(FlyerAiGenerateSyncResponse.serializer(), initial)
    }.getOrNull()
    if (sync != null && sync.imageBase64.isNotBlank()) {
        return FlyerAiJobStatusResponse(
            status = "done",
            imageBase64 = sync.imageBase64,
            revisedPrompt = sync.revisedPrompt,
            flyerAiGenerationsUsed = sync.flyerAiGenerationsUsed,
            flyerAiGenerationsRemaining = sync.flyerAiGenerationsRemaining,
            flyerAiUnlimited = sync.flyerAiUnlimited,
        )
    }

    throw FlyerAiGenerateException("Réponse serveur inattendue pour la génération IA.")
}

private suspend fun pollFlyerAiJob(
    api: MyfidpassApi,
    slug: String,
    jobId: String,
): FlyerAiJobStatusResponse {
    val deadline = System.currentTimeMillis() + 240_000
    var delayMs = 800L
    while (System.currentTimeMillis() < deadline) {
        delay(delayMs)
        delayMs = minOf(delayMs + 100, 2_000)
        val raw = api.dashboardFlyerAiJob(slug, jobId)
        val status = jsonNet.decodeFromJsonElement(FlyerAiJobStatusResponse.serializer(), raw)
        when (status.status.lowercase()) {
            "done" -> {
                if (status.imageBase64.isNullOrBlank()) {
                    throw FlyerAiGenerateException("Génération terminée sans image.")
                }
                return status
            }
            "failed" -> {
                val msg = status.error?.trim().orEmpty().ifEmpty { "Échec de la génération." }
                throw FlyerAiGenerateException(msg)
            }
        }
    }
    throw FlyerAiGenerateException("La génération prend plus de temps que prévu. Réessayez.")
}
