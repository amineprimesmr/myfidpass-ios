package fr.myfidpass.ui.components

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.CopyrightOverlay
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polygon
import org.osmdroid.views.overlay.compass.CompassOverlay
import org.osmdroid.views.overlay.gestures.RotationGestureOverlay

/** Carte périmètre OpenStreetMap — aligné iOS `PerimeterMapView` (sans MapKit). */
@Composable
fun PerimeterMapView(
    latitude: Double?,
    longitude: Double?,
    radiusMeters: Int,
    modifier: Modifier = Modifier,
    onMapClick: ((Double, Double) -> Unit)? = null,
    showMapChrome: Boolean = true,
) {
    val context = LocalContext.current
    val lat = latitude ?: 48.8566
    val lng = longitude ?: 2.3522
    val hasPoint = latitude != null && longitude != null

    val mapView = remember {
        Configuration.getInstance().userAgentValue = context.packageName
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(showMapChrome)
            zoomController.setVisibility(
                org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER,
            )
            controller.setZoom(17.0)
            if (!showMapChrome) {
                overlays.removeAll { it is CopyrightOverlay || it is CompassOverlay || it is RotationGestureOverlay }
            }
        }
    }

    DisposableEffect(lat, lng, radiusMeters, hasPoint, showMapChrome) {
        mapView.overlays.clear()
        val center = GeoPoint(lat, lng)
        mapView.controller.setCenter(center)
        if (hasPoint) {
            mapView.overlays.add(Marker(mapView).apply {
                position = center
                setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            })
            mapView.overlays.add(
                Polygon().apply {
                    points = Polygon.pointsAsCircle(center, radiusMeters.toDouble())
                    fillPaint.color = 0x33FF0066
                    outlinePaint.color = 0xCCFF0066.toInt()
                    outlinePaint.strokeWidth = 4f
                },
            )
        }
        if (!showMapChrome) {
            mapView.overlays.removeAll {
                it is CopyrightOverlay || it is CompassOverlay || it is RotationGestureOverlay
            }
        }
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
