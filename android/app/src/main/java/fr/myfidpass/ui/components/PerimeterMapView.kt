package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.util.MapTileIndex
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.CopyrightOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import org.osmdroid.views.overlay.compass.CompassOverlay
import org.osmdroid.views.overlay.gestures.RotationGestureOverlay

/** Tuiles sombres CARTO — vrai dark mode (l’inversion MAPNIK reste trop claire). */
private object CartoDarkMatterTileSource : OnlineTileSourceBase(
    "CartoDarkMatter",
    0,
    20,
    256,
    ".png",
    arrayOf(
        "https://a.basemaps.cartocdn.com/dark_all/",
        "https://b.basemaps.cartocdn.com/dark_all/",
        "https://c.basemaps.cartocdn.com/dark_all/",
    ),
    "© OpenStreetMap contributors © CARTO",
) {
    override fun getTileURLString(pMapTileIndex: Long): String =
        baseUrl + MapTileIndex.getZoom(pMapTileIndex) + "/" +
            MapTileIndex.getX(pMapTileIndex) + "/" +
            MapTileIndex.getY(pMapTileIndex) + mImageFilenameEnding
}

private fun perimeterMapZoomLevel(radiusMeters: Int, showMapChrome: Boolean): Double {
    return if (!showMapChrome) {
        when {
            radiusMeters <= 50 -> 14.2
            radiusMeters <= 100 -> 13.6
            radiusMeters <= 200 -> 13.0
            else -> 12.5
        }
    } else {
        when {
            radiusMeters <= 50 -> 16.0
            radiusMeters <= 100 -> 15.3
            else -> 14.8
        }
    }
}

/** Carte périmètre OpenStreetMap — aligné iOS `LocalAutomationReliefMapBackdrop`. */
@Composable
fun PerimeterMapView(
    latitude: Double?,
    longitude: Double?,
    radiusMeters: Int,
    modifier: Modifier = Modifier,
    onMapClick: ((Double, Double) -> Unit)? = null,
    showMapChrome: Boolean = true,
    darkAppearance: Boolean = true,
) {
    val context = LocalContext.current
    val lat = latitude ?: 48.8566
    val lng = longitude ?: 2.3522
    val hasPoint = latitude != null && longitude != null
    val zoomLevel = perimeterMapZoomLevel(radiusMeters, showMapChrome)

    val mapView = remember {
        Configuration.getInstance().userAgentValue = context.packageName
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(showMapChrome)
            zoomController.setVisibility(
                org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER,
            )
            if (!showMapChrome) {
                overlays.removeAll { it is CopyrightOverlay || it is CompassOverlay || it is RotationGestureOverlay }
            }
        }
    }

    DisposableEffect(darkAppearance) {
        if (darkAppearance) {
            mapView.setTileSource(CartoDarkMatterTileSource)
            mapView.overlayManager.tilesOverlay.apply {
                setColorFilter(null)
                setLoadingBackgroundColor(android.graphics.Color.BLACK)
            }
            mapView.setBackgroundColor(android.graphics.Color.BLACK)
        } else {
            mapView.setTileSource(TileSourceFactory.MAPNIK)
            mapView.overlayManager.tilesOverlay.apply {
                setColorFilter(null)
                setLoadingBackgroundColor(android.graphics.Color.TRANSPARENT)
            }
            mapView.setBackgroundColor(android.graphics.Color.TRANSPARENT)
        }
        mapView.invalidate()
        onDispose { }
    }

    DisposableEffect(lat, lng, radiusMeters, hasPoint, showMapChrome, zoomLevel) {
        mapView.overlays.clear()
        val center = GeoPoint(lat, lng)
        mapView.controller.setCenter(center)
        mapView.controller.setZoom(zoomLevel)
        if (hasPoint) {
            mapView.overlays.add(Marker(mapView).apply {
                position = center
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            })
            mapView.overlays.add(
                Polygon().apply {
                    points = Polygon.pointsAsCircle(center, radiusMeters.toDouble())
                    fillPaint.color = 0x332563EB
                    outlinePaint.color = 0xCC2563EB.toInt()
                    outlinePaint.strokeWidth = 4f
                },
            )
        }
        if (!showMapChrome) {
            mapView.overlays.removeAll {
                it is CopyrightOverlay || it is CompassOverlay || it is RotationGestureOverlay
            }
        }
        mapView.invalidate()
        onDispose { }
    }

    if (onMapClick != null) {
        DisposableEffect(onMapClick) {
            val listener = object : org.osmdroid.events.MapEventsReceiver {
                override fun singleTapConfirmedHelper(p: GeoPoint?): Boolean {
                    p ?: return false
                    onMapClick(p.latitude, p.longitude)
                    return true
                }
                override fun longPressHelper(p: GeoPoint?) = false
            }
            val events = org.osmdroid.views.overlay.MapEventsOverlay(listener)
            mapView.overlays.add(0, events)
            onDispose { mapView.overlays.remove(events) }
        }
    }

    AndroidView(
        factory = { mapView },
        modifier = modifier.fillMaxSize(),
        update = { it.invalidate() },
    )
}
