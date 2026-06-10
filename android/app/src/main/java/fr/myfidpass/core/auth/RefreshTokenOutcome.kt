package fr.myfidpass.core.auth

enum class RefreshTokenOutcome {
    Success,
    MissingRefreshToken,
    InvalidToken,
    /** Compte supprimé côté serveur — déconnexion immédiate même si le JWT access est encore valide. */
    SessionRevoked,
    TransientFailure,
}
