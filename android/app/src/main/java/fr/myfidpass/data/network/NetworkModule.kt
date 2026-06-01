package fr.myfidpass.data.network

import fr.myfidpass.BuildConfig
import fr.myfidpass.core.auth.RefreshTokenCoordinator
import fr.myfidpass.core.auth.RefreshTokenOutcome
import fr.myfidpass.data.local.SessionStore
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.kotlinx.serialization.asConverterFactory
import okhttp3.MediaType.Companion.toMediaType
import java.util.concurrent.TimeUnit

class NetworkModule(
    baseUrl: String,
    private val sessionStore: SessionStore,
    refreshCoordinator: RefreshTokenCoordinator,
) {
    private val httpUrl = baseUrl.toHttpUrl()
    private val refreshCoordinator = refreshCoordinator

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
        chain.proceed(
            req.newBuilder()
                .header("Authorization", "Bearer $token")
                .build(),
        )
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

    /** Refresh proactif avant requête — aligné iOS `ensureValidAccessToken()`. */
    private val proactiveRefreshInterceptor = Interceptor { chain ->
        val path = chain.request().url.encodedPath
        if (path !in NoAuthPaths && path !in AuthPathsExemptFrom401Refresh) {
            refreshCoordinator.ensureValidAccessTokenSync()
        }
        chain.proceed(chain.request())
    }

    private val refreshInterceptor = Interceptor { chain ->
        val request = chain.request()
        val path = request.url.encodedPath
        var response = chain.proceed(request)
        if (response.code != 401) return@Interceptor response
        if (path in AuthPathsExemptFrom401Refresh) {
            return@Interceptor response
        }
        if (request.header("X-Retry") == "1") {
            return@Interceptor response
        }
        response.close()

        val outcome = refreshCoordinator.refreshSync(force = true)
        when (outcome) {
            RefreshTokenOutcome.Success -> {
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
            RefreshTokenOutcome.TransientFailure -> {
                if (fr.myfidpass.core.auth.JwtAccessExpiry.stillWithinValidityWindow(sessionStore.accessToken)) {
                    val token = sessionStore.accessToken
                    if (!token.isNullOrEmpty()) {
                        val retry = request.newBuilder()
                            .header("Authorization", "Bearer $token")
                            .header("X-Retry", "1")
                            .build()
                        return@Interceptor chain.proceed(retry)
                    }
                }
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
            RefreshTokenOutcome.InvalidToken,
            RefreshTokenOutcome.MissingRefreshToken,
            -> {
                refreshCoordinator.terminateSessionIfAppropriate(outcome)
                return@Interceptor chain.proceed(request.newBuilder().header("X-Retry", "1").build())
            }
        }
    }

    private val okHttp: OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(logging)
        .addInterceptor(proactiveRefreshInterceptor)
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
            "/api/auth/check-identifier",
            "/api/auth/email/send-code",
            "/api/auth/email/verify",
        )

        /** 401 sur ces routes ne déclenche pas de refresh (login, refresh lui-même…). `/api/auth/me` est refreshable. */
        private val AuthPathsExemptFrom401Refresh = setOf(
            "/api/auth/login",
            "/api/auth/register",
            "/api/auth/refresh",
            "/api/auth/config",
            "/api/auth/forgot-password",
            "/api/auth/reset-password",
            "/api/auth/google",
            "/api/auth/apple",
            "/api/auth/check-identifier",
            "/api/auth/email/send-code",
            "/api/auth/email/verify",
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
