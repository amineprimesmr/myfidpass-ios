package fr.myfidpass

import android.app.Application
import fr.myfidpass.di.AppContainer

class MyFidpassApplication : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}
