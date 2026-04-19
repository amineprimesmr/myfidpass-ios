package fr.myfidpass.data.network

import retrofit2.converter.kotlinx.serialization.asConverterFactory
import fr.myfidpass.BuildConfig
import fr.myfidpass.data.dto.AuthRefreshResponse
import fr.myfidpass.data.dto.RefreshRequest
import fr.myfidpass.data.local.SessionStore
import kotlinx.serialization.encodeToString
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import java.util.concurrent.TimeUnit

class NetworkModule(
    baseUrl: String,
    private val sessionStore: SessionStore,
) {
    private val refreshLock = Any()
    private val httpUrl = baseUrl.toHttpUrl()

    private val refreshClient: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private val logging = HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BODY else HttpLoggingInterceptor.Level.NONE
    }

    private val authInterceptor = Interceptor { chain ->
        val req = chain.request()
        val path = req.url.encodedPath
        if (path in NoAuthPaths) {
            return@Interceptor chain.proceed(req)
        }
        val token = sessionStore.accessToken
        if (token.isNullOrEmpty()) {
            return@Interceptor chain.proceed(req)
        }
        val next = req.newBuilder()
            .header("Authorization", "Bearer $token")
            .build()
        chain.proceed(next)
    }

    private val dashboardInterceptor = Interceptor { chain ->
        val req = chain.request()
        val slug = extractBusinessSlug(req.url.encodedPath)
        if (slug == null) {
            return@Interceptor chain.proceed(req)
        }
        val dash = sessionStore.dashboardTokenForSlug(slug)
        if (dash.isNullOrEmpty()) {
            return@Interceptor chain.proceed(req)
        }
        chain.proceed(req.newBuilder().header("X-Dashboard-Token", dash).build())
    }

    private val refreshInterceptor = Interceptor { chain ->
        val request = chain.request()
        var response = chain.proceed(request)
        if (response.code != 401) return@Interceptor response
        val path = request.url.encodedPath
        if (path.startsWith("/api/auth/")) {
            return@Interceptor response
        }
        if (request.header("X-Retry") == "1") {
            return@Interceptor response
        }
        response.close()
        synchronized(refreshLock) {
            val rt = sessionStore.refreshToken
            if (rt.isNullOrEmpty()) {
                sessionStore.clearSession()
                return@Interceptor chain.proceed(
                    request.newBuilder().header("X-Retry", "1").build(),
                )
            }
            val bodyStr = jsonNet.encodeToString(RefreshRequest(refreshToken = rt))
            val refreshUrl = httpUrl.resolve("/api/auth/refresh")!!
            val refreshReq = okhttp3.Request.Builder()
                .url(refreshUrl)
                .post(bodyStr.toRequestBody("application/json".toMediaType()))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json")
                .build()
            val r = refreshClient.newCall(refreshReq).execute()
            if (!r.isSuccessful) {
                r.close()
                sessionStore.clearSession()
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
            val respBody = r.body?.string()
            r.close()
            if (respBody.isNullOrEmpty()) {
                sessionStore.clearSession()
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
            val refreshed = try {
                jsonNet.decodeFromString<AuthRefreshResponse>(respBody)
            } catch (_: Exception) {
                sessionStore.clearSession()
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
            sessionStore.applyRefreshResponse(refreshed)
            val newToken = sessionStore.accessToken
            if (newToken.isNullOrEmpty()) {
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
            val retry = request.newBuilder()
                .header("Authorization", "Bearer $newToken")
                .removeHeader("X-Retry")
                .build()
            return@Interceptor chain.proceed(retry)
        }
    }

    private val okHttp: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(logging)
        .addInterceptor(authInterceptor)
        .addInterceptor(dashboardInterceptor)
        .addInterceptor(refreshInterceptor)
        .connectTimeout(120, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .build()

    private val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(httpUrl)
        .client(okHttp)
        .addConverterFactory(jsonNet.asConverterFactory("application/json".toMediaType()))
        .build()

    val api: MyfidpassApi = retrofit.create(MyfidpassApi::class.java)

    companion object {
        private val NoAuthPaths = setOf(
            "/api/auth/login",
            "/api/auth/register",
            "/api/auth/refresh",
            "/api/auth/config",
            "/api/auth/forgot-password",
            "/api/auth/reset-password",
            "/api/places/autocomplete",
            "/api/places/details",
            "/api/auth/google",
            "/api/auth/apple",
        )

        private fun extractBusinessSlug(path: String): String? {
            val prefix = "/api/businesses/"
            if (!path.startsWith(prefix)) return null
            val rest = path.removePrefix(prefix)
            val idx = rest.indexOf('/')
            if (idx <= 0) return null
            return java.net.URLDecoder.decode(rest.substring(0, idx), Charsets.UTF_8.name())
        }
    }
}
