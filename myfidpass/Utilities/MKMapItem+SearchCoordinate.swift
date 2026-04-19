//
//  MKMapItem+SearchCoordinate.swift
//  myfidpass
//
//  Coordonnées d’un résultat MKLocalSearch : `location` (iOS 26+) ou `placemark` (versions antérieures).
//

import CoreLocation
import MapKit

extension MKMapItem {
    /// Coordonnées du résultat de recherche locale.
    var mf_searchCoordinate: CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return location.coordinate
        }
        return placemark.coordinate
    }
}
