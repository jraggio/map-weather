// John Raggio

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
            if mapView?.annotations != nil{
                mapView.removeAnnotations(mapView.annotations as [MKAnnotation])
            }
            
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
                // print("didUpdateLocations called and different: \(locations)")
                lastLocation = userLocation.location
            }
        }else{
            // print("didUpdateLocations called and was previously empty: \(locations)")
            lastLocation = userLocation.location
        }

        userLocation.title = "" // prevents the callout for the blu dot
     }
    
    // need to override these if you are doing something more than showing a title and subtitle
    // i.e. adding an icon
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        // try to get a reusable annotation, otherwise create one
        var view = mapView.dequeueReusableAnnotationViewWithIdentifier("myID")
        
        if annotation is CityAnnotation{
            if view == nil {
                view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "myID")
            } else {
                view!.annotation = annotation
            }
            
            view?.canShowCallout=true
            
            // the code above you essentially get for free, what follows is "custom"
            // add an empty image for now.  It will be filled in when the annotation is selected
            view!.leftCalloutAccessoryView = UIImageView(frame: CGRect(x: 0, y: 0, width: 45, height: 45))
            view!.rightCalloutAccessoryView = UIButton(type: UIButtonType.DetailDisclosure) as UIButton

        }
        else if annotation is MKUserLocation{
            view = nil // use the default blue dot
        }
        
        return view
        
    }
    
    // called when the pin is tapped - load the image late since it shows the current weather
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        // set image for CityAnnotation
        if let ca = view.annotation as? CityAnnotation{
            // needed to wait to do this since the callout should have the most recent info to display
            // really should do this on a background thread, but not sure what we would show while waiting
            ca.loadData()
            
            if let imageView = view.leftCalloutAccessoryView as? UIImageView {
                if let url = ca.currentIconImageURL {
                    if let imageData = NSData(contentsOfURL: url){
                        if let image = UIImage(data: imageData){
                            imageView.contentMode = UIViewContentMode.ScaleAspectFill;
                            imageView.image = image
                        }
                    }
                }
            }
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
    
 // now using SFSafariViewController instead of old style web view
    
//    // set the url for the web view
//    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
//        if segue.identifier == "Show Forecast" {
//            if let dvc = segue.destinationViewController as? WebViewController {
//               dvc.urlString = ((sender as? MKAnnotationView)?.annotation as? CityAnnotation)?.forecastURLString
//            }
//        }
//    }

}

class CityAnnotation: NSObject, MKAnnotation{
    
    let coordinate: CLLocationCoordinate2D
    var forecastURLString: String?
    var city: String?
    var temperature: String?
    var currentIconImageURL: NSURL?
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        // Need a placeholder or the pin will suppress callouts!
        city = "Data to be Loaded Later"
    }
    
    var title: String?{
        return city
    }
    
    var subtitle: String? {
        return temperature
    }
   
    // could use error checking here in case json is malformed
    func loadData(){
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        
        if let jsonDict:NSDictionary = getJSON(coordinate){
            let observation = jsonDict["current_observation"] as! NSDictionary
            let location = observation["display_location"] as! NSDictionary
            
            city = (location["full"] as? String)!
            
            // force https since calls to http will fail!  This is due to ATS
            let urlString = observation["icon_url"] as! String
            currentIconImageURL = NSURL(string: urlString.stringByReplacingOccurrencesOfString("http:", withString: "https:"))!
            
            if let fedURLString = observation["forecast_url"] as? String{
                forecastURLString = fedURLString.stringByReplacingOccurrencesOfString("http:", withString: "https:")
            }
            
            temperature = observation["temperature_string"] as? String
        }
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        
    }
    
    private func getJSON(coordinate: CLLocationCoordinate2D) -> NSDictionary?{

        var result:NSDictionary?
        
        let coordinateURLString: String = "https://api.wunderground.com/api/5932fa7b05de42a2/conditions/forecast/alert/q/\(coordinate.latitude),\(coordinate.longitude).json"
        let url: NSURL? = NSURL( string: coordinateURLString)
        
        if let jsonData:NSData = NSData(contentsOfURL: url!){
            do {
                result = try NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.MutableContainers) as? NSDictionary
            } catch let error as NSError {
                print("Failed to load: \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
}

// samples used http, but that gave a runtime warning.  Looks like https works
// Get the city name from lat,long
// https://api.wunderground.com/api/5932fa7b05de42a2/geolookup/q/40.75921100,-73.98463800.json

// get the weather from city name
// https://api.wunderground.com/api/5932fa7b05de42a2/conditions/q/NY/New%20York.json that is retrieved above from lat/long

// forecast for a given lat/long -> this one UNDOCUMENTED call alone gets the city name and the weather
// https://api.wunderground.com/api/5932fa7b05de42a2/conditions/forecast/alert/q/40.75921100,-73.98463800.json


