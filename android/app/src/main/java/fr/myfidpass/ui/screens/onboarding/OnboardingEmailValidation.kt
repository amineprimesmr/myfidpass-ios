package fr.myfidpass.ui.screens.onboarding

object OnboardingEmailValidation {
    private val emailRegex = Regex("^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$", RegexOption.IGNORE_CASE)

    fun normalized(raw: String): String = raw.trim().lowercase()

    fun isValid(raw: String): Boolean = emailRegex.matches(normalized(raw))
}
