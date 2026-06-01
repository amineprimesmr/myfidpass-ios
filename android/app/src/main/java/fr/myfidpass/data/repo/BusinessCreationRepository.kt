package fr.myfidpass.data.repo

import fr.myfidpass.data.dto.CreateBusinessFromPlaceRequest
import fr.myfidpass.data.dto.CreateBusinessFromPlaceResponse
import fr.myfidpass.data.dto.CreateBusinessRequest
import fr.myfidpass.data.local.SessionStore
import fr.myfidpass.data.network.MyfidpassApi
import retrofit2.HttpException

class BusinessCreationRepository(
    private val api: MyfidpassApi,
    private val sessionStore: SessionStore,
) {
    suspend fun createFromPlace(
        googlePlaceId: String,
        establishmentName: String,
    ): CreateBusinessFromPlaceResponse {
        val name = establishmentName.trim().take(100)
        return try {
            val resp = api.createBusinessFromPlace(
                CreateBusinessFromPlaceRequest(
                    establishmentName = name,
                    googlePlaceId = googlePlaceId.trim(),
                ),
            )
            applyAfterCreate(resp.slug, resp.businesses)
            resp
        } catch (e: HttpException) {
            if (e.code() == 404) {
                val slug = slugify(name)
                val classic = api.createBusiness(
                    CreateBusinessRequest(name = name, slug = slug, organizationName = name),
                )
                val s = classic.slug ?: slug
                applyAfterCreate(s, null)
                CreateBusinessFromPlaceResponse(slug = s, name = classic.name, organizationName = classic.organizationName)
            } else {
                throw e
            }
        }
    }

    private suspend fun applyAfterCreate(slug: String, businesses: List<fr.myfidpass.data.dto.BusinessDto>?) {
        sessionStore.switchBusiness(slug)
        if (!businesses.isNullOrEmpty()) {
            sessionStore.applyMeResponse(
                fr.myfidpass.data.dto.AuthMeResponse(
                    user = fr.myfidpass.data.dto.AuthUser(email = sessionStore.userEmail),
                    businesses = businesses,
                ),
            )
        } else {
            val me = api.me()
            sessionStore.applyMeResponse(me)
        }
    }

    private fun slugify(name: String): String =
        name.lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
            .take(48)
            .ifEmpty { "commerce" }
}
