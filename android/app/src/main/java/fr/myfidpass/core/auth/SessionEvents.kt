package fr.myfidpass.core.auth

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/** Aligné iOS `NotificationCenter.myfidpassSessionInvalidated`. */
object SessionEvents {
    private val _invalidated = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val invalidated: SharedFlow<Unit> = _invalidated.asSharedFlow()

    fun notifyInvalidated() {
        _invalidated.tryEmit(Unit)
    }
}
