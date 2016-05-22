import UIKit
import SafariServices
import MapKit

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate{

    @IBOutlet weak var mapView: MKMapView!
    var locationManager: CLLocationManager!
    
    var lastLocation:CLLocation? {
        didSet{
            
            let center = CLLocationCoordinate2D(latitude: lastLocation!.coordinate.latitude, longitude: lastLocation!.coordinate.longitude)
            let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            
            self.mapView.setRegion(region, animated: true)
            
            // remove old annotations
            mapView.removeAnnotations(mapView.annotations)
            
            // drop a pin in the new location
            mapView.addAnnotation(CityAnnotation(coordinate: center))
        }
    }
    
    // establish the location object and set delgates for location and map view
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (CLLocationManager.locationServicesEnabled())
        {
            locationManager = CLLocationManager()
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            
            // will request permission for location using a string in the plist under NSLocationAlwaysUsageDescription
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        mapView.delegate = self
        mapView.showsUserLocation = true  // using for both the blue dot and pin
    }
    
    // there may be a better way to do this with parameters for CLLocationManager
    func mapView(mapView: MKMapView, didUpdateUserLocation userLocation: MKUserLocation) {
        let distanceThreshhold:CLLocationDistance = 10.0 // meters
        
        // avoid effect of GPS drift
        if(lastLocation != nil){
            if(userLocation.location!.distanceFromLocation(lastLocation!) > distanceThreshhold ){
                lastLocation = userLocation.location
            }
        }else{
            lastLocation = userLocation.location
        }

        userLocation.title = "" // prevents the callout for the blu dot
     }
    
    // need to override these if you are doing something more than showing a title and subtitle
    // i.e. adding an icon
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let ca = annotation as? CityAnnotation{
            
            // try to get a reusable annotation view, otherwise create one
            let annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier("myID")  ??
                                 MKPinAnnotationView(annotation: annotation, reuseIdentifier: "myID")
            
            annotationView.annotation = ca
            annotationView.canShowCallout=true
            
            // the code above you essentially get for free, but needs to be specified if 
            // you wish to add accessories as below
            
            annotationView.leftCalloutAccessoryView = ca.forecastView
            annotationView.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure) as UIButton
            
            return annotationView

        }
        else{
            return nil // use the default blue dot
        }
        
    }
    
    // called when the pin is tapped - load the image and other weather data late since it needs to get the current info
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        if let ca = view.annotation as? CityAnnotation{
            // The view will use placeholder text and an activity indicator
            // while the annotation loads the real data in the background
            // when it is done it will update the view with the city and weather info
            ca.loadDataForView(view)
        }
    }
    
    func mapView(mapView: MKMapView, didDeselectAnnotationView view: MKAnnotationView) {
        if let ca = view.annotation as? CityAnnotation{
            // have the ca discard any current weather info it has now
            ca.resetData()
            
            // since the views are resuable need to get the activty view from the reset ca,
            // otherwise we might see the previous weather icon here while the new one loads
            view.leftCalloutAccessoryView = ca.forecastView

        }
    }
    
    
    // called when the accessory is tapped, open url in safari view controller
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        if let urlString = (view.annotation as? CityAnnotation)?.forecastURLString{
            if let url = NSURL(string: urlString){
                let vc = SFSafariViewController(URL: url, entersReaderIfAvailable: true)
                presentViewController(vc, animated: true, completion: nil)
            }
        }
    }
 }

