package fr.myfidpass.core.auth

enum class RefreshTokenOutcome {
    Success,
    MissingRefreshToken,
    InvalidToken,
    TransientFailure,
}
